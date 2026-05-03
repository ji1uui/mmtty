unit ConvDef;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TConvDefForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  ConvDefForm: TConvDefForm;

implementation

{$R *.lfm}

procedure TConvDefForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('ConvDef');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
