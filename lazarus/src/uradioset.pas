unit uradioset;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TradiosetModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TradiosetModule.ModuleName: string;
begin
  Result := 'radioset';
end;

end.
