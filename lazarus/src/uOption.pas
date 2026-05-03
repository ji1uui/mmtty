unit uOption;

{$mode objfpc}{$H+}

// Application configuration store (Repository pattern).
// TIniConfigStore implements IConfigStore backed by an INI file.
// All option reads/writes go through the interface — UI forms never touch TIniFile directly.

interface

uses
  Classes, SysUtils, IniFiles, SyncObjs,
  uDomainTypes, uInterfaces, uEventBus;

const
  // INI section names
  SEC_COMM    = 'Comm';
  SEC_AUDIO   = 'Audio';
  SEC_RTTY    = 'RTTY';
  SEC_UI      = 'UI';
  SEC_LOGGING = 'Logging';

type
  // =========================================================================
  // INI-file backed config store
  // =========================================================================
  TIniConfigStore = class(TInterfacedObject, IConfigStore)
  private
    FFilePath: string;
    FIni: TMemIniFile;
    FLock: TCriticalSection;
    FDirty: Boolean;
    FBus: TEventBus;
  public
    constructor Create(const AFilePath: string; ABus: TEventBus);
    destructor Destroy; override;

    // IConfigStore
    function GetString(const AKey, ADefault: string): string;
    procedure SetString(const AKey, AValue: string);
    function GetInteger(const AKey: string; ADefault: Integer): Integer;
    procedure SetInteger(const AKey: string; AValue: Integer);
    function GetFloat(const AKey: string; ADefault: Double): Double;
    procedure SetFloat(const AKey: string; AValue: Double);
    function GetBoolean(const AKey: string; ADefault: Boolean): Boolean;
    procedure SetBoolean(const AKey: string; AValue: Boolean);
    procedure Save;
    procedure Load;

    function IsDirty: Boolean;
  end;

  // =========================================================================
  // Typed option accessor: strongly-typed overlay on IConfigStore
  // =========================================================================
  TAppOptions = class
  private
    FStore: IConfigStore;
  public
    constructor Create(AStore: IConfigStore);

    // Communication
    function CommPort: string;
    procedure SetCommPort(const AValue: string);
    function CommBaud: Integer;
    procedure SetCommBaud(AValue: Integer);
    function PttViaRts: Boolean;
    procedure SetPttViaRts(AValue: Boolean);

    // Audio
    function AudioInDevice: Integer;
    procedure SetAudioInDevice(AValue: Integer);
    function AudioOutDevice: Integer;
    procedure SetAudioOutDevice(AValue: Integer);
    function SampleRate: Integer;
    procedure SetSampleRate(AValue: Integer);

    // RTTY
    function RttyBaud: Double;
    procedure SetRttyBaud(AValue: Double);
    function RttyShift: Double;
    procedure SetRttyShift(AValue: Double);
    function RttyMark: Double;
    procedure SetRttyMark(AValue: Double);
    function UoS: Boolean;
    procedure SetUoS(AValue: Boolean);

    // UI
    function WindowLeft: Integer;
    procedure SetWindowLeft(AValue: Integer);
    function WindowTop: Integer;
    procedure SetWindowTop(AValue: Integer);
    function WindowWidth: Integer;
    procedure SetWindowWidth(AValue: Integer);
    function WindowHeight: Integer;
    procedure SetWindowHeight(AValue: Integer);

    // Logging
    function LogFilePath: string;
    procedure SetLogFilePath(const AValue: string);
    function QsoFilePath: string;
    procedure SetQsoFilePath(const AValue: string);

    procedure SaveAll;
    procedure LoadAll;

    property Store: IConfigStore read FStore;
  end;

  // =========================================================================
  // In-memory config store for testing
  // =========================================================================
  TMemoryConfigStore = class(TInterfacedObject, IConfigStore)
  private
    FValues: TStringList;
    function BuildKey(const AKey: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    function GetString(const AKey, ADefault: string): string;
    procedure SetString(const AKey, AValue: string);
    function GetInteger(const AKey: string; ADefault: Integer): Integer;
    procedure SetInteger(const AKey: string; AValue: Integer);
    function GetFloat(const AKey: string; ADefault: Double): Double;
    procedure SetFloat(const AKey: string; AValue: Double);
    function GetBoolean(const AKey: string; ADefault: Boolean): Boolean;
    procedure SetBoolean(const AKey: string; AValue: Boolean);
    procedure Save;
    procedure Load;
  end;

implementation

{ TIniConfigStore }

constructor TIniConfigStore.Create(const AFilePath: string; ABus: TEventBus);
begin
  inherited Create;
  FFilePath := AFilePath;
  FBus   := ABus;
  FDirty := False;
  FLock  := TCriticalSection.Create;
  FIni   := TMemIniFile.Create(AFilePath);
end;

destructor TIniConfigStore.Destroy;
begin
  if FDirty then Save;
  FIni.Free;
  FLock.Free;
  inherited;
end;

// Key format: "Section/Name" -> split on '/' for INI section+key
function TIniConfigStore.GetString(const AKey, ADefault: string): string;
var
  Sep: Integer;
  Section, Name: string;
begin
  Sep := Pos('/', AKey);
  if Sep > 0 then
  begin
    Section := Copy(AKey, 1, Sep - 1);
    Name := Copy(AKey, Sep + 1, MaxInt);
  end
  else
  begin
    Section := 'General';
    Name := AKey;
  end;

  FLock.Acquire;
  try
    Result := FIni.ReadString(Section, Name, ADefault);
  finally
    FLock.Release;
  end;
end;

procedure TIniConfigStore.SetString(const AKey, AValue: string);
var
  Sep: Integer;
  Section, Name: string;
begin
  Sep := Pos('/', AKey);
  if Sep > 0 then
  begin
    Section := Copy(AKey, 1, Sep - 1);
    Name := Copy(AKey, Sep + 1, MaxInt);
  end
  else
  begin
    Section := 'General';
    Name := AKey;
  end;

  FLock.Acquire;
  try
    FIni.WriteString(Section, Name, AValue);
    FDirty := True;
  finally
    FLock.Release;
  end;
end;

function TIniConfigStore.GetInteger(const AKey: string; ADefault: Integer): Integer;
begin
  Result := StrToIntDef(GetString(AKey, IntToStr(ADefault)), ADefault);
end;

procedure TIniConfigStore.SetInteger(const AKey: string; AValue: Integer);
begin
  SetString(AKey, IntToStr(AValue));
end;

function TIniConfigStore.GetFloat(const AKey: string; ADefault: Double): Double;
begin
  Result := StrToFloatDef(GetString(AKey, FloatToStr(ADefault)), ADefault);
end;

procedure TIniConfigStore.SetFloat(const AKey: string; AValue: Double);
begin
  SetString(AKey, FloatToStr(AValue));
end;

function TIniConfigStore.GetBoolean(const AKey: string; ADefault: Boolean): Boolean;
var
  S: string;
begin
  S := UpperCase(GetString(AKey, BoolToStr(ADefault, True)));
  Result := (S = 'TRUE') or (S = '1') or (S = 'YES');
end;

procedure TIniConfigStore.SetBoolean(const AKey: string; AValue: Boolean);
begin
  SetString(AKey, BoolToStr(AValue, True));
end;

procedure TIniConfigStore.Save;
begin
  FLock.Acquire;
  try
    FIni.UpdateFile;
    FDirty := False;
  finally
    FLock.Release;
  end;
end;

procedure TIniConfigStore.Load;
begin
  FLock.Acquire;
  try
    FIni.Rename(FFilePath, True);
  finally
    FLock.Release;
  end;
end;

function TIniConfigStore.IsDirty: Boolean;
begin
  Result := FDirty;
end;

{ TAppOptions }

constructor TAppOptions.Create(AStore: IConfigStore);
begin
  inherited Create;
  FStore := AStore;
end;

function TAppOptions.CommPort: string;
begin
  Result := FStore.GetString(SEC_COMM + '/Port', 'COM1');
end;

procedure TAppOptions.SetCommPort(const AValue: string);
begin
  FStore.SetString(SEC_COMM + '/Port', AValue);
end;

function TAppOptions.CommBaud: Integer;
begin
  Result := FStore.GetInteger(SEC_COMM + '/Baud', 9600);
end;

procedure TAppOptions.SetCommBaud(AValue: Integer);
begin
  FStore.SetInteger(SEC_COMM + '/Baud', AValue);
end;

function TAppOptions.PttViaRts: Boolean;
begin
  Result := FStore.GetBoolean(SEC_COMM + '/PttViaRts', True);
end;

procedure TAppOptions.SetPttViaRts(AValue: Boolean);
begin
  FStore.SetBoolean(SEC_COMM + '/PttViaRts', AValue);
end;

function TAppOptions.AudioInDevice: Integer;
begin
  Result := FStore.GetInteger(SEC_AUDIO + '/InDevice', 0);
end;

procedure TAppOptions.SetAudioInDevice(AValue: Integer);
begin
  FStore.SetInteger(SEC_AUDIO + '/InDevice', AValue);
end;

function TAppOptions.AudioOutDevice: Integer;
begin
  Result := FStore.GetInteger(SEC_AUDIO + '/OutDevice', 0);
end;

procedure TAppOptions.SetAudioOutDevice(AValue: Integer);
begin
  FStore.SetInteger(SEC_AUDIO + '/OutDevice', AValue);
end;

function TAppOptions.SampleRate: Integer;
begin
  Result := FStore.GetInteger(SEC_AUDIO + '/SampleRate', 11025);
end;

procedure TAppOptions.SetSampleRate(AValue: Integer);
begin
  FStore.SetInteger(SEC_AUDIO + '/SampleRate', AValue);
end;

function TAppOptions.RttyBaud: Double;
begin
  Result := FStore.GetFloat(SEC_RTTY + '/BaudRate', 45.45);
end;

procedure TAppOptions.SetRttyBaud(AValue: Double);
begin
  FStore.SetFloat(SEC_RTTY + '/BaudRate', AValue);
end;

function TAppOptions.RttyShift: Double;
begin
  Result := FStore.GetFloat(SEC_RTTY + '/Shift', 170.0);
end;

procedure TAppOptions.SetRttyShift(AValue: Double);
begin
  FStore.SetFloat(SEC_RTTY + '/Shift', AValue);
end;

function TAppOptions.RttyMark: Double;
begin
  Result := FStore.GetFloat(SEC_RTTY + '/Mark', 2295.0);
end;

procedure TAppOptions.SetRttyMark(AValue: Double);
begin
  FStore.SetFloat(SEC_RTTY + '/Mark', AValue);
end;

function TAppOptions.UoS: Boolean;
begin
  Result := FStore.GetBoolean(SEC_RTTY + '/UoS', True);
end;

procedure TAppOptions.SetUoS(AValue: Boolean);
begin
  FStore.SetBoolean(SEC_RTTY + '/UoS', AValue);
end;

function TAppOptions.WindowLeft: Integer;
begin
  Result := FStore.GetInteger(SEC_UI + '/Left', 100);
end;

procedure TAppOptions.SetWindowLeft(AValue: Integer);
begin
  FStore.SetInteger(SEC_UI + '/Left', AValue);
end;

function TAppOptions.WindowTop: Integer;
begin
  Result := FStore.GetInteger(SEC_UI + '/Top', 100);
end;

procedure TAppOptions.SetWindowTop(AValue: Integer);
begin
  FStore.SetInteger(SEC_UI + '/Top', AValue);
end;

function TAppOptions.WindowWidth: Integer;
begin
  Result := FStore.GetInteger(SEC_UI + '/Width', 900);
end;

procedure TAppOptions.SetWindowWidth(AValue: Integer);
begin
  FStore.SetInteger(SEC_UI + '/Width', AValue);
end;

function TAppOptions.WindowHeight: Integer;
begin
  Result := FStore.GetInteger(SEC_UI + '/Height', 600);
end;

procedure TAppOptions.SetWindowHeight(AValue: Integer);
begin
  FStore.SetInteger(SEC_UI + '/Height', AValue);
end;

function TAppOptions.LogFilePath: string;
begin
  Result := FStore.GetString(SEC_LOGGING + '/LogFile', 'mmtty.log');
end;

procedure TAppOptions.SetLogFilePath(const AValue: string);
begin
  FStore.SetString(SEC_LOGGING + '/LogFile', AValue);
end;

function TAppOptions.QsoFilePath: string;
begin
  Result := FStore.GetString(SEC_LOGGING + '/QsoFile', 'mmtty.adi');
end;

procedure TAppOptions.SetQsoFilePath(const AValue: string);
begin
  FStore.SetString(SEC_LOGGING + '/QsoFile', AValue);
end;

procedure TAppOptions.SaveAll;
begin
  FStore.Save;
end;

procedure TAppOptions.LoadAll;
begin
  FStore.Load;
end;

{ TMemoryConfigStore }

constructor TMemoryConfigStore.Create;
begin
  inherited Create;
  FValues := TStringList.Create;
  FValues.Sorted := True;
end;

destructor TMemoryConfigStore.Destroy;
begin
  FValues.Free;
  inherited;
end;

function TMemoryConfigStore.BuildKey(const AKey: string): string;
begin
  Result := UpperCase(AKey);
end;

function TMemoryConfigStore.GetString(const AKey, ADefault: string): string;
var
  Idx: Integer;
begin
  Idx := FValues.IndexOfName(BuildKey(AKey));
  if Idx < 0 then Result := ADefault
  else Result := FValues.ValueFromIndex[Idx];
end;

procedure TMemoryConfigStore.SetString(const AKey, AValue: string);
begin
  FValues.Values[BuildKey(AKey)] := AValue;
end;

function TMemoryConfigStore.GetInteger(const AKey: string; ADefault: Integer): Integer;
begin
  Result := StrToIntDef(GetString(AKey, ''), ADefault);
end;

procedure TMemoryConfigStore.SetInteger(const AKey: string; AValue: Integer);
begin
  SetString(AKey, IntToStr(AValue));
end;

function TMemoryConfigStore.GetFloat(const AKey: string; ADefault: Double): Double;
begin
  Result := StrToFloatDef(GetString(AKey, ''), ADefault);
end;

procedure TMemoryConfigStore.SetFloat(const AKey: string; AValue: Double);
begin
  SetString(AKey, FloatToStr(AValue));
end;

function TMemoryConfigStore.GetBoolean(const AKey: string; ADefault: Boolean): Boolean;
var
  S: string;
begin
  S := UpperCase(GetString(AKey, BoolToStr(ADefault, True)));
  Result := (S = 'TRUE') or (S = '1') or (S = 'YES');
end;

procedure TMemoryConfigStore.SetBoolean(const AKey: string; AValue: Boolean);
begin
  SetString(AKey, BoolToStr(AValue, True));
end;

procedure TMemoryConfigStore.Save;
begin
  // No persistence for memory store
end;

procedure TMemoryConfigStore.Load;
begin
end;

end.
