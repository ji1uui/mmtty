unit uFft;

{$mode objfpc}{$H+}

// FFT implementation (Strategy pattern: IDspStage).
// Cooley-Tukey radix-2 DIT FFT, power-of-two lengths only.
// Produces magnitude spectrum for the scope/waterfall display.

interface

uses
  Classes, SysUtils, Math, uDomainTypes, uInterfaces, uDspPipeline;

type
  // =========================================================================
  // Core FFT engine (pure math, no I/O dependencies — SRP)
  // =========================================================================
  TFftEngine = class
  public
    // In-place complex FFT (size must be power of two)
    class procedure Fft(var AData: TComplexArray; AInverse: Boolean = False);

    // Real FFT: convert real signal to complex spectrum
    class function RealFft(const AReal: TRealArray): TComplexArray;

    // Compute magnitude spectrum from complex FFT output
    class function MagnitudeSpectrum(const AComplex: TComplexArray): TRealArray;

    // Compute power spectrum (|X|^2) — avoids sqrt
    class function PowerSpectrum(const AComplex: TComplexArray): TRealArray;

    // Return frequency resolution for a given FFT size and sample rate
    class function FreqResolution(AFftSize, ASampleRate: Integer): Double;
  end;

  // =========================================================================
  // FFT DSP stage: feeds into IDspPipeline
  // =========================================================================
  TFftStage = class(TAbstractDspStage)
  private
    FFftSize: Integer;
    FWindow: TRealArray;
    FOutputMagnitude: TRealArray;  // retained for scope queries

    procedure BuildWindow;
    function NextPowerOfTwo(N: Integer): Integer;
  public
    constructor Create(AFftSize: Integer; ASampleRate: Integer);

    // IDspStage — outputs magnitude spectrum
    function Process(const AInput: TRealArray): TRealArray; override;

    // Last computed magnitude spectrum (thread-safe read — copy on write)
    function GetMagnitudeSpectrum: TRealArray;

    property FftSize: Integer read FFftSize;
  end;

  // =========================================================================
  // Goertzel tone detector — more efficient than FFT for single frequencies
  // =========================================================================
  TGoertzelDetector = class
  private
    FTargetHz: Double;
    FSampleRate: Integer;
    FBlockSize: Integer;
    FCoeff: Double;
    FQ1, FQ2: Double;
    FSampleCount: Integer;
    procedure UpdateCoeff;
  public
    constructor Create(ATargetHz: Double; ASampleRate, ABlockSize: Integer);

    procedure Feed(ASample: Double);
    function Magnitude: Double;
    procedure Reset;
    procedure SetTargetHz(AHz: Double);

    property TargetHz: Double read FTargetHz;
  end;

implementation

{ TFftEngine }

class procedure TFftEngine.Fft(var AData: TComplexArray; AInverse: Boolean);
var
  N, I, J, K, M, Step: Integer;
  Angle, WRe, WIm, URe, UIm, TRe, TIm: Double;
  Temp: TComplexItem;
begin
  N := Length(AData);
  if N <= 1 then Exit;

  // Bit-reversal permutation
  J := 0;
  for I := 1 to N - 1 do
  begin
    M := N shr 1;
    while J >= M do
    begin
      J := J - M;
      M := M shr 1;
    end;
    J := J + M;
    if I < J then
    begin
      Temp := AData[I];
      AData[I] := AData[J];
      AData[J] := Temp;
    end;
  end;

  // Cooley-Tukey butterfly
  Step := 1;
  while Step < N do
  begin
    if AInverse then
      Angle := Pi / Step
    else
      Angle := -Pi / Step;

    WRe := Cos(Angle);
    WIm := Sin(Angle);
    I := 0;
    while I < N do
    begin
      URe := 1.0;
      UIm := 0.0;
      for J := 0 to Step - 1 do
      begin
        K := I + J + Step;
        TRe := URe * AData[K].Re - UIm * AData[K].Im;
        TIm := URe * AData[K].Im + UIm * AData[K].Re;
        AData[K].Re := AData[I + J].Re - TRe;
        AData[K].Im := AData[I + J].Im - TIm;
        AData[I + J].Re := AData[I + J].Re + TRe;
        AData[I + J].Im := AData[I + J].Im + TIm;
        TRe := URe;
        URe := TRe * WRe - UIm * WIm;
        UIm := TRe * WIm + UIm * WRe;
      end;
      Inc(I, Step * 2);
    end;
    Step := Step * 2;
  end;

  if AInverse then
    for I := 0 to N - 1 do
    begin
      AData[I].Re := AData[I].Re / N;
      AData[I].Im := AData[I].Im / N;
    end;
end;

class function TFftEngine.RealFft(const AReal: TRealArray): TComplexArray;
var
  I, N: Integer;
begin
  N := Length(AReal);
  SetLength(Result, N);
  for I := 0 to N - 1 do
  begin
    Result[I].Re := AReal[I];
    Result[I].Im := 0.0;
  end;
  Fft(Result);
end;

class function TFftEngine.MagnitudeSpectrum(const AComplex: TComplexArray): TRealArray;
var
  I, Half: Integer;
begin
  Half := Length(AComplex) div 2;
  SetLength(Result, Half);
  for I := 0 to Half - 1 do
    Result[I] := Sqrt(AComplex[I].Re * AComplex[I].Re +
                      AComplex[I].Im * AComplex[I].Im);
end;

class function TFftEngine.PowerSpectrum(const AComplex: TComplexArray): TRealArray;
var
  I, Half: Integer;
begin
  Half := Length(AComplex) div 2;
  SetLength(Result, Half);
  for I := 0 to Half - 1 do
    Result[I] := AComplex[I].Re * AComplex[I].Re +
                 AComplex[I].Im * AComplex[I].Im;
end;

class function TFftEngine.FreqResolution(AFftSize, ASampleRate: Integer): Double;
begin
  if AFftSize = 0 then Result := 0.0
  else Result := ASampleRate / AFftSize;
end;

{ TFftStage }

function TFftStage.NextPowerOfTwo(N: Integer): Integer;
begin
  Result := 1;
  while Result < N do Result := Result shl 1;
end;

procedure TFftStage.BuildWindow;
var
  I: Integer;
begin
  SetLength(FWindow, FFftSize);
  for I := 0 to FFftSize - 1 do
    FWindow[I] := 0.5 * (1.0 - Cos(2.0 * Pi * I / (FFftSize - 1)));
end;

constructor TFftStage.Create(AFftSize: Integer; ASampleRate: Integer);
begin
  inherited Create('FFT', ASampleRate);
  FFftSize := NextPowerOfTwo(AFftSize);
  BuildWindow;
end;

function TFftStage.Process(const AInput: TRealArray): TRealArray;
var
  Windowed: TRealArray;
  Complex: TComplexArray;
  I, Len: Integer;
begin
  Len := Min(Length(AInput), FFftSize);
  SetLength(Windowed, FFftSize);
  FillChar(Windowed[0], FFftSize * SizeOf(Double), 0);

  for I := 0 to Len - 1 do
    Windowed[I] := AInput[I] * FWindow[I];

  Complex := TFftEngine.RealFft(Windowed);
  FOutputMagnitude := TFftEngine.MagnitudeSpectrum(Complex);
  Result := Copy(FOutputMagnitude, 0, Length(FOutputMagnitude));
end;

function TFftStage.GetMagnitudeSpectrum: TRealArray;
begin
  Result := Copy(FOutputMagnitude, 0, Length(FOutputMagnitude));
end;

{ TGoertzelDetector }

constructor TGoertzelDetector.Create(ATargetHz: Double; ASampleRate, ABlockSize: Integer);
begin
  inherited Create;
  FTargetHz   := ATargetHz;
  FSampleRate := ASampleRate;
  FBlockSize  := ABlockSize;
  FQ1 := 0.0;
  FQ2 := 0.0;
  FSampleCount := 0;
  UpdateCoeff;
end;

procedure TGoertzelDetector.UpdateCoeff;
begin
  FCoeff := 2.0 * Cos(2.0 * Pi * FTargetHz / FSampleRate);
end;

procedure TGoertzelDetector.Feed(ASample: Double);
var
  Q0: Double;
begin
  Q0 := ASample + FCoeff * FQ1 - FQ2;
  FQ2 := FQ1;
  FQ1 := Q0;
  Inc(FSampleCount);
end;

function TGoertzelDetector.Magnitude: Double;
begin
  Result := Sqrt(FQ1 * FQ1 + FQ2 * FQ2 - FQ1 * FQ2 * FCoeff);
end;

procedure TGoertzelDetector.Reset;
begin
  FQ1 := 0.0;
  FQ2 := 0.0;
  FSampleCount := 0;
end;

procedure TGoertzelDetector.SetTargetHz(AHz: Double);
begin
  FTargetHz := AHz;
  UpdateCoeff;
  Reset;
end;

end.
