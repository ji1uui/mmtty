unit ummrp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TmmrpModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TmmrpModule.ModuleName: string;
begin
  Result := 'mmrp';
end;

end.
