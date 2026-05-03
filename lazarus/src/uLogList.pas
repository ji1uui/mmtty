unit uLogList;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TLogListModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TLogListModule.ModuleName: string;
begin
  Result := 'LogList';
end;

end.
