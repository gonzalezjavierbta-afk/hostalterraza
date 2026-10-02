#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verificación de la migración documental de 'Sistema QR desarrollo'.

Uso:  python3 AMPLIACION/_backups/verificar_migracion.py        (desde la carpeta raíz del sistema documental)
Compara los respaldos .bak (originales, CRLF normalizado) contra el árbol nuevo. Exit 0 = todo OK.
"""
import os, re, sys, glob
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
META = {'INDEX.md', 'MIGRACION-DOCS.md', 'NOTAS-MIGRACION.md'}
ENTRY = ['DECISIONS.md', 'ERRORES_HISTORICOS.md', 'NEXT.md', 'TASKS.md', 'PROJECT.md', 'BLUEPRINT.md',
         'Reglas de Oro QR.md', 'AMPLIACION/TEMPLATES.md', 'INDEX.md']
LIM_L, LIM_B = 200, 30000


def read_lines(path):
    t = open(path, encoding='utf-8', newline='').read().replace('\r\n', '\n').replace('\r', '\n')
    L = t.split('\n')
    if L and L[-1] == '':
        L.pop()
    return L


def trivial(l):
    s = l.strip()
    return (not s) or re.fullmatch(r'-{3,}', s) is not None


orig = {}
for p in sorted(glob.glob(os.path.join(HERE, '*.bak'))):
    m = re.match(r'^(.*)\.(\d{4}-\d{2}-\d{2})\.bak$', os.path.basename(p))
    orig[m.group(1)] = read_lines(p)

new = {}
for dp, dn, fn in os.walk(ROOT):
    if '_backups' in dp.split(os.sep):
        continue
    for f in fn:
        if f.endswith('.md'):
            rel = os.path.relpath(os.path.join(dp, f), ROOT).replace(os.sep, '/')
            new[rel] = read_lines(os.path.join(dp, f))

results = []   # (nombre, ok, detalle)


def check(name, ok, detail=''):
    results.append((name, bool(ok), detail))


# 1. Respaldos presentes
check('Respaldos .bak presentes (8 originales)', len(orig) == 8, f'{len(orig)} encontrados: ' + ', '.join(sorted(orig)))

# 2. IDs pre/post
id_re = re.compile(r'(?:ADR-\d+|TSK-(?:\d+|SQL|V03)|BUG-(?:\d+|XXX))')
c_old, c_new = Counter(), Counter()
for L in orig.values():
    for l in L:
        c_old.update(id_re.findall(l))
for rel, L in new.items():
    if rel in META:
        continue
    for l in L:
        c_new.update(id_re.findall(l))
# Extras permitidos y explicados (NO son IDs nuevos): ADR-038 se lista en la tabla de huecos de numeración (no existe en ningún original);
# BUG-018/BUG-019 son la expansión de la cita compacta "BUG-006/018/019" del original.
ALLOWED_EXTRA = {'ADR-038', 'BUG-018', 'BUG-019'}
for fam in ('ADR', 'TSK', 'BUG'):
    o = {k for k in c_old if k.startswith(fam)}
    n = {k for k in c_new if k.startswith(fam)}
    extra = (n - o) - ALLOWED_EXTRA
    ok = (o <= n) and not extra
    note = ''
    if (n - o) & ALLOWED_EXTRA:
        note = f' (extras explicados: {sorted((n - o) & ALLOWED_EXTRA)})'
    check(f'IDs {fam}-XXX: todos los del original existen y no hay IDs nuevos', ok,
          f'pre={len(o)} post={len(n)}{note}' + ('' if ok else f' faltan={sorted(o-n)[:8]} sobran={sorted(extra)[:8]}'))
low = [k for k in c_old if c_new[k] < c_old[k]]
check('Ninguna aparición de ID se perdió (post ≥ pre por ID)', not low,
      f'{sum(c_old.values())} apariciones pre → {sum(c_new.values())} post (las extra son filas de índice/enlaces)' + (f'; con menos: {low[:8]}' if low else ''))

# 3. Unidades pre/post
n_adr_pre = sum(1 for l in orig['DECISIONS.md'] if re.match(r'^#{2,4}\s+ADR-\d+', l))
n_adr_post = len([r for r in new if re.match(r'decisiones/ADR-\d+', r)])
check('ADR: encabezados originales = archivos decisiones/ADR-*.md', n_adr_pre == n_adr_post, f'{n_adr_pre} = {n_adr_post}')
check('Nota no-ADR (modo express) en decisiones/', 'decisiones/NOTA-modo-express.md' in new)
n_e_pre = sum(1 for l in orig['ERRORES_HISTORICOS.md'] if re.match(r'^## \d+\.', l))
n_e_post = len([r for r in new if re.match(r'errores/E\d\d-', r)])
check('ERRORES: secciones originales = archivos errores/E##-*.md', n_e_pre == n_e_post, f'{n_e_pre} = {n_e_post}')
n_t_pre = sum(1 for l in orig['TASKS.md'] if re.match(r'^- \[[ x]\]', l))
n_t_post = sum(1 for r in ('TASKS-DETALLE.md', 'TASKS-ARCHIVO.md') for l in new[r] if re.match(r'^- \[[ x]\]', l))
check('TASKS: ítems `- [ ]`/`- [x]` originales = DETALLE + ARCHIVO', n_t_pre == n_t_post, f'{n_t_pre} = {n_t_post}')
hit = re.compile(r'^#### (-\d+|0b?)\.\s')
n_h_pre = sum(1 for l in orig['NEXT.md'] if hit.match(l))
n_h_post = sum(1 for r in ('NEXT.md', 'HISTORIA-NEXT.md') for l in new[r] if hit.match(l))
check('NEXT: hitos originales = NEXT + HISTORIA-NEXT', n_h_pre == n_h_post, f'{n_h_pre} = {n_h_post}')
n_c_pre = sum(1 for l in orig['TEMPLATES.md'] if l.startswith('## '))
n_c_post = len([r for r in new if r.startswith('AMPLIACION/templates/')])
check('TEMPLATES: capítulos `##` originales = archivos AMPLIACION/templates/', n_c_pre == n_c_post, f'{n_c_pre} = {n_c_post}')

# 4. Todo dato del original existe (multiconjunto de líneas, estricto)
need, have = Counter(), Counter()
for L in orig.values():
    need.update(l.rstrip() for l in L if not trivial(l))
for rel, L in new.items():
    if rel in META:
        continue
    have.update(l.rstrip() for l in L if not trivial(l))
missing = need - have
total_need = sum(need.values())
check('Cada línea no vacía de los 8 originales existe en el sistema nuevo (conteo estricto)', not missing,
      f'{total_need - sum(missing.values())}/{total_need} líneas presentes' + (f'; FALTAN {sum(missing.values())}: ' + ' || '.join(k[:70] for k in list(missing)[:5]) if missing else ''))

# 5. Topes de los documentos de entrada
for rel in ENTRY:
    L = new.get(rel)
    if L is None:
        check(f'Tope {rel}', False, 'no existe'); continue
    b = len(('\n'.join(L) + '\n').encode('utf-8'))
    check(f'Tope {rel} ≤{LIM_L} líneas y ≤{LIM_B // 1000} KB', len(L) <= LIM_L and b <= LIM_B, f'{len(L)} líneas · {b/1024:.1f} KB')

# 6. Enlaces e anclas
anchors = {rel: set(re.findall(r'<a id="([^"]+)"></a>', '\n'.join(L))) for rel, L in new.items()}
bad, n_links = [], 0
link_re = re.compile(r'\]\((?!https?:|mailto:)([^)#\s]*)(?:#([^)\s]*))?\)')
for rel, L in new.items():
    base = os.path.dirname(rel)
    for i, l in enumerate(L):
        for m in link_re.finditer(l):
            n_links += 1
            path = m.group(1).replace('%20', ' ')
            frag = m.group(2)
            tgt = rel if path == '' else os.path.normpath(os.path.join(base, path)).replace(os.sep, '/')
            if tgt not in new and not os.path.exists(os.path.join(ROOT, tgt)):
                bad.append(f'{rel}:{i+1} → {tgt}'); continue
            if frag and anchors.get(tgt) and frag not in anchors[tgt]:
                bad.append(f'{rel}:{i+1} → {tgt}#{frag}')
check('Todos los enlaces relativos y anclas resuelven', not bad, f'{n_links} enlaces revisados' + (f'; rotos: {bad[:5]}' if bad else ''))

# 7. Rangos de líneas de los índices apuntan al sitio correcto
rb = []
def chk_ranges(src, row_re, target, starts):
    T = new[target]
    n = 0
    for l in new[src]:
        m = row_re.search(l)
        if not m:
            continue
        a = int(m.group('a'))
        n += 1
        ok = a - 1 < len(T) and T[a - 1].startswith(starts)
        if not ok:
            rb.append(f'{src}→{target} L{a}')
    return n

n1 = chk_ranges('TASKS.md', re.compile(r'TASKS-DETALLE\.md#[^)]+\).*\| L(?P<a>\d+)-\d+ \|\s*$'), 'TASKS-DETALLE.md', '- [ ]')
n2 = chk_ranges('TASKS-DETALLE.md', re.compile(r'^\| \[.+?\]\(#[^)]+\) \|.*\| L(?P<a>\d+)-\d+ \|\s*$'), 'TASKS-DETALLE.md', '- [ ]')
n3 = chk_ranges('TASKS-ARCHIVO.md', re.compile(r'^\| \[.+?\]\(#[^)]+\) \|.*\| L(?P<a>\d+)-\d+ \|\s*$'), 'TASKS-ARCHIVO.md', '- [x]')
n4 = chk_ranges('HISTORIA-NEXT.md', re.compile(r'^\| \[.+?\]\(#hito[^)]+\) \|.*\| L(?P<a>\d+)-\d+ \|\s*$'), 'HISTORIA-NEXT.md', '#### ')
n5 = chk_ranges('BLUEPRINT.md', re.compile(r'^\| .+ \| L(?P<a>\d+)-\d+ \|\s*$'), 'BLUEPRINT.md', '#')
n6 = chk_ranges('Reglas de Oro QR.md', re.compile(r'^\| .+ \| L(?P<a>\d+)-\d+ \|\s*$'), 'Reglas de Oro QR.md', '#')
check('Rangos "Líneas" de tableros y mapas apuntan a la línea correcta', not rb, f'{n1+n2+n3+n4+n5+n6} rangos revisados' + (f'; mal: {rb[:5]}' if rb else ''))

# informe
ok_all = all(r[1] for r in results)
if '--md' in sys.argv:
    print('| Comprobación | Resultado | Detalle |\n|---|---|---|')
    for n, ok, d in results:
        print(f'| {n} | {"✅ OK" if ok else "❌ FALLA"} | {d.replace("|", "/")} |')
else:
    for n, ok, d in results:
        print(('OK    ' if ok else 'FALLA ') + n + ('  — ' + d if d else ''))
    print('\nRESULTADO GLOBAL:', 'TODO OK' if ok_all else 'HAY FALLAS')
sys.exit(0 if ok_all else 1)
