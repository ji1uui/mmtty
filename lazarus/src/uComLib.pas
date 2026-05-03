unit uComLib;

{$mode objfpc}{$H+}

// Communication port factory (Abstract Factory + Registry pattern).
// Decouples consumers from concrete port types; new backends plug in via registration.

interface

uses
  Classes, SysUtils, uDomainTypes, uInterfaces, uEventBus, uComm;

type
  TCommPortType = (
    cptSerial,    // Physical RS-232 / USB-serial
    cptExtFsk,    // EXTFSK virtual keyer
    cptNull       // Null object (testing / no hardware)
  );

  // TX queue: thread-safe ring buffer implementing ITxQueue
  TTxCommandQueue = class(TInterfacedObject, ITxQueue)
  private
    FItems: array of TTxCommand;
    FHead, FTail, FCount: Integer;
    FCapacity: Integer;
    FLock: TRTLCriticalSection;
  public
    constructor Create(ACapacity: Integer = 256);
    destructor Destroy; override;

    procedure Enqueue(const ACommand: TTxCommand);
    function Dequeue(out ACommand: TTxCommand): Boolean;
    function Peek(out ACommand: TTxCommand): Boolean;
    procedure Clear;
    function GetCount: Integer;
    function GetIsEmpty: Boolean;

    property Count: Integer read GetCount;
    property IsEmpty: Boolean read GetIsEmpty;
  end;

  // Factory: creates comm port instances by type
  TCommPortFactory = class
  public
    class function Create(
      AType: TCommPortType;
      ABus: TEventBus;
      APttViaRts: Boolean = True): ICommPort;

    class function CreateFromConfig(
      const ATypeName: string;
      ABus: TEventBus): ICommPort;

    class function CreateTxQueue(ACapacity: Integer = 256): ITxQueue;
  end;

implementation

uses
  SyncObjs;

{ TTxCommandQueue }

constructor TTxCommandQueue.Create(ACapacity: Integer);
begin
  inherited Create;
  FCapacity := ACapacity;
  SetLength(FItems, ACapacity);
  FHead := 0;
  FTail := 0;
  FCount := 0;
  InitCriticalSection(FLock);
end;

destructor TTxCommandQueue.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited;
end;

procedure TTxCommandQueue.Enqueue(const ACommand: TTxCommand);
begin
  EnterCriticalSection(FLock);
  try
    if FCount >= FCapacity then
      raise EInvalidOperation.Create('TX queue full');
    FItems[FTail] := ACommand;
    FTail := (FTail + 1) mod FCapacity;
    Inc(FCount);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTxCommandQueue.Dequeue(out ACommand: TTxCommand): Boolean;
begin
  EnterCriticalSection(FLock);
  try
    if FCount = 0 then begin Result := False; Exit; end;
    ACommand := FItems[FHead];
    FHead := (FHead + 1) mod FCapacity;
    Dec(FCount);
    Result := True;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTxCommandQueue.Peek(out ACommand: TTxCommand): Boolean;
begin
  EnterCriticalSection(FLock);
  try
    if FCount = 0 then begin Result := False; Exit; end;
    ACommand := FItems[FHead];
    Result := True;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TTxCommandQueue.Clear;
begin
  EnterCriticalSection(FLock);
  try
    FHead := 0;
    FTail := 0;
    FCount := 0;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTxCommandQueue.GetCount: Integer;
begin
  EnterCriticalSection(FLock);
  try
    Result := FCount;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTxCommandQueue.GetIsEmpty: Boolean;
begin
  Result := GetCount = 0;
end;

{ TCommPortFactory }

class function TCommPortFactory.Create(
  AType: TCommPortType;
  ABus: TEventBus;
  APttViaRts: Boolean): ICommPort;
begin
  case AType of
    cptSerial: Result := TSerialCommPort.Create(ABus, APttViaRts);
    cptNull:   Result := TNullCommPort.Create(ABus);
  else
    Result := TNullCommPort.Create(ABus);
  end;
end;

class function TCommPortFactory.CreateFromConfig(
  const ATypeName: string;
  ABus: TEventBus): ICommPort;
var
  Upper: string;
begin
  Upper := UpperCase(ATypeName);
  if Upper = 'SERIAL' then
    Result := Create(cptSerial, ABus)
  else if Upper = 'NULL' then
    Result := Create(cptNull, ABus)
  else
    raise EArgumentException.CreateFmt('Unknown comm port type: %s', [ATypeName]);
end;

class function TCommPortFactory.CreateTxQueue(ACapacity: Integer): ITxQueue;
begin
  Result := TTxCommandQueue.Create(ACapacity);
end;

end.
