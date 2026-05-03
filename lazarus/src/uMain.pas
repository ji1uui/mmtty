unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TMainModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TMainModule.ModuleName: string;
begin
  Result := 'Main';
end;

end.
