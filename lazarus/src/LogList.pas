unit LogList;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TLogListForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  LogListForm: TLogListForm;

implementation

{$R *.lfm}

procedure TLogListForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('LogList');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
