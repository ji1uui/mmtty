unit uShortCut;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TShortCutModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TShortCutModule.ModuleName: string;
begin
  Result := 'ShortCut';
end;

end.
