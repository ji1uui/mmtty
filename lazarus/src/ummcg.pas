unit ummcg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TmmcgModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TmmcgModule.ModuleName: string;
begin
  Result := 'mmcg';
end;

end.
