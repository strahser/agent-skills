# Revit Skills Wiki — хаб знаний

Общий хаб: навигация по локальным вики **проектов** и общие темы. Каждый проект ведёт
свою локальную вики в `<проект>\.opencode\wiki\`, здесь — ссылки на них и общий справочник.

## Проекты (локальные вики)

| Проект | Локальная вики | Что внутри |
|--------|----------------|------------|
| HeatLossRevit2 | [`E:\ПлагиныРевит\HeatLossRevit2\.opencode\wiki\index.md`](../../../HeatLossRevit2/.opencode/wiki/index.md) | Clean Architecture V10, ExternalEvent, баги создания стен, UI теплопотерь, флаг наружности проёмов, настройки + JSON-хранение; ������ ������� WPF (2026-08-14); TUnit-тесты |
| MepBimServer | [`E:\ПлагиныРевит\MepBimServer\.opencode\wiki\index.md`](../../../MepBimServer/.opencode/wiki/index.md) | JSON-экспорт Revit, архитектура Three.js вьювера |
| MepTaggingSolution | [`E:\ПлагиныРевит\MepTaggingSolution\.opencode\wiki\index.md`](../../../MepTaggingSolution/.opencode/wiki/index.md) | Разделение ядра (Ядро 1/Ядро 2), баги размещения марок, задачи 2026-08-13 (ExternalEvent, немодальное окно, пофазовые логи, таблица-виджеты правил) и 2026-08-13_1 (ОВ/ВК + локальные стратегии, трубные мосты) |
| dev-pipeline | [`E:\ПлагиныРевит\dev-pipeline\.opencode\wiki\index.md`](../../../dev-pipeline/.opencode/wiki/index.md) | Конвейер задач: protocol/architecture/runbook, скилы конвейера |
| AHUCalculator | [`E:\ПлагиныРевит\AHUCalculator\.opencode\wiki\index.md`](../../../AHUCalculator/.opencode/wiki/index.md) | Расчёт приточных установок (конвейерный проект) |
| DwgParser | [`E:\ПлагиныРевит\DwgParser\.opencode\wiki\index.md`](../../../DwgParser/.opencode/wiki/index.md) | Парсинг DWG/DXF/PDF (BimExtractor, C#): таблицы спецификаций, PDF-блоки (table/text), кодировка cp1251, HTML-отчёты (АР/КЖ/КМ/ВК) |
| DesignBase | [`E:\ПлагиныРевит\DesignBase\.opencode\wiki\index.md`](../../../DesignBase/.opencode/wiki/index.md) | RAG по проектной документации ВВ-17+М1: SQLite+FTS5 (30,434 chunks), DOCX/PDF/DWG→реестр листов/объектов, DWG title block detection, PDF text extraction, LLM-ответ с цитатами, golden-eval 8/8. ВЗУ ТСГ, Делаваль, Родин, **РД** (дедупликация) |

## Общие темы (здесь, в agent-skills)

- [MCP Servers](mcp-servers.md) — документация MCP-серверов (opencode-browser, playwright, storage, …)
- [DeepSeek Harness](dsh-harness.md) — запуск харнесса (start-harness.ps1), общение через API, модели, скилы
- [Agent Workflow](agent-workflow.md) — самоуправление: добавление скилов, обновление wiki, git push
- [Project Structure](project-structure.md) — структура репозиториев и рабочего пространства
- [Dashboard и OpenContext](dashboard-opencontext.md) — локальный веб-дашборд, глобальная база знаний
- [Django Task App](django-task-app.md) — планировщик задач (проект вне E:\ПлагиныРевит)
- [Revit Installer (WixSharp)](revit-installer.md) — MSI perUser/perMachine, WixSharp, MajorUpgrade, чистая установка, WPF pack URI
- [Инспекция PDF без GUI](pdf-inspect.md) — PyMuPDF рендер страниц в PNG → Read картинкой;
  счётчик встроенных изображений (проверка «иконки попали в PDF»)

## Скилы

Все скилы (Revit + конвейер dev-pipeline + парсинг РД) — в `agent-skills\.opencode\skills\`:
- Revit: revit-api, revit-testing, revit-test-fixtures, revit-test-runner, revit-3d-export,
  revit-json-serialization, threejs-viewer, mcp-setup, revit-wiki, cloud-ai-bridge, revit-installer
- Конвейер: pipeline-controller, pipeline-executor, pipeline-reviewer, pipeline-planner,
  pipeline-browser-bridge, pipeline-qwen-worker, pipeline-placement-expert, **pipeline-grill**
  (вопросы владельцу до работы: explore-first, Q-файлы + wait_answer, ASSUMPTION),
  planning-with-files, architect-review, software-architecture, solid-principles, knowledge-base
- Парсинг РД: **pdf-spec-parsing** (PDF: текстовый слой → anchor-спеки → find_tables → vision;
  проверка ВОР; слепые тесты моделей 2026-09-08), **dwg-text-parsing** (DWG/BimExtractor:
  тексты да, spec-таблицы нет; СПДС/zombie)

## Быстрые ссылки

| Что | Где |
|-----|-----|
| Вьювер | `MepBimServer\ui\demo3D\Index.html` |
| Revit плагин | `MepBimServer\` (C#) |
| Тестовый экспорт | `demo3D\ProjectExport_*.json` |
| Навигация шапка | `ui\partials\site-header.html` |
| Плагины opencode | `.opencode\plugins\` (html-tools, threejs-tools, revit-tools) |
