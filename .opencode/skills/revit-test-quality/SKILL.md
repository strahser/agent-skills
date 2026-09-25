---
name: revit-test-quality
description: >
  Quality policy for Revit C# plugin tests (Nice3point.TUnit.Revit / MTP).
  USE FOR: acceptance criteria when writing or reviewing tests — exact-value assertions,
  proof by live headless run, meaningful tests, fixtures from real project files, brittleness rules,
  TestOutput hygiene (no RVT dump).
  DO NOT USE FOR: thread mechanics (revit-testing), running tests (revit-test-runner),
  wiring fixture documents/data (revit-test-fixtures).
license: MIT
---

# Revit Test Quality Policy

A test is done when it asserts exact observable values, ran green in a live run,
and will not break on the next unrelated change. Compile-success is never proof.

## When to use

- Writing a new test or reviewing one produced by the agent.
- Deciding whether a test result "counts" as confirmation.

## When not to use

- Threading/executor questions → `revit-testing`.
- How to launch the runner → `revit-test-runner`.
- Where to get documents and cases → `revit-test-fixtures`.

## Rule 1 — Exact values, never ranges

Assert the concrete expected value. Range assertions hide regressions:
a broken formula can still land "between 1 and 10".

| Kind | Required | Forbidden as a substitute |
|---|---|---|
| double/length/area | `IsEqualTo(expected).Within(tol)` with the smallest tolerance the API allows (typically `1e-6`; use document tolerance for geometry) | `IsGreaterThan`, `IsBetween`, `IsPositive` |
| XYZ/geometry | exact point/vector within tolerance: `IsAlmostEqualTo` checks per component | `!= null`, `Length > 0` |
| counts/sets | exact count **and** exact expected names/keys | `IsNotEmpty()` alone (unless the test IS an existence check) |
| strings/enums/parameters | `IsEqualTo(...)` exact match | `Contains`, `StartsWith` unless the spec is itself a pattern |
| limits in specs | allowed only when the requirement literally is a bound (e.g. "slope ≥ 0.5%") | — |

Every floating-point comparison carries an explicit tolerance — the same one the
production code uses. Bare `==` on doubles is a defect.

Guard-metric corollary (HeatLossRevit4): snapshot/pipeline guards assert the full
metric row — parameters, zones, walls, windows/openings, and links between them
(e.g. wall→room, opening→wall, floor→room) — as exact numbers/keys, not
`pass = range1 && range2 && ...` collapsed into a single `IsTrue()`.

## Rule 2 — Proof is a live run, not a build

"It compiles" and "the logic looks right" are not confirmation. Required evidence:

1. Run the suite live against the installed Revit. Generic shape:
   `dotnet run --project <Tests.csproj> -c Release.RNN` (`RNN` = installed Revit year).
   On .NET 10 SDK use `dotnet run`, not `dotnet test` (MTP limitation).
2. Filtered run: `--treenode-filter "/<Assembly>/<Namespace>/<Class>/<Test>"`
   (4 segments; VSTest `--filter` silently matches nothing).
3. Legacy non-SDK projects (Base.csproj + Newtonsoft): build with `--no-restore`,
   then execute the prebuilt `.exe` from `bin\<config>\` directly — see `revit-test-runner`.
4. The agent report must include: run command, pass/fail summary, path to the report
   (`bin\<config>\TestResults\*-report.html` or TRX). A red or skipped suite = not done.
5. Headless means no UI session: no `RevitAPIUI` types, no `TaskDialog.Show` in
   assertions, no assumption that a human clicks anything.

Repo grounding (HeatLossRevit4): entry point is `Tools\run_tests.ps1`
(`headless` <5s without Revit: Core.Tests + Snapshot.Tests + validate_building;
`revit` 30–60s needs Revit 2024: `DirectShapeSnapshot.Tool.exe` + tables;
`all` = both). Build is MSBuild (`Debug` + `Debug.R24`, `DeployAddin=false`
in test runs), not `dotnet run`. Filtered Revit runs use the same 4-segment
`--treenode-filter` on `DirectShapeSnapshot.Tool.exe` / `DirectShapeSnapshot.Tests.exe`.

## Rule 3 — Meaningful tests only

- Assert the **observable result**: model state after the operation, file content,
  exported value — never framework plumbing, internal caches, or mock call counts.
- One behavior per test. Name = `Method_Scenario_ExpectedResult`.
- Arrange / Act / Assert blocks are mandatory and visually separated.
- Forbidden test shapes:
  - tautologies (`await Assert.That(true).IsTrue()` as the only check);
  - "does not throw" as the only assertion, unless the contract is exactly that;
  - tests that re-implement the method under test inside the assertion;
  - tests of trivial get/set wrappers with no logic.
- If deleting the assertion would not change what the test proves, the test is weak.

## Rule 4 — Fixtures hit real projects

- Default fixture is a **real `.rvt` from the project/sample set**, routed through
  `revit-test-fixtures`. The fixture file name is stated in the test or its docs.
  The expected values are taken from that file's known elements, not invented.
- Synthetic in-memory documents are allowed only for pure unit-level math
  (XYZ, BoundingBoxXYZ, curve arithmetic) that needs no document context.
- Data sources yield primitives only (numbers, strings, file paths, element names);
  Revit objects are built/resolved in the test body, on the Revit thread.
- Never mutate the shared fixture file in place; if a test writes, it copies to
  `%TEMP%` first.

Repo grounding (HeatLossRevit4): fixture is `DirectShapeSnapshot/Tests/TestData/TestBuildingAR_2024.rvt`
(tracked in git), opened as a detached copy — never in place.

## Rule 5 — Anti-brittleness

A test is brittle if an unrelated change can break it. Hard rules:

| Source of brittleness | Rule |
|---|---|
| `ElementId` hardcoded across documents | Resolve elements by `UniqueId`, name, or category filter within the fixture; Ids are per-document |
| Whole-document counts | Assert counts only inside a scoped collector or a seeded fixture with known content |
| Time/randomness | No `DateTime.Now`, `Guid`, or `Random` in expected values; inject fixed values |
| Ordering/state leakage | Each test stands alone: TUnit creates a new class instance; do not rely on another test's side effects; roll back or isolate document changes |
| Absolute machine paths | `%TEMP%` or fixture-relative paths only |
| Missing tolerance | Every double/geometry comparison has an explicit `Within(tol)` |
| UI assumptions | Headless only — no visible dialog, selection, or active view dependency |
| Shared mutable fixture | One fixture file per test area; writes go to a copy |

## Rule 6 — TestOutput hygiene (no artifact dumps)

Test runs must not pile files into the repo:

- Default for mass runs: `HL_TEST_SAVE_RVT=0` — work copies, metrics and RVT go to
  `%TEMP%\DirectShapeSnapshot_TestOutput`, checks go through `CheckSaved()`
  (green without a file). Repo `Tests/TestOutput` is not a result archive.
- One run writes at most one small metrics JSON (`<Case>_metrics.json`); no
  per-run `*.rvt` copies, no `*_HHmmssfff.rvt` fallbacks committed, no `*.docx`
  snapshots unless the test IS the report test.
- `.gitignore` covers `Tests/TestOutput/*` except a documented keep-list
  (fixture + golden tables, if any). Before green report: `TestOutput` file count
  unchanged or explicitly justified.

## Validation (acceptance checklist)

[ ] Every numeric assertion is exact value + explicit tolerance; no range used where a value is known.
[ ] Evidence attached: command line, pass/fail summary, report path from a real live run (config matches installed Revit).
[ ] Test asserts observable model/file/value; name states the behavior; AAA blocks present.
[ ] Fixture is a named real project file (or a justified pure-math case); expected values come from that file.
[ ] No hardcoded cross-document ElementIds, no time/random in expectations, no ordering dependency, no absolute paths, no UI dependency.
[ ] TestOutput hygiene: `HL_TEST_SAVE_RVT=0` for mass runs, ≤1 small metrics JSON per run, no new `*.rvt` in repo.

## Common pitfalls

| Pitfall | Correct approach |
|---|---|
| `IsGreaterThan(0)` instead of the real expected value | Compute the expected value and assert it with `Within(tol)` |
| "Build passed" reported as test proof | Run live and attach summary + report path |
| `--filter "FullyQualifiedName~..."` → zero tests | `--treenode-filter` with 4 segments; verify via `--list-tests` |
| Test asserts an ElementId literal from someone's local model | Resolve by UniqueId/name inside the fixture |
| Two tests share one modified document | Isolate per test; copy before writing |
| Fixture invented ad hoc in the test body | Real project file via `revit-test-fixtures`, or pure-math justification |
| Composite `pass = a && b && ...` + single `IsTrue()` | Assert each metric separately with exact values; log the row |
| 179 `*.rvt` in `TestOutput` | `HL_TEST_SAVE_RVT=0` + `%TEMP%` + `CheckSaved()`; repo stays clean |
