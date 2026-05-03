unit ucountry;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TcountryModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TcountryModule.ModuleName: string;
begin
  Result := 'country';
end;

end.
