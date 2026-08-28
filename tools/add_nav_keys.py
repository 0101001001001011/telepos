import io, os
base = os.path.join(os.path.dirname(__file__), '..', 'assets', 'i18n')
vals = {
    'ru': ('Отчёты', 'Склад'),
    'en': ('Reports', 'Stock'),
    'kk': ('Есептер', 'Қойма'),
    'ky': ('Отчёттор', 'Кампа'),
    'uz': ('Hisobotlar', 'Ombor'),
}
for loc, (rep, stk) in vals.items():
    p = os.path.join(base, f'intl_{loc}.arb')
    with io.open(p, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    if any('"navReports"' in ln for ln in lines):
        print(f'{loc}: already present, skip')
        continue
    out = []
    for ln in lines:
        out.append(ln)
        if '"@@locale"' in ln:
            out.append(f'  "navReports": "{rep}",\n')
            out.append(f'  "navStock": "{stk}",\n')
    with io.open(p, 'w', encoding='utf-8') as f:
        f.writelines(out)
    print(f'{loc}: inserted navReports/navStock')
