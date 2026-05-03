unit uDomainTypes;

{$mode objfpc}{$H+}

interface

type
  // Communication port state
  TCommState = (
    csDisconnected,
    csConnecting,
    csConnected,
    csDisconnecting,
    csError
  );

  // TX lifecycle state
  TTxState = (
    tsIdle,
    tsWaitingPtt,
    tsSending,
    tsTuning,
    tsAborting
  );

  // TX command types (Command pattern)
  TTxCommandType = (
    tcNone,
    tcText,
    tcSwitchToRx,
    tcTune,
    tcAbort,
    tcFigShift,
    tcLetShift,
    tcDiddleOn,
    tcDiddleOff
  );

  TTxCommand = record
    CommandType: TTxCommandType;
    Data: string;
    Priority: Integer;
  end;

  // Audio configuration
  TAudioFormat = record
    SampleRate: Integer;
    Channels: Integer;
    BitsPerSample: Integer;
  end;

  // RTTY configuration
  TRttyMode = (
    rmRTTY,
    rmPSK31,
    rmFSK,
    rmAFSK
  );

  TModulationType = (
    mtNone,
    mtMark,
    mtSpace
  );

  TRttyConfig = record
    Mode: TRttyMode;
    BaudRate: Double;
    ShiftHz: Double;
    MarkHz: Double;
    SpaceHz: Double;
    Inversion: Boolean;
    UoS: Boolean;    // Unshift on Space
  end;

  // Log entry
  TLogLevel = (
    llDebug,
    llInfo,
    llWarning,
    llError
  );

  TLogEntry = record
    Level: TLogLevel;
    Timestamp: TDateTime;
    Message: string;
    Source: string;
  end;

  // QSO contact record
  TQsoRecord = record
    Callsign: string;
    DateTime: TDateTime;
    Frequency: Int64;
    Mode: string;
    RSTSent: string;
    RSTReceived: string;
    Name: string;
    Comments: string;
  end;

  // Radio control
  TRadioMode = (
    rmUnknown,
    rmCW,
    rmSSB,
    rmAM,
    rmFM,
    rmRTTY,
    rmDigital
  );

  // DSP buffer types
  TRealArray  = array of Double;
  TComplexItem = record Re, Im: Double; end;
  TComplexArray = array of TComplexItem;

  // Event data
  TCommEventType = (
    ceConnected,
    ceDisconnected,
    ceError,
    ceDataReceived
  );

  TCommEvent = record
    EventType: TCommEventType;
    PortName: string;
    ErrorMsg: string;
  end;

  TRxEvent = record
    DecodedText: string;
    Frequency: Double;
    SignalLevel: Double;
  end;

implementation

end.
