unit ucradio;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TcradioModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TcradioModule.ModuleName: string;
begin
  Result := 'cradio';
end;

end.
