unit ummtty;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TmmttyModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TmmttyModule.ModuleName: string;
begin
  Result := 'mmtty';
end;

end.
