unit uEditDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TEditDlgModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TEditDlgModule.ModuleName: string;
begin
  Result := 'EditDlg';
end;

end.
