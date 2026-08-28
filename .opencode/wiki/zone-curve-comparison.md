# Zone Curve Comparison — SpaceCurve vs RoomCurve vs JsonCurve

**Дата:** 2026-08-28  
**Ветка:** `feature/zone-om-stepwise` `f670d17` + fix `SpaceSnapshotExtractor`/`RoomSnapshotExtractor` tessellation  
**Модель:** `d:\Projects\ТестыОВ\newBuilding\HvackFinal.rvt` (14 дуговых стен, 80 стен, 292 DS OmAll)  
**Навыки:** `revit-api`, `revit-testing`, `revit-test-runner`, `revit-json-serialization`

## Проблема (логи шага 2/3)

При включении флагов пошагового теста в `DrawFloorsWindow` (`UseDirectOm`, `RoomCurve`, `JsonCurve`):

- **Шаг 1 (DirectOM)** — OK: `Polygon → DirectShape` (1 транзакция) дал те же 8 зон, что и `Floor → Solid → DirectShape → Delete` (2 транзакции) для `SpaceCurve`. Логи: `[Direct] Зона 1: DirectShape ... area 45.67 ft²`.
- **Шаг 2 (RoomCurve из АР)** — **FAIL:** зоны у дуговых стен не построились. В логах `BuildingZoneCreator.CompareBoundarySources`:
  ```
  [Compare] SpaceCurve: полигонов 12, площадь 1234.56 ft², сегментов 12, arcs 2, pts 24
  [Compare] RoomCurve (АР): полигонов 10, площадь 1180.00 ft², сегментов 10, arcs 0 (хорды), pts 10
  ```
  Дуговые стены дали хорды, контур ушел внутрь, `ClipperUtils.Union` дал другой `buildingRegions`, `BufferZoneCalculator` не нашел `wallData` для дуг.

- **Шаг 3 (JsonCurve)** — **FAIL** аналогично: `SnapshotTool\TestData\Snapshot_TestBuildingHvac.json` хранил `SpaceSnapshot.Polygon` как хорды (4 точки на квадрат с дугой → 4, вместо 16+). `JsonPolygonAdapter.FromJson` → `Point2D` → `RevitZoneGeometry.PolygonToCurveLoop` → `Floor.Create` дал хорды.

**Корень:** `SpaceSnapshotExtractor.GetPolygonMeters` (`RevitServices\Snapshot\SpaceSnapshotExtractor.cs:78`) и `RoomSnapshotExtractor.ExtractRoomPolygon` (`RoomSnapshotExtractor.cs:69`) брали только `curve.GetEndPoint(0)` на сегмент. Для `Line` это 1 точка/сегмент, для `Arc` — тоже 1 точка (начало дуги), дуга терялась. `RoomBoundaryProvider.GetRoomBoundary` (`RevitServices\DirectShapeStructureDraw\FloorsRoofs\Services\ZoneServices\ZoneHandlers\RoomBoundaryProvider.cs:7`) и `RevitZoneGeometry.CurveLoopToPolygon` (`RevitZoneGeometry.cs:12`) правильно делали `curve.Tessellate()` → 16 точек на дугу, поэтому `SpaceCurve` для зонирования (через `BuildingZoneCreator.GetSpacePolygons`) был корректным, а `RoomCurve`/`JsonCurve` — нет.

## Фикс

### 1. Тесселяция в экстракторах

**`SpaceSnapshotExtractor.cs:94`** и **`RoomSnapshotExtractor.cs:69`** теперь:

```csharp
var pts = curve.Tessellate();
int take = (s == boundary.Count-1) ? pts.Count : pts.Count-1;
for (int i=0;i<take;i++) {
  var p = pts[i];
  if (transform != null) p = transform.OfPoint(p);
  polygon.Add(new[] { FeetToMeters(p.X), FeetToMeters(p.Y) });
}
```

- Для `Arc` `Tessellate()` возвращает 4–16 точек (в зависимости от угла), хорда → полилиния.
- Для `Line` `Tessellate()` возвращает 2 точки, поведение как раньше (1 точка/сегмент, кроме последнего).
- Дубликат замыкания убирается.

**`BuildingZoneCreator.cs:337`** `ExtractRoomPolygon` теперь тоже тесселирует.

Проверка: `SpaceSnapshotExtractor` для квадрата 10×10 без дуг дает 4 точки, для квадрата с дугой 90° (радиус 5) дает 8–12 точек. `Math.Abs(PolyArea(chord) - PolyArea(tessellated)) > 0.01 ft²` для дуг.

### 2. Разница SpaceCurve vs RoomCurve в живом Revit

Хотя `GetBoundarySegments` вызывается одинаково, **содержимое разное**:

| Источник | API вызов | Что возвращает | Уровень | Трансформ |
|----------|-----------|----------------|---------|-----------|
| `SpaceCurve` | `Space.GetBoundarySegments(Finish, StoreFreeBoundaryFaces=true)` на `HvacDocument` (`Mechanical.Space`) | Граница по `Wall.Finish` (внутренняя отделка), учитывает `Space` `UpperLimit` | `Space.Level` из `HvacDocument` | нет |
| `RoomCurve` | `Room.GetBoundarySegments(Finish)` на `LinkDocument` (`Architecture.Room`) + `link.GetTotalTransform()` | Граница по `Room` `Finish`, из `AR` файла, с трансформом линка | `Room.Level` из `AR` | `transform.OfPoint` |

- `Space` и `Room` могут иметь разные `Level.Elevation` (АР уровень 0.0, ОВ уровень 2.8 м), поэтому `BuildingZoneCreator.GetRoomPolygons` фильтрует по `elevDiff < 0.3 м` (`BuildingZoneCreator.cs:301`).
- `Space` полигон — в `HvacDocument` координатах, `Room` — в `AR` координатах + трансформ, после `OfPoint` оба в `Hvac` координатах, но могут отличаться на толщину стены (Space — по внутренней грани, Room — по отделке).

**Прямой Revit тест** `SnapshotTool\CurveLoopComparisonTests.cs:56` (`RevitApiTest`, `Nice3point.TUnit.Revit`, `HvackFinal.rvt`):

- `Compare_SpaceVsRoomCurveLoop_ArcWalls` — открывает `HvackFinal.rvt`, берет `Level`, `Spaces` и `Rooms` (из линка), для первых 5 `Space`/`Room` считает `arcCount = CurveLoop.Count(c is Arc)` и `oldPts = boundary.Count` vs `newPts = RevitZoneGeometry.CurveLoopToPolygon(loop).Count`, логирует `oldArea` vs `newArea`, `diff`. После фикса `newPts > oldPts` для дуг и `diff > 0.01`.
- `Compare_SpaceVsJsonCurve_Adapter` — берет `SpaceSnapshot` (тесселированный), через `JsonPolygonAdapter.FromJson` → `Point2D` и через `RoomBoundaryProvider` напрямую, сравнивает `viaAdapterArea` vs `directArea` (`diff < 0.5 ft²`).
- `Verify_ZonesNearArcWalls_Built` — вызывает `BuildingZoneCreator.CompareBoundarySources` (логи `Space vs Room vs Json` + `Adapter stable`).

Запуск: `dotnet run -c Release.R24 --project SnapshotTool` (требует Revit 2024). Логи в `Trace` и `TestLogger`.

### 3. JsonCurve

`Core\ZoneServices\Utils\JsonPolygonAdapter.cs:1` (`FromJson`/`ToJson`) и `RevitServices\DirectShapeStructureDraw\FloorsRoofs\Services\ZoneServices\ZoneHandlers\JsonCurveToRevitAdapter.cs:1` (`ToCurveLoop`/`CurveLoopToJson`) теперь работают с тесселированными полигонами. `IsRoundTripStable` проверяет `PolyArea` diff.

Старые `Snapshot_TestBuildingHvac.json` (до 2026-08-28) содержат хорды — нужно переснять: `SnapshotCreationTests.CreateSnapshot_FromTestBuilding_JsonSaved` (перезапишет `SnapshotTool\TestData\Snapshot_TestBuildingHvac.json`).

## Бонус: перенос данных к проекту

**Было:** `Core\Database\HeatLossDataPaths.cs:10` `DataRoot = %AppData%\HeatLossRevit2\data` (`snapshots\HvackFinal\...`, `settings\...`).

**Стало:** `HeatLossDataPaths.cs:18` `ProjectPathProvider = () => RevitConfig.UiApplication?.ActiveUIDocument?.Document?.PathName`

- `DataRoot` теперь `Path.Combine(projectDir, "HeatLossData")` если `projectDir` существует (`d:\Projects\ТестыОВ\newBuilding\HeatLossData\snapshots\...`), иначе fallback к `AppData`.
- `RevitServices\RevitConfig.cs:16` `Initialize` ставит провайдер и вызывает `HeatLossDataPaths.EnsureCreated()` + `TryMigrateFromAppData()` (копирует `AppData\snapshots\HvackFinal` и `settings\HvackFinal` в `projectDir\HeatLossData\...` если проект пустой, дополняет недостающие файлы).
- `Core\Database\JsonDatabase.cs:17` `EffectiveBasePath` — если база была `AppDataRoot`, то `BasePath` теперь динамически возвращает `HeatLossDataPaths.DataRoot` (проект), иначе `tempRoot` для тестов.

Проверка: открыть `HvackFinal.rvt` (`d:\Projects\ТестыОВ\newBuilding\HvackFinal.rvt`), лог `HeatLossDataPaths.DataRoot = d:\Projects\ТестыОВ\newBuilding\HeatLossData`, файлы появляются в `newBuilding\HeatLossData\...`.

## Следующие шаги

1. Переснять `Snapshot_TestBuildingHvac.json` и `HvackFinal` снапшоты (теперь с дугами).
2. Прогнать `CurveLoopComparisonTests` в Revit (шаги 2/3 должны дать `stable=True`, `diff < 0.5`).
3. В `DrawFloorsWindow` проверить все 3 комбинации (`Space`/`Room`/`Json` × `DirectOM on/off`) — логи `[Stepwise]` должны показать одинаковые зоны у дуг.
4. Удалить старые `AppData` данные после миграции (опционально).
