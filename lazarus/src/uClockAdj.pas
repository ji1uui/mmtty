unit uClockAdj;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TClockAdjModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TClockAdjModule.ModuleName: string;
begin
  Result := 'ClockAdj';
end;

end.
