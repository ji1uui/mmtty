unit radioset;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TradiosetForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  radiosetForm: TradiosetForm;

implementation

{$R *.lfm}

procedure TradiosetForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('radioset');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
