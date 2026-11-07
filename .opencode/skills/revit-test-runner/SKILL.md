---
name: revit-test-runner
description: >
  Run Revit API tests locally using AutomationServiceHandler (aps-automation-csharp-revit.local.debug.tool).
  USE FOR: local test execution, CI/CD pipelines, debugging test failures.
  DO NOT USE FOR: writing tests (use revit-testing), setting up test fixtures (use revit-test-fixtures).
license: MIT
---

# Revit Test Runner

Local test execution using `AutomationServiceHandler` from `aps-automation-csharp-revit.local.debug.tool`.

## When to use

- Running Revit API tests locally
- Debugging test failures
- CI/CD pipeline integration
- Quick test iterations without full solution rebuild

## When not to use

- Writing tests — use `revit-testing`
- Setting up test fixtures — use `revit-test-fixtures`
- Creating UI elements — use `revit-ui`
- Quality/acceptance criteria (is the test strong enough) — use `revit-test-quality`

## AutomationServiceHandler Setup

### 1. Install from NuGet

```shell
dotnet add package aps-automation-csharp-revit.local.debug.tool
```

### 2. Configure Test Runner

```csharp
// TestRunner.cs - IExternalCommand implementation
[Transaction(TransactionMode.Manual)]
public class TestRunner : IExternalCommand
{
    public Result Execute(ExternalCommandData commandData, ref string message, ElementSet elements)
    {
        var uiApp = commandData.Application;
        var doc = uiApp.ActiveUIDocument.Document;

        var results = new List<string>();

        // Run tests
        results.Add($"Document: {doc.Title}");
        results.Add($"Elements: {new FilteredElementCollector(doc).WhereElementIsNotElementType().Count()}");

        // Show results
        var sb = new StringBuilder();
        sb.AppendLine("=== Test Results ===");
        foreach (var result in results)
        {
            sb.AppendLine($"  • {result}");
        }

        TaskDialog.Show("Tests Completed", sb.ToString());
        return Result.Succeeded;
    }
}
```

### 3. Build and Deploy

```shell
# Build for debug
dotnet build -o "path\to\YourProject\bin\Debug2"

# Copy to Revit addins folder
copy "path\to\YourProject\bin\Debug2\YourProject.dll" "%APPDATA%\Autodesk\Revit\Addins\2025\"
```

## Running Tests

### Option 1: Via Revit AddinManager

1. Open Revit
2. Open AddinManager (Ctrl+Shift+AddinManager)
3. Select `TestRunner` command
4. Click Run

### Option 2: Via Command Line (Nice3point.TUnit.Revit)

```shell
# Run all tests
dotnet test -c Release.R25

# Run specific test
dotnet test -c Release.R25 --filter "FullyQualifiedName~WallCreationTests"

# Run with verbosity
dotnet test -c Release.R25 --verbosity normal
```

### Option 3: Via dotnet run

```shell
# Run with arguments
dotnet run -c Release.R25 --project RevitTesting.csproj
```

### Option 4: Run prebuilt executable directly (WORKAROUND for legacy Base.csproj + Newtonsoft)

**Symptom:** `dotnet run -c Release.R24 --project SnapshotTool -- --treenode-filter "..."` fails at compile
with hundreds of `CS0246: Не удалось найти тип или имя пространства имен "Newtonsoft"`
in a **legacy non-SDK** project referenced by the test project (e.g. `Base\Base.csproj` with
`<PackageReference Include="Newtonsoft.Json" Version="13.0.4"/>`).

**Why:** `dotnet run` re-runs NuGet restore with its own props/configuration, regenerates
`project.assets.json` and forces a full recompile of the legacy project — but package references
are then not resolved for that project, so it fails. Direct `dotnet build <testproj.csproj> -c Release.RNN --no-restore`
can succeed incrementally without touching the legacy project.

**Workaround — skip `dotnet run` entirely and execute the already-built test runner:**

```shell
# build once (incremental — does not rebuild the broken legacy project)
dotnet build SnapshotTool\SnapshotTool.csproj -c Release.R24 --no-restore

# run the prebuilt test executable directly (an exe, even though the project is a test project)
SnapshotTool\bin\Release.R24\SnapshotTool.exe --treenode-filter "/*/SnapshotTool/GeneralizedWallsTests/*"
# or --list-tests to see what's available
SnapshotTool\bin\Release.R24\SnapshotTool.exe --list-tests
```

Notes:
- The runner is a real `.exe` (`OutputType=Exe`), so it can be started directly from `bin\<config>`.
- Do **NOT** use `dotnet run` for filtered runs on repos with such legacy projects — it restores and breaks the build.
- Results land in `bin\<config>\TestResults\` (`*-report.html`, TRX, etc.).

### IMPORTANT: TUnit `--treenode-filter` syntax

TUnit (Microsoft Testing Platform) does **NOT** understand VSTest `--filter "FullyQualifiedName~..."` — it is silently
rejected and prints the MTP help, resulting in `Zero tests ran`. Use `--treenode-filter` instead:

```
/<Assembly>/<Namespace>/<Class name>/<Test name>
```

- `*` is a wildcard inside a single segment. `/**` matches any depth, but only at the end.
- Examples:
  - all tests in class `GeneralizedWallsTests` (namespace `SnapshotTool`, assembly also `SnapshotTool`):
    `--treenode-filter "/*/SnapshotTool/GeneralizedWallsTests/*"`
  - single test: `--treenode-filter "/*/SnapshotTool/GeneralizedWallsTests/Save_GeneralizedWalls_AsSeparateFile"`
  - by test name: `--treenode-filter "/*/*/*/AcceptCookiesTest"`
  - by property: `--treenode-filter "/*/*/*/*[Category=Smoke]"`, exclude `[Category!=Slow]`
- A filter with too few segments silently matches **0 tests** (e.g. `"*/GeneralizedWallsTests/*"` is
  *Assembly/Namespace/Class* — it will not match anything in practice). Always use at least 4 segments
  or verify with `--list-tests`.

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Run Revit Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'
      
      - name: Build
        run: dotnet build -c Release.R25
      
      - name: Test
        run: dotnet test -c Release.R25 --logger "trx;LogFileName=results.trx"
      
      - name: Upload Results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: '**/*.trx'
```

## Debugging Tips

### Known issue: `Attempted to write protected memory` **before** any test runs

**Symptom:** `BeforeTestSessionException: BeforeTestSession hook failed: Attempted to write protected memory`
inside `Nice3point.Revit.Injector.Injector.InjectApplication()`, exit `-1073741819 (0xC0000005)`,
about 4 s, **0 tests executed**.

**Not the same** as the discovery-time error described in `revit-testing` (a constructor, field initializer
or data source touched the Revit API). Here the failure is in the injector, before discovery bodies run.

**Verified 07.11.2026 (HeatLossRevit4, Revit 2024, same built exe):**

- passes from `D:\temp\...` and from the main repo path `D:\Projects\HeatLossRevit4\...`;
- fails from `D:\Projects\HL4test`, `D:\Projects\HL4omtemplate`, `D:\Projects\HL4-omtemplate\...`
  (a fresh worktree / working copy) — **regardless of path length** (a long `D:\temp\...` copy passes,
  a shorter `D:\Projects\HL4test` fails).

**Rule:** run live tests from a **short allowed root** such as `D:\temp\...`, not from a fresh
worktree/copy under `D:\Projects\HL4-*`. The owner's recorded workaround is to keep temp files there too:
`$env:TEMP="D:\temp"; $env:TMP="D:\temp"` (`PROMPT-2026-11-01-om-unidentified-bg2-WORKER.md`).

**Recipe:**

```powershell
Get-Process Revit -ErrorAction SilentlyContinue   # must be closed, no leftover instance
$env:HL_TEST_SAVE_RVT="0"; $env:TEMP="D:\temp"; $env:TMP="D:\temp"
$dst="D:\temp\hl4-live"
New-Item -ItemType Directory $dst -Force | Out-Null
Copy-Item "<repo>\DirectShapeSnapshot\Tests\bin\Debug.R24\*" $dst -Recurse -Force
Push-Location $dst
& "$dst\DirectShapeSnapshot.Tests.exe" --treenode-filter "/*/*/<TestClass>/*"
```

If the hook still fails, it is the environment (AV/security path policy), not the test code:
report the exact error and do **not** weaken assertions to make it green.

### Common Issues

1. **DLL locked by Revit** — Use different output folder (`bin\Debug2`)
2. **Tests not found** — Check `TestsConfiguration.cs` has `[assembly: TestExecutor<RevitThreadExecutor>]`
3. **Transaction errors** — Ensure `[Transaction(TransactionMode.Manual)]` on test class
4. **Revit not found** — Verify Revit 2025 is installed and version matches configuration

### Logging Output

```csharp
// Add logging to tests
[Test]
public async Task TestWithLogging()
{
    var doc = Application.ActiveUIDocument.Document;
    var walls = new FilteredElementCollector(doc)
        .OfClass(typeof(Wall))
        .Cast<Wall>()
        .ToList();
    
    // Log to output
    foreach (var wall in walls)
    {
        Trace.WriteLine($"Wall {wall.Id}: {wall.Name}");
    }
    
    await Assert.That(walls).IsNotEmpty();
}
```

## Validation

- [ ] Test project compiles without errors
- [ ] `.addin` file points to correct DLL path
- [ ] Revit 2025 is running before test execution
- [ ] Test results are displayed or logged

## References

- [AutomationServiceHandler Documentation](https://github.com/aps-automation-csharp-revit.local.debug.tool)
- [Nice3point.TUnit.Revit](https://www.nuget.org/packages/Nice3point.TUnit.Revit)
- [Revit API Documentation](https://www.revitapidocs.com/)
