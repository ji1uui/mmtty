unit uEditDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  TEditDlgModule = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor TEditDlgModule.Create;
begin
  inherited Create('EditDlg');
  Initialize;
end;

function TEditDlgModule.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
