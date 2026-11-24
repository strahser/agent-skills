---
name: alice-browser-bridge
description: >
  Подключение к Алисе AI для бизнеса (alice.yandex.ru) через MCP browse/relay в Code Mode:
  отправить задачу в существующий чат, дождаться ответа, забрать полный текст, при необходимости
  подтвердить доступ к Яндекс.Диску («Разрешить один раз»). USE FOR: задачи vision/OCR по PDF
  и чертежам, поиск/загрузка файлов на Диске, консультации Алисы по нормам и проектам, когда
  нужен её доступ к браузеру/Диску. DO NOT USE FOR: облачные LLM через LocalAssitent
  (cloud-ai-bridge / pipeline-browser-bridge), локальные задачи, которые ассистент решает сам.
license: MIT
---

# Alice Browser Bridge (MCP `browse`)

Алиса живёт в браузере пользователя (Edge, расширение `browse`), а не в MCP-сервере.
Связь идёт через **relay MCP `browse`** и доступна **только внутри Code Mode** через `execute`.

## Ключевые правила (читать первыми)

1. **Не использовать namespace `browser`** (инструменты `browser.tabs.*`, `browser.click` и т.п.).
   Это in-app browser десктопа с табами `tab_<uuid>` — он НЕ подключён к сессии Алисы.
   Работают только `tools.browse.*` (tab — числовой, например `789898619`).
2. Chat ID из URL (например `01a1da1b-0b63-4000-9aab-b85ae418d103`) — **не tab ID**.
   Tab ID берётся из `navigate`/`tabs.list`.
3. Если `status` вернул `connected=false` / `pairingState=paired-offline` — передать
   пользователю `nextStep` и ждать, не запускать retry-цикл.
4. Кнопку «Разрешить один раз» на Диск подтверждать в пределах сессии — нажимать по мере появления.

## Проверка связи

```js
const s = await tools.browse.status({});
return {connected:s.connected, extension:s.extension?.connected,
        relay:s.relay?.endpoint, tabs:s.tabs.map(t=>({tab:t.tab,url:t.url,lent:t.lent}))};
```

Ожидаемо: `connected=true`, `pairingState=connected`, relay `http://127.0.0.1:19988`,
extension origin `chrome-extension://mfnicocicmmlkpjnaffgihfjhdgjkdjg`, browser `edge-this-computer`.

Если relay остановлен — сначала `browse status` / `browse session list` в PowerShell;
`browse serve` поднимать только если пользователь явно попросил (foreground-процесс).

## Подключение к нужному чату

**Вариант A — вкладка уже открыта:**

```js
const list = await tools.browse.tabs({action:'list'});
// найти tab, у которого url содержит alice.yandex.ru/chat/<chat-id>
// tab из поля tab; lent=true — пользовательская вкладка, не закрывать без просьбы
```

**Вариант B — вкладки нет:**

```js
const t = await tools.browse.navigate({
  url:'https://alice.yandex.ru/chat/01a1da1b-0b63-4000-9aab-b85ae418d103/?utm_source=global-bar360'
});   // вернёт {tab}; Query-параметр можно оставить
```

## Рабочий цикл

1. `status` → `navigate`/`tabs.list` → числовой `tab`.
2. `snapshot({tab, interactive:true})` → refs (`e12`, `e78`, …).
3. `fill({tab, ref:'e…', value:'…'})`.
4. `press({tab, ref:'e…', key:'Enter'})`.
5. `wait_for({tab, ms:300000})` и/или `eval({tab, expression:'document.body.innerText.slice(-N)'})`.
6. `snapshot` заново — refs меняются после каждого ответа, старые переиспользовать нельзя.
7. `tabs({action:'close', tab})` — закрывать только свои вкладки.

Медленные vision-задачи (21+ стр. PDF) идут 20–60 мин; цикл ожидания — `wait_for` по 300 с,
не busy-loop. Если ответ свёрнут — `click({tab, selector:'text=Развернуть'})`, затем `innerText`.

## Доступ к Яндекс.Диску

- Если Алиса просит разрешение: `snapshot({tab, interactive:true, find:'Разрешить один раз'})`
  → `click({tab, ref:...})`; повторять по мере появления.
- Файлы LOCAL ПК в `browse.upload` не попадают (file roots — только temp на C:); рабочий путь:
  загрузить файл на Диск через Yandex API (токен `WRITE_CIMRUS` из локального инвентаря,
  в чат/репозиторий не писать) и дать Алисе путь `disk:/tasks/...` в промпте.

## Частые ошибки

| Симптом | Причина | Лечение |
|---|---|---|
| `Unknown snapshot ref: e78` | страница обновилась | `snapshot` заново |
| `tab is gone` | вкладка закрылась idle-cleanup | `navigate` без `tab`, новый ID |
| `upload needs a ref or selector` | нет `input[type=file]` | использовать Диск, не upload |
| `outside the file roots` | файл вне temp | не обходить, использовать Диск |
| Пустой ответ | свёрнут | клик «Развернуть» |
| `browser.tabs.list` пуст | не тот namespace | `tools.browse.*` через `execute` |

## Связанные материалы

- Wiki репозитория: `.opencode/wiki/alice-browser-bridge.md` — подробный рабочий протокол,
  включая подтверждение бизнес-аккаунта и нюансы snapshot.
- Инструкция для агента в DesignBase:
  `d:\ПлагиныРевит\DesignBase\output\nok_blind\ALICE-BROWSER-ACCESS-INSTRUCTION.md`.
- Секреты: `D:\ПлагиныРевит\YaDiskDownloader\Yandex API.txt` (локально, в `.gitignore`);
  в git — только `docs/SECRETS-INVENTORY.md`.
