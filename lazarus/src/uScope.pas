unit uScope;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TScopeModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TScopeModule.ModuleName: string;
begin
  Result := 'Scope';
end;

end.
