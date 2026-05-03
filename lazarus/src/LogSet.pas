unit LogSet;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TLogSetForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  LogSetForm: TLogSetForm;

implementation

{$R *.lfm}

procedure TLogSetForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('LogSet');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
