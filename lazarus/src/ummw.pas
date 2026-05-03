unit ummw;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TmmwModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TmmwModule.ModuleName: string;
begin
  Result := 'mmw';
end;

end.
