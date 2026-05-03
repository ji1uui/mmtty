unit uRtty;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TRttyModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TRttyModule.ModuleName: string;
begin
  Result := 'Rtty';
end;

end.
