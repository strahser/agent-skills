# Установка скилов и MCP для аудита (кратко)

Для задания `TASK-2026-10-09-full-audit.md` нужны 5 скилов и 4 MCP-сервера.
Проверено 09.10.2026 на этой машине: скилы есть, `revit-mcp`/`netwright` на месте,
`roslyn_graph`/`astgrep` **не установлены**, в конфигах висят пути несуществующего диска `E:`.

## 1. Скилы — ставить ничего не надо

Скилы — обычные `.md`, лежат здесь: `D:\ПлагиныРевит\agent-skills\.opencode\skills\`.
Подключаются строкой `skills.paths` в `opencode.json` (в `HeatLossRevit4/opencode.json`
уже прописано верно). Для аудита нужны — все есть:

| Скил | Путь |
|---|---|
| `code-audit-graph` | `.opencode/skills/code-audit-graph/SKILL.md` |
| `architect-review` | `.opencode/skills/architect-review/SKILL.md` |
| `solid-principles` | `.opencode/skills/solid-principles/SKILL.md` |
| `software-architecture` | `.opencode/skills/software-architecture/SKILL.md` |
| `revit-test-quality` | `.opencode/skills/revit-test-quality/SKILL.md` |
| `mcp-setup` | `.opencode/skills/mcp-setup/SKILL.md` |

Вики: `.opencode/wiki/mcp-code-graph.md` (граф кода), `mcp-servers.md` (остальные).

## 2. MCP — установка

### `revit-mcp` — готов, ничего ставить не надо

- Сервер: `D:\ПлагиныРевит\RevitMcp\mcp-server\server.py`, Python 3.12:
  `C:\Users\Strakhov\AppData\Local\Programs\Python\Python312\python.exe`.
- В `HeatLossRevit4/opencode.json` уже прописан (починено 09.10.2026: диск `D:`, Python312).

### `netwright` — готов

- Бинарник: `D:\ПлагиныРевит\Netwright\netwright.exe`, прописан в том же `opencode.json`.

### `roslyn_graph` — УСТАНОВИТЬ (граф C#, основной инструмент аудита)

```powershell
$env:Path = 'D:\Tools\dotnet;' + $env:Path
dotnet tool install -g RoslynCodeLens.Mcp   # было 2.18.1, MIT
# exe появится: C:\Users\Strakhov\.dotnet\tools\roslyn-codelens-mcp.exe
```

Конфиг (`agent-skills/opencode.json`, блок `mcp.roslyn-graph`) — **исправить `E:` на `D:`**:

```json
"roslyn-graph": {
  "type": "local",
  "command": ["C:\\Users\\Strakhov\\.dotnet\\tools\\roslyn-codelens-mcp.exe",
              "D:\\ПлагиныРевит\\HeatLossRevit4\\HeatLossRevit.sln"],
  "cwd": "D:\\ПлагиныРевит\\HeatLossRevit4",
  "enabled": true, "timeout": 180000,
  "environment": { "ROSLYN_CODELENS_OPEN_PROJECT_TIMEOUT_SECONDS": "600" }
}
```

Холодный старт открывает решение 30–60 с; в ответах Calling: `limit`, громоздкое — в файл.

### `astgrep` — УСТАНОВИТЬ (только структурные правки; для поиска смысла бесполезен)

1. Node.js LTS: https://nodejs.org → `node --version` должен отвечать.
2. `npm install -g ast-grep-mcp` (было 0.0.2, MIT).
3. Конфиг (`agent-skills/opencode.json`, блок `mcp.ast-grep`) — **исправить `E:` на `D:`**,
   обязателен `AST_GREP_BIN` (иначе `spawn EINVAL`), пути — только относительные от `cwd`,
   язык C# — `cs`/`csharp`.

## 3. Застарелые пути `E:` — исправить перед аудитом

Диска `E:` на машине нет (пустой). Заменить `E:\ПлагиныРевит` → `D:\ПлагиныРевит`:

- `agent-skills/opencode.json`: `roslyn-graph` (command, cwd), `ast-grep` (cwd),
  `filesystem`/`git` (`E:\ПлагиныРевит\HeatEnergyCalculator` — проверить, жив ли этот путь вообще).
- `.opencode/wiki/mcp-code-graph.md`: пример `cordis.patch.yml` (args, cwd).
- DSH-профиль `C:\Users\Strakhov\.dsh\profiles\web\cordis.patch.yml` (если аудит идёт из DSH):
  перед правкой — бэкап `cordis.patch.yml.bak-<дата>`, серверы добавлять только через `insert:`.

## 4. Проверка готовности (чеклист)

- [ ] `skill code-audit-graph|architect-review|solid-principles|software-architecture|revit-test-quality` читаются.
- [ ] `roslyn_graph`: `list_solutions` → `HeatLossRevit.sln`, 25 проектов, `status: ready`.
- [ ] `astgrep`: `ast_grep_version` → ответ; пробный `find_references` — ссылки с файлами/строками.
- [ ] `revit-mcp`/`netwright` стартуют из `HeatLossRevit4/opencode.json`.
- [ ] `E:` не встречается ни в одном активном конфиге (`grep -r "E:\\\\ПлагиныРевит" --include=*.json --include=*.md --include=*.yml`).
