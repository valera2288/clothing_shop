"""Собирает docs/er_spec.md — исходные данные для ручного построения
ER-диаграмм в draw.io (диаграммы сами скрипт не рисует).

Запуск: python docs/tools/make_er_spec.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from schema_meta import ENTITIES, FIELDS, PB_TYPES, RELATIONS  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

SQL_TYPES = {"text": "TEXT", "number": "NUMERIC", "bool": "BOOLEAN", "date": "TEXT",
             "select": "TEXT", "relation": "TEXT", "url": "TEXT", "email": "TEXT",
             "password": "TEXT", "autodate": "TEXT", "file": "TEXT", "json": "JSON",
             "editor": "TEXT"}


def load_schema():
    with open(os.path.join(ROOT, "pocketbase", "pb_schema.json"), encoding="utf-8") as f:
        return {c["name"]: c for c in json.load(f)}


def field_rows(col):
    """Строки словаря данных по полям коллекции (без системных id, created, updated)."""
    rows = []
    for f in col["fields"]:
        if f["name"] in ("id", "created", "updated"):
            continue
        rows.append(f)
    return rows


def constraints(f, col_name, schema):
    c = []
    if f["type"] == "number":
        if f.get("required"):
            c.append("обязательное, ≠ 0")
        if f.get("min") is not None:
            c.append(f"от {int(f['min'])}")
        if f.get("max") is not None:
            c.append(f"до {int(f['max'])}")
        if f.get("onlyInt"):
            c.append("целое")
    elif f["type"] == "text":
        if f.get("required"):
            c.append("обязательное")
        if f.get("min"):
            c.append(f"от {f['min']} символов")
        if f.get("max"):
            c.append(f"до {f['max']} символов")
        if f.get("pattern"):
            c.append(f"шаблон {f['pattern']}")
    elif f["type"] == "select":
        c.append("обязательное" if f.get("required") else "необязательное")
        c.append("значения: " + ", ".join(f["values"]))
    elif f["type"] == "relation":
        c.append("обязательное" if f.get("required") else "необязательное")
        target = next((n for n, x in schema.items() if x["id"] == f["collectionId"]), "?")
        c.append(f"внешний ключ → {target}")
        if f.get("maxSelect", 1) > 1:
            c.append("несколько значений")
        if f.get("cascadeDelete"):
            c.append("каскадное удаление")
    elif f["type"] == "bool":
        c.append("по умолчанию false")
    elif f["type"] in ("date", "url", "email"):
        c.append("обязательное" if f.get("required") else "необязательное")
    for idx in schema[col_name].get("indexes", []):
        if "UNIQUE" not in idx.upper():
            continue
        cols = [x.strip().strip("`\"") for x in idx[idx.index("(") + 1: idx.rindex(")")].split(",")]
        if f["name"] in cols:
            if len(cols) == 1:
                c.append("уникальное")
            else:
                c.append("уникально вместе с: " + ", ".join(x for x in cols if x != f["name"]))
    return "; ".join(dict.fromkeys(c))


def main():
    schema = load_schema()
    out = ["# Исходные данные для ER-диаграмм (draw.io)\n",
           "Диаграммы строятся вручную в draw.io по этим таблицам. Файл создан скриптом "
           "`docs/tools/make_er_spec.py` из `pocketbase/pb_schema.json`.\n",
           "## Связи\n", "| Сущность A | Сущность B | Вид | Реализация | Смысл |", "|---|---|---|---|---|"]
    for a, b, kind, impl, why in RELATIONS:
        out.append(f"| {a} | {b} | {kind} | {impl} | {why} |")
    out.append("\n## Логическая модель: сущности и атрибуты\n")
    for name, title, purpose in ENTITIES:
        col = schema[name]
        out.append(f"### {title} (`{name}`)\n\n{purpose}\n")
        out.append("| Атрибут | Тип | Ключ | Назначение |\n|---|---|---|---|")
        out.append(f"| id | Текст | PK | {FIELDS[name]['id']} |")
        for f in field_rows(col):
            key = "FK" if f["type"] == "relation" and f.get("maxSelect", 1) == 1 else ""
            out.append(f"| {f['name']} | {PB_TYPES.get(f['type'], f['type'])} | {key} | "
                       f"{FIELDS[name].get(f['name'], '')} |")
        out.append("")
    out.append("## Физическая модель: таблицы SQLite\n")
    for name, title, _ in ENTITIES:
        col = schema[name]
        out.append(f"### `{name}`\n\n| Столбец | Тип SQLite | Ограничения |\n|---|---|---|")
        out.append("| id | TEXT | PRIMARY KEY, NOT NULL |")
        for f in field_rows(col):
            out.append(f"| {f['name']} | {SQL_TYPES.get(f['type'], 'TEXT')} | "
                       f"NOT NULL; {constraints(f, name, schema)} |")
        out.append("| created | TEXT | NOT NULL, автодата |")
        out.append("| updated | TEXT | NOT NULL, автодата |")
        out.append("")
    with open(os.path.join(ROOT, "docs", "er_spec.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print("docs/er_spec.md готов")


if __name__ == "__main__":
    main()
