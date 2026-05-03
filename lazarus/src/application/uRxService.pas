unit uRxService;

{$mode objfpc}{$H+}

// RX orchestration service (Facade pattern).
// Wires IAudioInput -> IDspPipeline -> IRttyDecoder and publishes decode events.

interface

uses
  Classes, SysUtils, SyncObjs,
  uDomainTypes, uInterfaces, uEventBus;

type
  TRxService = class(TInterfacedObject, IRxService)
  private
    FAudioIn:    IAudioInput;
    FPipeline:   IDspPipeline;
    FDecoder:    IRttyDecoder;
    FBus:        TEventBus;
    FRunning:    Boolean;
    FDecodeText: string;
    FLock:       TCriticalSection;

    procedure OnAudioData(const AData: TRealArray);
    procedure PublishDecode(const AText: string);
  public
    constructor Create(
      AAudioIn: IAudioInput;
      APipeline: IDspPipeline;
      ADecoder: IRttyDecoder;
      ABus: TEventBus);
    destructor Destroy; override;

    // IRxService
    procedure Start;
    procedure Stop;
    function GetDecodedText: string;
    function GetIsRunning: Boolean;

    property IsRunning: Boolean read GetIsRunning;
    property DecodedText: string read GetDecodedText;
  end;

implementation

{ TRxService }

constructor TRxService.Create(
  AAudioIn: IAudioInput;
  APipeline: IDspPipeline;
  ADecoder: IRttyDecoder;
  ABus: TEventBus);
begin
  inherited Create;
  FAudioIn  := AAudioIn;
  FPipeline := APipeline;
  FDecoder  := ADecoder;
  FBus      := ABus;
  FRunning  := False;
  FLock     := TCriticalSection.Create;

  FAudioIn.SetCallback(@OnAudioData);
end;

destructor TRxService.Destroy;
begin
  Stop;
  FLock.Free;
  inherited;
end;

procedure TRxService.Start;
begin
  if FRunning then Exit;
  FRunning := True;
  FAudioIn.Start;
end;

procedure TRxService.Stop;
begin
  if not FRunning then Exit;
  FRunning := False;
  FAudioIn.Stop;
end;

procedure TRxService.OnAudioData(const AData: TRealArray);
var
  Processed: TRealArray;
  Decoded: string;
begin
  // DSP pipeline (filters, envelope detection, etc.)
  Processed := FPipeline.Execute(AData);

  // Feed processed samples to the RTTY decoder
  FDecoder.FeedSamples(Processed);

  // Collect any new decoded characters
  Decoded := FDecoder.GetDecodedText;
  if Decoded <> '' then
    PublishDecode(Decoded);

  // Publish signal level for scope/indicator UI
  FBus.Publish(TEvents.RX_SIGNAL_LEVEL,
    TDoubleEventData.Create(FDecoder.GetSignalLevel));
end;

procedure TRxService.PublishDecode(const AText: string);
var
  Data: TStringEventData;
begin
  FLock.Acquire;
  try
    FDecodeText := FDecodeText + AText;
  finally
    FLock.Release;
  end;

  Data := TStringEventData.Create(AText);
  try
    FBus.Publish(TEvents.RX_TEXT_DECODED, Data);
  finally
    Data.Free;
  end;
end;

function TRxService.GetDecodedText: string;
begin
  FLock.Acquire;
  try
    Result := FDecodeText;
  finally
    FLock.Release;
  end;
end;

function TRxService.GetIsRunning: Boolean;
begin
  Result := FRunning;
end;

end.
