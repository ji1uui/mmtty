unit SendFile;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TSendFileForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  SendFileForm: TSendFileForm;

implementation

{$R *.lfm}

procedure TSendFileForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('SendFile');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
