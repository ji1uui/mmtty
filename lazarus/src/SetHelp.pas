unit SetHelp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TSetHelpForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  SetHelpForm: TSetHelpForm;

implementation

{$R *.lfm}

procedure TSetHelpForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('SetHelp');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
