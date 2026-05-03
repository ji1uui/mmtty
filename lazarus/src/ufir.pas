unit ufir;

{$mode objfpc}{$H+}

// FIR filter implementations (Strategy pattern: IDspStage).
// Filter designs use the window method; supports lowpass, highpass, bandpass.

interface

uses
  Classes, SysUtils, Math, uDomainTypes, uInterfaces, uDspPipeline;

type
  TFilterType = (ftLowPass, ftHighPass, ftBandPass, ftBandStop);
  TWindowType  = (wtRectangular, wtHann, wtHamming, wtBlackman);

  // =========================================================================
  // FIR filter design utilities (static — no state)
  // =========================================================================
  TFirDesign = class
  public
    // Compute window coefficients
    class function Window(AType: TWindowType; ALength: Integer): TRealArray;

    // Sinc-windowed FIR design
    class function LowPass(
      ACutoffHz, ASampleRate: Double;
      ANumTaps: Integer;
      AWindow: TWindowType = wtHamming): TRealArray;

    class function HighPass(
      ACutoffHz, ASampleRate: Double;
      ANumTaps: Integer;
      AWindow: TWindowType = wtHamming): TRealArray;

    class function BandPass(
      ALowHz, AHighHz, ASampleRate: Double;
      ANumTaps: Integer;
      AWindow: TWindowType = wtHamming): TRealArray;
  end;

  // =========================================================================
  // FIR filter DSP stage
  // =========================================================================
  TFirFilterStage = class(TAbstractDspStage)
  private
    FCoeffs: TRealArray;     // filter taps
    FDelay: TRealArray;      // delay line (circular)
    FDelayPos: Integer;      // write head in delay line
    FTaps: Integer;
  public
    constructor Create(
      const ACoeffs: TRealArray;
      const AName: string;
      ASampleRate: Integer);

    function Process(const AInput: TRealArray): TRealArray; override;
    procedure SetCoeffs(const ACoeffs: TRealArray);

    // Convenience constructors
    class function CreateLowPass(
      ACutoffHz, ASampleRate: Double;
      ANumTaps: Integer): TFirFilterStage;

    class function CreateHighPass(
      ACutoffHz, ASampleRate: Double;
      ANumTaps: Integer): TFirFilterStage;

    class function CreateBandPass(
      ALowHz, AHighHz, ASampleRate: Double;
      ANumTaps: Integer): TFirFilterStage;
  end;

  // =========================================================================
  // Single-pole IIR lowpass (simpler / cheaper than FIR for smoothing)
  // =========================================================================
  TIirLowPassStage = class(TAbstractDspStage)
  private
    FAlpha: Double;
    FPrev: Double;
  public
    constructor Create(ACutoffHz, ASampleRate: Double; const AName: string = 'IirLowPass');
    function Process(const AInput: TRealArray): TRealArray; override;
    procedure SetCutoff(ACutoffHz, ASampleRate: Double);
  end;

implementation

{ TFirDesign }

class function TFirDesign.Window(AType: TWindowType; ALength: Integer): TRealArray;
var
  I: Integer;
begin
  SetLength(Result, ALength);
  case AType of
    wtRectangular:
      for I := 0 to ALength - 1 do Result[I] := 1.0;

    wtHann:
      for I := 0 to ALength - 1 do
        Result[I] := 0.5 * (1.0 - Cos(2.0 * Pi * I / (ALength - 1)));

    wtHamming:
      for I := 0 to ALength - 1 do
        Result[I] := 0.54 - 0.46 * Cos(2.0 * Pi * I / (ALength - 1));

    wtBlackman:
      for I := 0 to ALength - 1 do
        Result[I] := 0.42 - 0.5 * Cos(2.0 * Pi * I / (ALength - 1))
                          + 0.08 * Cos(4.0 * Pi * I / (ALength - 1));
  end;
end;

class function TFirDesign.LowPass(
  ACutoffHz, ASampleRate: Double;
  ANumTaps: Integer;
  AWindow: TWindowType): TRealArray;
var
  I, M: Integer;
  Fc, Sum, H: Double;
  Win: TRealArray;
begin
  M := ANumTaps - 1;
  Fc := ACutoffHz / ASampleRate;
  Win := Window(AWindow, ANumTaps);
  SetLength(Result, ANumTaps);
  Sum := 0.0;

  for I := 0 to M do
  begin
    if I = M div 2 then
      H := 2.0 * Fc
    else
      H := Sin(2.0 * Pi * Fc * (I - M / 2)) / (Pi * (I - M / 2));
    Result[I] := H * Win[I];
    Sum := Sum + Result[I];
  end;

  // Normalize for unity DC gain
  if Sum > 0.0 then
    for I := 0 to M do Result[I] := Result[I] / Sum;
end;

class function TFirDesign.HighPass(
  ACutoffHz, ASampleRate: Double;
  ANumTaps: Integer;
  AWindow: TWindowType): TRealArray;
var
  I: Integer;
  LP: TRealArray;
begin
  LP := LowPass(ACutoffHz, ASampleRate, ANumTaps, AWindow);
  SetLength(Result, ANumTaps);
  // Spectral inversion: negate and add 1 at center tap
  for I := 0 to ANumTaps - 1 do
    Result[I] := -LP[I];
  Result[ANumTaps div 2] := Result[ANumTaps div 2] + 1.0;
end;

class function TFirDesign.BandPass(
  ALowHz, AHighHz, ASampleRate: Double;
  ANumTaps: Integer;
  AWindow: TWindowType): TRealArray;
var
  I: Integer;
  LP1, LP2: TRealArray;
begin
  LP1 := LowPass(AHighHz, ASampleRate, ANumTaps, AWindow);
  LP2 := LowPass(ALowHz,  ASampleRate, ANumTaps, AWindow);
  SetLength(Result, ANumTaps);
  for I := 0 to ANumTaps - 1 do
    Result[I] := LP1[I] - LP2[I];
end;

{ TFirFilterStage }

constructor TFirFilterStage.Create(
  const ACoeffs: TRealArray;
  const AName: string;
  ASampleRate: Integer);
begin
  inherited Create(AName, ASampleRate);
  SetCoeffs(ACoeffs);
end;

procedure TFirFilterStage.SetCoeffs(const ACoeffs: TRealArray);
begin
  FCoeffs  := Copy(ACoeffs, 0, Length(ACoeffs));
  FTaps    := Length(FCoeffs);
  SetLength(FDelay, FTaps);
  FillChar(FDelay[0], FTaps * SizeOf(Double), 0);
  FDelayPos := 0;
end;

function TFirFilterStage.Process(const AInput: TRealArray): TRealArray;
var
  I, J, Pos: Integer;
  Acc: Double;
begin
  SetLength(Result, Length(AInput));
  for I := 0 to High(AInput) do
  begin
    FDelay[FDelayPos] := AInput[I];
    Acc := 0.0;
    Pos := FDelayPos;
    for J := 0 to FTaps - 1 do
    begin
      Acc := Acc + FCoeffs[J] * FDelay[Pos];
      if Pos = 0 then Pos := FTaps - 1
      else Dec(Pos);
    end;
    FDelayPos := (FDelayPos + 1) mod FTaps;
    Result[I] := Acc;
  end;
end;

class function TFirFilterStage.CreateLowPass(
  ACutoffHz, ASampleRate: Double; ANumTaps: Integer): TFirFilterStage;
begin
  Result := Create(
    TFirDesign.LowPass(ACutoffHz, ASampleRate, ANumTaps),
    Format('FIR-LP-%.0fHz', [ACutoffHz]),
    Round(ASampleRate));
end;

class function TFirFilterStage.CreateHighPass(
  ACutoffHz, ASampleRate: Double; ANumTaps: Integer): TFirFilterStage;
begin
  Result := Create(
    TFirDesign.HighPass(ACutoffHz, ASampleRate, ANumTaps),
    Format('FIR-HP-%.0fHz', [ACutoffHz]),
    Round(ASampleRate));
end;

class function TFirFilterStage.CreateBandPass(
  ALowHz, AHighHz, ASampleRate: Double; ANumTaps: Integer): TFirFilterStage;
begin
  Result := Create(
    TFirDesign.BandPass(ALowHz, AHighHz, ASampleRate, ANumTaps),
    Format('FIR-BP-%.0f-%.0fHz', [ALowHz, AHighHz]),
    Round(ASampleRate));
end;

{ TIirLowPassStage }

constructor TIirLowPassStage.Create(ACutoffHz, ASampleRate: Double; const AName: string);
begin
  inherited Create(AName, Round(ASampleRate));
  FPrev := 0.0;
  SetCutoff(ACutoffHz, ASampleRate);
end;

procedure TIirLowPassStage.SetCutoff(ACutoffHz, ASampleRate: Double);
var
  RC, DT: Double;
begin
  RC := 1.0 / (2.0 * Pi * ACutoffHz);
  DT := 1.0 / ASampleRate;
  FAlpha := DT / (RC + DT);
end;

function TIirLowPassStage.Process(const AInput: TRealArray): TRealArray;
var
  I: Integer;
begin
  SetLength(Result, Length(AInput));
  for I := 0 to High(AInput) do
  begin
    FPrev := FPrev + FAlpha * (AInput[I] - FPrev);
    Result[I] := FPrev;
  end;
end;

end.
