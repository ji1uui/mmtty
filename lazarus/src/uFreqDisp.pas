unit uFreqDisp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TFreqDispModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TFreqDispModule.ModuleName: string;
begin
  Result := 'FreqDisp';
end;

end.
