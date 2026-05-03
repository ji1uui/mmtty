unit uPlayDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TPlayDlgModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TPlayDlgModule.ModuleName: string;
begin
  Result := 'PlayDlg';
end;

end.
