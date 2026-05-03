unit uComm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TCommModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TCommModule.ModuleName: string;
begin
  Result := 'Comm';
end;

end.
