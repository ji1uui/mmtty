unit uComLib;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TComLibModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TComLibModule.ModuleName: string;
begin
  Result := 'ComLib';
end;

end.
