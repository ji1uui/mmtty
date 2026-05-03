unit uTxService;

{$mode objfpc}{$H+}

// TX orchestration service (Facade + Command pattern).
// Owns the TX state machine and drives ITxQueue -> ICommPort -> IPttController.

interface

uses
  Classes, SysUtils, SyncObjs,
  uDomainTypes, uInterfaces, uEventBus, uTxStateMachine;

type
  TTxWorkerThread = class;

  TTxService = class(TInterfacedObject, ITxService)
  private
    FCommPort:    ICommPort;
    FPtt:         IPttController;
    FQueue:       ITxQueue;
    FProfile:     IModulationProfile;
    FBus:         TEventBus;
    FStateMachine: TTxStateMachine;
    FWorker:      TTxWorkerThread;
    FPttDelayMs:  Integer;

    procedure DoAbort;
    procedure NotifyTxStarted;
    procedure NotifyTxStopped;
  public
    constructor Create(
      ACommPort: ICommPort;
      APtt: IPttController;
      AQueue: ITxQueue;
      AProfile: IModulationProfile;
      ABus: TEventBus);
    destructor Destroy; override;

    // ITxService
    procedure SendText(const AText: string);
    procedure SendCommand(const ACommand: TTxCommand);
    procedure Abort;
    procedure Tune(ADurationMs: Integer);
    function GetState: TTxState;

    property State: TTxState read GetState;
    property PttDelayMs: Integer read FPttDelayMs write FPttDelayMs;
  end;

  // Worker thread: drains the TX queue and writes encoded bytes to the port
  TTxWorkerThread = class(TThread)
  private
    FService: TTxService;
    FStopEvent: TEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(AService: TTxService);
    destructor Destroy; override;
    procedure RequestStop;
  end;

implementation

{ TTxWorkerThread }

constructor TTxWorkerThread.Create(AService: TTxService);
begin
  inherited Create(True);  // suspended
  FService := AService;
  FStopEvent := TEvent.Create(nil, True, False, '');
  FreeOnTerminate := False;
end;

destructor TTxWorkerThread.Destroy;
begin
  FStopEvent.Free;
  inherited;
end;

procedure TTxWorkerThread.RequestStop;
begin
  FStopEvent.SetEvent;
  Terminate;
end;

procedure TTxWorkerThread.Execute;
var
  Cmd: TTxCommand;
  Encoded: TBytes;
begin
  while not Terminated do
  begin
    if FStopEvent.WaitFor(1) = wrSignaled then
      Break;

    if not Assigned(FService.FQueue) then Continue;
    if not FService.FQueue.Dequeue(Cmd) then Continue;

    case Cmd.CommandType of
      tcText:
      begin
        if Assigned(FService.FProfile) and Assigned(FService.FCommPort) then
        begin
          // Encode each character and send; break if abort requested
          var Ch: AnsiChar;
          for Ch in AnsiString(Cmd.Data) do
          begin
            if Terminated then Break;
            Encoded := FService.FProfile.EncodeChar(Ch);
            if Length(Encoded) > 0 then
              FService.FCommPort.WriteBytes(Encoded);
          end;
        end;
      end;

      tcSwitchToRx:
      begin
        if Assigned(FService.FPtt) then
          FService.FPtt.SetPtt(False);
        FService.FStateMachine.Transition(tsIdle);
        FService.NotifyTxStopped;
      end;

      tcAbort:
      begin
        FService.DoAbort;
        Break;
      end;

      tcTune:
      begin
        // Tuning is handled by TTxService.Tune directly
      end;
    end;

    if FService.FQueue.IsEmpty then
    begin
      FService.FBus.Publish(TEvents.TX_QUEUE_EMPTY, nil);
    end;
  end;
end;

{ TTxService }

constructor TTxService.Create(
  ACommPort: ICommPort;
  APtt: IPttController;
  AQueue: ITxQueue;
  AProfile: IModulationProfile;
  ABus: TEventBus);
begin
  inherited Create;
  FCommPort := ACommPort;
  FPtt      := APtt;
  FQueue    := AQueue;
  FProfile  := AProfile;
  FBus      := ABus;
  FPttDelayMs := 50;
  FStateMachine := TTxStateMachine.Create(ABus);
  FWorker := TTxWorkerThread.Create(Self);
  FWorker.Start;
end;

destructor TTxService.Destroy;
begin
  if Assigned(FWorker) then
  begin
    FWorker.RequestStop;
    FWorker.WaitFor;
    FWorker.Free;
  end;
  FStateMachine.Free;
  inherited;
end;

procedure TTxService.SendText(const AText: string);
var
  Cmd: TTxCommand;
begin
  Cmd.CommandType := tcText;
  Cmd.Data := AText;
  Cmd.Priority := 0;
  SendCommand(Cmd);
end;

procedure TTxService.SendCommand(const ACommand: TTxCommand);
begin
  if FStateMachine.CurrentState = tsIdle then
  begin
    FStateMachine.Transition(tsWaitingPtt);
    if Assigned(FPtt) then
    begin
      FPtt.SetPtt(True);
      Sleep(FPttDelayMs);  // PTT propagation delay
    end;
    FStateMachine.Transition(tsSending);
    NotifyTxStarted;
  end;
  FQueue.Enqueue(ACommand);
end;

procedure TTxService.Abort;
begin
  var Cmd: TTxCommand;
  Cmd.CommandType := tcAbort;
  Cmd.Data := '';
  Cmd.Priority := 100;
  FQueue.Enqueue(Cmd);
end;

procedure TTxService.Tune(ADurationMs: Integer);
begin
  if FStateMachine.CurrentState <> tsIdle then Exit;
  FStateMachine.Transition(tsTuning);
  if Assigned(FPtt) then FPtt.SetPtt(True);
  Sleep(ADurationMs);
  if Assigned(FPtt) then FPtt.SetPtt(False);
  FStateMachine.Transition(tsIdle);
end;

function TTxService.GetState: TTxState;
begin
  Result := FStateMachine.CurrentState;
end;

procedure TTxService.DoAbort;
begin
  FQueue.Clear;
  FStateMachine.Transition(tsAborting);
  if Assigned(FPtt) then FPtt.SetPtt(False);
  FStateMachine.Transition(tsIdle);
  NotifyTxStopped;
end;

procedure TTxService.NotifyTxStarted;
begin
  FBus.Publish(TEvents.TX_STARTED, nil);
end;

procedure TTxService.NotifyTxStopped;
begin
  FBus.Publish(TEvents.TX_STOPPED, nil);
end;

end.
