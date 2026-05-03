unit uMmcgDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  TMmcgDlgModule = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor TMmcgDlgModule.Create;
begin
  inherited Create('MmcgDlg');
  Initialize;
end;

function TMmcgDlgModule.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
