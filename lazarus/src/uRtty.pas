unit uRtty;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  TRttyModule = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor TRttyModule.Create;
begin
  inherited Create('Rtty');
  Initialize;
end;

function TRttyModule.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
