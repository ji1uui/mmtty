unit QsoDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TQsoDlgForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  QsoDlgForm: TQsoDlgForm;

implementation

{$R *.lfm}

procedure TQsoDlgForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('QsoDlg');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
