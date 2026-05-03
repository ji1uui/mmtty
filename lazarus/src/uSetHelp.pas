unit uSetHelp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TSetHelpModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TSetHelpModule.ModuleName: string;
begin
  Result := 'SetHelp';
end;

end.
