# Telegram-мост к opencode

Удалённое управление агентом opencode из Telegram вынесено в отдельный проект:

**https://github.com/strahser/OpencodeTelegram**

Локальная копия: `e:\ПлагиныРевит\OpencodeTelegram\`

## Что умеет

- Задания свободным текстом, общение с агентом
- Подтверждение разрешений из чата (`YES` / `ALWAYS` / `NO`)
- Сессии (`/new /sessions /switch`), модели, диффы, shell
- Бесплатные модели opencode Zen, подписка Go не нужна

## Как использовать

1. В каталоге `OpencodeTelegram` запустить `scripts\enable-telegram.cmd`,
   ввести токен бота (`@BotFather`) и chat id (`@userinfobot`).
2. Запустить хаб: `scripts\run-telegram-hub.cmd`
   (`opencode serve --port 4096`) или `opencode` в том же каталоге.
3. Первой командой в чате создать сессию (`/new`).

Подробности — в `README.md` проекта OpencodeTelegram.

## История

Мост разработан и отлажен в этом репозитории (миссия `M-TG-1` в
`.opencode/project.db`): замена Go-модели на Zen-free, `ask`-разрешения,
патчи плагина (русские отчёты, дедупликация `🔐`). Затем перенесён
в отдельный репозиторий, здесь оставлена только эта ссылка.
Известный апстрим-баг: `bash`-тул opencode 1.18.x падает на Windows/serve
(`H.loadWebAssemblyModule`, anomalyco/opencode#40789).
