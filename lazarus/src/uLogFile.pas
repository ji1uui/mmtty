unit uLogFile;

{$mode objfpc}{$H+}

// Log persistence (Repository pattern).
// TFileLogSink implements ILogSink; TQsoFileRepository implements IQsoRepository.
// Consumers depend on interfaces only — swap backends without touching call sites.

interface

uses
  Classes, SysUtils, SyncObjs,
  uDomainTypes, uInterfaces, uEventBus;

type
  // =========================================================================
  // File-based log sink (ILogSink)
  // =========================================================================
  TFileLogSink = class(TInterfacedObject, ILogSink)
  private
    FFilePath: string;
    FStream: TFileStream;
    FLock: TCriticalSection;
    FMinLevel: TLogLevel;
    FIsOpen: Boolean;

    function LevelLabel(ALevel: TLogLevel): string;
    function FormatEntry(const AEntry: TLogEntry): string;
  public
    constructor Create(const AFilePath: string; AMinLevel: TLogLevel = llInfo);
    destructor Destroy; override;

    function Open: Boolean;
    procedure Close;

    // ILogSink
    procedure Log(const AEntry: TLogEntry);
    procedure Flush;
    function GetIsOpen: Boolean;

    property IsOpen: Boolean read GetIsOpen;
    property MinLevel: TLogLevel read FMinLevel write FMinLevel;
  end;

  // =========================================================================
  // ADIF-format QSO repository (IQsoRepository)
  // =========================================================================
  TQsoFileRepository = class(TInterfacedObject, IQsoRepository)
  private
    FFilePath: string;
    FRecords: TList;
    FDirty: Boolean;
    FBus: TEventBus;

    function FormatAdif(const AQso: TQsoRecord): string;
    function ParseAdif(const ALine: string; out AQso: TQsoRecord): Boolean;
    function AdifField(const ATag, AValue: string): string;
    function ReadAdifField(const ALine, ATag: string; out AValue: string): Boolean;
  public
    constructor Create(const AFilePath: string; ABus: TEventBus);
    destructor Destroy; override;

    procedure Append(const AQso: TQsoRecord);
    function FindByCallsign(const ACallsign: string): TQsoRecord;
    procedure Save;
    procedure Load;

    function Count: Integer;
  end;

  // =========================================================================
  // Composite log sink: fan-out to multiple sinks
  // =========================================================================
  TCompositeLogSink = class(TInterfacedObject, ILogSink)
  private
    FSinks: TInterfaceList;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddSink(ASink: ILogSink);
    procedure RemoveSink(ASink: ILogSink);

    procedure Log(const AEntry: TLogEntry);
    procedure Flush;
    function GetIsOpen: Boolean;
  end;

  // =========================================================================
  // Logger helper: convenience class for creating TLogEntry
  // =========================================================================
  TLogger = class
  private
    FSink: ILogSink;
    FSource: string;
  public
    constructor Create(ASink: ILogSink; const ASource: string);

    procedure Debug(const AMsg: string);
    procedure Info(const AMsg: string);
    procedure Warning(const AMsg: string);
    procedure Error(const AMsg: string);
    procedure LogFmt(ALevel: TLogLevel; const AFmt: string; const AArgs: array of const);
  end;

implementation

{ TFileLogSink }

constructor TFileLogSink.Create(const AFilePath: string; AMinLevel: TLogLevel);
begin
  inherited Create;
  FFilePath := AFilePath;
  FMinLevel := AMinLevel;
  FIsOpen   := False;
  FStream   := nil;
  FLock     := TCriticalSection.Create;
end;

destructor TFileLogSink.Destroy;
begin
  Close;
  FLock.Free;
  inherited;
end;

function TFileLogSink.Open: Boolean;
begin
  FLock.Acquire;
  try
    if FIsOpen then begin Result := True; Exit; end;
    try
      if FileExists(FFilePath) then
        FStream := TFileStream.Create(FFilePath, fmOpenWrite or fmShareDenyWrite)
      else
        FStream := TFileStream.Create(FFilePath, fmCreate or fmShareDenyWrite);
      FStream.Seek(0, soEnd);
      FIsOpen := True;
      Result  := True;
    except
      FIsOpen := False;
      Result  := False;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TFileLogSink.Close;
begin
  FLock.Acquire;
  try
    if Assigned(FStream) then
    begin
      FStream.Free;
      FStream := nil;
    end;
    FIsOpen := False;
  finally
    FLock.Release;
  end;
end;

function TFileLogSink.LevelLabel(ALevel: TLogLevel): string;
begin
  case ALevel of
    llDebug:   Result := 'DEBUG';
    llInfo:    Result := 'INFO ';
    llWarning: Result := 'WARN ';
    llError:   Result := 'ERROR';
  else
    Result := '?????';
  end;
end;

function TFileLogSink.FormatEntry(const AEntry: TLogEntry): string;
begin
  Result := Format('[%s] %s [%s] %s',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', AEntry.Timestamp),
     LevelLabel(AEntry.Level),
     AEntry.Source,
     AEntry.Message]) + LineEnding;
end;

procedure TFileLogSink.Log(const AEntry: TLogEntry);
var
  Line: string;
  Bytes: TBytes;
begin
  if AEntry.Level < FMinLevel then Exit;
  if not FIsOpen then Exit;

  Line := FormatEntry(AEntry);
  FLock.Acquire;
  try
    Bytes := TEncoding.UTF8.GetBytes(Line);
    FStream.WriteBuffer(Bytes[0], Length(Bytes));
  finally
    FLock.Release;
  end;
end;

procedure TFileLogSink.Flush;
begin
  // TFileStream flushes on each write; nothing extra needed
end;

function TFileLogSink.GetIsOpen: Boolean;
begin
  Result := FIsOpen;
end;

{ TQsoFileRepository }

constructor TQsoFileRepository.Create(const AFilePath: string; ABus: TEventBus);
begin
  inherited Create;
  FFilePath := AFilePath;
  FBus  := ABus;
  FList := TList.Create;
  FDirty := False;
end;

destructor TQsoFileRepository.Destroy;
var
  I: Integer;
  P: ^TQsoRecord;
begin
  for I := 0 to FList.Count - 1 do
  begin
    P := FList[I];
    Dispose(P);
  end;
  FList.Free;
  inherited;
end;

function TQsoFileRepository.AdifField(const ATag, AValue: string): string;
begin
  Result := Format('<%s:%d>%s ', [ATag, Length(AValue), AValue]);
end;

function TQsoFileRepository.FormatAdif(const AQso: TQsoRecord): string;
begin
  Result :=
    AdifField('CALL', AQso.Callsign) +
    AdifField('QSO_DATE', FormatDateTime('yyyymmdd', AQso.DateTime)) +
    AdifField('TIME_ON', FormatDateTime('hhnnss', AQso.DateTime)) +
    AdifField('FREQ', Format('%.4f', [AQso.Frequency / 1000000.0])) +
    AdifField('MODE', AQso.Mode) +
    AdifField('RST_SENT', AQso.RSTSent) +
    AdifField('RST_RCVD', AQso.RSTReceived) +
    AdifField('NAME', AQso.Name) +
    AdifField('COMMENT', AQso.Comments) +
    '<EOR>' + LineEnding;
end;

function TQsoFileRepository.ReadAdifField(
  const ALine, ATag: string; out AValue: string): Boolean;
var
  TagStr: string;
  P, Q: Integer;
  Len: Integer;
begin
  TagStr := '<' + UpperCase(ATag) + ':';
  P := Pos(TagStr, UpperCase(ALine));
  if P = 0 then begin Result := False; Exit; end;
  Q := Pos('>', ALine, P);
  if Q = 0 then begin Result := False; Exit; end;
  Len := StrToIntDef(Copy(ALine, P + Length(TagStr), Q - P - Length(TagStr)), 0);
  AValue := Copy(ALine, Q + 1, Len);
  Result := True;
end;

function TQsoFileRepository.ParseAdif(const ALine: string; out AQso: TQsoRecord): Boolean;
var
  DateStr, TimeStr, FreqStr: string;
begin
  FillChar(AQso, SizeOf(AQso), 0);
  Result := ReadAdifField(ALine, 'CALL', AQso.Callsign);
  if not Result then Exit;

  ReadAdifField(ALine, 'QSO_DATE', DateStr);
  ReadAdifField(ALine, 'TIME_ON', TimeStr);
  ReadAdifField(ALine, 'MODE', AQso.Mode);
  ReadAdifField(ALine, 'RST_SENT', AQso.RSTSent);
  ReadAdifField(ALine, 'RST_RCVD', AQso.RSTReceived);
  ReadAdifField(ALine, 'NAME', AQso.Name);
  ReadAdifField(ALine, 'COMMENT', AQso.Comments);

  if ReadAdifField(ALine, 'FREQ', FreqStr) then
    AQso.Frequency := Round(StrToFloatDef(FreqStr, 0.0) * 1000000);

  try
    AQso.DateTime := EncodeDate(
      StrToIntDef(Copy(DateStr, 1, 4), 0),
      StrToIntDef(Copy(DateStr, 5, 2), 0),
      StrToIntDef(Copy(DateStr, 7, 2), 0)) +
      EncodeTime(
        StrToIntDef(Copy(TimeStr, 1, 2), 0),
        StrToIntDef(Copy(TimeStr, 3, 2), 0),
        StrToIntDef(Copy(TimeStr, 5, 2), 0), 0);
  except
    AQso.DateTime := Now;
  end;
end;

procedure TQsoFileRepository.Append(const AQso: TQsoRecord);
var
  P: ^TQsoRecord;
begin
  New(P);
  P^ := AQso;
  FList.Add(P);
  FDirty := True;
  FBus.Publish(TEvents.QSO_LOGGED, TStringEventData.Create(AQso.Callsign));
end;

function TQsoFileRepository.FindByCallsign(const ACallsign: string): TQsoRecord;
var
  I: Integer;
  P: ^TQsoRecord;
  Upper: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Upper := UpperCase(ACallsign);
  for I := FList.Count - 1 downto 0 do
  begin
    P := FList[I];
    if UpperCase(P^.Callsign) = Upper then
    begin
      Result := P^;
      Exit;
    end;
  end;
end;

procedure TQsoFileRepository.Save;
var
  SL: TStringList;
  I: Integer;
  P: ^TQsoRecord;
begin
  SL := TStringList.Create;
  try
    SL.Add('ADIF Export from MMTTY Lazarus <EOH>');
    for I := 0 to FList.Count - 1 do
    begin
      P := FList[I];
      SL.Add(FormatAdif(P^));
    end;
    SL.SaveToFile(FFilePath);
    FDirty := False;
  finally
    SL.Free;
  end;
end;

procedure TQsoFileRepository.Load;
var
  SL: TStringList;
  I: Integer;
  QSO: TQsoRecord;
  P: ^TQsoRecord;
begin
  if not FileExists(FFilePath) then Exit;
  SL := TStringList.Create;
  try
    SL.LoadFromFile(FFilePath);
    for I := 0 to SL.Count - 1 do
      if ParseAdif(SL[I], QSO) then
      begin
        New(P);
        P^ := QSO;
        FList.Add(P);
      end;
  finally
    SL.Free;
  end;
end;

function TQsoFileRepository.Count: Integer;
begin
  Result := FList.Count;
end;

{ TCompositeLogSink }

constructor TCompositeLogSink.Create;
begin
  inherited Create;
  FSinks := TInterfaceList.Create;
end;

destructor TCompositeLogSink.Destroy;
begin
  FSinks.Free;
  inherited;
end;

procedure TCompositeLogSink.AddSink(ASink: ILogSink);
begin
  FSinks.Add(ASink);
end;

procedure TCompositeLogSink.RemoveSink(ASink: ILogSink);
begin
  FSinks.Remove(ASink);
end;

procedure TCompositeLogSink.Log(const AEntry: TLogEntry);
var
  I: Integer;
begin
  for I := 0 to FSinks.Count - 1 do
    ILogSink(FSinks[I]).Log(AEntry);
end;

procedure TCompositeLogSink.Flush;
var
  I: Integer;
begin
  for I := 0 to FSinks.Count - 1 do
    ILogSink(FSinks[I]).Flush;
end;

function TCompositeLogSink.GetIsOpen: Boolean;
begin
  Result := FSinks.Count > 0;
end;

{ TLogger }

constructor TLogger.Create(ASink: ILogSink; const ASource: string);
begin
  inherited Create;
  FSink := ASink;
  FSource := ASource;
end;

procedure TLogger.Debug(const AMsg: string);
var
  E: TLogEntry;
begin
  E.Level := llDebug; E.Timestamp := Now; E.Message := AMsg; E.Source := FSource;
  FSink.Log(E);
end;

procedure TLogger.Info(const AMsg: string);
var
  E: TLogEntry;
begin
  E.Level := llInfo; E.Timestamp := Now; E.Message := AMsg; E.Source := FSource;
  FSink.Log(E);
end;

procedure TLogger.Warning(const AMsg: string);
var
  E: TLogEntry;
begin
  E.Level := llWarning; E.Timestamp := Now; E.Message := AMsg; E.Source := FSource;
  FSink.Log(E);
end;

procedure TLogger.Error(const AMsg: string);
var
  E: TLogEntry;
begin
  E.Level := llError; E.Timestamp := Now; E.Message := AMsg; E.Source := FSource;
  FSink.Log(E);
end;

procedure TLogger.LogFmt(ALevel: TLogLevel; const AFmt: string; const AArgs: array of const);
var
  E: TLogEntry;
begin
  E.Level := ALevel; E.Timestamp := Now;
  E.Message := Format(AFmt, AArgs); E.Source := FSource;
  FSink.Log(E);
end;

end.
