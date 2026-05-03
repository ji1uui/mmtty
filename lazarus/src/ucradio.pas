unit ucradio;

{$mode objfpc}{$H+}

// Radio controller (Adapter pattern).
// IRadioController wraps CAT (Computer Aided Transceiver) protocol.
// Concrete adapters: TYaesuCatAdapter, TIcomCiVAdapter, TNullRadioController.
// Additional rigs plug in by implementing IRadioController without touching call sites.

interface

uses
  Classes, SysUtils,
  uDomainTypes, uInterfaces, uEventBus, uComm;

type
  TCatProtocol = (cpYaesu, cpIcom, cpKenwood, cpFlrig, cpNone);

  // =========================================================================
  // Abstract CAT adapter base — Template Method
  // =========================================================================
  TAbstractRadioController = class(TInterfacedObject, IRadioController)
  private
    FFrequency: Int64;
    FMode: TRadioMode;
    FConnected: Boolean;
    FBus: TEventBus;
  protected
    FCommPort: ICommPort;

    procedure SetFrequencyInternal(AHz: Int64); virtual; abstract;
    function GetFrequencyInternal: Int64; virtual; abstract;
    procedure SetModeInternal(AMode: TRadioMode); virtual; abstract;
    function GetModeInternal: TRadioMode; virtual; abstract;
    function DoConnect(const APortName: string; ABaudRate: Integer): Boolean; virtual; abstract;
    procedure DoDisconnect; virtual; abstract;

    function ModeToString(AMode: TRadioMode): string;
    function StringToMode(const AStr: string): TRadioMode;
  public
    constructor Create(ABus: TEventBus);

    // IRadioController
    function Connect(const APortName: string; ABaudRate: Integer): Boolean;
    procedure Disconnect;
    function SetFrequency(AHz: Int64): Boolean;
    function GetFrequency: Int64;
    function SetMode(AMode: TRadioMode): Boolean;
    function GetMode: TRadioMode;
    function GetIsConnected: Boolean;

    property Frequency: Int64 read GetFrequency write SetFrequency;
    property Mode: TRadioMode read GetMode write SetMode;
    property IsConnected: Boolean read GetIsConnected;
  end;

  // =========================================================================
  // Yaesu CAT adapter (FT-817/847/991 etc.)
  // =========================================================================
  TYaesuCatAdapter = class(TAbstractRadioController)
  protected
    procedure SetFrequencyInternal(AHz: Int64); override;
    function GetFrequencyInternal: Int64; override;
    procedure SetModeInternal(AMode: TRadioMode); override;
    function GetModeInternal: TRadioMode; override;
    function DoConnect(const APortName: string; ABaudRate: Integer): Boolean; override;
    procedure DoDisconnect; override;
  private
    function YaesuModeCode(AMode: TRadioMode): Byte;
    procedure SendCommand(const ACmd: TBytes);
    function ReadResponse(AExpected: Integer): TBytes;
  end;

  // =========================================================================
  // Null radio controller — Null Object pattern (no hardware)
  // =========================================================================
  TNullRadioController = class(TAbstractRadioController)
  private
    FFreq: Int64;
    FModeInternal: TRadioMode;
  protected
    procedure SetFrequencyInternal(AHz: Int64); override;
    function GetFrequencyInternal: Int64; override;
    procedure SetModeInternal(AMode: TRadioMode); override;
    function GetModeInternal: TRadioMode; override;
    function DoConnect(const APortName: string; ABaudRate: Integer): Boolean; override;
    procedure DoDisconnect; override;
  end;

  // Factory
  TRadioControllerFactory = class
  public
    class function Create(
      AProtocol: TCatProtocol;
      ABus: TEventBus): IRadioController;
  end;

implementation

{ TAbstractRadioController }

constructor TAbstractRadioController.Create(ABus: TEventBus);
begin
  inherited Create;
  FBus := ABus;
  FFrequency := 14070000;
  FMode := rmRTTY;
  FConnected := False;
end;

function TAbstractRadioController.ModeToString(AMode: TRadioMode): string;
begin
  case AMode of
    rmCW:      Result := 'CW';
    rmSSB:     Result := 'SSB';
    rmAM:      Result := 'AM';
    rmFM:      Result := 'FM';
    rmRTTY:    Result := 'RTTY';
    rmDigital: Result := 'DIG';
  else
    Result := 'USB';
  end;
end;

function TAbstractRadioController.StringToMode(const AStr: string): TRadioMode;
var
  S: string;
begin
  S := UpperCase(AStr);
  if S = 'CW'   then Result := rmCW
  else if S = 'AM'   then Result := rmAM
  else if S = 'FM'   then Result := rmFM
  else if S = 'RTTY' then Result := rmRTTY
  else if S = 'DIG'  then Result := rmDigital
  else Result := rmSSB;
end;

function TAbstractRadioController.Connect(const APortName: string; ABaudRate: Integer): Boolean;
begin
  Result := DoConnect(APortName, ABaudRate);
  FConnected := Result;
  if Result then
    FBus.Publish(TEvents.RADIO_FREQ_CHANGED,
      TIntEventData.Create(GetFrequencyInternal));
end;

procedure TAbstractRadioController.Disconnect;
begin
  DoDisconnect;
  FConnected := False;
end;

function TAbstractRadioController.SetFrequency(AHz: Int64): Boolean;
begin
  if not FConnected then begin Result := False; Exit; end;
  SetFrequencyInternal(AHz);
  FFrequency := AHz;
  FBus.Publish(TEvents.RADIO_FREQ_CHANGED, TIntEventData.Create(AHz));
  Result := True;
end;

function TAbstractRadioController.GetFrequency: Int64;
begin
  if FConnected then
    Result := GetFrequencyInternal
  else
    Result := FFrequency;
end;

function TAbstractRadioController.SetMode(AMode: TRadioMode): Boolean;
begin
  if not FConnected then begin Result := False; Exit; end;
  SetModeInternal(AMode);
  FMode := AMode;
  FBus.Publish(TEvents.RADIO_MODE_CHANGED,
    TStringEventData.Create(ModeToString(AMode)));
  Result := True;
end;

function TAbstractRadioController.GetMode: TRadioMode;
begin
  if FConnected then
    Result := GetModeInternal
  else
    Result := FMode;
end;

function TAbstractRadioController.GetIsConnected: Boolean;
begin
  Result := FConnected;
end;

{ TYaesuCatAdapter }

function TYaesuCatAdapter.DoConnect(const APortName: string; ABaudRate: Integer): Boolean;
begin
  FCommPort := TSerialCommPort.Create(nil, False);
  Result := FCommPort.Open(APortName, ABaudRate);
end;

procedure TYaesuCatAdapter.DoDisconnect;
begin
  if Assigned(FCommPort) then
    FCommPort.Close;
end;

function TYaesuCatAdapter.YaesuModeCode(AMode: TRadioMode): Byte;
begin
  case AMode of
    rmSSB:     Result := $01;
    rmCW:      Result := $02;
    rmAM:      Result := $04;
    rmFM:      Result := $08;
    rmRTTY:    Result := $0A;
    rmDigital: Result := $0C;
  else
    Result := $01;
  end;
end;

procedure TYaesuCatAdapter.SendCommand(const ACmd: TBytes);
begin
  if Assigned(FCommPort) and (FCommPort.State = csConnected) then
    FCommPort.WriteBytes(ACmd);
end;

function TYaesuCatAdapter.ReadResponse(AExpected: Integer): TBytes;
begin
  SetLength(Result, AExpected);
  if Assigned(FCommPort) and (FCommPort.State = csConnected) then
    FCommPort.ReadBytes(Result, AExpected)
  else
    SetLength(Result, 0);
end;

procedure TYaesuCatAdapter.SetFrequencyInternal(AHz: Int64);
var
  Cmd: TBytes;
  BCD: Int64;
begin
  // Yaesu 5-byte CAT: FA command (FT-991 etc.) — simplified BCD encoding
  BCD := AHz div 10;  // 10-Hz resolution
  SetLength(Cmd, 5);
  Cmd[0] := (BCD shr 28) and $FF;
  Cmd[1] := (BCD shr 20) and $FF;
  Cmd[2] := (BCD shr 12) and $FF;
  Cmd[3] := (BCD shr 4)  and $FF;
  Cmd[4] := $01;  // Set frequency opcode
  SendCommand(Cmd);
end;

function TYaesuCatAdapter.GetFrequencyInternal: Int64;
var
  Cmd, Resp: TBytes;
begin
  SetLength(Cmd, 5);
  FillChar(Cmd[0], 5, 0);
  Cmd[4] := $03;  // Read frequency opcode
  SendCommand(Cmd);
  Resp := ReadResponse(5);
  if Length(Resp) >= 4 then
    Result := (Int64(Resp[0]) shl 28 or Int64(Resp[1]) shl 20 or
               Int64(Resp[2]) shl 12 or Int64(Resp[3]) shl 4) * 10
  else
    Result := 0;
end;

procedure TYaesuCatAdapter.SetModeInternal(AMode: TRadioMode);
var
  Cmd: TBytes;
begin
  SetLength(Cmd, 5);
  FillChar(Cmd[0], 5, 0);
  Cmd[0] := YaesuModeCode(AMode);
  Cmd[4] := $07;  // Set mode opcode
  SendCommand(Cmd);
end;

function TYaesuCatAdapter.GetModeInternal: TRadioMode;
begin
  Result := rmRTTY;  // Simplified: read mode not implemented in this stub
end;

{ TNullRadioController }

function TNullRadioController.DoConnect(const APortName: string; ABaudRate: Integer): Boolean;
begin
  FFreq := 14070000;
  FModeInternal := rmRTTY;
  Result := True;
end;

procedure TNullRadioController.DoDisconnect;
begin
end;

procedure TNullRadioController.SetFrequencyInternal(AHz: Int64);
begin
  FFreq := AHz;
end;

function TNullRadioController.GetFrequencyInternal: Int64;
begin
  Result := FFreq;
end;

procedure TNullRadioController.SetModeInternal(AMode: TRadioMode);
begin
  FModeInternal := AMode;
end;

function TNullRadioController.GetModeInternal: TRadioMode;
begin
  Result := FModeInternal;
end;

{ TRadioControllerFactory }

class function TRadioControllerFactory.Create(
  AProtocol: TCatProtocol; ABus: TEventBus): IRadioController;
begin
  case AProtocol of
    cpYaesu: Result := TYaesuCatAdapter.Create(ABus);
    cpNone:  Result := TNullRadioController.Create(ABus);
  else
    Result := TNullRadioController.Create(ABus);
  end;
end;

end.
