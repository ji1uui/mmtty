unit uTxdDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, PortCommon;

type
  TTxdDlgModule = class(TPortModule)
  public
    constructor Create;
    function StatusText: string;
  end;

implementation

constructor TTxdDlgModule.Create;
begin
  inherited Create('TxdDlg');
  Initialize;
end;

function TTxdDlgModule.StatusText: string;
begin
  Result := Name + ': ' + BoolToOnOff(Initialized);
end;

end.
