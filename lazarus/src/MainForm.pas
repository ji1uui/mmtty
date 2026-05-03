unit MainForm;

{$mode objfpc}{$H+}

// Main application window — thin presenter only.
// All domain logic lives in TMMTTYApp and the service layer.
// This form subscribes to events via TEventBus; it never calls domain code directly.

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ExtCtrls, ComCtrls, Menus,
  uDomainTypes, uInterfaces, uEventBus, uOption, ummtty;

type
  TfrmMain = class(TForm, IEventHandler)
    // -- UI Components (populated by .lfm) --
    MemoRx:       TMemo;
    MemoTx:       TMemo;
    StatusBar:    TStatusBar;
    PanelTop:     TPanel;
    BtnConnect:   TButton;
    BtnDisconnect: TButton;
    BtnSend:      TButton;
    BtnAbort:     TButton;
    BtnTune:      TButton;
    LblFreq:      TLabel;
    LblStatus:    TLabel;
    MainMenu1:    TMainMenu;
    MnuFile:      TMenuItem;
    MnuFileExit:  TMenuItem;
    MnuOptions:   TMenuItem;
    MnuOptSettings: TMenuItem;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtnConnectClick(Sender: TObject);
    procedure BtnDisconnectClick(Sender: TObject);
    procedure BtnSendClick(Sender: TObject);
    procedure BtnAbortClick(Sender: TObject);
    procedure BtnTuneClick(Sender: TObject);
    procedure MnuFileExitClick(Sender: TObject);
    procedure MnuOptSettingsClick(Sender: TObject);

  private
    FApp:     TMMTTYApp;
    FOptions: TAppOptions;
    FBus:     TEventBus;

    procedure InitApp;
    procedure SubscribeEvents;
    procedure UnsubscribeEvents;
    procedure UpdateConnectButtons;
    procedure UpdateTxButtons;
    procedure AppendRxText(const AText: string);
    procedure SetStatusText(const AText: string);

    // IEventHandler — receives all subscribed events on any thread
    procedure HandleEvent(const AEventName: string; AData: TObject);

    // Thread-safe UI updates (marshalled to main thread)
    procedure OnRxTextDecoded(const AEventName: string; AData: TObject);
    procedure OnTxStateChanged(const AEventName: string; AData: TObject);
    procedure OnCommConnected(const AEventName: string; AData: TObject);
    procedure OnCommDisconnected(const AEventName: string; AData: TObject);
    procedure OnCommError(const AEventName: string; AData: TObject);
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

uses
  uTxStateMachine;

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Caption := 'MMTTY Lazarus';
  FBus := TEventBus.Instance;
  InitApp;
  SubscribeEvents;
  UpdateConnectButtons;
  UpdateTxButtons;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  UnsubscribeEvents;
  FreeAndNil(FApp);
  FreeAndNil(FOptions);
end;

procedure TfrmMain.InitApp;
var
  Config: TMMTTYConfig;
  Store: IConfigStore;
  IniPath: string;
begin
  IniPath := ChangeFileExt(Application.ExeName, '.ini');
  Store := TIniConfigStore.Create(IniPath, FBus);
  Store.Load;
  FOptions := TAppOptions.Create(Store);

  Config := TMMTTYApp.DefaultConfig;
  Config.CommPortName    := FOptions.CommPort;
  Config.CommBaudRate    := FOptions.CommBaud;
  Config.PttViaRts       := FOptions.PttViaRts;
  Config.AudioInDevice   := FOptions.AudioInDevice;
  Config.AudioOutDevice  := FOptions.AudioOutDevice;
  Config.SampleRate      := FOptions.SampleRate;
  Config.RttyBaudRate    := FOptions.RttyBaud;
  Config.RttyShiftHz     := FOptions.RttyShift;
  Config.RttyMarkHz      := FOptions.RttyMark;
  Config.UseDummyDevices := False;

  FApp := TMMTTYApp.Create(Config);
  FApp.Initialize;
end;

procedure TfrmMain.SubscribeEvents;
begin
  FBus.Subscribe(TEvents.RX_TEXT_DECODED,   Self);
  FBus.Subscribe(TEvents.TX_STATE_CHANGED,  Self);
  FBus.Subscribe(TEvents.COMM_CONNECTED,    Self);
  FBus.Subscribe(TEvents.COMM_DISCONNECTED, Self);
  FBus.Subscribe(TEvents.COMM_ERROR,        Self);
end;

procedure TfrmMain.UnsubscribeEvents;
begin
  FBus.Unsubscribe(TEvents.RX_TEXT_DECODED,   Self);
  FBus.Unsubscribe(TEvents.TX_STATE_CHANGED,  Self);
  FBus.Unsubscribe(TEvents.COMM_CONNECTED,    Self);
  FBus.Unsubscribe(TEvents.COMM_DISCONNECTED, Self);
  FBus.Unsubscribe(TEvents.COMM_ERROR,        Self);
end;

// IEventHandler — dispatches to typed handlers
procedure TfrmMain.HandleEvent(const AEventName: string; AData: TObject);
begin
  // Handlers may fire from a worker thread; marshal to main thread.
  // TThread.Queue avoids blocking the caller.
  if AEventName = TEvents.RX_TEXT_DECODED then
    TThread.Queue(nil, procedure begin OnRxTextDecoded(AEventName, AData); end)
  else if AEventName = TEvents.TX_STATE_CHANGED then
    TThread.Queue(nil, procedure begin OnTxStateChanged(AEventName, AData); end)
  else if AEventName = TEvents.COMM_CONNECTED then
    TThread.Queue(nil, procedure begin OnCommConnected(AEventName, AData); end)
  else if AEventName = TEvents.COMM_DISCONNECTED then
    TThread.Queue(nil, procedure begin OnCommDisconnected(AEventName, AData); end)
  else if AEventName = TEvents.COMM_ERROR then
    TThread.Queue(nil, procedure begin OnCommError(AEventName, AData); end);
end;

procedure TfrmMain.OnRxTextDecoded(const AEventName: string; AData: TObject);
begin
  if AData is TStringEventData then
    AppendRxText(TStringEventData(AData).Value);
end;

procedure TfrmMain.OnTxStateChanged(const AEventName: string; AData: TObject);
begin
  UpdateTxButtons;
  if AData is TTxStateChangedData then
    SetStatusText('TX: ' + TTxStateMachine.StateName(TTxStateChangedData(AData).NewState));
end;

procedure TfrmMain.OnCommConnected(const AEventName: string; AData: TObject);
begin
  SetStatusText('Connected');
  UpdateConnectButtons;
  FApp.StartRx;
end;

procedure TfrmMain.OnCommDisconnected(const AEventName: string; AData: TObject);
begin
  SetStatusText('Disconnected');
  UpdateConnectButtons;
end;

procedure TfrmMain.OnCommError(const AEventName: string; AData: TObject);
var
  Msg: string;
begin
  Msg := 'Error';
  if AData is TStringEventData then
    Msg := 'Error: ' + TStringEventData(AData).Value;
  SetStatusText(Msg);
  UpdateConnectButtons;
end;

procedure TfrmMain.BtnConnectClick(Sender: TObject);
begin
  if not FApp.Connect then
    ShowMessage('Failed to connect. Check port settings.');
end;

procedure TfrmMain.BtnDisconnectClick(Sender: TObject);
begin
  FApp.StopRx;
  FApp.Disconnect;
end;

procedure TfrmMain.BtnSendClick(Sender: TObject);
var
  Text: string;
begin
  Text := MemoTx.Text;
  if Text = '' then Exit;
  FApp.SendText(Text);
  MemoTx.Clear;
end;

procedure TfrmMain.BtnAbortClick(Sender: TObject);
begin
  FApp.AbortTx;
end;

procedure TfrmMain.BtnTuneClick(Sender: TObject);
begin
  FApp.StartTune(5000);
end;

procedure TfrmMain.MnuFileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.MnuOptSettingsClick(Sender: TObject);
begin
  ShowMessage('Settings dialog — implement uOption form here.');
end;

procedure TfrmMain.UpdateConnectButtons;
var
  Connected: Boolean;
begin
  Connected := FApp.IsConnected;
  BtnConnect.Enabled    := not Connected;
  BtnDisconnect.Enabled := Connected;
end;

procedure TfrmMain.UpdateTxButtons;
var
  Idle: Boolean;
begin
  Idle := FApp.GetTxState = tsIdle;
  BtnSend.Enabled  := Idle and FApp.IsConnected;
  BtnAbort.Enabled := not Idle;
  BtnTune.Enabled  := Idle and FApp.IsConnected;
end;

procedure TfrmMain.AppendRxText(const AText: string);
begin
  MemoRx.Lines.Add(AText);
  // Auto-scroll
  MemoRx.SelStart := Length(MemoRx.Text);
  MemoRx.SelLength := 0;
end;

procedure TfrmMain.SetStatusText(const AText: string);
begin
  if StatusBar.Panels.Count > 0 then
    StatusBar.Panels[0].Text := AText
  else
    StatusBar.SimpleText := AText;
end;

end.
