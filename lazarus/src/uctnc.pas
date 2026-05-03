unit uctnc;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TctncModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TctncModule.ModuleName: string;
begin
  Result := 'ctnc';
end;

end.
