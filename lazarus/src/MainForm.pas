unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type
  TfrmMain = class(TForm)
    MemoStatus: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    procedure LoadPortingInventory;
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Caption := 'MMTTY Lazarus Port (WIP)';
  LoadPortingInventory;
end;

procedure TfrmMain.LoadPortingInventory;
const
  Inventory: array[0..9] of string = (
    'Source inventory imported from legacy C++Builder tree.',
    'Target compilers: Lazarus/FPC for macOS (Apple Silicon) and Windows.',
    'This bootstrap builds the app shell and tracks migration units.',
    'Next step: translate each .cpp/.h pair into Pascal units.',
    'High-priority units: Main, Comm, Sound, Rtty, Wave, Fft, Scope.',
    'Forms to migrate from .dfm -> .lfm: Main, Option, LogSet, QsoDlg, ...',
    'Protocol modules: TNC, CAT/rig control, log link, macro key.',
    'DSP modules: FIR, FFT, demodulator, clock adjustment.',
    'I/O modules: serial COM abstraction, audio input/output, file send.',
    'See PORTING_STATUS.md for complete file-by-file mapping.'
  );
var
  S: String;
begin
  MemoStatus.Clear;
  for S in Inventory do
    MemoStatus.Lines.Add(S);
end;

end.
