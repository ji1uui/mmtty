unit uSendFile;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TSendFileModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TSendFileModule.ModuleName: string;
begin
  Result := 'SendFile';
end;

end.
