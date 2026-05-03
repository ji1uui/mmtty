unit uSound;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TSoundModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TSoundModule.ModuleName: string;
begin
  Result := 'Sound';
end;

end.
