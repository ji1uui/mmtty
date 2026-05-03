unit MmcgDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TMmcgDlgForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  MmcgDlgForm: TMmcgDlgForm;

implementation

{$R *.lfm}

procedure TMmcgDlgForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('MmcgDlg');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
