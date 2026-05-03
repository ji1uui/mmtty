unit uLogConv;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TLogConvModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TLogConvModule.ModuleName: string;
begin
  Result := 'LogConv';
end;

end.
