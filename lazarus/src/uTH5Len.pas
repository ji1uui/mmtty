unit uTH5Len;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TTH5LenModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TTH5LenModule.ModuleName: string;
begin
  Result := 'TH5Len';
end;

end.
