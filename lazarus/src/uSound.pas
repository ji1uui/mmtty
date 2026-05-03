unit uSound;

{$mode objfpc}{$H+}

// Audio I/O adapter layer (Adapter pattern).
// Platform-specific audio backed behind IAudioInput / IAudioOutput interfaces.
// Windows uses WaveIn/WaveOut (MMSYSTEM); non-Windows stubs compile but are inert.

interface

uses
  Classes, SysUtils,
  {$IFDEF WINDOWS}
  MMSystem, Windows,
  {$ENDIF}
  uDomainTypes, uInterfaces, uEventBus;

const
  WAVE_BUFFER_COUNT = 4;
  WAVE_BUFFER_FRAMES = 1024;

type
  // =========================================================================
  // Abstract base — common bookkeeping
  // =========================================================================
  TAbstractAudioDevice = class
  protected
    FFormat: TAudioFormat;
    FDeviceIndex: Integer;
    FIsOpen: Boolean;
    FBus: TEventBus;
  public
    constructor Create(ABus: TEventBus);
    function GetIsOpen: Boolean;
    function ListDevices: TStringList; virtual; abstract;
    property IsOpen: Boolean read GetIsOpen;
  end;

  // =========================================================================
  // Audio Input (WaveIn adapter)
  // =========================================================================
  TWaveInDevice = class(TAbstractAudioDevice, IAudioInput)
  private
    FCallback: TAudioDataCallback;
    FIsRunning: Boolean;
    {$IFDEF WINDOWS}
    FWaveIn: HWAVEIN;
    FHeaders: array[0..WAVE_BUFFER_COUNT - 1] of TWAVEHDR;
    FBuffers: array[0..WAVE_BUFFER_COUNT - 1] of array of SmallInt;
    procedure ProcessBuffer(AHeader: PWAVEHDR);
    class procedure WaveInCallback(
      hWaveIn: HWAVEIN; uMsg: UINT;
      dwInstance, dwParam1, dwParam2: DWORD_PTR); stdcall; static;
    {$ENDIF}
  public
    constructor Create(ABus: TEventBus);
    destructor Destroy; override;

    // IAudioInput
    function Open(const AFormat: TAudioFormat; ADeviceIndex: Integer): Boolean;
    procedure Close;
    procedure SetCallback(ACallback: TAudioDataCallback);
    function Start: Boolean;
    procedure Stop;
    function GetIsOpen: Boolean;
    function ListDevices: TStringList; override;
  end;

  // =========================================================================
  // Audio Output (WaveOut adapter)
  // =========================================================================
  TWaveOutDevice = class(TAbstractAudioDevice, IAudioOutput)
  private
    FIsRunning: Boolean;
    {$IFDEF WINDOWS}
    FWaveOut: HWAVEOUT;
    {$ENDIF}
  public
    constructor Create(ABus: TEventBus);
    destructor Destroy; override;

    // IAudioOutput
    function Open(const AFormat: TAudioFormat; ADeviceIndex: Integer): Boolean;
    procedure Close;
    function WriteSamples(const AData: TRealArray): Integer;
    function Start: Boolean;
    procedure Stop;
    function GetIsOpen: Boolean;
    function ListDevices: TStringList; override;
  end;

  // =========================================================================
  // Null audio devices — Null Object pattern
  // =========================================================================
  TNullAudioInput = class(TInterfacedObject, IAudioInput)
  private
    FCallback: TAudioDataCallback;
    FIsOpen: Boolean;
  public
    function Open(const AFormat: TAudioFormat; ADeviceIndex: Integer): Boolean;
    procedure Close;
    procedure SetCallback(ACallback: TAudioDataCallback);
    function Start: Boolean;
    procedure Stop;
    function GetIsOpen: Boolean;
    function ListDevices: TStringList;
  end;

  TNullAudioOutput = class(TInterfacedObject, IAudioOutput)
  private
    FIsOpen: Boolean;
  public
    function Open(const AFormat: TAudioFormat; ADeviceIndex: Integer): Boolean;
    procedure Close;
    function WriteSamples(const AData: TRealArray): Integer;
    function Start: Boolean;
    procedure Stop;
    function GetIsOpen: Boolean;
    function ListDevices: TStringList;
  end;

  // Factory
  TAudioDeviceFactory = class
  public
    class function CreateInput(ABus: TEventBus; ANullDevice: Boolean = False): IAudioInput;
    class function CreateOutput(ABus: TEventBus; ANullDevice: Boolean = False): IAudioOutput;
    class function DefaultFormat(ASampleRate: Integer = 11025): TAudioFormat;
  end;

implementation

{ TAbstractAudioDevice }

constructor TAbstractAudioDevice.Create(ABus: TEventBus);
begin
  inherited Create;
  FIsOpen := False;
  FBus := ABus;
end;

function TAbstractAudioDevice.GetIsOpen: Boolean;
begin
  Result := FIsOpen;
end;

{ TWaveInDevice }

constructor TWaveInDevice.Create(ABus: TEventBus);
begin
  inherited Create(ABus);
  FIsRunning := False;
  {$IFDEF WINDOWS}
  FWaveIn := 0;
  {$ENDIF}
end;

destructor TWaveInDevice.Destroy;
begin
  if FIsOpen then Close;
  inherited;
end;

function TWaveInDevice.Open(const AFormat: TAudioFormat; ADeviceIndex: Integer): Boolean;
{$IFDEF WINDOWS}
var
  WFX: TWaveFormatEx;
  I: Integer;
begin
  if FIsOpen then begin Result := False; Exit; end;

  FFormat := AFormat;
  FDeviceIndex := ADeviceIndex;

  WFX.wFormatTag      := WAVE_FORMAT_PCM;
  WFX.nChannels       := AFormat.Channels;
  WFX.nSamplesPerSec  := AFormat.SampleRate;
  WFX.wBitsPerSample  := AFormat.BitsPerSample;
  WFX.nBlockAlign     := (WFX.nChannels * WFX.wBitsPerSample) div 8;
  WFX.nAvgBytesPerSec := WFX.nSamplesPerSec * WFX.nBlockAlign;
  WFX.cbSize          := 0;

  if waveInOpen(@FWaveIn, ADeviceIndex, @WFX,
      DWORD_PTR(@TWaveInDevice.WaveInCallback),
      DWORD_PTR(Self), CALLBACK_FUNCTION) <> MMSYSERR_NOERROR then
  begin
    Result := False;
    Exit;
  end;

  for I := 0 to WAVE_BUFFER_COUNT - 1 do
  begin
    SetLength(FBuffers[I], WAVE_BUFFER_FRAMES * AFormat.Channels);
    FillChar(FHeaders[I], SizeOf(TWAVEHDR), 0);
    FHeaders[I].lpData         := PAnsiChar(@FBuffers[I][0]);
    FHeaders[I].dwBufferLength := WAVE_BUFFER_FRAMES * AFormat.Channels * (AFormat.BitsPerSample div 8);
    FHeaders[I].dwUser         := DWORD_PTR(I);
    waveInPrepareHeader(FWaveIn, @FHeaders[I], SizeOf(TWAVEHDR));
    waveInAddBuffer(FWaveIn, @FHeaders[I], SizeOf(TWAVEHDR));
  end;

  FIsOpen := True;
  Result := True;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

procedure TWaveInDevice.Close;
begin
  if not FIsOpen then Exit;
  Stop;
  {$IFDEF WINDOWS}
  if FWaveIn <> 0 then
  begin
    waveInReset(FWaveIn);
    waveInClose(FWaveIn);
    FWaveIn := 0;
  end;
  {$ENDIF}
  FIsOpen := False;
end;

procedure TWaveInDevice.SetCallback(ACallback: TAudioDataCallback);
begin
  FCallback := ACallback;
end;

function TWaveInDevice.Start: Boolean;
begin
  if not FIsOpen then begin Result := False; Exit; end;
  {$IFDEF WINDOWS}
  FIsRunning := waveInStart(FWaveIn) = MMSYSERR_NOERROR;
  Result := FIsRunning;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

procedure TWaveInDevice.Stop;
begin
  if not FIsRunning then Exit;
  {$IFDEF WINDOWS}
  waveInStop(FWaveIn);
  {$ENDIF}
  FIsRunning := False;
end;

function TWaveInDevice.GetIsOpen: Boolean;
begin
  Result := FIsOpen;
end;

function TWaveInDevice.ListDevices: TStringList;
{$IFDEF WINDOWS}
var
  I, Count: Integer;
  Caps: TWaveInCaps;
begin
  Result := TStringList.Create;
  Count := waveInGetNumDevs;
  for I := 0 to Count - 1 do
  begin
    FillChar(Caps, SizeOf(Caps), 0);
    if waveInGetDevCaps(I, @Caps, SizeOf(Caps)) = MMSYSERR_NOERROR then
      Result.Add(Caps.szPname);
  end;
end;
{$ELSE}
begin
  Result := TStringList.Create;
end;
{$ENDIF}

{$IFDEF WINDOWS}
procedure TWaveInDevice.ProcessBuffer(AHeader: PWAVEHDR);
var
  SampleCount, I: Integer;
  Samples: PSmallInt;
  RealBuf: TRealArray;
begin
  if not Assigned(FCallback) then Exit;
  SampleCount := AHeader^.dwBytesRecorded div (FFormat.BitsPerSample div 8);
  SetLength(RealBuf, SampleCount);
  Samples := PSmallInt(AHeader^.lpData);
  for I := 0 to SampleCount - 1 do
    RealBuf[I] := Samples[I] / 32768.0;
  FCallback(RealBuf);
  waveInAddBuffer(FWaveIn, AHeader, SizeOf(TWAVEHDR));
end;

class procedure TWaveInDevice.WaveInCallback(
  hWaveIn: HWAVEIN; uMsg: UINT;
  dwInstance, dwParam1, dwParam2: DWORD_PTR); stdcall;
var
  Device: TWaveInDevice;
begin
  if uMsg <> WIM_DATA then Exit;
  Device := TWaveInDevice(Pointer(dwInstance));
  Device.ProcessBuffer(PWAVEHDR(dwParam1));
end;
{$ENDIF}

{ TWaveOutDevice }

constructor TWaveOutDevice.Create(ABus: TEventBus);
begin
  inherited Create(ABus);
  FIsRunning := False;
  {$IFDEF WINDOWS}
  FWaveOut := 0;
  {$ENDIF}
end;

destructor TWaveOutDevice.Destroy;
begin
  if FIsOpen then Close;
  inherited;
end;

function TWaveOutDevice.Open(const AFormat: TAudioFormat; ADeviceIndex: Integer): Boolean;
{$IFDEF WINDOWS}
var
  WFX: TWaveFormatEx;
begin
  if FIsOpen then begin Result := False; Exit; end;
  FFormat := AFormat;

  WFX.wFormatTag      := WAVE_FORMAT_PCM;
  WFX.nChannels       := AFormat.Channels;
  WFX.nSamplesPerSec  := AFormat.SampleRate;
  WFX.wBitsPerSample  := AFormat.BitsPerSample;
  WFX.nBlockAlign     := (WFX.nChannels * WFX.wBitsPerSample) div 8;
  WFX.nAvgBytesPerSec := WFX.nSamplesPerSec * WFX.nBlockAlign;
  WFX.cbSize          := 0;

  Result := waveOutOpen(@FWaveOut, ADeviceIndex, @WFX,
    0, 0, CALLBACK_NULL) = MMSYSERR_NOERROR;
  if Result then FIsOpen := True;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

procedure TWaveOutDevice.Close;
begin
  if not FIsOpen then Exit;
  Stop;
  {$IFDEF WINDOWS}
  if FWaveOut <> 0 then
  begin
    waveOutReset(FWaveOut);
    waveOutClose(FWaveOut);
    FWaveOut := 0;
  end;
  {$ENDIF}
  FIsOpen := False;
end;

function TWaveOutDevice.WriteSamples(const AData: TRealArray): Integer;
{$IFDEF WINDOWS}
var
  IntBuf: array of SmallInt;
  Header: TWAVEHDR;
  I: Integer;
begin
  if not FIsOpen then begin Result := -1; Exit; end;
  SetLength(IntBuf, Length(AData));
  for I := 0 to High(AData) do
    IntBuf[I] := Round(AData[I] * 32767);

  FillChar(Header, SizeOf(Header), 0);
  Header.lpData         := PAnsiChar(@IntBuf[0]);
  Header.dwBufferLength := Length(IntBuf) * SizeOf(SmallInt);
  waveOutPrepareHeader(FWaveOut, @Header, SizeOf(Header));
  if waveOutWrite(FWaveOut, @Header, SizeOf(Header)) = MMSYSERR_NOERROR then
    Result := Length(AData)
  else
    Result := -1;
end;
{$ELSE}
begin
  Result := -1;
end;
{$ENDIF}

function TWaveOutDevice.Start: Boolean;
begin
  FIsRunning := FIsOpen;
  Result := FIsRunning;
end;

procedure TWaveOutDevice.Stop;
begin
  FIsRunning := False;
end;

function TWaveOutDevice.GetIsOpen: Boolean;
begin
  Result := FIsOpen;
end;

function TWaveOutDevice.ListDevices: TStringList;
{$IFDEF WINDOWS}
var
  I, Count: Integer;
  Caps: TWaveOutCaps;
begin
  Result := TStringList.Create;
  Count := waveOutGetNumDevs;
  for I := 0 to Count - 1 do
  begin
    FillChar(Caps, SizeOf(Caps), 0);
    if waveOutGetDevCaps(I, @Caps, SizeOf(Caps)) = MMSYSERR_NOERROR then
      Result.Add(Caps.szPname);
  end;
end;
{$ELSE}
begin
  Result := TStringList.Create;
end;
{$ENDIF}

{ TNullAudioInput }

function TNullAudioInput.Open(const AFormat: TAudioFormat; ADeviceIndex: Integer): Boolean;
begin
  FIsOpen := True;
  Result := True;
end;

procedure TNullAudioInput.Close;
begin
  FIsOpen := False;
end;

procedure TNullAudioInput.SetCallback(ACallback: TAudioDataCallback);
begin
  FCallback := ACallback;
end;

function TNullAudioInput.Start: Boolean;
begin
  Result := True;
end;

procedure TNullAudioInput.Stop;
begin
end;

function TNullAudioInput.GetIsOpen: Boolean;
begin
  Result := FIsOpen;
end;

function TNullAudioInput.ListDevices: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('(Null Audio Input)');
end;

{ TNullAudioOutput }

function TNullAudioOutput.Open(const AFormat: TAudioFormat; ADeviceIndex: Integer): Boolean;
begin
  FIsOpen := True;
  Result := True;
end;

procedure TNullAudioOutput.Close;
begin
  FIsOpen := False;
end;

function TNullAudioOutput.WriteSamples(const AData: TRealArray): Integer;
begin
  Result := Length(AData);
end;

function TNullAudioOutput.Start: Boolean;
begin
  Result := True;
end;

procedure TNullAudioOutput.Stop;
begin
end;

function TNullAudioOutput.GetIsOpen: Boolean;
begin
  Result := FIsOpen;
end;

function TNullAudioOutput.ListDevices: TStringList;
begin
  Result := TStringList.Create;
  Result.Add('(Null Audio Output)');
end;

{ TAudioDeviceFactory }

class function TAudioDeviceFactory.CreateInput(
  ABus: TEventBus; ANullDevice: Boolean): IAudioInput;
begin
  if ANullDevice then
    Result := TNullAudioInput.Create
  else
    Result := TWaveInDevice.Create(ABus);
end;

class function TAudioDeviceFactory.CreateOutput(
  ABus: TEventBus; ANullDevice: Boolean): IAudioOutput;
begin
  if ANullDevice then
    Result := TNullAudioOutput.Create
  else
    Result := TWaveOutDevice.Create(ABus);
end;

class function TAudioDeviceFactory.DefaultFormat(ASampleRate: Integer): TAudioFormat;
begin
  Result.SampleRate    := ASampleRate;
  Result.Channels      := 1;
  Result.BitsPerSample := 16;
end;

end.
