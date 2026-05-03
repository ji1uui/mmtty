unit uradioset;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  TradiosetModule = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor TradiosetModule.Create;
begin
  inherited Create('radioset');
  Initialize;
end;

function TradiosetModule.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
