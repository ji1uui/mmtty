unit ufir;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TfirModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TfirModule.ModuleName: string;
begin
  Result := 'fir';
end;

end.
