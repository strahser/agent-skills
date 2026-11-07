---
name: project-hygiene
description: >
  Clean up the workspace after a work block: worker sessions, git worktrees/copies, test artifacts
  (rvt/png/TestResults/TestOutput), and the plans repository structure (active vs _archive).
  USE FOR: end-of-block cleanup, stale worktree/session removal, keeping PLAN/STATUS/_archive tidy,
  deciding what may be deleted safely.
  DO NOT USE FOR: deleting user files or unmerged work; changing project behavior or tests.
license: MIT
---

# Гигиена рабочего места и планов

**Принцип:** после принятого блока на машине не должно оставаться ничего, что понадобится
только для этого блока. Чистое дерево — это не «красиво», это условие следующего блока:
следующий агент не должен разбирать чужие копии, сессии и артефакты.

## 1. Сессии и процессы

- После приёмки блока рабочая сессия больше не нужна: удалить её состояние и лог.
  Состояния — `%TEMP%\<prefix>-sessions\<title>.state` (`HL4` → `hl4-sessions`); логи — `%TEMP%\<title>.log`.
- Если CLI поддерживает удаление сессий — `opencode session delete <id>` (не удалять сессию
  планировщика и текущую).
- `Get-Process Revit` — после живых тестов не должно быть «зависшего» экземпляра. Удалять только
  тестовый экземпляр (запущенный тестом), не Revit пользователя.
- Не оставлять detached `cmd`/`powershell`, запущенные `start_session.ps1`: проверить по `pid`
  из state-файла.

## 2. Рабочие копии и worktree

Правило проекта: **одна сессия — одна копия и одна ветка**. После блока копия удаляется.

Перед удалением — три проверки:

```powershell
git -C <copy> status --short                 # нет незакоммиченных правок
git -C <copy> log origin/<branch>..HEAD      # нет неотправленных коммитов (пусто)
git -C <copy> merge-base --is-ancestor HEAD origin/<target>; $LASTEXITCODE  # 0 = влита
```

- Ветка должна быть **запушена** (`git ls-remote --heads origin <branch>`) или слита.
- Удаление: `git worktree remove <path>`; при блокировке — `--force` **только** после проверок выше.
- Затем `git worktree prune` и `git worktree list` — должен остаться только активный worktree.
- Диагностические копии `bin` (`D:\temp\...`) удалять сразу после проверки — они не нужны.
- **Живые тесты — из `D:\temp\...` или основного пути `D:\Projects\HeatLossRevit4`**, не из
  `D:\Projects\HL4-*`: в свежем worktree инжектор падает `Attempted to write protected memory`
  (см. `revit-test-runner`). Поэтому тестовые worktree лучше сразу создавать в `D:\temp`.

## 3. Артефакты тестов

- `HL_TEST_SAVE_RVT=0` — `.rvt`/`.png` не пишутся в репозиторий; OutputDir — `%TEMP%`/`D:\temp`.
- Удалять из рабочей копии перед коммитом/после блока:
  `bin\**\TestResults`, `TestOutput`, `*.trx`, `*.html`, `*.rvt`, `*.png`, `*.log` тестов.
- `git status --ignored` — смотреть глазами: «ignored» не значит «оставить навсегда».
- Не коммитить `bin/`, `obj/`, `TestResults/`, `TestOutput/`, `*.rvt`, `*.rfa`, `*.png` (кроме эталонов).

## 4. Структура репозитория планов

- **Корень** — только активное: `PLAN.md`, `STATUS.md`, активный `STRUCTURE-*`, активные
  `PROMPT-*`/`REPORT-*`/`TASK-*` (пока блок не закрыт).
- **Закрытое** — `git mv` (история сохраняется) в:
  - `_archive/prompts/` — промпты рабочих,
  - `_archive/reports/` — отчёты,
  - `_archive/plans/` — закрытые планы,
  - `_archive/verdicts/` — вердикты планировщика,
  - `_archive/tasks/` — закрытые задания.
- `_archive/README.md` — индекс архива; при переносе добавить строку.
- `modules/` — карточки/подкарточки; `_reference/` — реестры и эталоны; `Tools/` — скрипты.
- **Не удалять** `.reload/`, `Resume/`, пользовательские untracked-файлы: сначала `git status`,
  потом решение (спросить владельца, если не ваше).
- Один блок = один коммит; после блока обновить `STATUS.md` и `STRUCTURE`/план.

## 5. Чек-лист конца блока

- [ ] ветка запушена (`git ls-remote`), sha совпадает;
- [ ] вердикт записан в `_archive/verdicts/`;
- [ ] `STATUS.md` обновлён, `STRUCTURE`/план — тоже;
- [ ] закрытые `PROMPT`/`REPORT`/`TASK` перенесены в `_archive/` через `git mv`;
- [ ] worktree/копия удалены, `git worktree list` чист;
- [ ] state-файл и лог сессии удалены; `Revit.exe` не висит;
- [ ] `TestResults`/`TestOutput`/`*.rvt`/`*.png` удалены, `git status` чистый (кроме пользовательских);
- [ ] в планах корень не содержит закрытых артефактов.

**Запрещено:** удалять чужую/незапушенную работу, ветку без проверки, пользовательские файлы;
«чистить» историю git (`reset --hard`, `push --force`) ради гигиены.
