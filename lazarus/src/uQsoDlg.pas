unit uQsoDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TQsoDlgModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TQsoDlgModule.ModuleName: string;
begin
  Result := 'QsoDlg';
end;

end.
