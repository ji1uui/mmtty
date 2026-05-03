unit uHamlog5;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  THamlog5Module = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor THamlog5Module.Create;
begin
  inherited Create('Hamlog5');
  Initialize;
end;

function THamlog5Module.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
