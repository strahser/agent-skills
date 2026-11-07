---
name: revit-test-fixtures
description: >
  Supply Autodesk Revit API tests with the documents, services, and data cases they run against, and pick the right data source for each situation.
  USE FOR: seeding a fresh in-memory model per test, opening installed sample .rvt/.rfa files as fixtures, choosing between [MethodDataSource] and [InstanceMethodDataSource], running one test body across several file kinds, injecting services under test through a dependency-injection data source, and test skipping.
  DO NOT USE FOR: writing the test itself or the Revit-thread executor model (use revit-testing), or measuring performance (that is a benchmark, not a fixture).
license: MIT
---

# Revit Test Fixtures

A fixture is everything a test runs against: the document, the services it calls, and the cases it repeats over.
Choosing the wrong one is the usual cause of tests that pass alone but fail together, or that silently test nothing.
Match the situation to one reference below and open only that one.

Two invariants hold across every variant:

1. **Create and close documents on the Revit thread.** Any hook that opens, seeds, or closes a document carries `[HookExecutor<RevitThreadExecutor>]`, and every opened or created document is closed in teardown.
2. **Discovery runs before Revit exists.** TUnit evaluates every data source, constructs the test class, and resolves every injected service during discovery, off the Revit thread — they yield only primitives (numbers, strings, file paths) and never call the Revit API at construction. The test body turns those primitives into Revit objects on the Revit thread.

```csharp
public static string[] DocumentPaths => Directory.EnumerateFiles(directory, "*.rvt").ToArray(); // primitives, off-thread

[After(Test)]
[HookExecutor<RevitThreadExecutor>] // teardown touches Revit; it runs on the Revit thread
public void CloseDocument()
{
    _document?.Close(false);
}
```

## When to use

- A test needs a document, an injected service, or a repeated set of cases.
- Tests share state and interfere with each other.

## Fixture Patterns

### Seeded Document

Create a fresh in-memory document with specific elements for each test:

```csharp
public sealed class WallTests : RevitApiTest
{
    private Document _document = null!;

    [Before(Test)]
    [HookExecutor<RevitThreadExecutor>]
    public void SeedModel()
    {
        _document = Application.NewProjectDocument(UnitSystem.Metric);
        
        using var transaction = new Transaction(_document, "Seed");
        transaction.Start();
        
        // Create test elements
        var level = Level.Create(_document, "Test Level", 0);
        Wall.Create(_document, Line.CreateBound(XYZ.Zero, new XYZ(10, 0, 0)), level.Id, false);
        
        transaction.Commit();
    }

    [After(Test)]
    [HookExecutor<RevitThreadExecutor>]
    public void Cleanup()
    {
        _document?.Close(false);
    }

    [Test]
    public async Task WallCount_ReturnsSeededCount()
    {
        var walls = new FilteredElementCollector(_document)
            .OfClass(typeof(Wall))
            .ToElementIds();

        await Assert.That(walls.Count).IsEqualTo(1);
    }
}
```

### Parameterized Fixtures

Run the same test across multiple sample files:

```csharp
public class SampleFileTests : RevitApiTest
{
    public static string[] SampleFiles => new[]
    {
        @"C:\Samples\Project1.rvt",
        @"C:\Samples\Project2.rvt"
    };

    [Test]
    [InstanceMethodDataSource(nameof(SampleFiles))]
    public async Task Document_HasLevels(string filePath)
    {
        var document = Application.OpenDocumentFile(filePath);
        
        try
        {
            var levels = new FilteredElementCollector(document)
                .OfClass(typeof(Level))
                .ToElementIds();

            await Assert.That(levels.Count).IsGreaterThan(0);
        }
        finally
        {
            document.Close(false);
        }
    }
}
```

### Dependency Injection

Inject services through TUnit's DI:

```csharp
public class ServiceTests : RevitApiTest
{
    private readonly IMyService _service;

    public ServiceTests(IMyService service)
    {
        _service = service;
    }

    [Test]
    public async Task Service_ProcessDocument()
    {
        var document = Application.ActiveUIDocument.Document;
        
        var result = _service.Process(document);
        
        await Assert.That(result).IsTrue();
    }
}
```

## Data Source Selection

| Scenario | Data Source | Example |
|----------|-------------|---------|
| Fixed primitive values | `[Arguments]` | `[Arguments(1, 2, 3)]` |
| Static list of files/values | `[MethodDataSource]` | `[MethodDataSource(nameof(SampleFiles))]` |
| Constructor-dependent values | `[InstanceMethodDataSource]` | `[InstanceMethodDataSource(nameof(GetCases))]` |
| Service injection | DI data source | Constructor injection |

## Validation

- [ ] Each test gets isolated state; nothing leaks between tests.
- [ ] Every opened or created document is closed in `[After(Test)]`.
- [ ] Fixture hooks that touch Revit use `[HookExecutor<RevitThreadExecutor>]`.
- [ ] Sample files are opened from a private copy, not in place.
- [ ] Data sources return primitives; Revit objects are built in the test body.

## Common Pitfalls

| Pitfall | Correct approach |
|---------|------------------|
| Tests passing alone but failing together | Give each test its own document or state. |
| A data source that returns a Revit object | Return primitives or paths; build Revit objects in the test body. |
| `[MethodDataSource]` on a constructor-dependent member | Use `[InstanceMethodDataSource]`. |
| Opening the sample file in place | Copy it to a temporary path and open the copy. |
| Failing when the samples folder is missing | Return an empty data set or call `Skip.Test(...)`. |
| A fixture test fails with `JsonSerializationException` on a file that **is** tracked in git | A stale generated copy in `bin\...\TestData` shadows the tracked fixture (seen 07.11.2026: `Snapshot_FullAR_1.3.json` 2.1 MB in bin vs 1.27 MB in git). Delete the bin copy or do a clean rebuild; the test searches from the assembly directory upward and finds the bin copy first. |
| **All** tests fail at ~0 ms with `BeforeTestSession … Attempted to write protected memory` | Not a fixture problem — the injector could not start Revit from this location. See `revit-test-runner` → "Known issue: Attempted to write protected memory before any test runs" (run from `D:\temp\...`). |

## References

- [TUnit Data Sources](https://thomhurst.github.io/TUnit/)
- [revit-testing skill](../revit-testing/SKILL.md)
- [RevitUnit Repository](https://github.com/Nice3point/RevitUnit)
