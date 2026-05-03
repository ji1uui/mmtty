unit TxdDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TTxdDlgForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  TxdDlgForm: TTxdDlgForm;

implementation

{$R *.lfm}

procedure TTxdDlgForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('TxdDlg');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
