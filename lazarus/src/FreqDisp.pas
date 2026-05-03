unit FreqDisp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TFreqDispForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  FreqDispForm: TFreqDispForm;

implementation

{$R *.lfm}

procedure TFreqDispForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('FreqDisp');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
