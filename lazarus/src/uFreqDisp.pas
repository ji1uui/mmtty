unit uFreqDisp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  TFreqDispModule = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor TFreqDispModule.Create;
begin
  inherited Create('FreqDisp');
  Initialize;
end;

function TFreqDispModule.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
