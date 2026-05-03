unit uTncSet;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TTncSetModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TTncSetModule.ModuleName: string;
begin
  Result := 'TncSet';
end;

end.
