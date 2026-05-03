unit uServiceLocator;

{$mode objfpc}{$H+}

// Service Locator / lightweight DI container.
// Components register themselves; consumers resolve by interface GUID.
// Prefer constructor injection where possible; use this for cross-cutting
// singleton services (EventBus, Logger, Config).

interface

uses
  Classes, SysUtils, uInterfaces;

type
  EServiceNotFound = class(Exception);
  EServiceAlreadyRegistered = class(Exception);

  TServiceLocator = class
  private
    FServices: TStringList;  // key = GUID string, value = IInterface
    class var FInstance: TServiceLocator;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Register(const AGUID: TGUID; AService: IInterface);
    procedure RegisterOrReplace(const AGUID: TGUID; AService: IInterface);
    function Resolve(const AGUID: TGUID): IInterface;
    function TryResolve(const AGUID: TGUID; out AService: IInterface): Boolean;
    procedure Unregister(const AGUID: TGUID);
    procedure Clear;

    // Typed helpers
    function ResolveCommPort: ICommPort;
    function ResolvePttController: IPttController;
    function ResolveTxQueue: ITxQueue;
    function ResolveAudioInput: IAudioInput;
    function ResolveAudioOutput: IAudioOutput;
    function ResolveLogSink: ILogSink;
    function ResolveConfigStore: IConfigStore;
    function ResolveRadioController: IRadioController;
    function ResolveTxService: ITxService;
    function ResolveRxService: IRxService;

    class function Instance: TServiceLocator;
    class procedure FreeInstance;
  end;

implementation

{ TServiceLocator }

constructor TServiceLocator.Create;
begin
  inherited Create;
  FServices := TStringList.Create;
  FServices.Sorted := True;
end;

destructor TServiceLocator.Destroy;
begin
  Clear;
  FServices.Free;
  inherited;
end;

procedure TServiceLocator.Register(const AGUID: TGUID; AService: IInterface);
var
  Key: string;
begin
  Key := GUIDToString(AGUID);
  if FServices.IndexOf(Key) >= 0 then
    raise EServiceAlreadyRegistered.CreateFmt(
      'Service already registered: %s', [Key]);
  FServices.AddObject(Key, TObject(Pointer(AService)));
  AService._AddRef;
end;

procedure TServiceLocator.RegisterOrReplace(const AGUID: TGUID; AService: IInterface);
var
  Key: string;
  Idx: Integer;
  Old: IInterface;
begin
  Key := GUIDToString(AGUID);
  Idx := FServices.IndexOf(Key);
  if Idx >= 0 then
  begin
    Old := IInterface(Pointer(FServices.Objects[Idx]));
    if Assigned(Old) then Old._Release;
    FServices.Objects[Idx] := TObject(Pointer(AService));
  end
  else
    FServices.AddObject(Key, TObject(Pointer(AService)));
  AService._AddRef;
end;

function TServiceLocator.Resolve(const AGUID: TGUID): IInterface;
begin
  if not TryResolve(AGUID, Result) then
    raise EServiceNotFound.CreateFmt(
      'Service not found: %s', [GUIDToString(AGUID)]);
end;

function TServiceLocator.TryResolve(const AGUID: TGUID; out AService: IInterface): Boolean;
var
  Idx: Integer;
begin
  Idx := FServices.IndexOf(GUIDToString(AGUID));
  if Idx < 0 then
  begin
    AService := nil;
    Result := False;
  end
  else
  begin
    AService := IInterface(Pointer(FServices.Objects[Idx]));
    Result := True;
  end;
end;

procedure TServiceLocator.Unregister(const AGUID: TGUID);
var
  Idx: Integer;
  Svc: IInterface;
begin
  Idx := FServices.IndexOf(GUIDToString(AGUID));
  if Idx >= 0 then
  begin
    Svc := IInterface(Pointer(FServices.Objects[Idx]));
    if Assigned(Svc) then Svc._Release;
    FServices.Delete(Idx);
  end;
end;

procedure TServiceLocator.Clear;
var
  I: Integer;
  Svc: IInterface;
begin
  for I := 0 to FServices.Count - 1 do
  begin
    Svc := IInterface(Pointer(FServices.Objects[I]));
    if Assigned(Svc) then Svc._Release;
  end;
  FServices.Clear;
end;

function TServiceLocator.ResolveCommPort: ICommPort;
begin
  Result := ICommPort(Resolve(ICommPort));
end;

function TServiceLocator.ResolvePttController: IPttController;
begin
  Result := IPttController(Resolve(IPttController));
end;

function TServiceLocator.ResolveTxQueue: ITxQueue;
begin
  Result := ITxQueue(Resolve(ITxQueue));
end;

function TServiceLocator.ResolveAudioInput: IAudioInput;
begin
  Result := IAudioInput(Resolve(IAudioInput));
end;

function TServiceLocator.ResolveAudioOutput: IAudioOutput;
begin
  Result := IAudioOutput(Resolve(IAudioOutput));
end;

function TServiceLocator.ResolveLogSink: ILogSink;
begin
  Result := ILogSink(Resolve(ILogSink));
end;

function TServiceLocator.ResolveConfigStore: IConfigStore;
begin
  Result := IConfigStore(Resolve(IConfigStore));
end;

function TServiceLocator.ResolveRadioController: IRadioController;
begin
  Result := IRadioController(Resolve(IRadioController));
end;

function TServiceLocator.ResolveTxService: ITxService;
begin
  Result := ITxService(Resolve(ITxService));
end;

function TServiceLocator.ResolveRxService: IRxService;
begin
  Result := IRxService(Resolve(IRxService));
end;

class function TServiceLocator.Instance: TServiceLocator;
begin
  if not Assigned(FInstance) then
    FInstance := TServiceLocator.Create;
  Result := FInstance;
end;

class procedure TServiceLocator.FreeInstance;
begin
  FreeAndNil(FInstance);
end;

initialization
  TServiceLocator.FInstance := nil;

finalization
  TServiceLocator.FreeInstance;

end.
