unit uMmcgDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TMmcgDlgModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TMmcgDlgModule.ModuleName: string;
begin
  Result := 'MmcgDlg';
end;

end.
