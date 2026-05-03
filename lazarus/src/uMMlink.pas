unit uMMlink;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TMMlinkModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TMMlinkModule.ModuleName: string;
begin
  Result := 'MMlink';
end;

end.
