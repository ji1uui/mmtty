unit uDspPipeline;

{$mode objfpc}{$H+}

// Strategy + Composite pattern: composable DSP stage chain.
// Each stage is an IDspStage; the pipeline sequences them.

interface

uses
  Classes, SysUtils, uDomainTypes, uInterfaces;

type
  TDspStageList = specialize TFPGInterfacedObjectList<IDspStage>;

  // Abstract base for all DSP stages — DRY boilerplate for subclasses
  TAbstractDspStage = class(TInterfacedObject, IDspStage)
  private
    FStageName: string;
    FSampleRate: Integer;
  public
    constructor Create(const AName: string; ASampleRate: Integer);

    function Process(const AInput: TRealArray): TRealArray; virtual; abstract;
    function GetStageName: string;
    function GetSampleRate: Integer;
    procedure SetSampleRate(ARate: Integer); virtual;
    property StageName: string read GetStageName;
    property SampleRate: Integer read GetSampleRate write SetSampleRate;
  end;

  // Passthrough stage: useful as a null-object / placeholder
  TPassthroughStage = class(TAbstractDspStage)
  public
    function Process(const AInput: TRealArray): TRealArray; override;
  end;

  // Gain stage: simple amplitude scaling
  TGainStage = class(TAbstractDspStage)
  private
    FGain: Double;
  public
    constructor Create(AGain: Double; ASampleRate: Integer);
    function Process(const AInput: TRealArray): TRealArray; override;
    property Gain: Double read FGain write FGain;
  end;

  // DC blocker: removes DC offset via single-pole IIR
  TDcBlockerStage = class(TAbstractDspStage)
  private
    FPrev: Double;
    FPrevOut: Double;
    FAlpha: Double;  // typically 0.995
  public
    constructor Create(AAlpha: Double; ASampleRate: Integer);
    function Process(const AInput: TRealArray): TRealArray; override;
  end;

  // Squaring demodulator stage: |x|^2 for envelope detection
  TEnvelopeDetectorStage = class(TAbstractDspStage)
  public
    function Process(const AInput: TRealArray): TRealArray; override;
  end;

  // Pipeline (Composite): chains stages sequentially
  TDspPipeline = class(TInterfacedObject, IDspPipeline)
  private
    FStages: TDspStageList;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddStage(AStage: IDspStage);
    procedure RemoveStage(const AStageName: string);
    function Execute(const AInput: TRealArray): TRealArray;
    function GetStageCount: Integer;
    procedure Clear;
    property StageCount: Integer read GetStageCount;
  end;

  // Factory: builds common pipeline configurations
  TDspPipelineFactory = class
  public
    class function CreateRttyRxPipeline(ASampleRate: Integer): IDspPipeline;
    class function CreateRttyTxPipeline(ASampleRate: Integer): IDspPipeline;
  end;

implementation

{ TAbstractDspStage }

constructor TAbstractDspStage.Create(const AName: string; ASampleRate: Integer);
begin
  inherited Create;
  FStageName := AName;
  FSampleRate := ASampleRate;
end;

function TAbstractDspStage.GetStageName: string;
begin
  Result := FStageName;
end;

function TAbstractDspStage.GetSampleRate: Integer;
begin
  Result := FSampleRate;
end;

procedure TAbstractDspStage.SetSampleRate(ARate: Integer);
begin
  FSampleRate := ARate;
end;

{ TPassthroughStage }

function TPassthroughStage.Process(const AInput: TRealArray): TRealArray;
begin
  Result := Copy(AInput, 0, Length(AInput));
end;

{ TGainStage }

constructor TGainStage.Create(AGain: Double; ASampleRate: Integer);
begin
  inherited Create('Gain', ASampleRate);
  FGain := AGain;
end;

function TGainStage.Process(const AInput: TRealArray): TRealArray;
var
  I: Integer;
begin
  SetLength(Result, Length(AInput));
  for I := 0 to High(AInput) do
    Result[I] := AInput[I] * FGain;
end;

{ TDcBlockerStage }

constructor TDcBlockerStage.Create(AAlpha: Double; ASampleRate: Integer);
begin
  inherited Create('DcBlocker', ASampleRate);
  FAlpha := AAlpha;
  FPrev := 0.0;
  FPrevOut := 0.0;
end;

function TDcBlockerStage.Process(const AInput: TRealArray): TRealArray;
var
  I: Integer;
  Y: Double;
begin
  SetLength(Result, Length(AInput));
  for I := 0 to High(AInput) do
  begin
    Y := AInput[I] - FPrev + FAlpha * FPrevOut;
    FPrev := AInput[I];
    FPrevOut := Y;
    Result[I] := Y;
  end;
end;

{ TEnvelopeDetectorStage }

function TEnvelopeDetectorStage.Process(const AInput: TRealArray): TRealArray;
var
  I: Integer;
begin
  SetLength(Result, Length(AInput));
  for I := 0 to High(AInput) do
    Result[I] := AInput[I] * AInput[I];
end;

{ TDspPipeline }

constructor TDspPipeline.Create;
begin
  inherited Create;
  FStages := TDspStageList.Create;
end;

destructor TDspPipeline.Destroy;
begin
  FStages.Free;
  inherited;
end;

procedure TDspPipeline.AddStage(AStage: IDspStage);
begin
  FStages.Add(AStage);
end;

procedure TDspPipeline.RemoveStage(const AStageName: string);
var
  I: Integer;
begin
  for I := FStages.Count - 1 downto 0 do
    if FStages[I].StageName = AStageName then
    begin
      FStages.Delete(I);
      Break;
    end;
end;

function TDspPipeline.Execute(const AInput: TRealArray): TRealArray;
var
  I: Integer;
  Buf: TRealArray;
begin
  Buf := Copy(AInput, 0, Length(AInput));
  for I := 0 to FStages.Count - 1 do
    Buf := FStages[I].Process(Buf);
  Result := Buf;
end;

function TDspPipeline.GetStageCount: Integer;
begin
  Result := FStages.Count;
end;

procedure TDspPipeline.Clear;
begin
  FStages.Clear;
end;

{ TDspPipelineFactory }

class function TDspPipelineFactory.CreateRttyRxPipeline(ASampleRate: Integer): IDspPipeline;
var
  Pipeline: TDspPipeline;
begin
  Pipeline := TDspPipeline.Create;
  Pipeline.AddStage(TDcBlockerStage.Create(0.995, ASampleRate));
  Pipeline.AddStage(TGainStage.Create(1.0, ASampleRate));
  Pipeline.AddStage(TEnvelopeDetectorStage.Create('Envelope', ASampleRate));
  Result := Pipeline;
end;

class function TDspPipelineFactory.CreateRttyTxPipeline(ASampleRate: Integer): IDspPipeline;
var
  Pipeline: TDspPipeline;
begin
  Pipeline := TDspPipeline.Create;
  Pipeline.AddStage(TGainStage.Create(0.9, ASampleRate));  // prevent clipping
  Result := Pipeline;
end;

end.
