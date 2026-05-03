unit uWave;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TWaveModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TWaveModule.ModuleName: string;
begin
  Result := 'Wave';
end;

end.
