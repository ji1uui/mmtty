unit TextEdit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TTextEditForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  TextEditForm: TTextEditForm;

implementation

{$R *.lfm}

procedure TTextEditForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('TextEdit');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
