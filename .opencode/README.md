# Revit Skills for OpenCode

Набор навыков (skills) для [OpenCode](https://opencode.ai), упрощающих разработку плагинов и тестов для Autodesk Revit.

## Skills

| Skill | Описание |
|-------|----------|
| [revit-api](skills/revit-api/SKILL.md) | Базовые паттерны Revit API: транзакции, сборщики, геометрия |
| [revit-testing](skills/revit-testing/SKILL.md) | Unit-тесты с Nice3point.TUnit.Revit |
| [revit-test-fixtures](skills/revit-test-fixtures/SKILL.md) | Фикстуры, хуки, параметризованные тесты |
| [revit-test-runner](skills/revit-test-runner/SKILL.md) | Автоматизация запуска тестов в Revit |
| [revit-3d-export](skills/revit-3d-export/SKILL.md) | Экспорт геометрии Revit для 3D-вьювера |
| [revit-json-serialization](skills/revit-json-serialization/SKILL.md) | Сериализация Revit объектов в JSON |
| [threejs-viewer](skills/threejs-viewer/SKILL.md) | Архитектура Three.js 3D вьювера |
| [mcp-setup](skills/mcp-setup/SKILL.md) | Настройка MCP серверов |
| [revit-wiki](skills/revit-wiki/SKILL.md) | База знаний проекта (автозагрузка при старте) |
| [cloud-ai-bridge](skills/cloud-ai-bridge/SKILL.md) | Роутинг задач к облачному ИИ (DeepSeek/Qwen) |
| [pipeline-controller](skills/pipeline-controller/SKILL.md) | Агент-1: диспетчер/контролёр конвейера dev-pipeline |
| [pipeline-executor](skills/pipeline-executor/SKILL.md) | Агент-2: сотрудник-исполнитель конвейера |
| [pipeline-reviewer](skills/pipeline-reviewer/SKILL.md) | Ревьюер: git-аудит, PASS/NEEDS_CHANGES/FAIL |
| [pipeline-planner](skills/pipeline-planner/SKILL.md) | Планировщик миссий/декомпозиция задач |
| [pipeline-browser-bridge](skills/pipeline-browser-bridge/SKILL.md) | Агент-3: мост к облачному ИИ (LocalAssitent) |
| [pipeline-qwen-worker](skills/pipeline-qwen-worker/SKILL.md) | Тяжёлый воркер через облачный Qwen |
| [pipeline-placement-expert](skills/pipeline-placement-expert/SKILL.md) | Эксперт по расстановке тегов (MepTaggingSolution) |
| [planning-with-files](skills/planning-with-files/SKILL.md) | Планирование с файлами (task_plan/findings/progress) |
| [architect-review](skills/architect-review/SKILL.md) | Архитектурное ревью (read-only) |
| [software-architecture](skills/software-architecture/SKILL.md) | Clean Architecture/DDD паттерны |
| [solid-principles](skills/solid-principles/SKILL.md) | SOLID-принципы для классов/модулей |
| [knowledge-base](skills/knowledge-base/SKILL.md) | Правила пополнения базы знаний |
| [code-audit-graph](skills/code-audit-graph/SKILL.md) | Аудит кода: «ненужные цепочки», матрица решений, read/write-аудит графом (read-only) |

## Wiki

Хаб знаний: [wiki/](wiki/index.md) — ссылки на локальные вики проектов + общие темы.

- [Project Structure](wiki/project-structure.md) — структура репозиториев
- [MCP Servers](wiki/mcp-servers.md) — документация MCP
- [MCP графа кода (C#)](wiki/mcp-code-graph.md) — `roslyn_graph` + `astgrep`: установка в DSH,
  read/write-аудит, отброшенные кандидаты, грабли
- Локальные вики проектов: HeatLossRevit2, MepBimServer, MepTaggingSolution, dev-pipeline, AHUCalculator
  (`<проект>\.opencode\wiki\index.md`)

## Установка

Скопируйте папку `skills/` в `.opencode/` вашего проекта, либо настройте `skills.import` в `opencode.json`:

```
your-project/
  .opencode/
    skills/
      revit-api/SKILL.md
      revit-testing/SKILL.md
      revit-test-fixtures/SKILL.md
      revit-test-runner/SKILL.md
```

## Требования

- Autodesk Revit 2025+
- .NET SDK 8.0+
- [Nice3point.TUnit.Revit](https://www.nuget.org/packages/Nice3point.TUnit.Revit)
- [Nice3point.Revit.Sdk](https://www.nuget.org/packages/Nice3point.Revit.Sdk)

## Лицензия

MIT