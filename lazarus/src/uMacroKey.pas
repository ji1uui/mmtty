unit uMacroKey;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TMacroKeyModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TMacroKeyModule.ModuleName: string;
begin
  Result := 'MacroKey';
end;

end.
