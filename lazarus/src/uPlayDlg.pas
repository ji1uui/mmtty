unit uPlayDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  TPlayDlgModule = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor TPlayDlgModule.Create;
begin
  inherited Create('PlayDlg');
  Initialize;
end;

function TPlayDlgModule.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
