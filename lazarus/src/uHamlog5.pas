unit uHamlog5;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  THamlog5Module = class
  public
    class function ModuleName: string;
  end;

implementation

class function THamlog5Module.ModuleName: string;
begin
  Result := 'Hamlog5';
end;

end.
