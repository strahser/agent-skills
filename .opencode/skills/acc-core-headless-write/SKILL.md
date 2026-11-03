---
name: acc-core-headless-write
description: Headless DWG writing via AccCore (accoreconsole + .NET DLL) in DwgParser. Use when creating/editing DWG without GUI, batch-generating entities (fans, inserts, tables), verifying DWG integrity, or working around AutoCAD's interactive prompts. Covers run.bat CLI, safety (backup/UNDO/dry-run), commands BUILDFANS/DUMPSUMMARY/QUERY/EXTRACTJSON/VERIFY, and the Cyrillic-path and DefaultFormatForSave gotchas.
---

# AccCore — headless запись DWG (DwgParser)

Репозиторий: `d:\ПлагиныРевит\DwgParser` (ветка `feature/bimextractor-csharp`).
Модуль: `DwgParser\AccCore\` — `AcFanCmd\` (.NET DLL, net48) + `run.bat` (CLI) + `README.md`.
Документация: `AccCore\README.md`, анализ источника идей: `DwgParser\docs\CAD_AGENT_MCP_ANALYSIS.md`.

## Когда использовать

- Нужно **создать/изменить DWG без открытого AutoCAD** (batch-генерация: вентиляторы, вставки блоков, таблицы, слои).
- Нужно **пересохранить/нормализовать** DWG (формат 2018) через родной движок Autodesk — единственный надёжный писатель (ACadSharp-запись AutoCAD не пересохраняет, `ErrorStatus=53`; ezdxf — только DXF).
- Нужно **проверить** DWG: слои, счётчики, экстенты, подозрительные сущности.
- Нужно **выгрузить** полилинии/блоки в JSON для расчётов/DesignBase.

## Команды DLL (AcFanCmd.dll)

| Команда | Назначение |
|---|---|
| `BUILDFANS` | прецедент: 48 вентиляторов Р-1800 на коровник №3 (слой ACI 6, блок, сетка 4×12, очистка кластеров, легенда + нативная TABLE 9×3) |
| `DUMPTABLE` | вывести таблицы Лист1 |
| `DUMPSUMMARY` | слои (имя/цвет/on/frozen/locked), определения блоков, счётчики по типам, экстенты |
| `QUERY` | поиск по типу/слою/имени блока (AND), лимит; handle, тип, слой, цвет, bounds, позиция |
| `EXTRACTJSON` | экспорт полилиний + блоков (с атрибутами) в JSON schema v1; путь и паттерн имени блока задаются промптами |
| `VERIFY` | целостность: экстенты, счётчики, предупреждения о сущностях с бесконечными экстентами |
| `ADDFANTEST` | PoC: круг на слой 0 |

## CLI (run.bat)

```
run.bat [--dry-run] <in.dwg> <out.dwg> <COMMAND> [extra.scr]
```

Примеры:
```
run.bat Plan.dwg Plan_fans.dwg BUILDFANS
run.bat Plan_fans.dwg Plan_fans.dwg DUMPTABLE
run.bat --dry-run Plan.dwg Plan_fans.dwg BUILDFANS
```

## Безопасность записи (двухфазный контракт)

1. **Dry-run**: `--dry-run` печатает план (вход/выход/команда/путь бэкапа) и запускает только `DUMPSUMMARY` на входе — файл не трогается.
2. **Бэкап**: перед записью вход копируется в `%TEMP%\acccore_backups\<name>_<date>_<rnd>.dwg` (захватывает **последнее сохранённое** состояние, не in-memory правки — сохраните чертёж перед запуском, если есть несохранённые изменения).
3. **UNDO-группа**: команда оборачивается в `_.UNDO _Begin`/`_.UNDO _End` — один Ctrl+Z откатывает всю операцию в AutoCAD.
4. **Проверка**: после прогона проверяется существование и размер выходного файла.
5. **Несохранённый чертёж не правится** — работаем только по сохранённому файлу.

Идея позаимствована из `cad-agent-mcp` (MCP-мост AutoCAD): план → подтверждение → резервная копия → выполнение.

## Грабли (критично)

1. **Кириллица в пути DLL**: AutoCAD ExtensionLoader **не грузит managed DLL из путей с не-ASCII символами** (например `d:\ПлагиныРевит\...`). Симптом: «Неизвестная команда» + ошибка привязки сборки. `run.bat` решает это копированием DLL во `%TEMP%\AcFanCmd_<rnd>.dll` (ASCII-путь) и NETLOAD именно копии. При ручном вызове accoreconsole — копируйте DLL сами.
2. **`DefaultFormatForSave`**: должен быть `64` (DWG 2018), не `65` (DXF). Иначе QSAVE начинает предлагать DXF и конвертация сложного чертежа может виснуть. `run.bat` задаёт `(setenv "DefaultFormatForSave" "64")` в .scr, но реестр (`HKCU\...\Profiles\<<Нестандартный профиль>>\General`) тоже должен быть 64 — менять на закрытом AutoCAD.
3. **Нативная TABLE** хранится бинарником (код 310) — ezdxf/ACadSharp видят 1×1, но в AutoCAD корректна. Проверять через `DUMPTABLE`.
4. **Не держать AutoCAD открытым** при `reg add` — при выходе он перезапишет значение обратно.
5. В конце accoreconsole часто пишет `ERROR: Can't delete temp file (errno=13)` — безвредно.

## Требования

- AutoCAD 2022 (`C:\Program Files\Autodesk\AutoCAD 2022\accoreconsole.exe`).
- .NET SDK + ссылки на AutoCAD 2022 SDK (accoremgd/acmgd/AcDbMgd) — пути в csproj жёсткие.
- Сборка: `dotnet build AccCore\AcFanCmd\AcFanCmd.csproj -c Debug` → `bin\Debug\net48\AcFanCmd.dll`.

## Ограничения

- Требуется установленный AutoCAD (accoreconsole поставляется с ним).
- Для машин без AutoCAD: только ODA Drawings SDK или CadLib.
- В accoreconsole нет ActiveX/COM — LISP-таблицы не сделать, только .NET API.
- Оверлеи/снимки/GUI-инструменты (из cad-agent-mcp) в headless не применимы.

## Связь с DesignBase

`DesignBase\ingest\dwg_texts.py` использует BimExtractor (ACadSharp, чтение). AccCore — писатель; данные проекта (например, вентиляторы) пока в DesignBase не сохраняются — по договорённости, при выходе в проект переносить (координаты, слои, таблицы) через `EXTRACTJSON`.

## Прецедент: вентиляторы Р-1800 (коровник №3)

- 48 новых INSERT на слой `Вентиляторы_новые` (ACI 6), 72 старых DDF1200P сохранены.
- Раскладка: X × 12, Y × 4 (18000..231000 × 6000..54000), ≥4400 мм, крепление к колоннам.
- Легенда + нативная TABLE 9×3 на Лист1.
- Карточка: `ProjectsPalns\M1\_current\2026-11-02_Korpus-Fans-Р1800.md`; итоговый DWG: `ProjectsPalns\M1\_artifacts\`.
- Рабочая папка: `d:\Проекты Симрус\M1\11 Работа\Страхов\2026\Коровник Вентиляторы\` (там же `run.bat`, `AcFanCmd.dll`, `Plan_current.dwg`).
