unit uScope;

{$mode objfpc}{$H+}

// Scope / spectrum display model (Observer pattern + MVC separation).
// TScopeModel holds display data; UI subscribes via IEventHandler.
// The model does NOT depend on LCL — it can run headless for tests.

interface

uses
  Classes, SysUtils, SyncObjs,
  uDomainTypes, uInterfaces, uEventBus, uFft;

type
  TScopeMode = (smOscilloscope, smSpectrum, smWaterfall);

  TScopeConfig = record
    Mode: TScopeMode;
    Width: Integer;     // display width in pixels
    Height: Integer;    // display height in pixels
    FreqMin: Double;    // Hz, left edge
    FreqMax: Double;    // Hz, right edge
    SampleRate: Integer;
  end;

  // =========================================================================
  // Scope model: produces display-ready data from audio samples
  // =========================================================================
  TScopeModel = class
  private
    FConfig: TScopeConfig;
    FFftStage: TFftStage;
    FSpectrumData: TRealArray;    // normalized magnitude [0..1]
    FWaveformData: TRealArray;    // raw samples for oscilloscope
    FMarkHz: Double;
    FSpaceHz: Double;
    FSignalLevel: Double;
    FLock: TCriticalSection;
    FBus: TEventBus;

    procedure PublishUpdate;
    procedure UpdateSpectrum(const ASamples: TRealArray);
    procedure UpdateWaveform(const ASamples: TRealArray);
  public
    constructor Create(const AConfig: TScopeConfig; ABus: TEventBus);
    destructor Destroy; override;

    procedure FeedSamples(const ASamples: TRealArray);

    function GetSpectrumData: TRealArray;
    function GetWaveformData: TRealArray;
    function GetSignalLevel: Double;

    procedure SetMarkHz(AHz: Double);
    procedure SetSpaceHz(AHz: Double);
    procedure SetMode(AMode: TScopeMode);

    property Config: TScopeConfig read FConfig;
    property MarkHz: Double read FMarkHz write SetMarkHz;
    property SpaceHz: Double read FSpaceHz write SetSpaceHz;
  end;

  // =========================================================================
  // Frequency display model (carrier frequency indicator)
  // =========================================================================
  TFreqDisplayModel = class
  private
    FCurrentHz: Double;
    FMarkHz: Double;
    FSpaceHz: Double;
    FBus: TEventBus;
  public
    constructor Create(ABus: TEventBus);

    procedure SetFrequency(AHz: Double);
    procedure SetMarkHz(AHz: Double);
    procedure SetSpaceHz(AHz: Double);

    function GetCurrentHz: Double;
    function GetMarkHz: Double;
    function GetSpaceHz: Double;
    function GetCenterHz: Double;

    property CurrentHz: Double read GetCurrentHz write SetFrequency;
    property MarkHz: Double read GetMarkHz write SetMarkHz;
    property SpaceHz: Double read GetSpaceHz write SetSpaceHz;
    property CenterHz: Double read GetCenterHz;
  end;

  // Event data for scope updates
  TScopeUpdateEvent = class
  public
    SpectrumData: TRealArray;
    WaveformData: TRealArray;
    SignalLevel: Double;
  end;

const
  EVENT_SCOPE_UPDATE = 'scope.update';

implementation

{ TScopeModel }

constructor TScopeModel.Create(const AConfig: TScopeConfig; ABus: TEventBus);
begin
  inherited Create;
  FConfig := AConfig;
  FBus := ABus;
  FMarkHz := 2295.0;
  FSpaceHz := 2125.0;
  FSignalLevel := 0.0;
  FLock := TCriticalSection.Create;
  FFftStage := TFftStage.Create(
    AConfig.Width * 2,  // FFT size >= 2x display width
    AConfig.SampleRate);
end;

destructor TScopeModel.Destroy;
begin
  FLock.Free;
  FFftStage.Free;
  inherited;
end;

procedure TScopeModel.FeedSamples(const ASamples: TRealArray);
begin
  case FConfig.Mode of
    smSpectrum, smWaterfall: UpdateSpectrum(ASamples);
    smOscilloscope:           UpdateWaveform(ASamples);
  end;
  PublishUpdate;
end;

procedure TScopeModel.UpdateSpectrum(const ASamples: TRealArray);
var
  RawMag: TRealArray;
  I: Integer;
  MaxVal: Double;
begin
  RawMag := FFftStage.Process(ASamples);

  MaxVal := 1e-10;
  for I := 0 to High(RawMag) do
    if RawMag[I] > MaxVal then MaxVal := RawMag[I];

  FLock.Acquire;
  try
    SetLength(FSpectrumData, Length(RawMag));
    for I := 0 to High(RawMag) do
      FSpectrumData[I] := RawMag[I] / MaxVal;

    // Signal level: peak in the RTTY passband
    FSignalLevel := 0.0;
    if (FConfig.SampleRate > 0) and (Length(RawMag) > 0) then
    begin
      var BinHz := FConfig.SampleRate / (Length(RawMag) * 2.0);
      var MarkBin := Round(FMarkHz / BinHz);
      var SpaceBin := Round(FSpaceHz / BinHz);
      MarkBin := Max(0, Min(MarkBin, High(RawMag)));
      SpaceBin := Max(0, Min(SpaceBin, High(RawMag)));
      FSignalLevel := Max(FSpectrumData[MarkBin], FSpectrumData[SpaceBin]);
    end;
  finally
    FLock.Release;
  end;
end;

procedure TScopeModel.UpdateWaveform(const ASamples: TRealArray);
begin
  FLock.Acquire;
  try
    FWaveformData := Copy(ASamples, 0, Length(ASamples));
  finally
    FLock.Release;
  end;
end;

procedure TScopeModel.PublishUpdate;
var
  Evt: TScopeUpdateEvent;
begin
  Evt := TScopeUpdateEvent.Create;
  Evt.SpectrumData := GetSpectrumData;
  Evt.WaveformData := GetWaveformData;
  Evt.SignalLevel  := FSignalLevel;
  try
    FBus.Publish(EVENT_SCOPE_UPDATE, Evt);
  finally
    Evt.Free;
  end;
end;

function TScopeModel.GetSpectrumData: TRealArray;
begin
  FLock.Acquire;
  try
    Result := Copy(FSpectrumData, 0, Length(FSpectrumData));
  finally
    FLock.Release;
  end;
end;

function TScopeModel.GetWaveformData: TRealArray;
begin
  FLock.Acquire;
  try
    Result := Copy(FWaveformData, 0, Length(FWaveformData));
  finally
    FLock.Release;
  end;
end;

function TScopeModel.GetSignalLevel: Double;
begin
  FLock.Acquire;
  try
    Result := FSignalLevel;
  finally
    FLock.Release;
  end;
end;

procedure TScopeModel.SetMarkHz(AHz: Double);
begin
  FMarkHz := AHz;
end;

procedure TScopeModel.SetSpaceHz(AHz: Double);
begin
  FSpaceHz := AHz;
end;

procedure TScopeModel.SetMode(AMode: TScopeMode);
begin
  FConfig.Mode := AMode;
end;

{ TFreqDisplayModel }

constructor TFreqDisplayModel.Create(ABus: TEventBus);
begin
  inherited Create;
  FBus := ABus;
  FCurrentHz := 14070000.0;
  FMarkHz := 2295.0;
  FSpaceHz := 2125.0;
end;

procedure TFreqDisplayModel.SetFrequency(AHz: Double);
begin
  FCurrentHz := AHz;
  FBus.Publish(TEvents.RADIO_FREQ_CHANGED, TIntEventData.Create(Round(AHz)));
end;

procedure TFreqDisplayModel.SetMarkHz(AHz: Double);
begin
  FMarkHz := AHz;
end;

procedure TFreqDisplayModel.SetSpaceHz(AHz: Double);
begin
  FSpaceHz := AHz;
end;

function TFreqDisplayModel.GetCurrentHz: Double;
begin
  Result := FCurrentHz;
end;

function TFreqDisplayModel.GetMarkHz: Double;
begin
  Result := FMarkHz;
end;

function TFreqDisplayModel.GetSpaceHz: Double;
begin
  Result := FSpaceHz;
end;

function TFreqDisplayModel.GetCenterHz: Double;
begin
  Result := (FMarkHz + FSpaceHz) / 2.0;
end;

end.
