unit InputWin;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TInputWinForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  InputWinForm: TInputWinForm;

implementation

{$R *.lfm}

procedure TInputWinForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('InputWin');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
