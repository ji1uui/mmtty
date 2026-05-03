unit uVerDsp;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TVerDspModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TVerDspModule.ModuleName: string;
begin
  Result := 'VerDsp';
end;

end.
