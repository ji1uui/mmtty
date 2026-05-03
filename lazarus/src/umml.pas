unit umml;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TmmlModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TmmlModule.ModuleName: string;
begin
  Result := 'mml';
end;

end.
