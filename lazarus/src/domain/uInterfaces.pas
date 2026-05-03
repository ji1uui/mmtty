unit uInterfaces;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uDomainTypes;

type
  // =========================================================================
  // Observer / Event Bus (Observer Pattern)
  // =========================================================================

  IEventHandler = interface
    ['{A1000001-0000-0000-0000-000000000001}']
    procedure HandleEvent(const AEventName: string; AData: TObject);
  end;

  IEventBus = interface
    ['{A1000001-0000-0000-0000-000000000002}']
    procedure Subscribe(const AEventName: string; AHandler: IEventHandler);
    procedure Unsubscribe(const AEventName: string; AHandler: IEventHandler);
    procedure Publish(const AEventName: string; AData: TObject);
  end;

  // =========================================================================
  // Communication Port (Adapter Pattern)
  // =========================================================================

  ICommPort = interface
    ['{A1000002-0000-0000-0000-000000000001}']
    function Open(const APortName: string; ABaudRate: Integer): Boolean;
    procedure Close;
    function WriteBytes(const AData: TBytes): Integer;
    function ReadBytes(ABuffer: TBytes; ACount: Integer): Integer;
    function GetState: TCommState;
    function GetPortName: string;
    property State: TCommState read GetState;
    property PortName: string read GetPortName;
  end;

  // PTT / hardware keying
  IPttController = interface
    ['{A1000002-0000-0000-0000-000000000002}']
    procedure SetPtt(AActive: Boolean);
    function GetPtt: Boolean;
    procedure SetRts(AActive: Boolean);
    procedure SetDtr(AActive: Boolean);
    property Active: Boolean read GetPtt write SetPtt;
  end;

  // =========================================================================
  // TX Queue (Command Pattern)
  // =========================================================================

  ITxQueue = interface
    ['{A1000003-0000-0000-0000-000000000001}']
    procedure Enqueue(const ACommand: TTxCommand);
    function Dequeue(out ACommand: TTxCommand): Boolean;
    function Peek(out ACommand: TTxCommand): Boolean;
    procedure Clear;
    function GetCount: Integer;
    function GetIsEmpty: Boolean;
    property Count: Integer read GetCount;
    property IsEmpty: Boolean read GetIsEmpty;
  end;

  // =========================================================================
  // Modulation / Protocol Strategy (Strategy Pattern)
  // =========================================================================

  IModulationProfile = interface
    ['{A1000004-0000-0000-0000-000000000001}']
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

  IDiddleStrategy = interface
    ['{A1000004-0000-0000-0000-000000000002}']
    function GetNextDiddleChar: AnsiChar;
    function ShouldDiddle: Boolean;
  end;

  // =========================================================================
  // DSP Pipeline (Strategy + Chain of Responsibility)
  // =========================================================================

  IDspStage = interface
    ['{A1000005-0000-0000-0000-000000000001}']
    function Process(const AInput: TRealArray): TRealArray;
    function GetStageName: string;
    function GetSampleRate: Integer;
    procedure SetSampleRate(ARate: Integer);
    property StageName: string read GetStageName;
    property SampleRate: Integer read GetSampleRate write SetSampleRate;
  end;

  IDspPipeline = interface
    ['{A1000005-0000-0000-0000-000000000002}']
    procedure AddStage(AStage: IDspStage);
    procedure RemoveStage(const AStageName: string);
    function Execute(const AInput: TRealArray): TRealArray;
    function GetStageCount: Integer;
    procedure Clear;
    property StageCount: Integer read GetStageCount;
  end;

  // =========================================================================
  // Audio I/O (Adapter Pattern)
  // =========================================================================

  TAudioDataCallback = procedure(const AData: TRealArray) of object;

  IAudioInput = interface
    ['{A1000006-0000-0000-0000-000000000001}']
    function Open(const AFormat: TAudioFormat; ADeviceIndex: Integer): Boolean;
    procedure Close;
    procedure SetCallback(ACallback: TAudioDataCallback);
    function Start: Boolean;
    procedure Stop;
    function GetIsOpen: Boolean;
    function ListDevices: TStringList;
    property IsOpen: Boolean read GetIsOpen;
  end;

  IAudioOutput = interface
    ['{A1000006-0000-0000-0000-000000000002}']
    function Open(const AFormat: TAudioFormat; ADeviceIndex: Integer): Boolean;
    procedure Close;
    function WriteSamples(const AData: TRealArray): Integer;
    function Start: Boolean;
    procedure Stop;
    function GetIsOpen: Boolean;
    function ListDevices: TStringList;
    property IsOpen: Boolean read GetIsOpen;
  end;

  // =========================================================================
  // RTTY Codec (Strategy Pattern)
  // =========================================================================

  IRttyEncoder = interface
    ['{A1000007-0000-0000-0000-000000000001}']
    function Encode(const AText: string): TBytes;
    function GetProfile: IModulationProfile;
    property Profile: IModulationProfile read GetProfile;
  end;

  IRttyDecoder = interface
    ['{A1000007-0000-0000-0000-000000000002}']
    procedure FeedSamples(const ASamples: TRealArray);
    function GetDecodedText: string;
    function GetSignalLevel: Double;
    function GetTuningOffset: Double;
    property DecodedText: string read GetDecodedText;
    property SignalLevel: Double read GetSignalLevel;
    property TuningOffset: Double read GetTuningOffset;
  end;

  // =========================================================================
  // Log Sink (Repository Pattern)
  // =========================================================================

  ILogSink = interface
    ['{A1000008-0000-0000-0000-000000000001}']
    procedure Log(const AEntry: TLogEntry);
    procedure Flush;
    function GetIsOpen: Boolean;
    property IsOpen: Boolean read GetIsOpen;
  end;

  IQsoRepository = interface
    ['{A1000008-0000-0000-0000-000000000002}']
    procedure Append(const AQso: TQsoRecord);
    function FindByCallsign(const ACallsign: string): TQsoRecord;
    procedure Save;
    procedure Load;
  end;

  // =========================================================================
  // Configuration (Repository Pattern)
  // =========================================================================

  IConfigStore = interface
    ['{A1000009-0000-0000-0000-000000000001}']
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

  // =========================================================================
  // Radio Control (Adapter Pattern)
  // =========================================================================

  IRadioController = interface
    ['{A100000A-0000-0000-0000-000000000001}']
    function Connect(const APortName: string; ABaudRate: Integer): Boolean;
    procedure Disconnect;
    function SetFrequency(AHz: Int64): Boolean;
    function GetFrequency: Int64;
    function SetMode(AMode: TRadioMode): Boolean;
    function GetMode: TRadioMode;
    function GetIsConnected: Boolean;
    property Frequency: Int64 read GetFrequency write SetFrequency;
    property Mode: TRadioMode read GetMode write SetMode;
    property IsConnected: Boolean read GetIsConnected;
  end;

  // =========================================================================
  // TX State Machine (State Pattern)
  // =========================================================================

  ITxStateMachine = interface
    ['{A100000B-0000-0000-0000-000000000001}']
    procedure Transition(ANewState: TTxState);
    function GetCurrentState: TTxState;
    function CanTransitionTo(AState: TTxState): Boolean;
    procedure OnEnterState(AState: TTxState);
    procedure OnExitState(AState: TTxState);
    property CurrentState: TTxState read GetCurrentState;
  end;

  // =========================================================================
  // Service interfaces (Facade Pattern)
  // =========================================================================

  ITxService = interface
    ['{A100000C-0000-0000-0000-000000000001}']
    procedure SendText(const AText: string);
    procedure SendCommand(const ACommand: TTxCommand);
    procedure Abort;
    procedure Tune(ADurationMs: Integer);
    function GetState: TTxState;
    property State: TTxState read GetState;
  end;

  IRxService = interface
    ['{A100000C-0000-0000-0000-000000000002}']
    procedure Start;
    procedure Stop;
    function GetDecodedText: string;
    function GetIsRunning: Boolean;
    property IsRunning: Boolean read GetIsRunning;
    property DecodedText: string read GetDecodedText;
  end;

implementation

end.
