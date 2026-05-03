unit uRtty;

{$mode objfpc}{$H+}

// RTTY codec (Strategy pattern).
// IModulationProfile: RTTY (Baudot/ITA2) encoder/decoder.
// IRttyEncoder / IRttyDecoder implementations are here; other modulations
// (PSK31, etc.) plug in via the same interfaces.

interface

uses
  Classes, SysUtils, Math,
  uDomainTypes, uInterfaces, uFft, uWave;

const
  // ITA2 / Baudot character table
  // Index 0..31: Letters shift; index 32..63: Figures shift
  // 0 = Null, special codes at known positions
  BAUDOT_LETTERS: array[0..31] of AnsiChar = (
    #0,  'E', #10, 'A',  ' ', 'S', 'I', 'U',
    #13, 'D', 'R', 'J',  'N', 'F', 'C', 'K',
    'T', 'Z', 'L', 'W',  'H', 'Y', 'P', 'Q',
    'O', 'B', 'G', #255, 'M', 'X', 'V', #255);

  BAUDOT_FIGURES: array[0..31] of AnsiChar = (
    #0,  '3', #10, '-',  ' ', #7,  '8', '7',
    #13, #255,'4', #7,   ',', '!', ':', '(',
    '5', '"', ')', '2',  '#', '6', '0', '1',
    '9', '?', '&', #255, '.', '/', ';', #255);

  BAUDOT_LTRS = $1F;  // Letter shift code
  BAUDOT_FIGS = $1B;  // Figure shift code

type
  TBaudotShift = (bsLetters, bsFigures);

  // =========================================================================
  // RTTY modulation profile (Strategy)
  // =========================================================================
  TRttyProfile = class(TInterfacedObject, IModulationProfile)
  private
    FConfig: TRttyConfig;
  public
    constructor Create(const AConfig: TRttyConfig);

    function GetName: string;
    function GetBaudRate: Double;
    function GetShiftHz: Double;
    function GetConfig: TRttyConfig;
    function EncodeChar(ACh: AnsiChar): TBytes;
    function GetDiddleChar: AnsiChar;

    property Name: string read GetName;
    property BaudRate: Double read GetBaudRate;
    property ShiftHz: Double read GetShiftHz;
  end;

  // =========================================================================
  // RTTY encoder: text -> Baudot byte stream
  // =========================================================================
  TRttyEncoder = class(TInterfacedObject, IRttyEncoder)
  private
    FProfile: IModulationProfile;
    FCurrentShift: TBaudotShift;
    FUoS: Boolean;           // Unshift on Space

    function CharToBaudot(ACh: AnsiChar; out ACode: Byte): Boolean;
    function NeedsShift(ACh: AnsiChar; out AShift: TBaudotShift): Boolean;
  public
    constructor Create(AProfile: IModulationProfile; AUoS: Boolean = True);

    function Encode(const AText: string): TBytes;
    function GetProfile: IModulationProfile;
    property Profile: IModulationProfile read GetProfile;
  end;

  // =========================================================================
  // RTTY decoder: audio samples -> Baudot -> text
  // Uses two Goertzel detectors (mark / space) for tone detection.
  // =========================================================================
  TRttyDecoder = class(TInterfacedObject, IRttyDecoder)
  private
    FProfile: IModulationProfile;
    FMarkDetector:  TGoertzelDetector;
    FSpaceDetector: TGoertzelDetector;
    FCurrentShift:  TBaudotShift;
    FBitBuffer:     Byte;
    FBitCount:      Integer;
    FDecodedText:   string;
    FSignalLevel:   Double;
    FTuningOffset:  Double;
    FSampleRate:    Integer;
    FBaudRate:      Double;
    FSamplesPerBit: Integer;
    FSampleBuf:     TRealArray;
    FBufPos:        Integer;

    procedure ProcessBit(ABit: Boolean);
    procedure ProcessByte(ACode: Byte);
    function BaudotToChar(ACode: Byte): AnsiChar;
  public
    constructor Create(AProfile: IModulationProfile; ASampleRate: Integer);
    destructor Destroy; override;

    procedure FeedSamples(const ASamples: TRealArray);
    function GetDecodedText: string;
    function GetSignalLevel: Double;
    function GetTuningOffset: Double;
    procedure Reset;

    property DecodedText: string read GetDecodedText;
    property SignalLevel: Double read GetSignalLevel;
    property TuningOffset: Double read GetTuningOffset;
  end;

  // Diddle strategies (Strategy pattern for idle behavior)
  TLettersDiddleStrategy = class(TInterfacedObject, IDiddleStrategy)
  public
    function GetNextDiddleChar: AnsiChar;
    function ShouldDiddle: Boolean;
  end;

  TIdleDiddleStrategy = class(TInterfacedObject, IDiddleStrategy)
  public
    function GetNextDiddleChar: AnsiChar;
    function ShouldDiddle: Boolean;
  end;

  // Factory
  TRttyFactory = class
  public
    class function CreateRttyConfig(
      ABaudRate: Double = 45.45;
      AShiftHz: Double = 170.0;
      AMarkHz: Double = 2295.0): TRttyConfig;

    class function CreateProfile(const AConfig: TRttyConfig): IModulationProfile;
    class function CreateEncoder(AProfile: IModulationProfile): IRttyEncoder;
    class function CreateDecoder(AProfile: IModulationProfile; ASampleRate: Integer): IRttyDecoder;
  end;

implementation

{ Baudot lookup tables (char -> code) built at startup }
var
  LettersTable: array[0..127] of Integer;  // -1 = not in letters shift
  FiguresTable: array[0..127] of Integer;  // -1 = not in figures shift

procedure BuildBaudotTables;
var
  I: Integer;
begin
  FillChar(LettersTable, SizeOf(LettersTable), $FF);  // -1
  FillChar(FiguresTable, SizeOf(FiguresTable), $FF);
  for I := 0 to 31 do
  begin
    if Ord(BAUDOT_LETTERS[I]) < 128 then
      LettersTable[Ord(BAUDOT_LETTERS[I])] := I;
    if Ord(BAUDOT_FIGURES[I]) < 128 then
      FiguresTable[Ord(BAUDOT_FIGURES[I])] := I;
  end;
end;

{ TRttyProfile }

constructor TRttyProfile.Create(const AConfig: TRttyConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

function TRttyProfile.GetName: string; begin Result := 'RTTY'; end;
function TRttyProfile.GetBaudRate: Double; begin Result := FConfig.BaudRate; end;
function TRttyProfile.GetShiftHz: Double; begin Result := FConfig.ShiftHz; end;
function TRttyProfile.GetConfig: TRttyConfig; begin Result := FConfig; end;

function TRttyProfile.EncodeChar(ACh: AnsiChar): TBytes;
begin
  // Single Baudot code byte (5-bit) returned; framing is caller's responsibility
  SetLength(Result, 1);
  if Ord(ACh) < 128 then
    Result[0] := Byte(LettersTable[Ord(ACh)])
  else
    SetLength(Result, 0);
end;

function TRttyProfile.GetDiddleChar: AnsiChar;
begin
  Result := AnsiChar(BAUDOT_LTRS);
end;

{ TRttyEncoder }

constructor TRttyEncoder.Create(AProfile: IModulationProfile; AUoS: Boolean);
begin
  inherited Create;
  FProfile := AProfile;
  FCurrentShift := bsLetters;
  FUoS := AUoS;
end;

function TRttyEncoder.CharToBaudot(ACh: AnsiChar; out ACode: Byte): Boolean;
var
  LetCode, FigCode: Integer;
begin
  ACh := AnsiChar(UpCase(Char(ACh)));
  LetCode := -1;
  FigCode := -1;
  if Ord(ACh) < 128 then
  begin
    LetCode := LettersTable[Ord(ACh)];
    FigCode := FiguresTable[Ord(ACh)];
  end;

  if LetCode >= 0 then begin ACode := LetCode; Result := True; end
  else if FigCode >= 0 then begin ACode := FigCode; Result := True; end
  else begin ACode := 0; Result := False; end;
end;

function TRttyEncoder.NeedsShift(ACh: AnsiChar; out AShift: TBaudotShift): Boolean;
var
  Code: Byte;
begin
  ACh := AnsiChar(UpCase(Char(ACh)));
  if Ord(ACh) < 128 then
  begin
    if LettersTable[Ord(ACh)] >= 0 then
    begin
      AShift := bsLetters;
      Result := FCurrentShift <> bsLetters;
    end
    else if FiguresTable[Ord(ACh)] >= 0 then
    begin
      AShift := bsFigures;
      Result := FCurrentShift <> bsFigures;
    end
    else
    begin
      AShift := FCurrentShift;
      Result := False;
    end;
  end
  else
  begin
    AShift := FCurrentShift;
    Result := False;
  end;
  Code := 0;
  Result := Result and CharToBaudot(ACh, Code);
end;

function TRttyEncoder.Encode(const AText: string): TBytes;
var
  OutBuf: TBytes;
  OutLen: Integer;
  I: Integer;
  Ch: AnsiChar;
  Shift: TBaudotShift;
  Code: Byte;

  procedure Emit(AByte: Byte);
  begin
    if OutLen >= Length(OutBuf) then
      SetLength(OutBuf, Length(OutBuf) + 64);
    OutBuf[OutLen] := AByte;
    Inc(OutLen);
  end;

begin
  SetLength(OutBuf, Length(AText) * 2 + 4);
  OutLen := 0;

  // Start with LTRS shift to establish known state
  Emit(BAUDOT_LTRS);
  FCurrentShift := bsLetters;

  for I := 1 to Length(AText) do
  begin
    Ch := AnsiChar(AText[I]);

    // UoS: revert to letters on space
    if (Ch = ' ') and FUoS and (FCurrentShift = bsFigures) then
    begin
      Emit(BAUDOT_LTRS);
      FCurrentShift := bsLetters;
    end;

    if NeedsShift(Ch, Shift) then
    begin
      if Shift = bsLetters then Emit(BAUDOT_LTRS)
      else Emit(BAUDOT_FIGS);
      FCurrentShift := Shift;
    end;

    if CharToBaudot(Ch, Code) then
      Emit(Code);
  end;

  SetLength(Result, OutLen);
  Move(OutBuf[0], Result[0], OutLen);
end;

function TRttyEncoder.GetProfile: IModulationProfile;
begin
  Result := FProfile;
end;

{ TRttyDecoder }

constructor TRttyDecoder.Create(AProfile: IModulationProfile; ASampleRate: Integer);
var
  Config: TRttyConfig;
begin
  inherited Create;
  FProfile  := AProfile;
  FSampleRate := ASampleRate;

  Config := AProfile.GetConfig;
  FBaudRate := Config.BaudRate;
  FSamplesPerBit := Round(ASampleRate / FBaudRate);

  FMarkDetector  := TGoertzelDetector.Create(Config.MarkHz,  ASampleRate, FSamplesPerBit);
  FSpaceDetector := TGoertzelDetector.Create(Config.SpaceHz, ASampleRate, FSamplesPerBit);

  FCurrentShift := bsLetters;
  FBitBuffer    := 0;
  FBitCount     := 0;
  FDecodedText  := '';
  FSignalLevel  := 0.0;
  FTuningOffset := 0.0;

  SetLength(FSampleBuf, FSamplesPerBit);
  FBufPos := 0;
end;

destructor TRttyDecoder.Destroy;
begin
  FMarkDetector.Free;
  FSpaceDetector.Free;
  inherited;
end;

procedure TRttyDecoder.FeedSamples(const ASamples: TRealArray);
var
  I: Integer;
  MarkMag, SpaceMag: Double;
begin
  for I := 0 to High(ASamples) do
  begin
    FMarkDetector.Feed(ASamples[I]);
    FSpaceDetector.Feed(ASamples[I]);
    FSampleBuf[FBufPos] := ASamples[I];
    Inc(FBufPos);

    if FBufPos >= FSamplesPerBit then
    begin
      MarkMag  := FMarkDetector.Magnitude;
      SpaceMag := FSpaceDetector.Magnitude;
      FSignalLevel := Max(MarkMag, SpaceMag);

      ProcessBit(MarkMag > SpaceMag);

      FMarkDetector.Reset;
      FSpaceDetector.Reset;
      FBufPos := 0;
    end;
  end;
end;

procedure TRttyDecoder.ProcessBit(ABit: Boolean);
begin
  // Simplified: collect 5 data bits after start bit, check stop bit
  if FBitCount = 0 then
  begin
    // Expect start bit (space = 0)
    if not ABit then
      Inc(FBitCount);
    // else: still waiting for start bit
  end
  else if FBitCount <= 5 then
  begin
    FBitBuffer := FBitBuffer or (Byte(ABit) shl (FBitCount - 1));
    Inc(FBitCount);
  end
  else
  begin
    // Stop bit (mark = 1)
    if ABit then
      ProcessByte(FBitBuffer);
    FBitBuffer := 0;
    FBitCount  := 0;
  end;
end;

procedure TRttyDecoder.ProcessByte(ACode: Byte);
var
  Ch: AnsiChar;
begin
  ACode := ACode and $1F;
  if ACode = BAUDOT_LTRS then begin FCurrentShift := bsLetters; Exit; end;
  if ACode = BAUDOT_FIGS then begin FCurrentShift := bsFigures; Exit; end;

  Ch := BaudotToChar(ACode);
  if Ch <> #0 then
    FDecodedText := FDecodedText + Ch;
end;

function TRttyDecoder.BaudotToChar(ACode: Byte): AnsiChar;
begin
  ACode := ACode and $1F;
  if FCurrentShift = bsLetters then
    Result := BAUDOT_LETTERS[ACode]
  else
    Result := BAUDOT_FIGURES[ACode];
end;

function TRttyDecoder.GetDecodedText: string;
begin
  Result := FDecodedText;
  FDecodedText := '';  // consume
end;

function TRttyDecoder.GetSignalLevel: Double; begin Result := FSignalLevel; end;
function TRttyDecoder.GetTuningOffset: Double; begin Result := FTuningOffset; end;

procedure TRttyDecoder.Reset;
begin
  FBitBuffer   := 0;
  FBitCount    := 0;
  FDecodedText := '';
  FBufPos      := 0;
  FMarkDetector.Reset;
  FSpaceDetector.Reset;
end;

{ TLettersDiddleStrategy }

function TLettersDiddleStrategy.GetNextDiddleChar: AnsiChar;
begin
  Result := AnsiChar(BAUDOT_LTRS);
end;

function TLettersDiddleStrategy.ShouldDiddle: Boolean;
begin
  Result := True;
end;

{ TIdleDiddleStrategy }

function TIdleDiddleStrategy.GetNextDiddleChar: AnsiChar;
begin
  Result := #0;
end;

function TIdleDiddleStrategy.ShouldDiddle: Boolean;
begin
  Result := False;
end;

{ TRttyFactory }

class function TRttyFactory.CreateRttyConfig(
  ABaudRate, AShiftHz, AMarkHz: Double): TRttyConfig;
begin
  Result.Mode     := rmRTTY;
  Result.BaudRate := ABaudRate;
  Result.ShiftHz  := AShiftHz;
  Result.MarkHz   := AMarkHz;
  Result.SpaceHz  := AMarkHz - AShiftHz;
  Result.Inversion := False;
  Result.UoS      := True;
end;

class function TRttyFactory.CreateProfile(const AConfig: TRttyConfig): IModulationProfile;
begin
  Result := TRttyProfile.Create(AConfig);
end;

class function TRttyFactory.CreateEncoder(AProfile: IModulationProfile): IRttyEncoder;
begin
  Result := TRttyEncoder.Create(AProfile, True);
end;

class function TRttyFactory.CreateDecoder(
  AProfile: IModulationProfile; ASampleRate: Integer): IRttyDecoder;
begin
  Result := TRttyDecoder.Create(AProfile, ASampleRate);
end;

initialization
  BuildBaudotTables;

end.
