unit uLogSet;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TLogSetModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TLogSetModule.ModuleName: string;
begin
  Result := 'LogSet';
end;

end.
