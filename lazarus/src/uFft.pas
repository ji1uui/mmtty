unit uFft;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TFftModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TFftModule.ModuleName: string;
begin
  Result := 'Fft';
end;

end.
