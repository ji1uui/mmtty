unit uOption;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TOptionModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TOptionModule.ModuleName: string;
begin
  Result := 'Option';
end;

end.
