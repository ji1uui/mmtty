unit uClockAdj;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  TClockAdjModule = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor TClockAdjModule.Create;
begin
  inherited Create('ClockAdj');
  Initialize;
end;

function TClockAdjModule.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
