unit TncSet;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TTncSetForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  TncSetForm: TTncSetForm;

implementation

{$R *.lfm}

procedure TTncSetForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('TncSet');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
