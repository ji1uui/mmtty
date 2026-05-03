unit PortCommon;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TPortModule = class
  private
    FName: string;
    FInitialized: Boolean;
  public
    constructor Create(const AName: string);
    procedure Initialize;
    procedure FinalizeModule;
    property Name: string read FName;
    property Initialized: Boolean read FInitialized;
  end;

function NormalizeFrequencyHz(const AText: string): Int64;
function BoolToOnOff(const AValue: Boolean): string;

implementation

constructor TPortModule.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FInitialized := False;
end;

procedure TPortModule.Initialize;
begin
  FInitialized := True;
end;

procedure TPortModule.FinalizeModule;
begin
  FInitialized := False;
end;

function NormalizeFrequencyHz(const AText: string): Int64;
var
  S: string;
begin
  S := StringReplace(Trim(AText), ',', '', [rfReplaceAll]);
  if S = '' then
    Exit(0);
  if not TryStrToInt64(S, Result) then
    Result := 0;
end;

function BoolToOnOff(const AValue: Boolean): string;
begin
  if AValue then
    Result := 'ON'
  else
    Result := 'OFF';
end;

end.
