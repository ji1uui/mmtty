unit PlayDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TPlayDlgForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  PlayDlgForm: TPlayDlgForm;

implementation

{$R *.lfm}

procedure TPlayDlgForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('PlayDlg');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
