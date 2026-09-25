# AGENTS.md — agent-skills (база знаний по Revit)

**Роль репозитория:** общий хаб знаний и справочник скилов по Revit-разработке и
конвейеру dev-pipeline. Это НЕ конвейер задач (dev-pipeline) и НЕ рабочий проект
(HeatLossRevit2 и др.). Здесь живут **знания**: общая wiki (навигация по проектам) +
общие скилы.

## Структура

- Скилы: `.opencode/skills/` — revit-api, revit-testing, revit-test-quality,
  revit-test-fixtures,
  revit-test-runner, revit-3d-export, revit-json-serialization, threejs-viewer,
  mcp-setup, revit-wiki, cloud-ai-bridge + скилы конвейера (перенесены из dev-pipeline):
  pipeline-controller, pipeline-executor, pipeline-reviewer, pipeline-planner,
  pipeline-browser-bridge, pipeline-qwen-worker, pipeline-placement-expert,
  pipeline-grill (grill-фаза: вопросы владельцу через Tasks\Вопросы + wait_answer),
  planning-with-files, architect-review, software-architecture, solid-principles, knowledge-base.
- Wiki (общая): `.opencode/wiki/index.md` — навигация: общие темы (MCP, workflow,
  структура, дашборд) + **ссылки на локальные вики проектов**.
- Локальные вики проектов (в каждом проекте): `<project>\.opencode\wiki\index.md` —
  HeatLossRevit2, MepBimServer, MepTaggingSolution, dev-pipeline, AHUCalculator.
- Git: `main`, remote `https://github.com/strahser/agent-skills.git`. Перед работой: `git pull`.

## Как пополняется база знаний

1. Агенты конвейера dev-pipeline (executor/controller/reviewer/qwen-worker) получают новое
   стабильное знание при выполнении задач — и записывают его в **локальную вику проекта**
   или общую wiki (см. скилл `knowledge-base`).
2. Общее знание (паттерны, форматы, MCP) → agent-skills; знание конкретного проекта →
   `<проект>\.opencode\wiki\`.
3. Формат: markdown; заголовок H1; ссылки относительные; commit message на английском, краткий
   (до 80 символов). Коммиты делает контролёр (Агент-1): `docs:` или `agent/A-NN: wiki: ...`.
4. Новую страницу — добавить ссылку в `wiki/index.md` соответствующей вики.
5. Не удалять существующие страницы и скилы без явной необходимости.

## Что НЕ делать

- Не вести здесь статусы задач/отчёты/вердикты — это dev-pipeline (TDL-задачи).
- Не коммитить: `.idea\`, `.opencode\` (runtime-состояние оркестратора устарело — не использовать),
  `node_modules`, `project.db`, логи.
- Устаревшая конфигурация оркестратора (opencode-orchestrator, /task, Commander/Planner/Worker)
  в `opencode.json` НЕ используется — конвейер живёт в dev-pipeline.

## Синхронизация

После изменений: commit + push (контролёр). Уведомление пользователю: «обновлено в revit-skills».
