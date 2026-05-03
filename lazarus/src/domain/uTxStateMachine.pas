unit uTxStateMachine;

{$mode objfpc}{$H+}

// State pattern: TX/RX lifecycle management.
// Guards illegal transitions and publishes state-change events.

interface

uses
  Classes, SysUtils, uDomainTypes, uInterfaces, uEventBus;

type
  TTxTransitionMatrix = array[TTxState, TTxState] of Boolean;

  TTxStateChangedData = class
  public
    OldState: TTxState;
    NewState: TTxState;
    constructor Create(AOld, ANew: TTxState);
  end;

  TTxStateMachine = class(TInterfacedObject, ITxStateMachine)
  private
    FCurrentState: TTxState;
    FBus: TEventBus;

    class function BuildTransitionMatrix: TTxTransitionMatrix;
    class var FTransitions: TTxTransitionMatrix;
    class var FMatrixInitialized: Boolean;
  public
    constructor Create(ABus: TEventBus);

    // ITxStateMachine
    procedure Transition(ANewState: TTxState);
    function GetCurrentState: TTxState;
    function CanTransitionTo(AState: TTxState): Boolean;
    procedure OnEnterState(AState: TTxState); virtual;
    procedure OnExitState(AState: TTxState); virtual;

    property CurrentState: TTxState read GetCurrentState;

    class function StateName(AState: TTxState): string;
  end;

implementation

{ TTxStateChangedData }

constructor TTxStateChangedData.Create(AOld, ANew: TTxState);
begin
  inherited Create;
  OldState := AOld;
  NewState := ANew;
end;

{ TTxStateMachine }

class function TTxStateMachine.BuildTransitionMatrix: TTxTransitionMatrix;
var
  M: TTxTransitionMatrix;
  S, D: TTxState;
begin
  for S := Low(TTxState) to High(TTxState) do
    for D := Low(TTxState) to High(TTxState) do
      M[S, D] := False;

  // tsIdle -> allowed targets
  M[tsIdle, tsWaitingPtt] := True;
  M[tsIdle, tsTuning]     := True;

  // tsWaitingPtt -> allowed targets
  M[tsWaitingPtt, tsSending]  := True;
  M[tsWaitingPtt, tsAborting] := True;

  // tsSending -> allowed targets
  M[tsSending, tsIdle]     := True;  // queue empty, PTT released
  M[tsSending, tsAborting] := True;

  // tsTuning -> allowed targets
  M[tsTuning, tsIdle]     := True;
  M[tsTuning, tsAborting] := True;

  // tsAborting -> allowed targets
  M[tsAborting, tsIdle] := True;

  Result := M;
end;

constructor TTxStateMachine.Create(ABus: TEventBus);
begin
  inherited Create;
  FCurrentState := tsIdle;
  FBus := ABus;

  if not FMatrixInitialized then
  begin
    FTransitions := BuildTransitionMatrix;
    FMatrixInitialized := True;
  end;
end;

function TTxStateMachine.CanTransitionTo(AState: TTxState): Boolean;
begin
  Result := FTransitions[FCurrentState, AState];
end;

procedure TTxStateMachine.Transition(ANewState: TTxState);
var
  OldState: TTxState;
  EventData: TTxStateChangedData;
begin
  if not CanTransitionTo(ANewState) then
    raise EInvalidOperation.CreateFmt(
      'Illegal TX state transition: %s -> %s',
      [StateName(FCurrentState), StateName(ANewState)]);

  OldState := FCurrentState;
  OnExitState(FCurrentState);
  FCurrentState := ANewState;
  OnEnterState(ANewState);

  EventData := TTxStateChangedData.Create(OldState, ANewState);
  try
    FBus.Publish(TEvents.TX_STATE_CHANGED, EventData);
  finally
    EventData.Free;
  end;
end;

function TTxStateMachine.GetCurrentState: TTxState;
begin
  Result := FCurrentState;
end;

procedure TTxStateMachine.OnEnterState(AState: TTxState);
begin
  // Override in subclass for entry actions
end;

procedure TTxStateMachine.OnExitState(AState: TTxState);
begin
  // Override in subclass for exit actions
end;

class function TTxStateMachine.StateName(AState: TTxState): string;
begin
  case AState of
    tsIdle:       Result := 'Idle';
    tsWaitingPtt: Result := 'WaitingPtt';
    tsSending:    Result := 'Sending';
    tsTuning:     Result := 'Tuning';
    tsAborting:   Result := 'Aborting';
  else
    Result := 'Unknown';
  end;
end;

initialization
  TTxStateMachine.FMatrixInitialized := False;

end.
