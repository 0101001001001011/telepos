"""Превращает черновик статьи в HTML-тело для формы публикации Инфостарта.

Источник один — `docs/internal/article-infostart-draft.md`. Отдельно
поддерживаемого HTML не заводим: два текста одной статьи разойдутся, и
разойдутся молча.

Что делает особенного:

* служебную шапку (блок `>` в начале) выбрасывает — она для нас, не для
  читателя;
* заголовок первого уровня выбрасывает: на Инфостарте он живёт в поле формы,
  а не в теле;
* метку `[СКРИНШОТ: файл.png — подпись]` разворачивает в `<img>` с ЯВНЫМ
  именем файла, потому что картинки загружаются в форму отдельно и связать их
  с местами в тексте больше нечем;
* `⟪…⟫` превращает в крикливую пометку: незаполненное должно быть видно в
  предпросмотре, а не находиться читателем.

Стилей не ставит намеренно: редактор площадки их вырезает, а полагаться на
вырезанное — способ получить статью, которая у автора выглядит иначе, чем у
читателя.
"""
import io
import re

SRC = 'docs/internal/article-infostart-draft.md'
OUT = 'docs/internal/article-infostart-body.html'

text = io.open(SRC, encoding='utf-8').read()

# Служебная шапка: от начала до первого `---` на отдельной строке.
text = text.split('\n---\n', 1)[1]

lines = text.split('\n')


def inline(s):
    s = (s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;'))
    s = re.sub(r'`([^`]+)`', r'<code>\1</code>', s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', s)
    s = re.sub(r'(?<![*\w])\*([^*]+)\*(?!\w)', r'<em>\1</em>', s)
    s = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', s)
    # Незаполненное — так, чтобы нельзя было не заметить в предпросмотре.
    s = re.sub(r'⟪(.+?)⟫',
               r'<strong>[ЗАПОЛНИТЬ ПЕРЕД ПУБЛИКАЦИЕЙ: \1]</strong>', s,
               flags=re.S)
    return s


out = []
i = 0
imgs = []
para = []


def flush():
    if para:
        out.append('<p>' + inline(' '.join(para).strip()) + '</p>')
        para.clear()


while i < len(lines):
    ln = lines[i]
    st = ln.strip()

    m = re.match(r'^\[СКРИНШОТ:\s*([^\s—]+)\s*—\s*(.+)\]$', st)
    if m:
        flush()
        name, cap = m.group(1), m.group(2)
        imgs.append((name, cap))
        out.append('<p><img src="%s" alt="%s"></p>' % (name, cap.replace('"', "'")))
        out.append('<p><em>%s</em></p>' % inline(cap))
        i += 1
        continue

    if st.startswith('### '):
        flush(); out.append('<h3>' + inline(st[4:]) + '</h3>'); i += 1; continue
    if st.startswith('## '):
        flush(); out.append('<h2>' + inline(st[3:]) + '</h2>'); i += 1; continue
    if st.startswith('# '):
        flush(); i += 1; continue          # заголовок живёт в поле формы
    if st == '---':
        flush(); out.append('<hr>'); i += 1; continue
    if st == '':
        flush(); i += 1; continue

    # таблица
    if st.startswith('|'):
        flush()
        rows = []
        while i < len(lines) and lines[i].strip().startswith('|'):
            rows.append(lines[i].strip())
            i += 1
        cells = [[c.strip() for c in r.strip('|').split('|')] for r in rows]
        body = [r for r in cells[1:] if not set(''.join(r).replace(' ', '')) <= set('-:')]
        out.append('<table>')
        out.append('<thead><tr>' + ''.join('<th>%s</th>' % inline(c) for c in cells[0]) + '</tr></thead>')
        out.append('<tbody>')
        for r in body:
            out.append('<tr>' + ''.join('<td>%s</td>' % inline(c) for c in r) + '</tr>')
        out.append('</tbody></table>')
        continue

    # список
    if re.match(r'^[-*] ', st) or re.match(r'^\d+\. ', st):
        flush()
        ordered = bool(re.match(r'^\d+\. ', st))
        items = []
        while i < len(lines):
            s2 = lines[i].strip()
            if re.match(r'^[-*] ', s2) or re.match(r'^\d+\. ', s2):
                items.append(re.sub(r'^([-*]|\d+\.) ', '', s2))
                i += 1
            elif s2 and lines[i].startswith(('  ', '\t')):
                items[-1] += ' ' + s2
                i += 1
            else:
                break
        tag = 'ol' if ordered else 'ul'
        out.append('<%s>' % tag)
        for it in items:
            out.append('<li>%s</li>' % inline(it))
        out.append('</%s>' % tag)
        continue

    # блок кода
    if st.startswith('```'):
        flush()
        i += 1
        code = []
        while i < len(lines) and not lines[i].strip().startswith('```'):
            code.append(lines[i])
            i += 1
        i += 1
        esc = '\n'.join(code).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
        out.append('<pre><code>%s</code></pre>' % esc)
        continue

    para.append(st)
    i += 1

flush()

html = '\n'.join(out) + '\n'
io.open(OUT, 'w', encoding='utf-8', newline='\n').write(html)

print('тело: %d строк, %.1f КБ' % (html.count('\n'), len(html.encode('utf-8')) / 1024))
print('картинок в тексте: %d' % len(imgs))
for n, c in imgs:
    print('   %-26s %s' % (n, c))
print('незаполненных мест: %d' % html.count('ЗАПОЛНИТЬ ПЕРЕД ПУБЛИКАЦИЕЙ'))
