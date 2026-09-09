---
name: dwg-text-parsing
description: Извлечение текстов и таблиц из DWG через BimExtractor (ACadSharp). Use when reading DWG files, extracting spec tables from drawings, diagnosing zombie/СПДС objects, or deciding whether DWG can supply specification data vs PDF/xlsx.
---

# DWG: тексты — да, спецификации — почти нет

Репозиторий: `E:\ПлагиныРевит\DwgParser` (BimExtractor, C#/.NET 8 + ACadSharp).
Вызов из DesignBase: `src/designbase/ingest/dwg_texts.py` → CLI `BimExtractor.Cli.dll <file.dwg> -o out.json --dump-json`,
кэш `output/dwg_texts/<sha16>.v4.json` (`CACHE_VER` v4 = Space + СПДС-счётчики).

## Что реально работает (кейс «Санпропускник», 13 DWG, 2026-09-08)

| Даёт | Не даёт |
|---|---|
| **Полные тексты**: 18 152 объектов по 13 файлам (АР 4 706, ТС 5 748, ВК 2 008) — поиск, верификация, чанки kind=dwg_text | **Спецификации как структуру**: 67 spec-таблиц, все дефектные |
| Счётчики диагностики: `counts[0] = {file, texts, tables, spds}` | Таблицы СПДС: `SPDSTABLE2`/`SPDSSTANDARDPART` — текст ячеек недоступен без декодера/ODA/COM |

- spec-таблицы BimExtractor: колонки — корзины по X (`col_46`, `col_145`), строки примешивают
  титул-блок → 116 «строк» ВК = мусор. Не использовать как источник позиций.
- `dwg_spec_tables.py` берёт только текстовые сетки КМ/КЖ (слои `Tablica`, `КР_9_Форматы_Таблицы`…).
  На спеках оборудования — 0.
- `АС.dwg`: 1 379 zombie-объектов (СПДС без Object Enabler) — текст недоступен.
- COM (AutoCAD): медленный (3/13 за разумное время), фильтр выбора считал всё подряд — чинить фильтр,
  если использовать.

## Decision tree для спек объекта

1. Спека xlsx/doc исходника → `spec_parser` / `spec_office` (лучший источник).
2. PDF-спека → скил `pdf-spec-parsing` (текстовый слой; anchor-парсер; find_tables; vision).
3. DWG → только текстовый поиск/верификация (BimExtractor texts), не структурные таблицы.
4. КМ/КЖ-текстовые сетки в DWG → `dwg_spec_tables` (единственный случай, где DWG даёт таблицу).

## Правила

- Оригиналы DWG read-only; для COM копировать в рабочую папку (кейс: `COM-копии\`, 13 файлов).
- При изменении формата дампа — поднимать `CACHE_VER` (иначе кэш врёт).
- `building`/`method`/`source_path` — обязательно в metadata чанков (provenance).
- Тесты BimExtractor: `dotnet test` (старое решение 14/14, BimExtractor 87/87).
- Сопутствующий скил: `pdf-spec-parsing` (когда DWG не даёт спеку — PDF даёт).
