unit uTextEdit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TTextEditModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TTextEditModule.ModuleName: string;
begin
  Result := 'TextEdit';
end;

end.
