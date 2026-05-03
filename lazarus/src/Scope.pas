unit Scope;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, PortCommon;

type
  TScopeForm = class(TForm)
    MemoInfo: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    FModule: TPortModule;
  end;

var
  ScopeForm: TScopeForm;

implementation

{$R *.lfm}

procedure TScopeForm.FormCreate(Sender: TObject);
begin
  FModule := TPortModule.Create('Scope');
  FModule.Initialize;
  MemoInfo.Lines.Text := FModule.Name + ' initialized';
end;

end.
