#!/usr/bin/env python3
"""
fix_theme_const.py — VelQix : adapte le code Dart au mode sombre.

AppTheme.surface / background / cardBg / textPrimary / textSecondary /
textHint / divider / border sont devenus des GETTERS (ils changent selon le
thème clair/sombre). Un getter ne peut plus apparaître dans une expression
`const`. Ce script retire automatiquement les `const` devant les widgets qui
les utilisent (et transforme `static const x = ...` en `static final x = ...`
quand l'initialiseur en dépend).

Usage (depuis la racine du projet Flutter, après un commit git) :
    python fix_theme_const.py lib            # modifie les fichiers en place
    python fix_theme_const.py lib --dry-run  # affiche seulement ce qui changerait

Puis :  flutter analyze
"""
import re, sys, pathlib

NAMES = r'background|surface|cardBg|textPrimary|textSecondary|textHint|divider|border'
OCC = re.compile(r'\bAppTheme\.(?:%s)\b' % NAMES)


# ── masque les commentaires et littéraux de chaînes (positions conservées) ──
def mask(src):
    n = len(src)
    out = list(src)

    def blank(a, b):
        for k in range(a, b):
            if out[k] != '\n':
                out[k] = ' '

    def string_end(i):
        """i = index du 1er guillemet (ou du 'r' d'une chaîne brute). Retourne l'index après la chaîne."""
        raw = False
        if src[i] == 'r':
            raw = True
            i += 1
        q = src[i]
        triple = src.startswith(q * 3, i)
        i += 3 if triple else 1
        while i < n:
            c = src[i]
            if not raw and c == '\\':
                i += 2
                continue
            if not raw and c == '$' and i + 1 < n and src[i + 1] == '{':
                depth = 1
                i += 2
                while i < n and depth:
                    ch = src[i]
                    if ch in '\'"':
                        i = string_end(i)
                        continue
                    if ch == '{':
                        depth += 1
                    elif ch == '}':
                        depth -= 1
                    i += 1
                continue
            if triple:
                if src.startswith(q * 3, i):
                    return i + 3
            elif c == q:
                return i + 1
            elif c == '\n':
                return i  # chaîne non terminée : on s'arrête
            i += 1
        return n

    i = 0
    while i < n:
        c = src[i]
        if src.startswith('//', i):
            j = src.find('\n', i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
        elif src.startswith('/*', i):
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            blank(i, j)
            i = j
        elif c in '\'"' or (c == 'r' and i + 1 < n and src[i + 1] in '\'"'
                            and (i == 0 or not (src[i - 1].isalnum() or src[i - 1] == '_'))):
            j = string_end(i)
            blank(i, j)
            i = j
        else:
            i += 1
    return ''.join(out)


CONST_PAREN = re.compile(r'\bconst\s+[\w.]+(?:\s*<[^;(){}]*>)?\s*$')
CONST_COLL = re.compile(r'\bconst\s*(?:<[^;(){}\[\]]*>)?\s*$')
DECL_CONST = re.compile(r'(?:^|[\s;{}])((?:static\s+)?)const\s+(?:[^=;{}]*?\s)?\w+\s*=\s*[^;{}]*$')


def is_literal_brace(M, i):
    """`{` d'un littéral Map/Set (True) ou d'un corps de classe/fonction/bloc (False)."""
    before = M[max(0, i - 250):i].rstrip()
    if CONST_COLL.search(M[max(0, i - 250):i]):
        return True
    if not before:
        return False
    if before[-1] in '=(,[:?':
        return True
    if before.endswith('=>') or re.search(r'\breturn$', before):
        return True
    return False


DEFAULT_PARAM = re.compile(r'[({,]\s*(?:this\.\w+|\w+)\s*=\s*$')


def edits_for(M, pos):
    """Retourne la liste de (debut, fin, remplacement) à appliquer pour l'occurrence en `pos`."""
    edits = []
    depth = 0
    i = pos - 1
    outer = None
    stop = -1
    while i >= 0:
        ch = M[i]
        if ch in ')]}':
            depth += 1
        elif ch in '([{':
            if depth == 0:
                if ch == '{' and not is_literal_brace(M, i):
                    stop = i          # corps de classe / fonction : on s'arrête
                    break
                outer = i
                before = M[max(0, i - 250):i]
                m = (CONST_PAREN if ch == '(' else CONST_COLL).search(before)
                if m:
                    kw = m.start() + max(0, i - 250)
                    edits.append((kw, kw + len('const'), ''))
            else:
                depth -= 1
        elif ch == ';' and depth == 0:
            stop = i
            break
        i -= 1
    # déclaration `static const x = ...Foo(...AppTheme.x...)` ou `const x = AppTheme.x;`
    head_end = outer if outer is not None else pos
    head = M[stop + 1:head_end]
    if DECL_CONST.search(' ' + head):
        kw = M.find('const', stop + 1)
        while kw != -1 and kw < head_end:
            if re.match(r'const\s', M[kw:kw + 6]) and (kw == 0 or not (M[kw - 1].isalnum() or M[kw - 1] == '_')):
                edits.append((kw, kw + len('const'), 'final'))
                break
            kw = M.find('const', kw + 1)
    return edits


def process(src):
    M = mask(src)
    all_edits = {}
    warns = []
    for m in OCC.finditer(M):
        before = M[max(0, m.start() - 80):m.start()]
        if DEFAULT_PARAM.search(before) and 'const ' not in before.split('(')[-1].split(',')[-1]:
            # valeur par défaut d'un paramètre : on ne touche à rien, on signale
            warns.append(src.count('\n', 0, m.start()) + 1)
            continue
        for a, b, r in edits_for(M, m.start()):
            all_edits[(a, b)] = r
    out = src
    for (a, b), r in sorted(all_edits.items(), reverse=True):
        end = b
        if r == '':
            while end < len(out) and out[end] in ' \t':
                end += 1
        out = out[:a] + r + out[end:]
    return out, len(all_edits), warns


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    dry = '--dry-run' in sys.argv
    if not args:
        print(__doc__)
        sys.exit(1)
    total = 0
    for root in args:
        p = pathlib.Path(root)
        files = [p] if p.is_file() else sorted(p.rglob('*.dart'))
        for f in files:
            if f.name == 'app_theme.dart':
                continue
            raw = f.read_bytes().decode('utf-8')
            crlf = '\r\n' in raw
            src = raw.replace('\r\n', '\n')
            new, n, warns = process(src)
            if n:
                total += n
                print(f'{"[dry] " if dry else ""}{f}: {n} `const` retiré(s)')
                if not dry:
                    f.write_bytes((new.replace('\n', '\r\n') if crlf else new).encode('utf-8'))
            for w in warns:
                print(f'  ⚠ {f}:{w} : valeur par défaut basée sur AppTheme.* — à vérifier à la main si `flutter analyze` signale une erreur')
    print(f'Terminé : {total} modification(s).')


if __name__ == '__main__':
    main()