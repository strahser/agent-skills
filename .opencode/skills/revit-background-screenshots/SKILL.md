---
name: revit-background-screenshots
description: >
  Take PNG screenshots of a Revit model in the background, without a human in the UI, using the Revit API.
  USE FOR: visual self-check or owner review of built DirectShapes (walls/openings/zones), comparing OM modes
  (by type / by function / by parallel), producing images for a report or a chat message from a headless test.
  DO NOT USE FOR: exporting geometry to Three.js (use revit-3d-export), authoring DWG (use cad-agent skills).
---

# Revit background screenshots (PNG через API)

Скриншот модели можно снять **без человека в Revit**: `Document.ExportImage` работает в фоновом
экземпляре Revit, который поднимает тест. Проверено на HeatLossRevit4 (Revit 2024, Nice3point.TUnit.Revit):
три файла ОМ отсняты за ~14 с.

## Когда применять

- Владелец просит «покажи, что построилось» — не нужно просить его открывать Revit.
- Самоконтроль после изменения геометрии/отборов: сравнить режимы построения глазами.
- Артефакт к отчёту или в чат: PNG + JSON с CoreId/параметрами тел.

## Рабочий рецепт (тест)

1. Открыть файл: `Application.OpenDocumentFile(path)`; закрывать `doc.Close(false)`.
2. **3D-вид может отсутствовать** — в документах от `NewProjectDocument` его нет (0 видов).
   Создать в памяти (файл не перезаписывать):

```csharp
var vft = new FilteredElementCollector(doc).OfClass(typeof(ViewFamilyType))
    .Cast<ViewFamilyType>().First(t => t.ViewFamily == ViewFamily.ThreeDimensional);
using (var t = new Transaction(doc, "Create3DView")) { t.Start(); View3D.CreateIsometric(doc, vft.Id); t.Commit(); }
```

3. Изометрия по габариту DirectShape. **`up` обязан быть перпендикулярен `forward`**, иначе
   `ArgumentsInconsistentException: The vectors upDirection and forwardDirection are not perpendicular`:

```csharp
var center = (bb.Min + bb.Max) * 0.5;
var size = (bb.Max - bb.Min).GetLength();
var forward = new XYZ(1, -1, 1).Normalize();
var up = (XYZ.BasisZ - forward * XYZ.BasisZ.DotProduct(forward)).Normalize();
var eye = center - forward * (size * 0.9);
using (var t = new Transaction(doc, "IsometricView"))
{ t.Start(); view.SetOrientation(new ViewOrientation3D(eye, up, forward)); t.Commit(); }
```

4. Экспорт. В Revit 2024 у `ImageExportOptions` **нет** `ViewId`/`ExportFileName`; есть
   `ViewName`, `SetViewsAndSheets(...)` и обязательный `ExportRange = ExportRange.SetOfViews`:

```csharp
var opts = new ImageExportOptions
{
    FilePath = Path.Combine(outDir, baseName),   // без расширения
    ExportRange = ExportRange.SetOfViews,
    HLRandWFViewsFileType = ImageFileType.PNG,
    ShadowViewsFileType = ImageFileType.PNG,
    ImageResolution = ImageResolution.DPI_150,
    ZoomType = ZoomFitType.FitToPage,
    PixelSize = 1600,
    ViewName = view.Name,
};
opts.SetViewsAndSheets(new List<ElementId> { view.Id });
doc.ExportImage(opts);
```

Файл получает имя `<FilePath> - <имя вида>.png` (Revit добавляет имя вида). Переименовывать не обязательно.

## Ловушки

- `HL_TEST_SAVE_RVT=0` в тестовой инфраструктуре HeatLossRevit4 отключает **и** `SaveOutputRvt` —
  RVT не появится, скриншоты при этом можно снимать (они не идут через `SaveOutputRvt`).
- Фильтр TUnit по классу: `--treenode-filter '/*/*/OmWallsScreenshotTests/*'`. Метод-фильтр может не сработать.
- Скриншот делается с текущего вида: если нужны зоны/оси/аннотации — включить категории на виде,
  иначе видно только тела.
- Для сравнения режимов снимать **исходные** файлы и не путать с `*_checked.rvt` (их правил владелец):
  исключать `EndsWith("_checked")`.
- Экспорт в фоне не требует открытого UI, но Revit-процесс должен стартовать в том же пользователе;
  один экземпляр — тесты помечать `[NotInParallel]`.

## Проверка результата

PNG сразу открывается инструментом чтения изображения — визуальная приёмка без Revit.
Для чисел рядом сохранять JSON: `CoreId`, `RoomId`, `IsExternal`, уровень, длина, высота.

## Реализация-образец

`HeatLossRevit4/DirectShapeSnapshot/Tests/OmWallsScreenshotTests.cs` (ветка `feature/tests-on-fixtures`):
обход `*.rvt` в `HL_SHOT_DIR`, исключение `_checked`, создание 3D-вида, изометрия, `ExportImage`,
лог в `shots/export.log`.
