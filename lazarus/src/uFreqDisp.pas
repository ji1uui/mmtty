unit uFreqDisp;

{$mode objfpc}{$H+}

// Frequency display presenter — bridges TFreqDisplayModel (domain) and LCL UI.
// Subscribes to RADIO_FREQ_CHANGED events; updates labels without polling.

interface

uses
  Classes, SysUtils,
  uDomainTypes, uInterfaces, uEventBus, uScope;

type
  // Callback type: UI calls this to redraw when model data changes
  TFreqUpdateCallback = procedure(const AFreqHz: Double; const ALabel: string) of object;

  TFreqDisplayPresenter = class(TInterfacedObject, IEventHandler)
  private
    FModel: TFreqDisplayModel;
    FBus: TEventBus;
    FOnUpdate: TFreqUpdateCallback;
    FLastDisplayHz: Double;

    function FormatFrequency(AHz: Double): string;
  public
    constructor Create(AModel: TFreqDisplayModel; ABus: TEventBus);
    destructor Destroy; override;

    // IEventHandler
    procedure HandleEvent(const AEventName: string; AData: TObject);

    procedure SetOnUpdate(ACallback: TFreqUpdateCallback);

    // Call from UI when user clicks/drags the frequency display
    procedure UserSetFrequency(AHz: Double);

    property Model: TFreqDisplayModel read FModel;
    property LastDisplayHz: Double read FLastDisplayHz;
  end;

implementation

{ TFreqDisplayPresenter }

constructor TFreqDisplayPresenter.Create(AModel: TFreqDisplayModel; ABus: TEventBus);
begin
  inherited Create;
  FModel := AModel;
  FBus := ABus;
  FLastDisplayHz := 0.0;
  FBus.Subscribe(TEvents.RADIO_FREQ_CHANGED, Self);
end;

destructor TFreqDisplayPresenter.Destroy;
begin
  FBus.Unsubscribe(TEvents.RADIO_FREQ_CHANGED, Self);
  inherited;
end;

procedure TFreqDisplayPresenter.HandleEvent(const AEventName: string; AData: TObject);
var
  FreqData: TIntEventData;
  Hz: Double;
begin
  if AEventName = TEvents.RADIO_FREQ_CHANGED then
  begin
    if AData is TIntEventData then
    begin
      FreqData := TIntEventData(AData);
      Hz := FreqData.Value;
      FLastDisplayHz := Hz;
      if Assigned(FOnUpdate) then
        FOnUpdate(Hz, FormatFrequency(Hz));
    end;
  end;
end;

function TFreqDisplayPresenter.FormatFrequency(AHz: Double): string;
var
  MHz: Double;
begin
  MHz := AHz / 1000000.0;
  if AHz >= 1000000 then
    Result := Format('%.4f MHz', [MHz])
  else if AHz >= 1000 then
    Result := Format('%.1f kHz', [AHz / 1000.0])
  else
    Result := Format('%.0f Hz', [AHz]);
end;

procedure TFreqDisplayPresenter.SetOnUpdate(ACallback: TFreqUpdateCallback);
begin
  FOnUpdate := ACallback;
end;

procedure TFreqDisplayPresenter.UserSetFrequency(AHz: Double);
begin
  FModel.SetFrequency(AHz);
end;

end.
