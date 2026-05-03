# MMTTY Refactoring Improvement List and Modernization Plan

## Scope and assumptions
- This plan targets the whole repository (`*.cpp/*.h`, `*.pas/*.lfm`, project files, docs).
- Priority is **robustness**, **readability**, and **maintainability** while preserving existing behavior.
- Strategy: incremental, testable slices to reduce regression risk in radio/real-time TX/RX paths.

---

## 1) Repository-wide issues (SOLID / design pattern perspective)

### 1.1 Single Responsibility Principle (SRP) violations
- Large classes and forms mix UI logic, domain logic, and hardware I/O.
- Examples: communication classes contain protocol decisions + timing + transport + platform calls.
- Improvement:
  - Split into layers: `UI`, `Application`, `Domain`, `Infrastructure`.
  - Move modem/protocol logic into pure domain services (no VCL/LCL dependencies).

### 1.2 Open/Closed Principle (OCP) gaps
- Behavior changes are handled with `switch`/flag branches in monolithic loops.
- Improvement:
  - Introduce Strategy pattern for modulation variants, diddle behavior, and TX pacing.
  - Introduce Policy objects for timing and queue behavior.

### 1.3 Liskov Substitution / Interface Segregation / Dependency Inversion gaps
- Code depends directly on OS APIs (`CreateFile`, `EscapeCommFunction`, etc.) and concrete implementations.
- Improvement:
  - Define interfaces (`ICommPort`, `IPttController`, `ITxScheduler`, `ILogSink`).
  - Inject concrete adapters (SerialPort, EXTFSKPort) via factory.
  - Keep domain services independent from platform details.

### 1.4 Error handling and state model weaknesses
- Many API calls return error conditions but state transitions are implicit.
- Improvement:
  - Explicit state machine (`Closed`, `Opening`, `Open`, `TxEnabled`, `Closing`, `Faulted`).
  - Centralized error object and error propagation path.

### 1.5 Legacy threading and timing coupling
- Busy loops and sleeps spread across operational logic.
- Improvement:
  - Encapsulate timing/sleep scheduling in a scheduler abstraction.
  - Replace implicit wait loops with explicit, testable scheduling behavior.

---

## 2) Target architecture (design patterns)

### 2.1 Hexagonal/Clean architecture (recommended)
- **Domain layer**: pure protocol/modem state, encoding/decoding rules.
- **Application layer**: TX/RX orchestration, use-cases (start TX, enqueue char, stop TX).
- **Infrastructure layer**: serial/EXTFSK adapters, file I/O, OS timers.
- **Presentation layer**: VCL/Lazarus forms.

### 2.2 Patterns to apply
- **Strategy**: modulation profile, diddle generation policy, pacing policy.
- **State**: TX/RX lifecycle state transitions.
- **Factory/Abstract Factory**: backend creation (COM, EXTFSK, mock).
- **Adapter**: wrap Win32 / Lazarus API differences.
- **Observer (or event bus)**: decouple UI updates/logging from processing.
- **Command**: TX queue control commands instead of raw sentinel bytes.

---

## 3) File split/integration proposals

### 3.1 Communication module (`Comm.*`, `ComLib.*`, related)
- Split `Comm.cpp` into:
  - `TxWorker.cpp/.h` (thread loop only)
  - `TxQueue.cpp/.h` (ring buffer + command queue)
  - `CommPortSerial.cpp/.h` (Win32 serial adapter)
  - `CommPortExtFsk.cpp/.h` (EXTFSK adapter)
  - `TxProtocol.cpp/.h` (diddle/fig-shift behavior)
  - `CommStateMachine.cpp/.h` (state transitions)
- Introduce shared interfaces in `include/core/interfaces/`.

### 3.2 DSP module (`Fft.*`, `fir.*`, `Wave.*`, `Sound.*`, `Scope.*`)
- Consolidate pure signal-processing utilities into `dsp/` package.
- Separate UI plotting concerns from DSP computations.
- Create `DspPipeline` that composes filters/fft components.

### 3.3 RTTY/modem module (`Rtty.*`, `ctnc.*`, `mml.*`, `mmw.*`)
- Split protocol state (baudot/shift rules) from transport and UI state.
- Extract `RttyEncoder`, `RttyDecoder`, `SymbolTiming` services.

### 3.4 UI/forms (`*.dfm`, `Main.*`, dialogs)
- Keep form classes thin: event forwarding only.
- Move business logic into presenters/controllers (`MainController`, `LogController`).

### 3.5 Logging/history (`Log*.*`, `Hamlog5.*`, `Loglink.*`)
- Introduce repository/service abstraction for log persistence.
- Normalize parsing/formatting concerns into dedicated components.

### 3.6 Lazarus port (`lazarus/src/*.pas`)
- Mirror architecture by creating equivalent units:
  - `core/`, `app/`, `infra/`, `ui/`
- Reduce divergence from C++ source through shared behavior specs.

---

## 4) Prioritized implementation roadmap

### Phase 0: Safety baseline (1-2 weeks)
1. Build matrix documentation (Borland/Delphi/Lazarus environments).
2. Add static checks (where feasible), formatting rules, and compile scripts.
3. Introduce regression harness for critical TX/RX behavior snapshots.

Deliverables:
- `docs/build-matrix.md`
- `scripts/build_*.sh` and/or batch equivalents
- baseline behavior fixtures

### Phase 1: Communication seam extraction (2-4 weeks)
1. Add interfaces: `ICommPort`, `ITxQueue`, `ITxProtocol`, `IPttController`.
2. Wrap existing COM/EXTFSK code behind adapters.
3. Move queue + control command semantics into `TxQueue`.
4. Add explicit state machine + centralized error handling.

Deliverables:
- New interface headers
- adapter implementations
- tests for queue/state transitions

### Phase 2: Protocol and timing refactor (2-3 weeks)
1. Extract diddle/fig-shift logic into `TxProtocol` strategy set.
2. Encapsulate wait calculation into `TxTimingPolicy`.
3. Remove magic values and implicit branch coupling.

Deliverables:
- protocol policy classes
- deterministic timing tests

### Phase 3: DSP modularization (3-5 weeks)
1. Extract pure DSP utilities and add test vectors.
2. Build composable `DspPipeline`.
3. Separate rendering/UI concerns.

### Phase 4: UI/controller cleanup (3-4 weeks)
1. Introduce controller/presenter layer for main and key dialogs.
2. Remove domain logic from forms.
3. Add event-driven update mechanism.

### Phase 5: Lazarus parity alignment (parallel track)
1. Port new architecture boundaries to `lazarus/src` units.
2. Add shared behavior specs to prevent drift.

---

## 5) Risk management
- High-risk areas: realtime TX timing, hardware control (RTS/DTR/PTT), DSP chain.
- Controls:
  - feature flags for new path vs legacy path
  - side-by-side output comparison
  - incremental merges limited to one subsystem at a time

---

## 6) Definition of done (per subsystem)
- Responsibilities separated by layer.
- Interfaces replace direct infra dependencies.
- Critical paths covered by regression tests.
- No behavior delta in reference scenarios.
- Updated architecture docs and migration notes.

---

## 7) Suggested first concrete tickets
1. Create `ICommPort` + `SerialCommPortAdapter` using existing code paths.
2. Add `TxControlCommand` enum/class and migrate sentinel-byte handling.
3. Extract TX queue ring-buffer into isolated unit with tests.
4. Add communication state machine skeleton and transition logging.
5. Introduce `TxProtocol` strategy for diddle behavior.
