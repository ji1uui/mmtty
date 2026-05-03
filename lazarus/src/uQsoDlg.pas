unit uQsoDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  TQsoDlgModule = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor TQsoDlgModule.Create;
begin
  inherited Create('QsoDlg');
  Initialize;
end;

function TQsoDlgModule.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
