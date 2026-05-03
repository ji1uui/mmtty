unit uComm;

{$mode objfpc}{$H+}

// Communication port adapter layer (Adapter + Template Method pattern).
// TAbstractCommPort defines the template; platform adapters override primitives.
// Win32 serial adapter is provided; additional adapters (EXTFSK, virtual) follow the same contract.

interface

uses
  Classes, SysUtils,
  {$IFDEF WINDOWS}
  Windows, Registry,
  {$ENDIF}
  uDomainTypes, uInterfaces, uEventBus;

type
  // =========================================================================
  // Abstract base — Template Method pattern
  // =========================================================================
  TAbstractCommPort = class(TInterfacedObject, ICommPort, IPttController)
  private
    FState: TCommState;
    FPortName: string;
    FBus: TEventBus;
  protected
    procedure SetState(AState: TCommState);

    // Primitives for subclasses (Template Method)
    function DoOpen(const APortName: string; ABaudRate: Integer): Boolean; virtual; abstract;
    procedure DoClose; virtual; abstract;
    function DoWrite(const AData: TBytes): Integer; virtual; abstract;
    function DoRead(ABuffer: TBytes; ACount: Integer): Integer; virtual; abstract;
    procedure DoSetRts(AActive: Boolean); virtual;
    procedure DoSetDtr(AActive: Boolean); virtual;
  public
    constructor Create(ABus: TEventBus);

    // ICommPort
    function Open(const APortName: string; ABaudRate: Integer): Boolean;
    procedure Close;
    function WriteBytes(const AData: TBytes): Integer;
    function ReadBytes(ABuffer: TBytes; ACount: Integer): Integer;
    function GetState: TCommState;
    function GetPortName: string;

    // IPttController
    procedure SetPtt(AActive: Boolean);
    function GetPtt: Boolean; virtual;
    procedure SetRts(AActive: Boolean);
    procedure SetDtr(AActive: Boolean);

    property State: TCommState read GetState;
    property PortName: string read GetPortName;
  end;

  // =========================================================================
  // Win32 serial port adapter
  // =========================================================================
  TSerialCommPort = class(TAbstractCommPort)
  private
    {$IFDEF WINDOWS}
    FHandle: THandle;
    {$ENDIF}
    FPttActive: Boolean;
    FPttViaRts: Boolean;  // True=RTS, False=DTR
  protected
    function DoOpen(const APortName: string; ABaudRate: Integer): Boolean; override;
    procedure DoClose; override;
    function DoWrite(const AData: TBytes): Integer; override;
    function DoRead(ABuffer: TBytes; ACount: Integer): Integer; override;
    procedure DoSetRts(AActive: Boolean); override;
    procedure DoSetDtr(AActive: Boolean); override;
  public
    constructor Create(ABus: TEventBus; APttViaRts: Boolean = True);
    function GetPtt: Boolean; override;

    class function EnumeratePorts: TStringList;
  end;

  // =========================================================================
  // Null port — Null Object pattern, for testing / no-hardware mode
  // =========================================================================
  TNullCommPort = class(TAbstractCommPort)
  private
    FPttActive: Boolean;
  protected
    function DoOpen(const APortName: string; ABaudRate: Integer): Boolean; override;
    procedure DoClose; override;
    function DoWrite(const AData: TBytes): Integer; override;
    function DoRead(ABuffer: TBytes; ACount: Integer): Integer; override;
    procedure DoSetRts(AActive: Boolean); override;
    procedure DoSetDtr(AActive: Boolean); override;
  public
    function GetPtt: Boolean; override;
  end;

implementation

{ TAbstractCommPort }

constructor TAbstractCommPort.Create(ABus: TEventBus);
begin
  inherited Create;
  FState := csDisconnected;
  FBus := ABus;
end;

procedure TAbstractCommPort.SetState(AState: TCommState);
begin
  FState := AState;
end;

function TAbstractCommPort.Open(const APortName: string; ABaudRate: Integer): Boolean;
begin
  SetState(csConnecting);
  FPortName := APortName;
  Result := DoOpen(APortName, ABaudRate);
  if Result then
  begin
    SetState(csConnected);
    FBus.Publish(TEvents.COMM_CONNECTED, TStringEventData.Create(APortName));
  end
  else
  begin
    SetState(csError);
    FBus.Publish(TEvents.COMM_ERROR,
      TStringEventData.Create('Failed to open: ' + APortName));
  end;
end;

procedure TAbstractCommPort.Close;
begin
  if FState = csDisconnected then Exit;
  SetState(csDisconnecting);
  DoClose;
  SetState(csDisconnected);
  FBus.Publish(TEvents.COMM_DISCONNECTED, TStringEventData.Create(FPortName));
end;

function TAbstractCommPort.WriteBytes(const AData: TBytes): Integer;
begin
  if FState <> csConnected then begin Result := -1; Exit; end;
  Result := DoWrite(AData);
end;

function TAbstractCommPort.ReadBytes(ABuffer: TBytes; ACount: Integer): Integer;
begin
  if FState <> csConnected then begin Result := -1; Exit; end;
  Result := DoRead(ABuffer, ACount);
end;

function TAbstractCommPort.GetState: TCommState;
begin
  Result := FState;
end;

function TAbstractCommPort.GetPortName: string;
begin
  Result := FPortName;
end;

procedure TAbstractCommPort.SetPtt(AActive: Boolean);
begin
  SetRts(AActive);
end;

function TAbstractCommPort.GetPtt: Boolean;
begin
  Result := False;
end;

procedure TAbstractCommPort.SetRts(AActive: Boolean);
begin
  DoSetRts(AActive);
end;

procedure TAbstractCommPort.SetDtr(AActive: Boolean);
begin
  DoSetDtr(AActive);
end;

procedure TAbstractCommPort.DoSetRts(AActive: Boolean);
begin
end;

procedure TAbstractCommPort.DoSetDtr(AActive: Boolean);
begin
end;

{ TSerialCommPort }

constructor TSerialCommPort.Create(ABus: TEventBus; APttViaRts: Boolean);
begin
  inherited Create(ABus);
  FPttViaRts := APttViaRts;
  FPttActive := False;
  {$IFDEF WINDOWS}
  FHandle := INVALID_HANDLE_VALUE;
  {$ENDIF}
end;

function TSerialCommPort.DoOpen(const APortName: string; ABaudRate: Integer): Boolean;
{$IFDEF WINDOWS}
var
  DCB: TDCB;
  Timeouts: TCommTimeouts;
begin
  FHandle := CreateFile(
    PChar('\\.\' + APortName),
    GENERIC_READ or GENERIC_WRITE,
    0, nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    0);

  if FHandle = INVALID_HANDLE_VALUE then begin Result := False; Exit; end;

  FillChar(DCB, SizeOf(DCB), 0);
  DCB.DCBlength := SizeOf(DCB);
  DCB.BaudRate  := ABaudRate;
  DCB.ByteSize  := 8;
  DCB.StopBits  := ONESTOPBIT;
  DCB.Parity    := NOPARITY;
  DCB.Flags     := dcb_Binary;

  if not SetCommState(FHandle, DCB) then
  begin
    CloseHandle(FHandle);
    FHandle := INVALID_HANDLE_VALUE;
    Result := False;
    Exit;
  end;

  Timeouts.ReadIntervalTimeout         := 1;
  Timeouts.ReadTotalTimeoutMultiplier  := 0;
  Timeouts.ReadTotalTimeoutConstant    := 1;
  Timeouts.WriteTotalTimeoutMultiplier := 0;
  Timeouts.WriteTotalTimeoutConstant   := 0;
  SetCommTimeouts(FHandle, Timeouts);
  Result := True;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

procedure TSerialCommPort.DoClose;
begin
  {$IFDEF WINDOWS}
  if FHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FHandle);
    FHandle := INVALID_HANDLE_VALUE;
  end;
  {$ENDIF}
end;

function TSerialCommPort.DoWrite(const AData: TBytes): Integer;
{$IFDEF WINDOWS}
var
  Written: DWORD;
begin
  if FHandle = INVALID_HANDLE_VALUE then begin Result := -1; Exit; end;
  if WriteFile(FHandle, AData[0], Length(AData), Written, nil) then
    Result := Written
  else
    Result := -1;
end;
{$ELSE}
begin
  Result := -1;
end;
{$ENDIF}

function TSerialCommPort.DoRead(ABuffer: TBytes; ACount: Integer): Integer;
{$IFDEF WINDOWS}
var
  BytesRead: DWORD;
begin
  if FHandle = INVALID_HANDLE_VALUE then begin Result := -1; Exit; end;
  if ReadFile(FHandle, ABuffer[0], ACount, BytesRead, nil) then
    Result := BytesRead
  else
    Result := -1;
end;
{$ELSE}
begin
  Result := -1;
end;
{$ENDIF}

procedure TSerialCommPort.DoSetRts(AActive: Boolean);
begin
  {$IFDEF WINDOWS}
  if FHandle <> INVALID_HANDLE_VALUE then
    if AActive then EscapeCommFunction(FHandle, SETRTS)
    else EscapeCommFunction(FHandle, CLRRTS);
  {$ENDIF}
  if FPttViaRts then FPttActive := AActive;
end;

procedure TSerialCommPort.DoSetDtr(AActive: Boolean);
begin
  {$IFDEF WINDOWS}
  if FHandle <> INVALID_HANDLE_VALUE then
    if AActive then EscapeCommFunction(FHandle, SETDTR)
    else EscapeCommFunction(FHandle, CLRDTR);
  {$ENDIF}
  if not FPttViaRts then FPttActive := AActive;
end;

function TSerialCommPort.GetPtt: Boolean;
begin
  Result := FPttActive;
end;

class function TSerialCommPort.EnumeratePorts: TStringList;
{$IFDEF WINDOWS}
var
  Reg: TRegistry;
  Names: TStringList;
  I: Integer;
begin
  Result := TStringList.Create;
  Reg := TRegistry.Create(KEY_READ);
  Names := TStringList.Create;
  try
    Reg.RootKey := HKEY_LOCAL_MACHINE;
    if Reg.OpenKey('HARDWARE\DEVICEMAP\SERIALCOMM', False) then
    begin
      Reg.GetValueNames(Names);
      for I := 0 to Names.Count - 1 do
        Result.Add(Reg.ReadString(Names[I]));
      Reg.CloseKey;
    end;
  finally
    Reg.Free;
    Names.Free;
  end;
end;
{$ELSE}
begin
  Result := TStringList.Create;
end;
{$ENDIF}

{ TNullCommPort }

function TNullCommPort.DoOpen(const APortName: string; ABaudRate: Integer): Boolean;
begin
  Result := True;
end;

procedure TNullCommPort.DoClose;
begin
end;

function TNullCommPort.DoWrite(const AData: TBytes): Integer;
begin
  Result := Length(AData);
end;

function TNullCommPort.DoRead(ABuffer: TBytes; ACount: Integer): Integer;
begin
  Result := 0;
end;

procedure TNullCommPort.DoSetRts(AActive: Boolean);
begin
  FPttActive := AActive;
end;

procedure TNullCommPort.DoSetDtr(AActive: Boolean);
begin
  FPttActive := AActive;
end;

function TNullCommPort.GetPtt: Boolean;
begin
  Result := FPttActive;
end;

end.
