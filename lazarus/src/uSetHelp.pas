unit uSetHelp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  TSetHelpModule = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor TSetHelpModule.Create;
begin
  inherited Create('SetHelp');
  Initialize;
end;

function TSetHelpModule.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
