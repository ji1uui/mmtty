unit uLogFile;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TLogFileModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TLogFileModule.ModuleName: string;
begin
  Result := 'LogFile';
end;

end.
