unit uLoglink;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TLoglinkModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TLoglinkModule.ModuleName: string;
begin
  Result := 'Loglink';
end;

end.
