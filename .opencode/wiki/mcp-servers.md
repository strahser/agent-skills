# MCP Servers

> Браузерные и UI-серверы. **Анализ кода (граф C#)** — на отдельной странице:
> [MCP графа кода](mcp-code-graph.md) (`roslyn_graph`, `astgrep`).

## opencode-browser

Браузерная автоматизация на Playwright.

**Установка:**
```bash
pip install playwright
python -m playwright install chromium
```

**Инструменты (30):** navigate, click, fill, screenshot, snapshot, execute_js, console/network логи.

**Конфиг (глобальный `~/.config/opencode/opencode.jsonc` или проект `.opencode/opencode.json`):**
```json
{
  "mcp": {
    "opencode-browser": {
      "type": "local",
      "command": ["python", "C:\\path\\to\\browser_mcp.py"],
      "enabled": true,
      "environment": {
        "MCP_BROWSER_HEADLESS": "true",
        "MCP_BROWSER_TIMEOUT": "30000"
      }
    }
  }
}
```

## Playwright

Запуск Playwright тестов.

**Конфиг:**
```json
{
  "mcp": {
    "playwright": {
      "type": "local",
      "command": ["python", "-m", "playwright"],
      "enabled": true
    }
  }
}
```

## threejs-devtools (planned)

Инспекция Three.js сцены. Пакет пока недоступен в npm — добавьте, когда появится.

```json
{
  "mcp": {
    "threejs-devtools": {
      "type": "local",
      "command": ["npx", "--yes", "threejs-devtools"],
      "enabled": true
    }
  }
}
```

## r3f-mcp (planned)

Генерация React Three Fiber компонентов. Пакет пока недоступен в npm.

```json
{
  "mcp": {
    "r3f-mcp": {
      "type": "local",
      "command": ["npx", "--yes", "r3f-mcp"],
      "enabled": true
    }
  }
}
```
