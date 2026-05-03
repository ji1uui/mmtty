unit uInputWin;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TInputWinModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TInputWinModule.ModuleName: string;
begin
  Result := 'InputWin';
end;

end.
