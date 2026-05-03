unit uMacroKey;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  TMacroKeyModule = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor TMacroKeyModule.Create;
begin
  inherited Create('MacroKey');
  Initialize;
end;

function TMacroKeyModule.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
