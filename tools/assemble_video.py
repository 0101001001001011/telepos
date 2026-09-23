# -*- coding: utf-8 -*-
# УСТАРЕЛО 2026-09-20. Решение Rob'а: озвучка и сборка обучающих роликов
# уходят на сторону SphereX целиком.
#
# Причина не в качестве этого кода. Голос здесь — Microsoft Zira Desktop,
# системный SAPI Windows, и он заметно хуже голоса SphereX, который
# выбирали долго и который один на весь канал. Плюс у SphereX это ОДИН
# механизм сборки с проверками, из которого сразу выходят постеры,
# вертикальные коротышки, водяной знак и выкладка на площадки. Два
# механизма на один канал — это две интонации и две очереди правок.
#
# ЧТО ОСТАЁТСЯ ЗДЕСЬ: съёмка. record_window.ps1 и отметки [VIDEO-MARK],
# которые печатает съёмочный прогон, — это наша часть работы и она не
# меняется. См. docs/video-production.md.
#
# Файл не удалён намеренно: пока сборщик SphereX не заработал, им можно
# сделать местную прикидку. Ролик для зрителя им собирать нельзя.

"""Собирает готовый ролик: картинка + закадровый голос + МЯГКИЕ субтитры.

Почему субтитры отдельной дорожкой, а не выжжены в кадр: сценарий это
прямо запрещает. Выжженный текст нельзя перевести, нельзя выключить, и
любая правка интерфейса заставляет переснимать ролик целиком вместо того,
чтобы переписать одну строку.

Почему звук и субтитры считаются здесь ЗАОДНО: у них одни и те же отметки
времени. Посчитай их в двух местах — и на первой же пересъёмке голос
поедет относительно подписей, причём заметит это только зритель.

    python tools/assemble_video.py --video out/pilot.mp4 --voice out/voice \
        --lead-in 6.0 --out out/pilot-final.mp4
"""
import argparse
import json
import os
import re
import subprocess
import sys


def probe_duration(path):
    out = subprocess.run(
        ['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
         '-of', 'csv=p=0', path],
        capture_output=True, text=True, check=True)
    return float(out.stdout.strip())


def srt_time(seconds):
    if seconds < 0:
        seconds = 0.0
    ms = int(round(seconds * 1000))
    h, ms = divmod(ms, 3600000)
    m, ms = divmod(ms, 60000)
    s, ms = divmod(ms, 1000)
    return '%02d:%02d:%02d,%03d' % (h, m, s, ms)


def split_sentences(text):
    """Режет сегмент на реплики для субтитров.

    По предложениям, а не по длине: подпись, оборванная на середине мысли,
    читается хуже, чем длинная. Кавычки и сокращения вроде «e.g.» тут не
    встречаются — текст пишется под озвучку и уже простой.
    """
    parts = re.split(r'(?<=[.!?])\s+', text.strip())
    return [p.strip() for p in parts if p.strip()]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--video', required=True)
    ap.add_argument('--voice', required=True,
                    help='каталог с narration.json и WAV-сегментами')
    ap.add_argument('--out', required=True)
    ap.add_argument('--lead-in', type=float, default=0.0,
                    help='сколько секунд в начале ролика занимает загрузка, '
                         'прежде чем можно начинать говорить')
    ap.add_argument('--gap', type=float, default=1.2,
                    help='пауза между сегментами речи, с')
    ap.add_argument('--srt-only', action='store_true')
    args = ap.parse_args()

    plan_path = os.path.join(args.voice, 'narration.json')
    with open(plan_path, encoding='utf-8-sig') as f:
        plan = json.load(f)
    if isinstance(plan, dict):
        plan = [plan]
    plan.sort(key=lambda r: r['order'])

    video_seconds = probe_duration(args.video)

    # Если раскладка уже несёт отметки — их собрал `align_narration.py` по
    # меткам, напечатанным съёмочной дорожкой. Они отмерены по настоящему
    # ролику, а расчёт «сегмент за сегментом» — догадка по сумме пауз:
    # замерено, что заявленных пауз 79 с, а материала 190 с, и к середине
    # ролика такая догадка отстаёт на минуту.
    if all('start' in row for row in plan):
        sys.stdout.write('раскладка взята из отметок прогона\n')
    else:
        at = args.lead_in
        for row in plan:
            row['start'] = at
            row['end'] = at + row['seconds']
            at = row['end'] + args.gap

    speech_end = plan[-1]['end']
    if speech_end > video_seconds:
        sys.stdout.write(
            'ВНИМАНИЕ: речь длиннее картинки — %.1f с против %.1f с.\n'
            'Последние %.1f с озвучки не на что положить: либо удлините '
            'паузы в хореографии, либо сократите текст.\n'
            % (speech_end, video_seconds, speech_end - video_seconds))

    # --- субтитры -------------------------------------------------------
    srt_path = os.path.splitext(args.out)[0] + '.en.srt'
    cues = []
    for row in plan:
        sentences = split_sentences(row['text'])
        total_chars = sum(len(s) for s in sentences) or 1
        cursor = row['start']
        for sentence in sentences:
            share = len(sentence) / total_chars
            length = row['seconds'] * share
            cues.append((cursor, cursor + length, sentence))
            cursor += length

    with open(srt_path, 'w', encoding='utf-8', newline='\n') as f:
        for i, (start, end, text) in enumerate(cues, 1):
            f.write('%d\n%s --> %s\n%s\n\n'
                    % (i, srt_time(start), srt_time(end), text))
    sys.stdout.write('субтитры: %s (%d реплик)\n' % (srt_path, len(cues)))

    if args.srt_only:
        return

    # --- звук и сборка --------------------------------------------------
    # Каждый сегмент задерживается на свою отметку и подмешивается к общей
    # тишине длиной с ролик. `amix` нормализует громкость по числу входов,
    # поэтому `normalize=0` — иначе голос тем тише, чем больше сегментов.
    # Все входы объявляются ДО любого `-map`: ffmpeg разбирает доводы по
    # порядку, и `-i`, вклинившийся между отображениями, ломает разбор —
    # именно на этом сборка отказала в первый раз.
    cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'warning', '-y',
           '-i', args.video]
    for row in plan:
        cmd += ['-i', row['file']]
    cmd += ['-i', srt_path]
    srt_index = len(plan) + 1

    parts = []
    labels = []
    for i, row in enumerate(plan, start=1):
        delay_ms = int(round(row['start'] * 1000))
        parts.append('[%d:a]adelay=%d|%d[a%d]' % (i, delay_ms, delay_ms, i))
        labels.append('[a%d]' % i)
    parts.append('%samix=inputs=%d:normalize=0:duration=longest[aout]'
                 % (''.join(labels), len(plan)))

    cmd += ['-filter_complex', ';'.join(parts),
            '-map', '0:v', '-map', '[aout]', '-map', '%d:s' % srt_index,
            '-c:v', 'copy', '-c:a', 'aac', '-b:a', '128k',
            '-c:s', 'mov_text', '-metadata:s:s:0', 'language=eng',
            # Длительность задаётся явно по картинке. `-shortest` при
            # `-c:v copy` её не обрезает — замерено: 18 с картинки дали
            # 81 с звука, и ролик кончался тишиной под чёрным кадром.
            '-t', '%.3f' % video_seconds,
            args.out]

    # Ошибку ffmpeg надо ПОКАЗАТЬ: `check=True` в одиночку прячет причину
    # за кодом возврата, и отказ выглядит загадкой.
    done = subprocess.run(cmd, capture_output=True, text=True)
    if done.returncode != 0:
        sys.stdout.write(done.stderr or '(ffmpeg промолчал)\n')
        sys.exit('ffmpeg отказал, код %d' % done.returncode)
    sys.stdout.write('готово: %s (%.1f с)\n'
                     % (args.out, probe_duration(args.out)))


if __name__ == '__main__':
    main()
