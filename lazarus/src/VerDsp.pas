unit VerDsp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TVerDspForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  VerDspForm: TVerDspForm;

implementation

{$R *.lfm}

procedure TVerDspForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('VerDsp');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
