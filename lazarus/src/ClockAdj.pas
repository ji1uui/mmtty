unit ClockAdj;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TClockAdjForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  ClockAdjForm: TClockAdjForm;

implementation

{$R *.lfm}

procedure TClockAdjForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('ClockAdj');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
