"""Static handbook renderer; intentionally no dependencies, accounts or analytics."""
from pathlib import Path
import html
import hashlib
import json
import re
import shutil

REPO = 'https://github.com/VertimaXx/ChronoFork-V3.1'
PAGES = {
    'docs/connector-controls.md': ('connector-controls.html', 'Full plugin controls'),
    'docs/connections.md': ('connections.html', 'Plugin connections'),
    'docs/combat-walkthrough.md': ('combat-walkthrough.html', 'Combat example'),
    'docs/start-here.md': ('start-here.html', 'Start here'),
    'docs/game-integration.md': ('game-integration.html', 'Connect your game'),
    'docs/integration.md': ('integration.html', 'API reference'),
    'docs/comparison.md': ('comparison.html', 'Original vs fork'),
    'docs/benchmarks.md': ('benchmarks.html', 'Benchmarks'),
    'docs/math-and-limits.md': ('math-and-limits.html', 'Math & limits'),
    'docs/faq.md': ('faq.html', 'FAQ'),
    'CREDITS.md': ('credits.html', 'Credits'),
}


def slug(s):
    return re.sub(r'[^a-z0-9\s-]', '', s.lower()).strip().replace(' ', '-')


def url(root, current, target):
    if re.match(r'^[a-z]+:|^#', target):
        return target
    path, sep, fragment = target.partition('#')
    resolved = (current.parent / path).resolve()
    rel = resolved.relative_to(root).as_posix()
    if rel in PAGES:
        return PAGES[rel][0] + (sep + fragment if sep else '')
    if rel.startswith('site/'):
        return rel[5:]
    if rel.startswith('dist/'):
        return 'downloads/' + rel[5:]
    if rel.startswith('benchmarks/data/'):
        return 'assets/data/' + rel.split('/')[-1]
    if rel == 'LICENSE':
        return 'license.txt'
    return REPO + '/blob/main/' + rel + (sep + fragment if sep else '')


def inline(root, current, s):
    parts = []
    def hold(value):
        parts.append(value)
        return f'\x00{len(parts)-1}\x00'
    s = re.sub(r'`([^`]+)`', lambda m: hold('<code>' + html.escape(m[1]) + '</code>'), s)
    s = re.sub(r'!\[([^]]*)\]\(([^)]+)\)', lambda m: hold('<img loading="lazy" src="' + html.escape(url(root, current, m[2]), quote=True) + '" alt="' + html.escape(m[1], quote=True) + '">'), s)
    s = re.sub(r'\[([^]]+)\]\(([^)]+)\)', lambda m: hold('<a href="' + html.escape(url(root, current, m[2]), quote=True) + '">' + html.escape(m[1]) + '</a>'), s)
    s = html.escape(s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', s)
    s = re.sub(r'\*([^*]+)\*', r'<em>\1</em>', s)
    for i, part in enumerate(parts):
        s = s.replace(f'\x00{i}\x00', part)
    return s


def markdown(root, current, s):
    lines, blocks, toc, i = s.splitlines(), [], [], 0
    fmt = lambda value: inline(root, current, value)
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if line.startswith('```'):
            lang, buf = line[3:], []
            i += 1
            while i < len(lines) and not lines[i].startswith('```'):
                buf.append(lines[i]); i += 1
            blocks.append('<pre><code class="language-' + html.escape(lang) + '">' + html.escape('\n'.join(buf)) + '</code></pre>')
            i += 1
            continue
        m = re.match(r'^(#{1,6}) (.*)', line)
        if m:
            level, title = len(m[1]), m[2]
            anchor = slug(title)
            blocks.append(f'<h{level} id="{anchor}">{fmt(title)}</h{level}>')
            if level == 2:
                toc.append((anchor, title))
            i += 1
            continue
        if line.startswith('|'):
            rows = []
            while i < len(lines) and lines[i].startswith('|'):
                cells = [c.strip() for c in lines[i].strip('|').split('|')]
                if not all(re.fullmatch(r':?-+:?', c) for c in cells):
                    rows.append(cells)
                i += 1
            blocks.append('<div class="table-scroll"><table><thead><tr>' + ''.join('<th scope="col">' + fmt(c) + '</th>' for c in rows[0]) + '</tr></thead><tbody>' + ''.join('<tr>' + ''.join('<td>' + fmt(c) + '</td>' for c in row) + '</tr>' for row in rows[1:]) + '</tbody></table></div>')
            continue
        if re.match(r'^(- |\d+\. )', line):
            ordered = bool(re.match(r'^\d', line))
            tag, buf = 'ol' if ordered else 'ul', []
            while i < len(lines) and re.match(r'^(\d+\. )' if ordered else r'^- ', lines[i]):
                buf.append('<li>' + fmt(re.sub(r'^(- |\d+\. )', '', lines[i])) + '</li>'); i += 1
            blocks.append('<' + tag + '>' + ''.join(buf) + '</' + tag + '>')
            continue
        buf = [line]; i += 1
        while i < len(lines) and lines[i].strip() and not re.match(r'^(#|\||```|- |\d+\. )', lines[i]):
            buf.append(lines[i]); i += 1
        blocks.append('<p>' + fmt(' '.join(buf)) + '</p>')
    return '\n'.join(blocks), toc


def shell(title, body, active='', toc=None, asset_versions=None):
    asset_versions = asset_versions or {}
    style_version = asset_versions.get('style.css', '')
    icon_version = asset_versions.get('icon.svg', '')
    links = [('index.html', 'Overview'), ('start-here.html', 'Start here'), ('connector-controls.html', 'Connect'), ('comparison.html', 'Compare'), ('benchmarks.html', 'Benchmarks'), ('math-and-limits.html', 'Limits'), ('help.html', 'Words & errors')]
    nav = ''.join(f'<a href="{path}"' + (' aria-current="page"' if active == path else '') + f'>{label}</a>' for path, label in links)
    aside = ''
    if toc:
        aside = '<aside class="toc" aria-label="On this page"><p class="eyebrow">On this page</p>' + ''.join(f'<a href="#{a}">{html.escape(t)}</a>' for a, t in toc) + '<hr><a href="integration.html">Exact API →</a><a href="faq.html">Frequently asked questions →</a></aside>'
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"><title>{html.escape(title)} · ChronoFork V3.2</title><meta name="description" content="ChronoFork V3.2: an unofficial, AI-assisted Chrono fork for checked gameplay contacts in competitive Roblox games. Setup, math, limitations and reproducible benchmark evidence."><link rel="icon" href="assets/icon.svg?v={icon_version}" type="image/svg+xml"><link rel="stylesheet" href="assets/style.css?v={style_version}"><script src="assets/app.js" defer></script></head>
<body><a class="skip" href="#content">Skip to content</a><header class="top"><a class="brand" href="index.html"><img src="assets/icon.svg?v={icon_version}" alt="" width="30" height="30">ChronoFork <span>V3.2</span></a><a class="repo-link" href="{REPO}">View on GitHub ↗</a></header><div class="nav-wrap"><nav aria-label="Main">{nav}</nav></div>
<main id="content" class="{'doc-layout' if toc else 'wide'}">{aside}{body}</main><footer><div><strong>ChronoFork V3.2</strong><p>An unofficial Chrono fork. Original credit: <a href="https://github.com/Parihsz/Chrono">Parihsz & contributors</a>.<br>Developed with <strong>OpenAI Codex / AI</strong> under <a href="https://github.com/VertimaXx">VertimaXx</a>'s direction.</p></div><div class="footer-links"><a href="credits.html">Full credits & lineage</a><a href="license.txt">MIT license</a><a href="faq.html">FAQ</a><a href="{REPO}/issues">Report a problem</a></div><p class="footer-note">V3.2 connector and plugin; unchanged V3.1 Core. Earlier benchmark versions stay labeled. No upstream endorsement or production certification is claimed.</p></footer></body></html>'''


def build_site(root):
    site = root / 'site'
    asset_versions = {name: hashlib.sha256((site / 'assets' / name).read_bytes()).hexdigest()[:12] for name in ['style.css', 'icon.svg']}
    (site / 'assets/data').mkdir(exist_ok=True)
    for p in (root / 'benchmarks/data').glob('*.json'):
        shutil.copyfile(p, site / 'assets/data' / p.name)
    shutil.copyfile(root / 'LICENSE', site / 'license.txt')
    (site / '.nojekyll').write_text('', newline='\n')
    old = json.loads((root / 'benchmarks/data/v3.0-numerical.json').read_text(encoding='utf-8'))
    bars = ''.join(f'<div class="bar-row"><span>{r["actors"]} actors</span><div class="bar-track"><div class="bar" style="width:{r["medianBatchUs"]/170*100:.3f}%"></div></div><strong>{r["medianBatchUs"]:.2f} µs</strong></div>' for r in old['load']['rows'])
    chart = '<section class="chart" aria-label="Earlier V3.0 full-service workload"><p class="eyebrow">Earlier V3.0 measurement · single workstation</p><h2>Full contact-service workload</h2><p>Median of five batch means. BeginAction + Query + EndAction, one sphere per actor, zero contacts, no world provider. Capture and game callbacks excluded.</p>' + bars + '<p class="small">Bars show CPU time per iteration, not p95 query latency or whole-game FPS.</p></section>'
    for name, (output, title) in PAGES.items():
        path = root / name
        body, toc = markdown(root, path, path.read_text(encoding='utf-8'))
        if name == 'docs/benchmarks.md':
            body = body.replace('<h2 ', chart + '<h2 ', 1)
        if name == 'docs/start-here.md':
            body += '<section class="downloads"><h2 id="downloads">V3.2 downloads</h2>' + ''.join(f'<a class="download" href="downloads/{file}" download><span>{label}</span><span>↓</span></a>' for file, label in [('ChronoFork-3.2.0.zip', 'Complete source + Studio bundle'), ('ChronoV3Setup.rbxmx', 'Studio setup plugin'), ('ChronoV3.rbxmx', 'Core module'), ('ChronoV3Toolkit.rbxmx', 'Developer toolkit'), ('ChronoV3Guides.rbxmx', 'In-game developer guide'), ('ChronoV3Tests.rbxmx', 'Studio tests'), ('MANIFEST.json', 'File hashes / manifest')]) + '</section>'
            toc.append(('downloads', 'Downloads'))
        (site / output).write_text(shell(title, '<article class="prose">' + body + '</article>', output, toc, asset_versions), encoding='utf-8', newline='\n')
    home = '''<section class="hero"><div><p class="eyebrow">Roblox / Luau · Unofficial Chrono fork</p><h1>Make contact.<br><span>Check the evidence.</span></h1><p class="lede">Gameplay hitbox checks for the competitive game you already have. Your server supplies checked positions. ChronoFork records them and checks contacts. Your game decides the result.</p><div class="buttons"><a class="button primary" href="start-here.html">Start with the setup guide →</a><a class="button" href="start-here.html#downloads">Download V3.2 ↓</a></div><p class="hero-credit">Original project: <a href="https://github.com/Parihsz/Chrono">Parihsz / Chrono</a>.<br>Competitive branch developed with <strong>OpenAI Codex / AI</strong>, directed by VertimaXx.</p></div><div class="diagram" aria-label="Your server supplies positions, ChronoFork checks contacts and your game applies outcomes"><div class="diagram-title"><span class="dot"></span> THE GAME STAYS YOURS</div><div class="flow-card"><span class="step">01</span><div><strong>Your checked positions</strong><small>Character, ball, custom actor</small></div></div><div class="flow-arrow">↓ Track + Capture</div><div class="flow-card focus"><span class="step">02</span><div><strong>ChronoFork V3.2</strong><small>Covered time · allowed shape · contact</small></div></div><div class="flow-arrow">↓ Returned evidence</div><div class="flow-card"><span class="step">03</span><div><strong>Your gameplay rules</strong><small>Tackle, possession, damage, stun</small></div></div><p>Movement, animations, VFX and cutscenes stay in your existing systems.</p></div></section>
<section class="scope-note"><strong>A contact-validation branch.</strong> This package does not bundle original Chrono's replication framework or replace Chrono.Start(). <a href="comparison.html">Understand the difference →</a></section>
<section class="section"><div class="section-head"><div><p class="eyebrow">One small set of connections</p><h2>Built around your game's moves.</h2></div><a href="game-integration.html">See how to connect →</a></div><div class="feature-grid"><div class="feature"><span class="tag">SPORTS</span><h3>Tackles & ball contact</h3><p>Choose a gameplay box, sphere or capsule. Your rules decide possession, teams, immunity and fouls.</p></div><div class="feature"><span class="tag">MELEE</span><h3>Hit periods & cancellation</h3><p>Query during a server-approved move. End it when the move finishes or is cancelled. Keep your animation system.</p></div><div class="feature"><span class="tag">RAYS & SWEEPS</span><h3>Explicit obstacle policy</h3><p>Check rays and swept spheres. Add historical obstacle data if walls should block the move.</p></div></div></section>
<section class="section"><div class="section-head"><div><p class="eyebrow">Explain first. Then configure.</p><h2>A setup you can read.</h2></div><a href="start-here.html">Follow the six pages →</a></div><div class="showcase"><img src="assets/hitbox-3.1.jpg" alt="Actual V3.1 setup with an editable hitbox preview in Studio" loading="lazy"><div><h3>Plain words, visible shapes.</h3><p>The Studio plugin explains fields, shows a hitbox picture and lets you review generated code. Unknown terms have definitions and examples.</p><ul><li>50 terms, 48 Core messages and 18 Connector explanations</li><li>Decimal comma or point input</li><li>Undo, Redo, rollback and no overwriting</li><li>Disabled practice test using made-up data</li></ul><p class="small">Earlier V3.1 setup capture from the development lab; current 3.2 controls are documented below. The arena is not part of the download.</p><a href="help.html">Search words & result messages →</a></div></div></section>
<section class="section evidence"><p class="eyebrow">Recorded V3.1 validation · 21 Oct 2026</p><h2>Evidence you can inspect.</h2><div class="stat-grid"><div><strong>63 / 63</strong><span>unit tests passed</span></div><div><strong>8,192</strong><span>synthetic timeline scenarios passed</span></div><div><strong>15 / 15</strong><span>generated practice variants passed</span></div></div><p>Earlier V3.0 measurements include 6,000 engine geometry cases and 34,000 matched covered history queries. Those results retain their earlier labels. Synthetic timing is not native network testing; no real competitive game is certified.</p><div class="buttons"><a class="button" href="benchmarks.html">Methods & raw data →</a><a class="button" href="comparison.html">Original vs fork →</a></div></section>
<section class="section split"><div><p class="eyebrow">The tradeoff is explicit</p><h2>Refuse uncertain evidence.</h2><p>Missing records, large gaps and resets produce a refusal. A returned pose should not hide that the requested time was never covered.</p><p>That stricter contract has a cost: the earlier checked-history benchmark took about <strong>2.67×</strong> the query CPU time of the original transform query. They perform different work.</p></div><div class="limit-card"><h3>What still belongs to your game</h3><ul><li>Trustworthy movement and animated pose data</li><li>Valid input, cooldowns and replay prevention</li><li>Fair timing and obstacle rules</li><li>Exactly-once gameplay outcomes</li></ul><p>Sampled hitboxes are not full continuous movement simulation.</p><a href="math-and-limits.html">Read the ranked limitations →</a></div></section>
<section class="callout"><div><p class="eyebrow">Start small</p><h2>One move. One checked result.</h2><p>Run the practice, connect your first real move, then test its uncertain cases.</p></div><a class="button primary" href="start-here.html">Open the beginner guide →</a></section>'''
    connection_section = '''<section class="section"><div class="section-head"><div><p class="eyebrow">Earlier 3.1 combat example · 24 Oct 2026</p><h2>The plugin supplies the connecting machinery.</h2></div><a href="connections.html">Use ChronoConnect →</a></div><div class="feature-grid"><div class="feature"><span class="tag">CONNECT</span><h3>Objects, events and generated calls</h3><p>Choose existing actors, a position source and accepted-move points. Review edits before applying; keep unusual rules in supplied Hooks.</p></div><div class="feature"><span class="tag">EXISTING GAME</span><h3>Three generated call blocks</h3><p>The tested melee connection changed one original script. Six other original scripts stayed byte-identical. Movement mapping stayed inside the package.</p><a href="combat-walkthrough.html">Follow the exact combat example →</a></div><div class="feature"><span class="tag">RECORDED CHECKS</span><h3>80 / 80 integration cases</h3><p>Baseline comparisons, real combat inputs, refused moves and actual movement flows. One client, zero added delay and rewind off; no production certification.</p><a href="benchmarks.html">Inspect methods and case data →</a></div></div></section>'''
    latest_section = '<section class="section"><p class="eyebrow">Connector/plugin 3.2 · 25 Oct 2026</p><h2>Core capabilities, available in the plugin.</h2><p>Choose earlier-position timing, repeated move checks, simulation-controlled recording, data-only objects, per-object limits, named body areas, multiple moves and obstacle providers. Customize unusual rules inside supplied package files. Core math stays unchanged.</p><div class="stat-grid"><div><strong>550 / 550</strong><span>current integration checks passed</span></div><div><strong>160</strong><span>included randomized Core comparisons</span></div><div><strong>8 tabs</strong><span>connection controls</span></div></div><p>One Studio client and deterministic server scenarios. These are integration checks, not fresh original-Chrono CPU or native-network benchmarks.</p><div class="buttons"><a class="button primary" href="connector-controls.html">Full controls & upgrade guide →</a><a class="button" href="benchmarks.html">Integration validation & scope →</a></div></section>'
    home = home.replace('<section class="section evidence">', latest_section + connection_section + '<section class="section evidence">', 1)
    (site / 'index.html').write_text(shell('Checked contacts for competitive Roblox games', home, 'index.html', asset_versions=asset_versions), encoding='utf-8', newline='\n')
    help_data = json.loads((site / 'assets/help.json').read_text(encoding='utf-8'))
    message_source = (root / 'runtime/Messages.luau').read_text(encoding='utf-8-sig')
    connector_messages = {m.group(1): json.loads('[' + m.group(2) + ']') for m in re.finditer(r'^\s*([a-z_]+)=\{(.*)\},?$', message_source, re.M)}
    assert connector_messages, 'Connector help export is empty'
    (site / 'assets/connector-help.json').write_text(json.dumps({'version': '3.2.0', 'messages': connector_messages}, indent=2) + '\n', encoding='utf-8', newline='\n')
    terms = ''.join('<section class="help-card" data-kind="term"><p class="eyebrow">Word · ' + html.escape(row[0]) + '</p><h2>' + html.escape(row[1]) + '</h2><p>' + html.escape(row[2]) + '</p><p class="example"><strong>Example:</strong> ' + html.escape(row[3]) + '</p></section>' for row in help_data['terms'])
    messages = ''.join('<section class="help-card" data-kind="message" data-code="' + html.escape(code) + '"><p class="eyebrow">Core 3.1 result</p><h2><code>' + html.escape(code) + '</code></h2><h3>' + html.escape(row[0]) + '</h3><p>' + html.escape(row[1]) + '</p><p class="example"><strong>Next step:</strong> ' + html.escape(row[2]) + '</p></section>' for code, row in sorted(help_data['messages'].items()))
    messages += ''.join('<section class="help-card" data-kind="message" data-code="' + html.escape(code) + '"><p class="eyebrow">Connector 3.2 result</p><h2><code>' + html.escape(code) + '</code></h2><h3>' + html.escape(row[0]) + '</h3><p>' + html.escape(row[1]) + '</p><p class="example"><strong>Next step:</strong> ' + html.escape(row[2]) + '</p></section>' for code, row in sorted(connector_messages.items()))
    help_body = '<section class="help-head"><p class="eyebrow">50 words · 48 Core + 18 Connector messages</p><h1>Look up a word.<br>Understand a result.</h1><p>Search a term or paste a reason code. Explanations guide your next step; they do not approve a refused check. Source_/target_ prefixes can identify whose record failed.</p><label for="help-search">Word or result code</label><input id="help-search" type="search" placeholder="Try history, authoritative, target_sample_gap…" autocomplete="off"><div class="help-controls"><label for="help-kind">Show</label><select id="help-kind"><option value="all">Words and messages</option><option value="term">Words only</option><option value="message">Messages only</option></select><button id="help-clear" type="button">Clear search</button><span id="help-count" role="status" aria-live="polite">116 entries</span></div><p class="small">Core messages use unchanged Core 3.1 Help. Connector 3.2 adds its own explanations; shared codes are labeled by layer. Use Connector.Explain or Core.Explain as appropriate. Keep exact codes in logs. Unknown codes remain unknown.</p></section><div class="help-grid">' + terms + messages + '</div><p id="help-empty" hidden>No matching entry. Check the original reason code and the exact API. An unknown result is not automatically safe.</p>'
    (site / 'help.html').write_text(shell('Words & result messages', help_body, 'help.html', asset_versions=asset_versions), encoding='utf-8', newline='\n')
