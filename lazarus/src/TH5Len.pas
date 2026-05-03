unit TH5Len;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TTH5LenForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  TH5LenForm: TTH5LenForm;

implementation

{$R *.lfm}

procedure TTH5LenForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('TH5Len');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
