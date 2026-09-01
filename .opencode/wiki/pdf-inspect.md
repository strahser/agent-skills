# Инспекция PDF без GUI (PyMuPDF → PNG → Read)

Как агенту посмотреть глазами PDF-артефакт (бланки, отчёты, чертежи), когда модель не
принимает PDF на вход: рендерим страницы в PNG и читаем их обычным Read (он умеет картинки).

## Инструмент

PyMuPDF (import `fitz`, новое имя `pymupdf`). Установлен в окружении DesignBase
(`D:\Projects\DesignBase`, `requirements.txt`: `PyMuPDF>=1.24`) — работает системным
`python`. Если нет: `python -m pip install pymupdf`.

## Приём (проверено 2026-08-24, AHUCalculator BL-1)

```python
import pymupdf  # или import fitz (deprecated-псевдоним, warning)

doc = pymupdf.open(r"path\file.pdf")
print("pages:", len(doc))
for i in range(min(3, len(doc))):
    pix = doc[i].get_pixmap(dpi=150)          # 150 dpi ≈ читаемый A4 (~1240x1755)
    pix.save(rf"C:\...\temp\page{i+1}.png")
    print(i + 1, pix.width, pix.height, "images:", len(doc[i].get_images(full=True)))
```

Затем `Read` на PNG — модель видит страницу картинкой.

- `get_images(full=True)` — быстрый счётчик встроенных растров (проверка «иконки/диаграммы
  реально попали в PDF» без рендера).
- `dpi=150` — компромисс размер/читаемость; для мелких подписей брать 200–300.

## Грабли

- В cmd.exe НЕ инлайнить многострочный `python -c "..."` — кавычки ломаются молча
  (команда завершается без вывода). Писать временный .py файл и запускать его.
- `import fitz` печатает deprecation-warning — не пугаться, это тот же пакет.
- Консоль Windows портит кириллицу в путях/выводе: `python -X utf8` +
  `[Console]::OutputEncoding=[Text.Encoding]::UTF8` в PowerShell.

## Где применялось

- AHUCalculator: визуальная проверка PDF-бланка ПВУ (иконки секций) —
  `artifacts\revit-bridge-20260823\АХВ_отчёт_ПВУ.pdf`, рендер стр.1 подтвердил строку
  иконок над плашками (коммит 39cde76).
