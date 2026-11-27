---
name: qwen-browser-bridge
description: >
  Подключение к Qwen (chat.qwen.ai) в УЖЕ ОТКРЫТОМ браузере пользователя (Edge) через MCP
  `browse`/relay в Code Mode (`tools.browse.*` внутри `execute`). Отправить промпт в существующий
  чат, дождаться ответа, забрать полный текст. USE FOR: «спросить Qwen», «отправить в открытый
  Qwen», задачи в уже открытой вкладке браузера, когда нужен ответ облачной модели без LocalAssitent
  и без qwen_bridge.py. DO NOT USE FOR: in-app browser (`browser.tabs.*`), dev-pipeline qwen_bridge.py
  (FILE:-блоки), LocalAssitent/Selenium порт 9222, Алису (alice-browser-bridge), локальные задачи.
license: MIT
---

# Qwen Browser Bridge (MCP `browse`)

Qwen живёт в браузере пользователя (Edge, расширение `browse`), а не в MCP-сервере.
Связь идёт через **relay MCP `browse`** и доступна **только внутри Code Mode** через `execute`.

Это тот же протокол, что `alice-browser-bridge`, но для `chat.qwen.ai`.

## Ключевые правила (читать первыми)

1. **НЕ использовать namespace `browser`** (`browser.tabs.open`, `browser.click`, ...).
   Это in-app browser десктопа с табами `tab_<uuid>` — он НЕ подключён к вкладкам Edge пользователя.
   Работают только `tools.browse.*` из `execute` (tab — числовой или именованный `qwen-ui`).
2. Chat ID из URL (`37870988-6724-4b16-96ef-db2e9ea8059c`) — **не tab ID**.
   Tab ID берётся из `tabs`/`navigate`; удобно закрепить имя `qwen-ui`.
3. Если `status` вернул `connected=false` / `pairingState=paired-offline` — передать
   пользователю `nextStep` и ждать; НЕ запускать retry-цикл и НЕ поднимать relay самовольно.
4. **Не путать interim-загрузку с выходом.** Сразу после `navigate` страница на долю секунды
   показывает «Войти / Зарегистрироваться», пока не подгрузятся чаты. Сначала
   `wait_for({tab, selector:'textarea.message-input-textarea', state:'visible'})`, затем
   `snapshot` заново. Только если после полной загрузки всё ещё нет поля ввода и виден вход —
   вызвать `handoff` и ждать: агенту нельзя логиниться, проходить 2FA и капчу.
   Не отправлять промпт в неавторизованную вкладку — ответ не придёт.

## Проверка связи и вкладки

```js
const s = await tools.browse.status({});
const t = await tools.browse.tabs({ action: 'list' });
return {
  connected: s.connected,
  pairingState: s.pairingState,
  relay: s.relay?.endpoint,
  qwenTab: t.tabs.find(x => x.id === 'qwen-ui' || x.url.includes('chat.qwen.ai'))
};
```

Ожидаемо: `connected=true`, `pairingState=connected`, relay `http://127.0.0.1:19988`,
браузер `edge-this-computer` (extension origin
`chrome-extension://mfnicocicmmlkpjnaffgihfjhdgjkdjg`).

**Вариант A — вкладка уже открыта:** взять `tab` из `tabs.list` (поле `tab` или `id`).
`lent=true` — вкладка пользователя: использовать по просьбе, не закрывать.

**Вариант B — вкладки нет:** открыть именованную устойчивую вкладку:

```js
const r = await tools.browse.tabs({
  action: 'new',
  id: 'qwen-ui',
  url: 'https://chat.qwen.ai/c/37870988-6724-4b16-96ef-db2e9ea8059c',
  allowedOrigins: ['chat.qwen.ai'],
  keepOpen: true,          // не дать idle-cleanup закрыть чат
  group: 'ai-bridge'
});
// r.tab — числовой ID; дальше везде передавать tab: 'qwen-ui' (или r.tab)
```

`navigate({url})` без `tab` тоже открывает вкладку, но она закроется idle-cleanup —
для чата предпочтительнее `tabs new` с `id` + `keepOpen`.

## Рабочий цикл

1. `status` → `tabs list` → `tab` (`qwen-ui`) → `wait_for` на textarea → проверить вход.
2. `snapshot({tab, interactive:true})` → refs (`e6`, `e7`, …).
3. `fill({tab, ref:'e…', value:'…'})` — поле ввода в Qwen:
   `textarea.message-input-textarea` (placeholder «Спросить Qwen»).
   Селектор допустим, но ref из свежего snapshot надёжнее.
4. Отправить: `press({tab, ref:'e…', key:'Enter'})` либо
   `click({tab, ref:'e7'})` (кнопка «Отправить»).
5. Ждать: `wait_for({tab, ms:300000})` и/или `snapshot({tab, find:'…', delta:true})`.
   Не busy-loop: цикл ожидания — `wait_for` по 300 с.
6. Забрать ответ:
   `eval({tab, expression:'document.body.innerText.slice(-8000)'})`.
   Если ответ свёрнут — `click({tab, selector:'text=Развернуть'})`, затем `innerText` заново.
7. `snapshot` заново после каждого ответа: refs меняются, старые переиспользовать нельзя.
8. Закрывать только свои вкладки: `tabs({action:'close', tab:'qwen-ui'})`
   (если она не `keepOpen` и не нужна дальше).

## Частые ошибки

| Симптом | Причина | Лечение |
|---|---|---|
| `browser.tabs.list` пуст / нет вкладки Edge | не тот namespace | `tools.browse.*` через `execute` |
| «Войти / Зарегистрироваться» сразу после open | страница ещё грузится | `wait_for` textarea + `snapshot` заново |
| «Войти / Зарегистрироваться» после загрузки | нет авторизации | `handoff`, ждать входа пользователя |
| `Unknown snapshot ref` | страница обновилась | `snapshot` заново |
| `tab is gone` | вкладку закрыл idle-cleanup | `tabs new` с `id:'qwen-ui', keepOpen:true` |
| Ответ не приходит | промпт отправлен до входа или после редиректа | проверить `snapshot`/`eval` URL, повторить после логина |
| `navigation refused` | адрес вне `allowedOrigins` | открывать с `allowedOrigins:['chat.qwen.ai']` |
| Пустой/обрезанный ответ | свёрнут или ещё генерируется | «Развернуть» + повторное `innerText` |

## Отличие от других Qwen-скилов

| Скил | Механизм | Когда |
|---|---|---|
| **qwen-browser-bridge** (этот) | MCP `browse` relay → открытый Edge | «спросить в открытом браузере», живой чат |
| `pipeline-qwen-worker` | `qwen_bridge.py`, FILE:-блоки | конвейер dev-pipeline, генерация файлов |
| `pipeline-browser-bridge` | LocalAssitent/Selenium, порт 9222 | события `browser_task` конвейера |
| `cloud-ai-bridge` | LocalAssitent, загрузка файлов | большой контекст, merge_docs |

## Связанные материалы

- `alice-browser-bridge` — тот же протокол для Алисы (вход в Яндекс.Диск и т.п.).
- `D:\ПлагиныРевит\agent-skills\.opencode\skills\alice-browser-bridge\SKILL.md`
- HTTP-relay: `http://127.0.0.1:19988`; при остановке — `browse status` /
  `browse session list` в PowerShell; `browse serve` поднимать только по явной просьбе.
