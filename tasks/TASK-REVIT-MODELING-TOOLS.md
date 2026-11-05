# План: насыщение RevitMcp плагина инструментами моделирования

**Статус:** Фаза 1 реализована (коммиты `dc145fc`, `c516592`); Фаза 2 реализована (коммит `6dad1d3`); Фазы 3–5 — в плане.
**Репозиторий:** `d:\ПлагиныРевит\RevitMcp` (Revit 2024, net48, MCP bridge).
**Дата:** 2026-11-03.
**Связано:** `TASK-BIM-REVIT-CORE.md` (ядро RevitBimCore), `DwgParser/AccCore` (DWG-писатель).

---

## 1. Цель

Сейчас RevitMcp.Addin умеет: Ping, Open, Close, DocInfo, Rooms, Levels, RunHeatLoss, ListHeatLossCommands. Для моделирования этого недостаточно — агент не может создавать/изменять элементы.

Нужно добавить набор **моделирующих инструментов**, доступных агенту через MCP, чтобы он мог:
- строить геометрию (стены, перекрытия, кровли, проёмы);
- размещать семейства (окна, двери, оборудование);
- управлять уровнями, осями, типами;
- редактировать параметры и геометрию;
- экспортировать/импортировать данные (связь с RevitBimCore JSON и AccCore DWG).

Все инструменты должны следовать двухфазному контракту (план → подтверждение → выполнение) и возвращать структурированный JSON.

## 2. Принципы

1. **Атомарность**: один инструмент = одно действие (или явно обозначенная batch-операция).
2. **Идемпотентность**: повторный вызов с тем же `external_id` не дублирует сущности (через `Comments` / shared param `BIM_Core_ExternalId`).
3. **Безопасность**: dry-run (план без выполнения), бэкап перед записью (Revit `Document.SaveAs` копия или `.rvt` копия), откат транзакцией.
4. **Структурированный ответ**: `{ ok, created_ids[], warnings[], diagnostics[] }`.
5. **Единицы**: вход в мм/градусах, конвертация внутри.
6. **Главный поток**: все вызовы Revit API — через `ExternalEvent` (как сейчас).
7. **Связь с ядром**: инструменты моделирования должны использовать `RevitBimCore.Revit` операции (IOperation), а не дублировать логику. RevitMcp.Addin ссылается на `RevitBimCore.Revit.dll`.

## 3. Категории и инструменты

### 3.1. Документ и уровни

| Инструмент | Вход | Выход | Примечание |
|---|---|---|---|
| `create_level` | name, elevation_mm | level_id | Идемпотентно по name/external_id |
| `list_levels` | — | [{id,name,elevation_ft}] | уже есть частично (Levels) |
| `create_grid` | name, start_mm, end_mm (или arc) | grid_id | прямолинейная/дуговая |
| `list_grids` | — | [...] | |
| `set_active_view` | view_name/id | ok | |
| `create_view_3d` | name, bbox? | view_id | |

### 3.2. Типы стен

| Инструмент | Вход | Выход |
|---|---|---|
| `list_wall_types` | — | [{id,name,width_mm,structure}] |
| `create_wall_type` | name, layers[{function,material,thickness_mm}] | type_id |
| `duplicate_wall_type` | source_name, new_name | type_id |

### 3.3. Стены

| Инструмент | Вход | Выход |
|---|---|---|
| `create_wall` | type, base_level, top_level?, geometry{line/arc}, flip, external_id? | wall_id |
| `create_wall_by_points` | type, base_level, points[[x,y],...], height_mm | wall_ids[] |
| `modify_wall` | wall_id, new_geometry?, new_height_mm?, flip? | ok |
| `delete_wall` | wall_id | ok |
| `get_wall` | wall_id | {type,levels,geometry,length_mm,height_mm} |

### 3.4. Проёмы и семейства

| Инструмент | Вход | Выход |
|---|---|---|
| `cut_opening` | host_wall_id, width_mm, height_mm, sill_mm, position_mm | opening_id |
| `place_door` | family, type, host_wall_id, position_mm, flip? | instance_id |
| `place_window` | family, type, host_wall_id, position_mm | instance_id |
| `place_family` | family, type, location_mm, rotation_deg, host? | instance_id |
| `load_family` | rfa_path | family_name, types[] |
| `list_families` | category? | [...] |
| `set_instance_param` | instance_id, param_name, value | ok |
| `get_instance_params` | instance_id | {params} |

### 3.5. Перекрытия, кровли, потолки

| Инструмент | Вход | Выход |
|---|---|---|
| `create_floor` | level_id, boundary[[x,y],...], floor_type? | floor_id |
| `create_roof` | host_level?, boundary, roof_type? | roof_id |
| `create_ceiling` | room_id/level, boundary, ceiling_type? | ceiling_id |

### 3.6. Помещения и зоны

| Инструмент | Вход | Выход |
|---|---|---|
| `create_room` | level_id, location_mm, number, name | room_id |
| `list_rooms` | level? | [...] (уже есть Rooms) |
| `set_room_param` | room_id, param, value | ok |

### 3.7. Редактирование геометрии

| Инструмент | Вход | Выход |
|---|---|---|
| `move_element` | element_id, delta_mm[x,y,z] | ok |
| `rotate_element` | element_id, center_mm, angle_deg | ok |
| `copy_element` | element_id, delta_mm | new_id |
| `mirror_element` | element_id, axis | new_id |
| `delete_elements` | ids[] | {deleted, failed} |

### 3.8. Запросы и измерения

| Инструмент | Вход | Выход |
|---|---|---|
| `get_element` | id | {type, category, params, bbox, location} |
| `query_elements` | filters{category,type,level,param=value} | [{id,...}] |
| `measure_distance` | id1, id2 | distance_mm |
| `get_bounding_box` | id | {min,max} |
| `list_categories` | — | [...] |

### 3.9. Экспорт/импорт

| Инструмент | Вход | Выход |
|---|---|---|
| `export_to_json` | path?, scope (all/selected) | json_path, counts |
| `import_from_json` | path | {created, updated, errors} (через RevitBimCore) |
| `export_to_dwg` | path | ok (через AccCore/Revit export) |

### 3.10. Спецификации (расчёты) на основе шаблона

| Инструмент | Вход | Выход | Примечание |
|---|---|---|---|
| `list_schedules` | — | [{id,name,category,fields[]}] | список спецификаций в документе (в т.ч. из шаблона) |
| `get_schedule` | schedule_id | {name, fields, rows[], total_count} | чтение данных спецификации |
| `create_schedule` | category, name, fields[], filters?, grouping?, sorting? | schedule_id | создание новой спецификации по шаблону полей |
| `duplicate_schedule` | source_id, new_name | schedule_id | копирование существующей (включая из шаблона) |
| `modify_schedule` | schedule_id, fields?, filters?, grouping?, sorting? | ok | изменение полей/фильтров/группировки |
| `export_schedule` | schedule_id, format (json/csv/xlsx), path? | file_path | выгрузка для расчётов/DesignBase |
| `refresh_schedule` | schedule_id? (all если пусто) | ok | принудительное обновление |

Принцип: спецификации создаются **на основе текущих в шаблоне** (.rte) — дублируем существующую спецификацию с нужными полями/фильтрами, а не строим с нуля. Шаблонные спецификации (например, «Спецификация дверей», «Ведомость стен») служат эталоном полей и форматирования.

### 3.11. Безопасность

| Инструмент | Вход | Выход |
|---|---|---|
| `dry_run` | operation + args | plan (без выполнения) |
| `undo_last` | — | ok |
| `backup_document` | path? | backup_path |

## 4. Фазы реализации

### Фаза 1 — MVP (моделирование стен/уровней/проёмов)
- `create_level`, `list_levels`, `create_wall_type`, `list_wall_types`, `create_wall`, `cut_opening`, `place_window`/`place_door`, `get_element`, `query_elements`, `delete_elements`.
- Использовать `RevitBimCore.Revit` операции (IOperation).
- Добавить в McpOps + McpHttpServer маршруты + MCP tool definitions в server.py.

### Фаза 2 — Геометрия и редактирование
- `create_floor`, `create_roof`, `create_ceiling`, `create_grid`, `move/rotate/copy/mirror`.

### Фаза 3 — Семейства и параметры
- `load_family`, `place_family`, `set_instance_param`, `get_instance_params`, `list_families`.

### Фаза 4 — Помещения и экспорт/импорт + спецификации
- `create_room`, `export_to_json` (RevitBimCore), `import_from_json`.
- Спецификации (3.10): `list_schedules`, `get_schedule`, `create_schedule` (на основе шаблонных), `duplicate_schedule`, `modify_schedule`, `export_schedule`, `refresh_schedule`.

### Фаза 5 — Безопасность и UX
- `dry_run`, `undo_last`, `backup_document`, batch-операции.

## 5. Архитектура реализации

```
McpOps (RevitMcp.Addin)  --calls-->  RevitBimCore.Revit operations (IOperation)
                                      --uses-->  Revit API (Document, Transaction)
MCP server (server.py)    --HTTP-->   McpHttpServer --> McpHandler (ExternalEvent) --> McpOps
```

- Каждый новый инструмент: метод в `McpOps`, маршрут в `McpHttpServer`, обработчик в `McpHandler`, определение tool в `server.py`.
- Транзакции и единицы — через `RevitBimCore` (RevitTransactionRunner, RevitUnitConverter).
- Идемпотентность — через external id в `Comments` (MVP) / shared param (v2).

## 6. Решения по вопросам (утверждено владельцем 2026-11-03)

1. **Приоритет фаз**: Фаза 1 (стены/уровни/проёмы) — ок. Далее по порядку.
2. **Семейства (.rfa)**: хранить в репозитории через **Git LFS**. MVP-набор: окна и двери (базовые типы из шаблона).
3. **Экспорт/импорт JSON**: использовать `RevitBimCore.Json` (схема v1), чтобы связать с K1/M1.
4. **Безопасность**: dry-run — для batch-операций, импорта и деструктивных действий (удаление, массовое изменение). Для одиночных create — транзакция + откат достаточно; опциональный флаг `confirm` для критичных.
5. **MEP**: на этом этапе только АР (архитектура). MEP — позже, отдельной фазой.
6. **Версия Revit**: фокус на 2024.

### Дополнительно (по запросу владельца)

7. **Спецификации**: добавлена категория 3.10 — создание/чтение/экспорт спецификаций на основе существующих в шаблоне (.rte). Шаблонные спецификации служат эталоном полей и форматирования; новые создаются дублированием + изменением фильтров/группировки.

## 6.1. Открытые вопросы (остаются)

(нет — все вопросы закрыты владельцем)

## 7. Тестирование через фоновый Revit

Все инструменты моделирования тестируются **через RevitMcp bridge** против реального запущенного Revit 2024 (фоновый режим, без GUI-кликов):

- **Smoke-тест**: `RevitMcp/scripts/test_modeling.py` — создаёт уровень, тип стены, стену, проём, помещение, проверяет query/get/delete, спецификации.
- **Режимы**: `--readonly` (только чтение), `--create` (полный цикл создания).
- **Интеграционные тесты**: Nice3point.TUnit.Revit (запуск в Revit) — проверяют создание ожидаемых сущностей.
- **Юнит-тесты**: логика (валидация, маппинг) — без Revit, обычный TUnit/xUnit.
- **Регрессия**: повторный прогон с тем же JSON не создаёт дублей (идемпотентность).

## 8. Критерии приёмки Фазы 1

- [ ] Агент может создать уровень, тип стены, стену, проём (окно/дверь) через MCP.
- [ ] Повторный вызов с тем же external_id не дублирует.
- [ ] Ответ содержит created_ids и diagnostics.
- [ ] Транзакция откатывается при ошибке.
- [ ] Юнит-тесты логики (валидация) проходят без Revit.
- [ ] Документация обновлена (README RevitMcp).

---

**Примечание:** это план. После утверждения — реализация по фазам, с коммитами и пушами. Не начинаю код без вашего «ок».
