unit uTH5Len;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  TTH5LenModule = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor TTH5LenModule.Create;
begin
  inherited Create('TH5Len');
  Initialize;
end;

function TTH5LenModule.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
