unit Option;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TOptionForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  OptionForm: TOptionForm;

implementation

{$R *.lfm}

procedure TOptionForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('Option');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
