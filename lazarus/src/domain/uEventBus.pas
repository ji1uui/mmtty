unit uEventBus;

{$mode objfpc}{$H+}

// Observer pattern: decoupled publish/subscribe event system.
// All UI and service updates flow through here to avoid direct coupling.

interface

uses
  Classes, SysUtils, SyncObjs, uInterfaces;

type
  TEventHandlerList = specialize TFPGInterfacedObjectList<IEventHandler>;

  TEventSubscription = record
    EventName: string;
    Handlers: TEventHandlerList;
  end;

  // Thread-safe event bus singleton
  TEventBus = class(TInterfacedObject, IEventBus)
  private
    FSubscriptions: TStringList;  // key=eventName, object=TEventHandlerList
    FLock: TCriticalSection;
    class var FInstance: TEventBus;

    function GetOrCreateHandlerList(const AEventName: string): TEventHandlerList;
  public
    constructor Create;
    destructor Destroy; override;

    // IEventBus
    procedure Subscribe(const AEventName: string; AHandler: IEventHandler);
    procedure Unsubscribe(const AEventName: string; AHandler: IEventHandler);
    procedure Publish(const AEventName: string; AData: TObject);

    class function Instance: TEventBus;
    class procedure FreeInstance;
  end;

  // Convenience adapter: connect a method to an event without implementing IEventHandler
  TMethodEventHandler = class(TInterfacedObject, IEventHandler)
  public type
    THandlerProc = procedure(const AEventName: string; AData: TObject) of object;
  private
    FMethod: THandlerProc;
  public
    constructor Create(AMethod: THandlerProc);
    procedure HandleEvent(const AEventName: string; AData: TObject);
  end;

  // Event name constants to avoid magic strings
  TEvents = class
  const
    // Communication events
    COMM_CONNECTED    = 'comm.connected';
    COMM_DISCONNECTED = 'comm.disconnected';
    COMM_ERROR        = 'comm.error';

    // TX lifecycle events
    TX_STARTED        = 'tx.started';
    TX_STOPPED        = 'tx.stopped';
    TX_STATE_CHANGED  = 'tx.state_changed';
    TX_QUEUE_EMPTY    = 'tx.queue_empty';

    // RX decode events
    RX_TEXT_DECODED   = 'rx.text_decoded';
    RX_SIGNAL_LEVEL   = 'rx.signal_level';
    RX_TUNING_OFFSET  = 'rx.tuning_offset';

    // Radio control events
    RADIO_FREQ_CHANGED = 'radio.freq_changed';
    RADIO_MODE_CHANGED = 'radio.mode_changed';

    // Audio events
    AUDIO_LEVEL_UPDATE = 'audio.level';
    AUDIO_ERROR        = 'audio.error';

    // Log events
    LOG_ENTRY_ADDED   = 'log.entry_added';
    QSO_LOGGED        = 'qso.logged';
  end;

  // Typed event data wrappers (avoids casting raw pointers)
  TStringEventData = class
  public
    Value: string;
    constructor Create(const AValue: string);
  end;

  TDoubleEventData = class
  public
    Value: Double;
    constructor Create(AValue: Double);
  end;

  TIntEventData = class
  public
    Value: Integer;
    constructor Create(AValue: Integer);
  end;

implementation

{ TEventBus }

constructor TEventBus.Create;
begin
  inherited Create;
  FSubscriptions := TStringList.Create;
  FSubscriptions.Sorted := True;
  FLock := TCriticalSection.Create;
end;

destructor TEventBus.Destroy;
var
  I: Integer;
begin
  FLock.Acquire;
  try
    for I := 0 to FSubscriptions.Count - 1 do
      FSubscriptions.Objects[I].Free;
    FSubscriptions.Free;
  finally
    FLock.Release;
  end;
  FLock.Free;
  inherited;
end;

function TEventBus.GetOrCreateHandlerList(const AEventName: string): TEventHandlerList;
var
  Idx: Integer;
begin
  Idx := FSubscriptions.IndexOf(AEventName);
  if Idx < 0 then
  begin
    Result := TEventHandlerList.Create;
    FSubscriptions.AddObject(AEventName, Result);
  end
  else
    Result := TEventHandlerList(FSubscriptions.Objects[Idx]);
end;

procedure TEventBus.Subscribe(const AEventName: string; AHandler: IEventHandler);
var
  Handlers: TEventHandlerList;
begin
  FLock.Acquire;
  try
    Handlers := GetOrCreateHandlerList(AEventName);
    if Handlers.IndexOf(AHandler) < 0 then
      Handlers.Add(AHandler);
  finally
    FLock.Release;
  end;
end;

procedure TEventBus.Unsubscribe(const AEventName: string; AHandler: IEventHandler);
var
  Idx, HandlerIdx: Integer;
  Handlers: TEventHandlerList;
begin
  FLock.Acquire;
  try
    Idx := FSubscriptions.IndexOf(AEventName);
    if Idx < 0 then Exit;
    Handlers := TEventHandlerList(FSubscriptions.Objects[Idx]);
    HandlerIdx := Handlers.IndexOf(AHandler);
    if HandlerIdx >= 0 then
      Handlers.Delete(HandlerIdx);
  finally
    FLock.Release;
  end;
end;

procedure TEventBus.Publish(const AEventName: string; AData: TObject);
var
  Idx, I: Integer;
  Handlers: TEventHandlerList;
  Snapshot: array of IEventHandler;
begin
  FLock.Acquire;
  try
    Idx := FSubscriptions.IndexOf(AEventName);
    if Idx < 0 then Exit;
    Handlers := TEventHandlerList(FSubscriptions.Objects[Idx]);
    SetLength(Snapshot, Handlers.Count);
    for I := 0 to Handlers.Count - 1 do
      Snapshot[I] := Handlers[I];
  finally
    FLock.Release;
  end;

  // Dispatch outside the lock to prevent deadlocks
  for I := 0 to High(Snapshot) do
    Snapshot[I].HandleEvent(AEventName, AData);
end;

class function TEventBus.Instance: TEventBus;
begin
  if not Assigned(FInstance) then
    FInstance := TEventBus.Create;
  Result := FInstance;
end;

class procedure TEventBus.FreeInstance;
begin
  FreeAndNil(FInstance);
end;

{ TMethodEventHandler }

constructor TMethodEventHandler.Create(AMethod: THandlerProc);
begin
  inherited Create;
  FMethod := AMethod;
end;

procedure TMethodEventHandler.HandleEvent(const AEventName: string; AData: TObject);
begin
  if Assigned(FMethod) then
    FMethod(AEventName, AData);
end;

{ Typed event data }

constructor TStringEventData.Create(const AValue: string);
begin
  inherited Create;
  Value := AValue;
end;

constructor TDoubleEventData.Create(AValue: Double);
begin
  inherited Create;
  Value := AValue;
end;

constructor TIntEventData.Create(AValue: Integer);
begin
  inherited Create;
  Value := AValue;
end;

initialization
  TEventBus.FInstance := nil;

finalization
  TEventBus.FreeInstance;

end.
