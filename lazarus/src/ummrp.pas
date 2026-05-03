unit ummrp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  TmmrpModule = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor TmmrpModule.Create;
begin
  inherited Create('mmrp');
  Initialize;
end;

function TmmrpModule.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
