unit ummtty;

{$mode objfpc}{$H+}

// Core MMTTY application module (Facade pattern).
// Wires all services together; single point of entry for the UI layer.
// The form only knows TMMTTYApp — not individual services.

interface

uses
  Classes, SysUtils,
  uDomainTypes, uInterfaces, uEventBus,
  uComm, uComLib, uSound, uWave, uRtty,
  uFft, ufir, uDspPipeline,
  uTxStateMachine, uServiceLocator,
  uTxService, uRxService;

type
  TMMTTYConfig = record
    CommPortName: string;
    CommBaudRate: Integer;
    PttViaRts: Boolean;
    AudioInDevice: Integer;
    AudioOutDevice: Integer;
    SampleRate: Integer;
    RttyBaudRate: Double;
    RttyShiftHz: Double;
    RttyMarkHz: Double;
    UseDummyDevices: Boolean;  // True = null comm/audio (no hardware)
  end;

  TMMTTYApp = class
  private
    FConfig: TMMTTYConfig;
    FBus: TEventBus;
    FLocator: TServiceLocator;

    FCommPort:  ICommPort;
    FPtt:       IPttController;
    FTxQueue:   ITxQueue;
    FAudioIn:   IAudioInput;
    FAudioOut:  IAudioOutput;
    FProfile:   IModulationProfile;
    FEncoder:   IRttyEncoder;
    FDecoder:   IRttyDecoder;
    FRxPipeline: IDspPipeline;

    FTxService: ITxService;
    FRxService: IRxService;

    FInitialized: Boolean;

    procedure BuildServices;
    procedure RegisterServices;
  public
    constructor Create(const AConfig: TMMTTYConfig);
    destructor Destroy; override;

    procedure Initialize;
    procedure Shutdown;

    // TX operations
    procedure SendText(const AText: string);
    procedure AbortTx;
    procedure StartTune(ADurationMs: Integer = 5000);

    // RX operations
    procedure StartRx;
    procedure StopRx;

    // Connection
    function Connect: Boolean;
    procedure Disconnect;

    // Accessors for UI
    function GetTxState: TTxState;
    function IsRxRunning: Boolean;
    function IsConnected: Boolean;

    property Bus: TEventBus read FBus;
    property Locator: TServiceLocator read FLocator;
    property Config: TMMTTYConfig read FConfig;
    property Initialized: Boolean read FInitialized;

    class function DefaultConfig: TMMTTYConfig;
  end;

implementation

{ TMMTTYApp }

constructor TMMTTYApp.Create(const AConfig: TMMTTYConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FBus := TEventBus.Instance;
  FLocator := TServiceLocator.Instance;
  FInitialized := False;
end;

destructor TMMTTYApp.Destroy;
begin
  if FInitialized then Shutdown;
  inherited;
end;

procedure TMMTTYApp.BuildServices;
var
  RttyConfig: TRttyConfig;
  AudioFmt: TAudioFormat;
begin
  // Communication port
  if FConfig.UseDummyDevices then
    FCommPort := TCommPortFactory.Create(cptNull, FBus)
  else
    FCommPort := TCommPortFactory.Create(cptSerial, FBus, FConfig.PttViaRts);

  FPtt := IPttController(FCommPort);

  // TX queue
  FTxQueue := TCommPortFactory.CreateTxQueue;

  // Audio devices
  AudioFmt := TAudioDeviceFactory.DefaultFormat(FConfig.SampleRate);
  FAudioIn  := TAudioDeviceFactory.CreateInput(FBus, FConfig.UseDummyDevices);
  FAudioOut := TAudioDeviceFactory.CreateOutput(FBus, FConfig.UseDummyDevices);
  FAudioIn.Open(AudioFmt, FConfig.AudioInDevice);
  FAudioOut.Open(AudioFmt, FConfig.AudioOutDevice);

  // RTTY profile + codec
  RttyConfig := TRttyFactory.CreateRttyConfig(
    FConfig.RttyBaudRate,
    FConfig.RttyShiftHz,
    FConfig.RttyMarkHz);
  FProfile := TRttyFactory.CreateProfile(RttyConfig);
  FEncoder := TRttyFactory.CreateEncoder(FProfile);
  FDecoder := TRttyFactory.CreateDecoder(FProfile, FConfig.SampleRate);

  // RX DSP pipeline
  FRxPipeline := TDspPipelineFactory.CreateRttyRxPipeline(FConfig.SampleRate);

  // Application services
  FTxService := TTxService.Create(FCommPort, FPtt, FTxQueue, FProfile, FBus);
  FRxService := TRxService.Create(FAudioIn, FRxPipeline, FDecoder, FBus);
end;

procedure TMMTTYApp.RegisterServices;
begin
  FLocator.RegisterOrReplace(ICommPort, FCommPort);
  FLocator.RegisterOrReplace(ITxQueue, FTxQueue);
  FLocator.RegisterOrReplace(IAudioInput, FAudioIn);
  FLocator.RegisterOrReplace(IAudioOutput, FAudioOut);
  FLocator.RegisterOrReplace(ITxService, FTxService);
  FLocator.RegisterOrReplace(IRxService, FRxService);
end;

procedure TMMTTYApp.Initialize;
begin
  if FInitialized then Exit;
  BuildServices;
  RegisterServices;
  FInitialized := True;
end;

procedure TMMTTYApp.Shutdown;
begin
  if not FInitialized then Exit;
  StopRx;
  Disconnect;
  FInitialized := False;
end;

function TMMTTYApp.Connect: Boolean;
begin
  if FConfig.UseDummyDevices then
    Result := FCommPort.Open('NULL', 9600)
  else
    Result := FCommPort.Open(FConfig.CommPortName, FConfig.CommBaudRate);
end;

procedure TMMTTYApp.Disconnect;
begin
  FCommPort.Close;
end;

procedure TMMTTYApp.SendText(const AText: string);
begin
  FTxService.SendText(AText);
end;

procedure TMMTTYApp.AbortTx;
begin
  FTxService.Abort;
end;

procedure TMMTTYApp.StartTune(ADurationMs: Integer);
begin
  FTxService.Tune(ADurationMs);
end;

procedure TMMTTYApp.StartRx;
begin
  FRxService.Start;
end;

procedure TMMTTYApp.StopRx;
begin
  FRxService.Stop;
end;

function TMMTTYApp.GetTxState: TTxState;
begin
  Result := FTxService.GetState;
end;

function TMMTTYApp.IsRxRunning: Boolean;
begin
  Result := FRxService.GetIsRunning;
end;

function TMMTTYApp.IsConnected: Boolean;
begin
  Result := FCommPort.GetState = csConnected;
end;

class function TMMTTYApp.DefaultConfig: TMMTTYConfig;
begin
  Result.CommPortName     := 'COM1';
  Result.CommBaudRate     := 9600;
  Result.PttViaRts        := True;
  Result.AudioInDevice    := 0;
  Result.AudioOutDevice   := 0;
  Result.SampleRate       := 11025;
  Result.RttyBaudRate     := 45.45;
  Result.RttyShiftHz      := 170.0;
  Result.RttyMarkHz       := 2295.0;
  Result.UseDummyDevices  := False;
end;

end.
