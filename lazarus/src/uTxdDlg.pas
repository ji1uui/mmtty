unit uTxdDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TTxdDlgModule = class
  public
    class function ModuleName: string;
  end;

implementation

class function TTxdDlgModule.ModuleName: string;
begin
  Result := 'TxdDlg';
end;

end.
