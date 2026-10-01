# MCP графа кода (C#) — установка и применение

Серверы, которые дают агенту **семантический граф C#-решения**: граф вызовов, ссылки,
иерархия типов, измерения сложности. Установлены и проверены 01.10.2026 на
`HeatLossRevit.sln` (25 проектов, net48) в ходе аудита HeatLossRevit4.

Отличие от `mcp-servers.md`: там браузерные/UI-серверы (opencode-browser, playwright),
здесь — **анализ кода**. Методология применения — скил `code-audit-graph`.

## Зачем (и зачем НЕ для этого)

По статье «Агент не справляется с аудитом кода? Просто добавь графы» (Positive Technologies,
Хабр 29.09.2026): линейное чтение репозитория не работает — нужна карта. Цифры VulnGym:
**56,5 % провалов агента = не нашёл файл (26,8 %) или строку (29,7 %)**.

Но проверить на практике важнее, чем поверить:

| Задача | Граф помогает? |
|---|---|
| Измерения: god-объекты, сложность, `catch`-статистика, мёртвый код, циклы | **да, незаменим** |
| read/write-аудит: кто пишет/читает поле или настройку | **да, объективно сильнее человека** |
| Подтвердить «метод никто не вызывает» | да, но grep даёт то же |
| Найти «ненужную цепочку» (фолбэк вместо валидации) | **нет** — дефект в намерении, а не в структуре |

Статья написана про **taint-анализ** (источник → сток, CPG, Joern, срезы PDG) — к аудиту
соответствия бизнес-логике это не прикладывается. Читать её как обоснование «заведите граф»,
а не как методику.

## Установленные серверы

### 1. `roslyn_graph` — основной

`RoslynCodeLens.Mcp 2.18.1` (NuGet, MIT), **67 инструментов** через
`Microsoft.CodeAnalysis` + `MSBuildWorkspace`.

```powershell
dotnet tool install -g RoslynCodeLens.Mcp
# exe: C:\Users\Strakhov\.dotnet\tools\roslyn-codelens-mcp.exe
```

Что реально нужно аудитору:

| Инструмент | Назначение |
|---|---|
| `find_references` (+ `kinds: ["write","readwrite"]`) | **главный для «мёртвых настроек»** и полей-сирот |
| `find_callers` / `get_call_graph` | кто вызывает, транзитивный граф |
| `find_god_objects` | тип, где размер **и** связность превышены одновременно |
| `get_complexity_metrics` | цикломатическая + когнитивная сложность (cognitive важнее) |
| `find_catch_blocks` | сколько `catch (Exception)` и сколько **без `throw`** |
| `find_async_violations` | `async void`, `.Result`/`.Wait()`, fire-and-forget |
| `find_disposable_misuse` | кандидаты в утечки (Revit `Options`/`CurveLoop` — реальные, `Element`/`Parameter` — ложные) |
| `find_unused_symbols` | **кандидаты**, не приговор (XAML/DI/рефлексия не видны) |
| `find_circular_dependencies` | циклы проектов/namespace |
| `get_project_health` | сводка по всем проектам одним вызовом |
| `analyze_change_impact` | радиус правки до её начала |

### 2. `astgrep` — только под структурные правки

`ast-grep-mcp 0.0.2` (npm, MIT), 4 инструмента, поверх ast-grep CLI 0.43.0.

```powershell
npm install -g ast-grep-mcp
```

Для **аудита смысла бесполезен** (ноль находок за сессию); полезен для массовых
структурных правок (`$A ?? $B`, `class $C { ... }`).

## Конфиг DSH

Файл: `C:\Users\Strakhov\.dsh\profiles\web\cordis.patch.yml` (профиль `web`).
**Новые серверы добавляются через `insert:`** — запись с одним `id:` без `insert:` будет
id-патчем существующей записи и **молча пропущена**.

```yaml
- insert:
    - id: mcp-roslyn-codelens
      name: "@deepseek-ai/dsh-mcp-client"
      config:
        serverName: roslyn_graph
        transport: stdio
        command: 'C:\Users\Strakhov\.dotnet\tools\roslyn-codelens-mcp.exe'
        args:
          - 'E:\ПлагиныРевит\HeatLossRevit4\HeatLossRevit.sln'
        cwd: 'E:\ПлагиныРевит\HeatLossRevit4'
        toolCallTimeoutMs: 180000
        env:
          ROSLYN_CODELENS_OPEN_PROJECT_TIMEOUT_SECONDS: '600'

    - id: mcp-ast-grep
      name: "@deepseek-ai/dsh-mcp-client"
      config:
        serverName: astgrep
        transport: stdio
        command: 'C:\Program Files\nodejs\node.exe'
        args:
          - 'C:\Users\Strakhov\AppData\Roaming\npm\node_modules\ast-grep-mcp\dist\index.js'
        cwd: 'E:\ПлагиныРевит\HeatLossRevit4'
        env:
          AST_GREP_BIN: 'C:\Users\Strakhov\AppData\Roaming\npm\node_modules\ast-grep-mcp\node_modules\@ast-grep\cli\ast-grep.exe'
```

Инструменты видны модели как `mcp__<serverName>__<tool>`, т.е. `mcp__roslyn_graph__*`
и `mcp__astgrep__*`. **Перезапуск GUI не нужен** — DSH подхватывает серверы на лету
(проверено: серверы заработали прямо в текущей сессии).

Перед правкой конфига — бэкап: `cordis.patch.yml.bak-<дата>`.

## Проверка работоспособности

```powershell
# 1) сервер отвечает и отдаёт инструменты (JSON-RPC через stdio)
#    initialize -> notifications/initialized -> tools/list
#    roslyn_graph: 67 инструментов, astgrep: 4
# 2) решение загружено
#    list_solutions -> HeatLossRevit.sln, 25 проектов, status: ready, skippedProjects: []
# 3) живой вызов
#    ast_grep_version -> 0.43.0 ; find_references("SomeSymbol") -> ссылки с файлами/строками
```

Наблюдения: `roslyn_graph` при холодном старте открывает решение **30–60 с**; один раз
был `disconnected`, клиент переподключился сам. Хендшейк через пайпы под песочницей
EPERM **не падал**.

## Отброшенные кандидаты

| Кандидат | Причина |
|---|---|
| `codebadger` (MCP поверх Joern) | требует **Docker**; Docker на машине нет |
| `CodeKG`, `code-review-graph` | требуют **Neo4j** |
| Serena | LSP-база: нет type hierarchy / implementations; GPL; требует `uv` |
| Semgrep | не граф — шаблонный поиск |
| SharpToolsMCP | только сборка из исходников; дублирует Roslyn CodeLens |
| `codegraphcontext` 0.6.13 | установлен (pip, embedded KuzuDB, C# через tree-sitter + `scip-dotnet`), но не прописан и индексация прервана — кандидат на третий сервер |

**Важно про Joern:** C# он **поддерживает** (`joern-cli/frontends/csharpsrc2cpg`), блокер был
не в языке, а в Docker у обёртки `codebadger`. Сам Joern ставится Windows-zip + JDK 21.

## Грабли

- **ast-grep MCP:** абсолютные пути отклоняются («Path must be relative»), рабочий каталог
  сервера = корень проекта, относительные пути — от него; язык C# — `cs`/`csharp`, методы
  через `selector: method_declaration`; **без `AST_GREP_BIN`** обёртка падает (`spawn EINVAL`).
- **Не дампить ответы в контекст:** `get_project_health` ≈ 40 КБ, `find_unused_symbols` ≈ 800
  записей, широкий шаблон ast-grep однажды вылил 705 КБ. Ставь `limit`, сужай `paths`,
  громоздкое сохраняй в файл.
- **`find_unused_symbols` — список кандидатов**, а не приговор: часть потребляется XAML,
  DI-контейнером и рефлексией. Каждый требует ручного подтверждения.
- **`find_disposable_misuse` даёт ложные срабатывания** на Revit-типах (`Element`, `Parameter`
  не `IDisposable`), но `Options`, `CurveLoop`, `Transform` — реальные утечки.

## Полезные замеры (эталон для сравнения проектов)

По HeatLossRevit4 (01.10.2026, 25 проектов, ~977 прод-файлов) — чтобы понимать порядок величин:

- 17 god-объектов; 29 методов с цикломатикой ≥30, 18 с когнитивной ≥50;
- 11 async-нарушений (3 `async void`, 2 `.Result`, 1 `.Wait()`, 5 fire-and-forget);
- **1038** `catch (Exception)`, из них **381** без `throw`;
- 803 кандидата в мёртвый код; ~176 кандидатов в утечки `IDisposable`;
- циклических зависимостей проектов — **0**.
