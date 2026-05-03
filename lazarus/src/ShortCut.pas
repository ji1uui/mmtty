unit ShortCut;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TShortCutForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  ShortCutForm: TShortCutForm;

implementation

{$R *.lfm}

procedure TShortCutForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('ShortCut');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
