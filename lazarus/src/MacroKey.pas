unit MacroKey;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TMacroKeyForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  MacroKeyForm: TMacroKeyForm;

implementation

{$R *.lfm}

procedure TMacroKeyForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('MacroKey');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
