unit EditDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TEditDlgForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  EditDlgForm: TEditDlgForm;

implementation

{$R *.lfm}

procedure TEditDlgForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('EditDlg');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
