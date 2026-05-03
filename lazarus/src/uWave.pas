unit uWave;

{$mode objfpc}{$H+}

// Waveform generation utilities (Strategy pattern for signal synthesis).
// Pure mathematical functions; no I/O or platform dependencies.

interface

uses
  Classes, SysUtils, Math, uDomainTypes, uInterfaces;

type
  // =========================================================================
  // Tone generator strategy interface
  // =========================================================================
  IToneGenerator = interface
    ['{B2000001-0000-0000-0000-000000000001}']
    function Generate(ASampleCount: Integer): TRealArray;
    procedure SetFrequency(AHz: Double);
    procedure SetAmplitude(AAmplitude: Double);
    procedure SetSampleRate(ARate: Integer);
    function GetFrequency: Double;
    function GetAmplitude: Double;
    function GetSampleRate: Integer;
    property Frequency: Double read GetFrequency write SetFrequency;
    property Amplitude: Double read GetAmplitude write SetAmplitude;
    property SampleRate: Integer read GetSampleRate write SetSampleRate;
  end;

  // =========================================================================
  // Sine wave generator
  // =========================================================================
  TSineWaveGenerator = class(TInterfacedObject, IToneGenerator)
  private
    FFrequency: Double;
    FAmplitude: Double;
    FSampleRate: Integer;
    FPhase: Double;       // current phase accumulator (radians)
    FPhaseStep: Double;   // pre-computed per-sample phase increment
    procedure UpdatePhaseStep;
  public
    constructor Create(AFrequency, AAmplitude: Double; ASampleRate: Integer);

    function Generate(ASampleCount: Integer): TRealArray;
    procedure SetFrequency(AHz: Double);
    procedure SetAmplitude(AAmplitude: Double);
    procedure SetSampleRate(ARate: Integer);
    function GetFrequency: Double;
    function GetAmplitude: Double;
    function GetSampleRate: Integer;

    property Frequency: Double read GetFrequency write SetFrequency;
    property Amplitude: Double read GetAmplitude write SetAmplitude;
    property SampleRate: Integer read GetSampleRate write SetSampleRate;
  end;

  // =========================================================================
  // FSK modulator: switches between mark and space tone generators
  // =========================================================================
  TFskModulator = class(TInterfacedObject, IDspStage)
  private
    FMarkGen:   IToneGenerator;
    FSpaceGen:  IToneGenerator;
    FCurrent:   TModulationType;
    FSampleRate: Integer;
    FStageName: string;
  public
    constructor Create(
      AMarkHz, ASpaceHz, AAmplitude: Double;
      ASampleRate: Integer);

    procedure SwitchToMark;
    procedure SwitchToSpace;
    procedure SetModulation(AType: TModulationType);

    // IDspStage (generate silence/mark/space on demand)
    function Process(const AInput: TRealArray): TRealArray;
    function GetStageName: string;
    function GetSampleRate: Integer;
    procedure SetSampleRate(ARate: Integer);

    property Current: TModulationType read FCurrent;
    property StageName: string read GetStageName;
    property SampleRate: Integer read GetSampleRate write SetSampleRate;
  end;

  // =========================================================================
  // Utility functions
  // =========================================================================
  TWaveUtils = class
  public
    // Compute RMS level of a buffer
    class function RmsLevel(const ABuf: TRealArray): Double;

    // Normalize buffer to peak amplitude
    class procedure Normalize(var ABuf: TRealArray; APeak: Double = 1.0);

    // Mix two buffers (simple sum)
    class function Mix(const A, B: TRealArray): TRealArray;

    // Generate a raised-cosine (Hann) window
    class function HannWindow(ALength: Integer): TRealArray;
  end;

implementation

{ TSineWaveGenerator }

constructor TSineWaveGenerator.Create(AFrequency, AAmplitude: Double; ASampleRate: Integer);
begin
  inherited Create;
  FFrequency  := AFrequency;
  FAmplitude  := AAmplitude;
  FSampleRate := ASampleRate;
  FPhase      := 0.0;
  UpdatePhaseStep;
end;

procedure TSineWaveGenerator.UpdatePhaseStep;
begin
  FPhaseStep := 2.0 * Pi * FFrequency / FSampleRate;
end;

function TSineWaveGenerator.Generate(ASampleCount: Integer): TRealArray;
var
  I: Integer;
begin
  SetLength(Result, ASampleCount);
  for I := 0 to ASampleCount - 1 do
  begin
    Result[I] := FAmplitude * Sin(FPhase);
    FPhase := FPhase + FPhaseStep;
    if FPhase >= 2.0 * Pi then
      FPhase := FPhase - 2.0 * Pi;
  end;
end;

procedure TSineWaveGenerator.SetFrequency(AHz: Double);
begin
  FFrequency := AHz;
  UpdatePhaseStep;
end;

procedure TSineWaveGenerator.SetAmplitude(AAmplitude: Double);
begin
  FAmplitude := AAmplitude;
end;

procedure TSineWaveGenerator.SetSampleRate(ARate: Integer);
begin
  FSampleRate := ARate;
  UpdatePhaseStep;
end;

function TSineWaveGenerator.GetFrequency: Double; begin Result := FFrequency; end;
function TSineWaveGenerator.GetAmplitude: Double; begin Result := FAmplitude; end;
function TSineWaveGenerator.GetSampleRate: Integer; begin Result := FSampleRate; end;

{ TFskModulator }

constructor TFskModulator.Create(
  AMarkHz, ASpaceHz, AAmplitude: Double; ASampleRate: Integer);
begin
  inherited Create;
  FStageName  := 'FskModulator';
  FSampleRate := ASampleRate;
  FCurrent    := mtMark;
  FMarkGen    := TSineWaveGenerator.Create(AMarkHz, AAmplitude, ASampleRate);
  FSpaceGen   := TSineWaveGenerator.Create(ASpaceHz, AAmplitude, ASampleRate);
end;

procedure TFskModulator.SwitchToMark;
begin
  FCurrent := mtMark;
end;

procedure TFskModulator.SwitchToSpace;
begin
  FCurrent := mtSpace;
end;

procedure TFskModulator.SetModulation(AType: TModulationType);
begin
  FCurrent := AType;
end;

function TFskModulator.Process(const AInput: TRealArray): TRealArray;
var
  N: Integer;
begin
  N := Length(AInput);
  if N = 0 then N := 256;
  case FCurrent of
    mtMark:  Result := FMarkGen.Generate(N);
    mtSpace: Result := FSpaceGen.Generate(N);
  else
    SetLength(Result, N);
    FillChar(Result[0], N * SizeOf(Double), 0);
  end;
end;

function TFskModulator.GetStageName: string; begin Result := FStageName; end;
function TFskModulator.GetSampleRate: Integer; begin Result := FSampleRate; end;

procedure TFskModulator.SetSampleRate(ARate: Integer);
begin
  FSampleRate := ARate;
  FMarkGen.SetSampleRate(ARate);
  FSpaceGen.SetSampleRate(ARate);
end;

{ TWaveUtils }

class function TWaveUtils.RmsLevel(const ABuf: TRealArray): Double;
var
  I: Integer;
  Sum: Double;
begin
  if Length(ABuf) = 0 then begin Result := 0.0; Exit; end;
  Sum := 0.0;
  for I := 0 to High(ABuf) do
    Sum := Sum + ABuf[I] * ABuf[I];
  Result := Sqrt(Sum / Length(ABuf));
end;

class procedure TWaveUtils.Normalize(var ABuf: TRealArray; APeak: Double);
var
  I: Integer;
  MaxVal, Scale: Double;
begin
  MaxVal := 0.0;
  for I := 0 to High(ABuf) do
    if Abs(ABuf[I]) > MaxVal then MaxVal := Abs(ABuf[I]);
  if MaxVal < 1e-10 then Exit;
  Scale := APeak / MaxVal;
  for I := 0 to High(ABuf) do
    ABuf[I] := ABuf[I] * Scale;
end;

class function TWaveUtils.Mix(const A, B: TRealArray): TRealArray;
var
  I, Len: Integer;
begin
  Len := Max(Length(A), Length(B));
  SetLength(Result, Len);
  for I := 0 to Len - 1 do
  begin
    Result[I] := 0.0;
    if I < Length(A) then Result[I] := Result[I] + A[I];
    if I < Length(B) then Result[I] := Result[I] + B[I];
  end;
end;

class function TWaveUtils.HannWindow(ALength: Integer): TRealArray;
var
  I: Integer;
begin
  SetLength(Result, ALength);
  for I := 0 to ALength - 1 do
    Result[I] := 0.5 * (1.0 - Cos(2.0 * Pi * I / (ALength - 1)));
end;

end.
