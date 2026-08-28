#!/usr/bin/env python3
"""Merge l10n manifests (from localization agents) into the 5 ARB files.

Handles two placeholder manifest shapes:
  A) per-key:  "key": {"ru":..,"en":..,..,"_placeholders":{"name":"String"}}
  B) top-level: "_placeholders": {"key": ["name1","name2"]}  (types inferred)

Template (intl_ru.arb) gets the @key metadata with placeholder types; other
locales get value strings only. Reuses existing keys (overwrites with same).
"""
import json, collections, os, sys

BASE = os.path.join(os.path.dirname(__file__), "..", "assets", "i18n")
LOCALES = ["ru", "en", "kk", "ky", "uz"]
LANGSET = set(LOCALES)

MANIFESTS = ["mA.json", "mB.json", "mC.json", "mD.json"]

# Extra keys we own (nav labels + a reused global the agents referenced).
EXTRA = {
    "navWmsDashboard": {"ru":"Склад WMS","en":"WMS","kk":"WMS қойма","ky":"WMS кампа","uz":"WMS ombor"},
    "navWmsWarehouses": {"ru":"Склады","en":"Warehouses","kk":"Қоймалар","ky":"Кампалар","uz":"Omborlar"},
    "navWmsBatches": {"ru":"Партии","en":"Batches","kk":"Партиялар","ky":"Партиялар","uz":"Partiyalar"},
    "navWmsSerials": {"ru":"Серии","en":"Serials","kk":"Сериялар","ky":"Сериялар","uz":"Seriyalar"},
    "navWmsCellStock": {"ru":"Ячейки","en":"Cells","kk":"Ұяшықтар","ky":"Уячалар","uz":"Kataklar"},
    "navWmsClaims": {"ru":"Рекламации","en":"Claims","kk":"Шағымдар","ky":"Доолор","uz":"Da'volar"},
    "navWmsMarking": {"ru":"Маркировка","en":"Marking","kk":"Таңбалау","ky":"Маркировка","uz":"Markirovka"},
    "navWmsSettings": {"ru":"Настройки WMS","en":"WMS settings","kk":"WMS баптаулары","ky":"WMS жөндөөлөрү","uz":"WMS sozlamalari"},
    "globalConfirm": {"ru":"Подтвердить","en":"Confirm","kk":"Растау","ky":"Ырастоо","uz":"Tasdiqlash"},
}

def infer_type(name):
    n = name.lower()
    if n in ("count", "days", "version", "id", "code", "barcode", "qty"):
        return "int"
    return "String"

def load_manifest(path):
    """Return (entries: {key: {locale: value}}, ph: {key: {name: type}})."""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    entries, ph = {}, {}
    top_ph = data.get("_placeholders", {})  # shape B
    for key, obj in data.items():
        if key == "_placeholders":
            continue
        langs = {k: v for k, v in obj.items() if k in LANGSET}
        if not langs:
            continue
        entries[key] = langs
        # shape A
        if isinstance(obj.get("_placeholders"), dict):
            ph[key] = {n: t for n, t in obj["_placeholders"].items()}
    # shape B (agent D)
    for key, names in top_ph.items():
        if key in entries:
            ph.setdefault(key, {})
            for n in names:
                ph[key].setdefault(n, infer_type(n))
    return entries, ph

def main():
    all_entries = {}
    all_ph = {}
    for m in MANIFESTS:
        p = os.path.join(os.path.dirname(__file__), m)
        if not os.path.exists(p):
            print(f"WARN: missing {m}", file=sys.stderr); continue
        e, ph = load_manifest(p)
        all_entries.update(e)
        all_ph.update(ph)
    for k, v in EXTRA.items():
        all_entries.setdefault(k, v)

    print(f"Total new keys: {len(all_entries)}; parameterized: {len(all_ph)}")

    for loc in LOCALES:
        path = os.path.join(BASE, f"intl_{loc}.arb")
        with open(path, encoding="utf-8") as f:
            arb = json.load(f, object_pairs_hook=collections.OrderedDict)
        added = 0
        for key, langs in all_entries.items():
            val = langs.get(loc) or langs.get("ru") or langs.get("en")
            if val is None:
                continue
            if key not in arb:
                added += 1
            arb[key] = val
            # @metadata only in template (ru) for parameterized keys
            if loc == "ru" and key in all_ph and all_ph[key]:
                arb["@" + key] = {
                    "placeholders": {n: {"type": t} for n, t in all_ph[key].items()}
                }
        with open(path, "w", encoding="utf-8") as f:
            json.dump(arb, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print(f"{loc}: +{added} new -> {path}")

if __name__ == "__main__":
    main()
