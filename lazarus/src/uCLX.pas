unit uCLX;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TCLXModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TCLXModule.ModuleName: string;
begin
  Result := 'CLX';
end;

end.
