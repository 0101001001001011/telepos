# -*- coding: utf-8 -*-
# ПЕРЕЕЗЖАЕТ К SphereX 2026-09-20. Логика верная и остаётся в силе —
# именно она показала, что раскладывать голос по сумме пауз нельзя
# (заявленных 79 с против снятых 190). Но считать её должен тот, кто
# синтезирует голос: длительности реплик берутся из озвучки, а озвучка
# теперь у SphereX.
#
# ЧТО ОСТАЁТСЯ ЗДЕСЬ: печать отметок [VIDEO-MARK] <блок> <секунда> в
# съёмочном прогоне. Отметки — часть съёмки, и они наши.

"""Кладёт реплики озвучки на ОТМЕРЕННЫЕ отметки ролика, а не на сумму пауз.

Почему не по сумме: заявленных пауз в хореографии 79 с, а снятого
материала 190 с. Разница — настоящие ожидания базы, сборки экрана и
переходов, и предсказать её нельзя. Голос, разложенный по сумме пауз,
к середине ролика отстал бы на минуту.

Съёмочная дорожка печатает строки вида

    [VIDEO-MARK] printer-tab 128.416

— секунда, на которой начинается блок, от начала записи. Здесь они
сшиваются с длительностями озвучки в одну раскладку для сборки.

    python tools/align_narration.py --log take.txt --voice out/voice \
        --out out/voice/narration.json
"""
import argparse
import io
import json
import re
import sys

MARK = re.compile(r'\[VIDEO-MARK\]\s+(\S+)\s+([0-9.]+)')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--log', required=True, help='вывод прогона')
    ap.add_argument('--voice', required=True, help='каталог с narration.json')
    ap.add_argument('--out', required=True)
    ap.add_argument('--shift', type=float, default=0.0,
                    help='поправка, с: положительная сдвигает голос позже. '
                         'Нужна, если запись началась раньше отсчёта.')
    args = ap.parse_args()

    marks = {}
    with io.open(args.log, encoding='utf-8', errors='replace') as f:
        for line in f:
            m = MARK.search(line)
            if m:
                # Последняя отметка побеждает: прогон могли повторить в
                # одном логе, и старые отметки указывали бы в прошлое.
                marks[m.group(1)] = float(m.group(2))

    if not marks:
        sys.exit('в логе нет ни одной отметки [VIDEO-MARK] — '
                 'дорожка их не печатала, выравнивать нечем')

    with io.open('%s/narration.json' % args.voice, encoding='utf-8-sig') as f:
        plan = json.load(f)
    if isinstance(plan, dict):
        plan = [plan]
    plan.sort(key=lambda r: r['order'])

    missing = [r['name'] for r in plan if r['name'] not in marks]
    if missing:
        sys.exit('для блоков нет отметок: %s\n'
                 'имена в 01-narration.txt и в mark(...) обязаны совпадать'
                 % ', '.join(missing))

    aligned = []
    for row in plan:
        start = marks[row['name']] + args.shift
        row = dict(row)
        row['start'] = start
        row['end'] = start + row['seconds']
        aligned.append(row)

    # Наложение реплик друг на друга — не мелочь: два голоса разом
    # неразборчивы оба. Лучше сказать об этом здесь, чем услышать в ролике.
    for a, b in zip(aligned, aligned[1:]):
        if a['end'] > b['start']:
            sys.stdout.write(
                'ВНИМАНИЕ: «%s» кончается на %.1f с, а «%s» начинается на '
                '%.1f с — реплики наложатся. Удлините паузу этого блока в '
                'хореографии на %.1f с.\n'
                % (a['name'], a['end'], b['name'], b['start'],
                   a['end'] - b['start']))

    with io.open(args.out, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(aligned, f, ensure_ascii=False, indent=1)

    sys.stdout.write('раскладка по отметкам: %s\n' % args.out)
    for row in aligned:
        sys.stdout.write('  %-12s %7.2f → %7.2f  (%.1f с речи)\n'
                         % (row['name'], row['start'], row['end'],
                            row['seconds']))


if __name__ == '__main__':
    main()
