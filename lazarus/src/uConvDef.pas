unit uConvDef;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TConvDefModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TConvDefModule.ModuleName: string;
begin
  Result := 'ConvDef';
end;

end.
