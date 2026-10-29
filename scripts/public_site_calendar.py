#!/usr/bin/env python3
"""Export the app's authored calendar and recordings into the public website.

The website has no account state or speech provider. Its bounded year explorer
uses the canonical Dart descriptions/order and the app's default recorded voice.
"""
from __future__ import annotations

import hashlib
import html
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
OWNERS = (
    'lib/features/calendar/calendar_period_descriptions.dart',
    'lib/features/calendar/kemetic_month_metadata.dart',
    'lib/features/calendar/decan_metadata.dart',
    'lib/features/onboarding/onboarding_overlay.dart',
    'lib/widgets/pronounce_icon_button.dart',
    'lib/features/calendar/calendar_month_detail.dart',
    'lib/features/calendar/speech_resolver.dart',
    'lib/features/calendar/speech_overrides.dart',
    'config/speech_library.v1.json',
)
VISIT_KEY = 'haw:website:opening:v1'
ICON_ASSET = 'assets/d9865b671a09d683d13a863089d8825e0f61a37696ce5d7d448bc8023aa62453.otf'

OPENING = '''<script id="haw-opening-visit">
(() => {
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  let seen = false;
  try { seen = localStorage.getItem('haw:website:opening:v1') === 'seen'; } catch {}
  if (!seen && !motion.matches && (!location.hash || location.hash === '#top')) {
    document.documentElement.classList.add('haw-opening');
    try { localStorage.setItem('haw:website:opening:v1', 'seen'); } catch {}
  }
})();
</script>'''

CSS = '''<style id="haw-calendar-experience-style">
@font-face{font-family:HawSpeechIcons;src:url('/assets/d9865b671a09d683d13a863089d8825e0f61a37696ce5d7d448bc8023aa62453.otf') format('opentype');font-weight:400;font-style:normal;font-display:block}
/* Match HawIntroSlide's existing delays, durations and curves; retain the hero layout. */
@keyframes haw-opening-line{from{opacity:0}to{opacity:1}}
.haw-opening #hero-title>span{animation:haw-opening-line 80ms linear 700ms both}
.haw-opening #hero-title>span.rhythm{animation-duration:1100ms;animation-delay:2200ms;animation-timing-function:cubic-bezier(0,0,.58,1)}
.haw-opening #hero-title>span.how{animation-duration:1400ms;animation-delay:4200ms;animation-timing-function:cubic-bezier(0,0,.58,1)}
.calendar-explorer{background:radial-gradient(ellipse at 16% 25%,#b4924510,transparent 60%),#0b0906;border-block:1px solid var(--line)}
.calendar-explorer .section-head{margin-bottom:38px}
.calendar-explorer .section-copy{max-width:390px}
.year-seasons{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:20px;margin-bottom:28px}
.year-season{border-top:2px solid #d5b77e30;padding-top:12px;color:#ae9e85;display:flex;justify-content:space-between;gap:8px;font-size:12px;line-height:1.5}
.year-season span:last-child{opacity:.8}.year-season[data-season="akhet"][data-active]{border-color:var(--akhet);color:#b4d1dd}
.year-season[data-season="peret"][data-active]{border-color:var(--peret);color:#bfd6ad}.year-season[data-season="shemu"][data-active]{border-color:var(--shemu);color:#e5c67d}
.year-spread{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);border:1px solid #b795573d;border-radius:5px;background:#100e0a;overflow:hidden}
.year-leaf{min-width:0;display:flex;flex-direction:column;padding:34px 36px 24px}
.year-leaf+.year-leaf{border-left:1px solid #b795573d;background:#15120c}
.year-position{font-size:11px;line-height:1.6;letter-spacing:.14em;text-transform:uppercase;color:#ae9874;margin-bottom:24px;display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap}
.year-name-row{display:flex;align-items:center;gap:10px}
.year-name-row h3{font-family:var(--serif);font-size:clamp(28px,2.7vw,39px);line-height:1.15;min-width:0;overflow-wrap:anywhere;color:#eee0c6}
.year-pronounce{display:grid;place-items:center;flex:0 0 44px;width:44px;height:44px;border-radius:50%;color:#d5b77e}
.year-pronounce:hover{background:#d5b77e12}.year-pronounce span{font:22px/1 HawSpeechIcons;letter-spacing:normal;text-transform:none;white-space:nowrap;word-wrap:normal;direction:ltr;-webkit-font-smoothing:antialiased}
.year-pronounce .speech-stop{display:none}.year-pronounce[aria-pressed="true"] .speech-play{display:none}.year-pronounce[aria-pressed="true"] .speech-stop{display:block}
.year-transliteration{font-family:HawText,Georgia,serif;font-size:19px;line-height:1.5;color:#bda781;margin-top:7px;min-height:29px}
.year-theme{font-family:var(--serif);font-size:25px;line-height:1.3;color:#d5b77e;margin-top:26px;margin-bottom:18px}
.year-prose{font-size:15px;line-height:1.85;color:#c1b49e;flex:1}.year-prose p+p{margin-top:17px}
#year-decan-detail,#year-threshold{flex:1}
.year-pager{display:flex;justify-content:space-between;align-items:center;gap:12px;border-top:1px solid #b7955730;padding-top:18px;margin-top:28px}
.year-pager button{display:flex;align-items:center;gap:9px;min-height:44px;font-size:13px;line-height:1.4;color:#e1cba2;padding:6px 0}
.year-pager button:disabled{opacity:.3;cursor:default}.year-pager button:not(:disabled):hover{color:#fff0d3}
.year-pager .icon{width:17px;height:17px}.year-pager button:last-child{text-align:right;justify-content:flex-end}
.year-meta{display:flex;justify-content:space-between;align-items:start;gap:20px;margin-top:18px;font-size:12px;line-height:1.7;color:#ab9b82}
.year-meta a{text-decoration:underline;text-underline-offset:3px}.year-meta p{max-width:640px}
.year-live{position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%);white-space:nowrap}
#year-audio-status{font-size:13px;line-height:1.6;color:#e1cba2;margin-top:16px}
.year-threshold{padding-top:20px;color:#c1b49e;font-size:16px;line-height:1.8}.year-threshold h3{font-family:var(--serif);color:#e1cba2;font-size:34px;line-height:1.2;margin-bottom:20px}
.year-threshold p+p{margin-top:16px}
@media(max-width:900px){.year-leaf{padding:28px 26px 20px}.year-name-row h3{font-size:30px}.year-theme{font-size:23px}.year-season{display:block}.year-season span{display:block}}
@media(max-width:650px){.calendar-explorer .section-head{margin-bottom:30px}.year-spread{grid-template-columns:1fr}.year-leaf{padding:26px 23px 18px}.year-leaf+.year-leaf{border-left:0;border-top:1px solid #b795573d}.year-position{margin-bottom:19px}.year-name-row h3{font-size:32px}.year-theme{margin-top:22px;font-size:25px}.year-prose{font-size:15px;line-height:1.8}.year-seasons{gap:10px;margin-bottom:24px}.year-season{font-size:11px}.year-meta{display:block}.year-meta>p+p{margin-top:9px}.year-pager{margin-top:24px}.year-pager button{font-size:12px}}
@media(max-width:360px){.year-leaf{padding-inline:18px}.year-name-row h3{font-size:28px}.year-position{font-size:10px;letter-spacing:.1em}}
@media(prefers-reduced-motion:reduce){.haw-opening #hero-title>span{animation:none!important;opacity:1}}
</style>'''

# Exact Material glyphs used by PronounceIconButton: volume_up_rounded and
# stop_circle_outlined. Keep the font bytes; do not approximate either drawing.
SPEAKER = '<span class="speech-play" aria-hidden="true">&#xf029a;</span><span class="speech-stop" aria-hidden="true">&#xf3e9;</span>'


def sha(body: bytes) -> str:
    return hashlib.sha256(body).hexdigest()


def export_calendar(root: Path = ROOT) -> tuple[dict, dict[str, bytes], dict]:
    descriptions = (root / OWNERS[0]).read_text()
    month_section, decan_section = descriptions.split('const List<String> calendarDecanDescriptions = [', 1)
    months = {int(i): text.strip() for i, text in re.findall(r"(\d+): '''(.*?)'''", month_section, re.S)}
    decans = [text.strip() for text in re.findall(r"'''(.*?)'''", decan_section, re.S)]
    metadata = (root / OWNERS[1]).read_text()
    records = re.findall(r'KemeticMonth\((.*?)\n  \)', metadata.split('const List<KemeticMonth> kKemeticMonths = [', 1)[1], re.S)
    speech = json.loads((root / OWNERS[-1]).read_text())
    phrases = {alias: p['id'] for p in speech['phrases'] for alias in [p['id'], *p['aliases']]}
    icon_body = (root / 'public-site' / ICON_ASSET).read_bytes()
    if ICON_ASSET != f'assets/{sha(icon_body)}.otf':
        raise ValueError('The app speech-control icon font changed.')
    assets = {ICON_ASSET: icon_body}
    bindings = {}

    def clip(key: str) -> str:
        if key not in phrases:
            raise ValueError(f'Missing canonical pronunciation: {key}')
        asset = f'speech/library/G/{phrases[key]}.m4a'
        path = 'assets/' + asset
        body = (root / path).read_bytes()
        if sha(body) != speech['asset_sha256'][asset]:
            raise ValueError(f'Changed pronunciation recording: {key}')
        name = f'assets/{sha(body)}.m4a'
        assets[name] = body
        bindings[name] = path
        return '/' + name

    result = {'months': [], 'decans': []}
    for record in records:
        def field(name: str) -> str:
            match = re.search(rf"\b{name}: '([^']*)'", record)
            if not match:
                raise ValueError(f'Changed month metadata format: {name}')
            return match[1]
        identifier = int(re.search(r'\bid: (\d+)', record)[1])
        if identifier == 0:
            continue
        title, theme, *paragraphs = months[identifier].split('\n\n')[0].split('\n') + months[identifier].split('\n\n')[1:]
        season = re.search(r'season: KemeticSeason\.(\w+)', record)[1]
        result['months'].append(dict(id=identifier, name=field('displayShort'),
            transliteration=field('displayTransliteration'), season=season,
            sourceText=months[identifier], theme=theme, paragraphs=paragraphs,
            audio=clip(f'month-{identifier:02}')))
    names = (root / OWNERS[2]).read_text().split('static const Map<int, List<String>> decanNames = {', 1)[1].split('};', 1)[0]
    ordered = [name for _, values in re.findall(r"(\d+): \[(.*?)\]", names)
               for name in re.findall(r"'([^']+)'", values)]
    if len(result['months']) != 13 or sorted(months) != list(range(1, 14)) or len(decans) != 36 or len(ordered) != 36:
        raise ValueError('The complete canonical year is required: 13 month records and 36 decans.')
    for i, (name, text) in enumerate(zip(ordered, decans), 1):
        headings, *paragraphs = text.split('\n\n')
        title, theme = headings.split('\n')
        canonical_name, meaning = title.split(' — ', 1)
        if name != canonical_name:
            raise ValueError(f'Decan name/order differs from authored description: {i}')
        result['decans'].append(dict(id=i, month=(i - 1) // 3 + 1, name=name,
            meaning=meaning.strip('“”'), theme=theme, paragraphs=paragraphs,
            sourceText=text, audio=clip(f'decan-{i:02}-cue')))
    provenance = dict(owners={path: sha((root / path).read_bytes()) for path in OWNERS},
                      recordings=bindings, voice='G', attribution='elevenlabs.io')
    return result, assets, provenance


def paragraphs(items: list[str]) -> str:
    return ''.join('<p>' + html.escape(p) + '</p>' for p in items)


def pronounce(kind: str, name: str) -> str:
    return (f'<button class="year-pronounce" type="button" id="year-{kind}-speech" '
            f'aria-label="Play pronunciation: {html.escape(name, quote=True)}" '
            f'title="Play pronunciation" aria-pressed="false">{SPEAKER}</button>')


def panel(data: dict) -> str:
    month, decan = data['months'][0], data['decans'][0]
    return f'''<section class="section calendar-explorer" id="explore-the-year" aria-labelledby="year-title">
<div class="wrap"><div class="section-head"><div><p class="kicker">The year, at your pace</p><h2 id="year-title">Meet the <em>rhythm.</em></h2></div><p class="section-copy">Move through the months and decans. Read their meaning, and hear each name.</p></div>
<div class="year-seasons" aria-label="The three seasons"><div class="year-season" data-season="akhet" data-active><span>Akhet</span><span>Inundation</span></div><div class="year-season" data-season="peret"><span>Peret</span><span>Emergence</span></div><div class="year-season" data-season="shemu"><span>Shemu</span><span>Harvest</span></div></div>
<div class="year-spread"><article class="year-leaf" aria-labelledby="year-month-name"><p class="year-position"><span id="year-month-position">Month 01 of 12</span><span id="year-month-season">Akhet · Inundation</span></p>
<div class="year-name-row"><h3 id="year-month-name">{html.escape(month['name'])}</h3>{pronounce('month', month['name'])}</div><p class="year-transliteration" id="year-month-transliteration">{html.escape(month['transliteration'])}</p>
<p class="year-theme" id="year-month-theme">{html.escape(month['theme'].split(' · ', 1)[-1])}</p><div class="year-prose" id="year-month-prose">{paragraphs(month['paragraphs'])}</div>
<nav class="year-pager" aria-label="Browse months"><button type="button" id="year-month-previous" disabled><span aria-hidden="true">←</span> Previous month</button><button type="button" id="year-month-next">Next month <span aria-hidden="true">→</span></button></nav></article>
<article class="year-leaf" aria-labelledby="year-decan-name"><p class="year-position"><span id="year-decan-position">Decan 01 of 36</span><span id="year-decan-days">Days 1–10</span></p>
<div id="year-decan-detail"><div class="year-name-row"><h3 id="year-decan-name">{html.escape(decan['name'])}</h3>{pronounce('decan', decan['name'])}</div><p class="year-transliteration" id="year-decan-meaning">{html.escape(decan['meaning'])}</p><p class="year-theme" id="year-decan-theme">{html.escape(decan['theme'])}</p><div class="year-prose" id="year-decan-prose">{paragraphs(decan['paragraphs'])}</div></div>
<div class="year-threshold" id="year-threshold" hidden><h3 id="year-threshold-name">Between one year<br>and the next.</h3><p>Heriu Renpet stands outside the twelve counted months, after the year’s work has completed and before Wp Rnpt opens the cycle again.</p><p>These days belong to the threshold, outside the 36 decans.</p></div>
<nav class="year-pager" aria-label="Browse decans"><button type="button" id="year-decan-previous" disabled><span aria-hidden="true">←</span> Previous decan</button><button type="button" id="year-decan-next">Next decan <span aria-hidden="true">→</span></button></nav></article></div>
<div class="year-meta"><p>Three decans make a month. Twelve months carry the year to Heriu Renpet, the Days upon the Year.</p><p>Voice recordings · <a href="https://elevenlabs.io/" target="_blank" rel="noopener noreferrer">elevenlabs.io</a></p></div>
<p class="year-live" id="year-announcement" role="status" aria-live="polite" aria-atomic="true"></p><p id="year-audio-status" role="status" hidden></p>
</div></section>'''


def additions(data: dict, *, interactive: bool = True) -> dict[str, str]:
    encoded = json.dumps(data, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
    return dict(opening=OPENING, style=CSS, panel=panel(data),
                controller=(f'<script type="application/json" id="haw-calendar-data">{encoded}</script>\n'
                            f'<script id="haw-calendar-controller">\n{CONTROLLER}\n</script>') if interactive else '')


def insert(text: str, blocks: dict[str, str]) -> str:
    for before, after in (
        ('<title>', blocks['opening'] + '\n<title>'),
        ('</head>', blocks['style'] + '\n</head>'),
        ('<section class="section film-section"', blocks['panel'] + '\n\n<section class="section film-section"'),
        ('</body>', blocks['controller'] + '\n</body>'),
    ):
        if text.count(before) != 1:
            raise ValueError('Website calendar insertion boundary changed.')
        text = text.replace(before, after, 1)
    return text


def remove(text: str, blocks: dict[str, str]) -> str:
    for block in blocks.values():
        if block and text.count(block) != 1:
            raise ValueError('Website calendar differs from its recorded revision.')
    text = text.replace(blocks['opening'] + '\n<title>', '<title>', 1)
    text = text.replace(blocks['style'] + '\n</head>', '</head>', 1)
    text = text.replace(blocks['panel'] + '\n\n<section class="section film-section"', '<section class="section film-section"', 1)
    text = text.replace(blocks['controller'] + '\n</body>', '</body>', 1)
    return text


CONTROLLER = r'''(() => {
  'use strict';
  const section = document.getElementById('explore-the-year');
  const data = JSON.parse(document.getElementById('haw-calendar-data').textContent);
  const byId = name => document.getElementById('year-' + name);
  const seasons = {akhet:'Akhet · Inundation', peret:'Peret · Emergence', shemu:'Shemu · Harvest', transition:'Days upon the Year'};
  let position = 0, generation = 0, active = null;
  const pad = n => String(n).padStart(2, '0');
  function text(id, value) { byId(id).textContent = value; }
  function prose(id, paragraphs) {
    byId(id).replaceChildren(...paragraphs.map(value => {
      const p = document.createElement('p'); p.textContent = value; return p;
    }));
  }
  function speechLabel(button, name, playing) {
    button.setAttribute('aria-pressed', String(playing));
    button.setAttribute('aria-label', (playing ? 'Stop pronunciation: ' : 'Play pronunciation: ') + name);
    button.title = playing ? 'Stop' : 'Play pronunciation';
  }
  function stopAudio() {
    ++generation;
    if (!active) return;
    const old = active; active = null;
    old.audio.pause(); old.audio.removeAttribute('src'); old.audio.load(); old.audio.remove();
    speechLabel(old.button, old.name, false);
  }
  async function speak(kind) {
    const button = byId(kind + '-speech');
    if (active?.button === button) { stopAudio(); return; }
    stopAudio();
    const item = kind === 'month' ? data.months[Math.floor(position / 3)] : data.decans[position];
    if (!item) return;
    byId('audio-status').hidden = true;
    document.querySelectorAll('video').forEach(video => video.pause());
    const token = generation, audio = document.createElement('audio');
    audio.id = 'year-pronunciation-audio'; audio.preload = 'none'; audio.hidden = true; audio.src = item.audio;
    section.append(audio); active = {audio, button, name:item.name};
    speechLabel(button, item.name, true);
    function failed() {
      if (token !== generation) return;
      stopAudio();
      const status = byId('audio-status');
      status.textContent = 'This pronunciation could not play. Please try again.'; status.hidden = false;
    }
    audio.addEventListener('ended', () => { if (token === generation) stopAudio(); });
    audio.addEventListener('error', failed);
    try { await audio.play(); } catch { failed(); }
  }
  function render(announce = true) {
    stopAudio(); byId('audio-status').hidden = true;
    const month = data.months[Math.floor(position / 3)], decan = data.decans[position];
    text('month-position', month.id === 13 ? 'After the twelve months' : 'Month ' + pad(month.id) + ' of 12');
    text('month-season', seasons[month.season]); text('month-name', month.name);
    text('month-transliteration', month.transliteration);
    text('month-theme', month.theme.split(' · ').slice(1).join(' · '));
    prose('month-prose', month.paragraphs); speechLabel(byId('month-speech'), month.name, false);
    byId('month-previous').disabled = month.id === 1;
    byId('month-next').firstChild.textContent = month.id === 13 ? 'Begin again ' : month.id === 12 ? 'Days upon the Year ' : 'Next month ';
    section.querySelectorAll('[data-season]').forEach(el => el.toggleAttribute('data-active', el.dataset.season === month.season));
    byId('decan-detail').hidden = !decan; byId('threshold').hidden = !!decan;
    byId('decan-detail').parentElement.setAttribute('aria-labelledby', decan ? 'year-decan-name' : 'year-threshold-name');
    text('decan-position', decan ? 'Decan ' + pad(decan.id) + ' of 36' : 'Outside the 36 decans');
    text('decan-days', decan ? 'Days ' + ((position % 3) * 10 + 1) + '–' + ((position % 3 + 1) * 10) : 'Heriu Renpet');
    if (decan) {
      text('decan-name', decan.name); text('decan-meaning', decan.meaning); text('decan-theme', decan.theme);
      prose('decan-prose', decan.paragraphs); speechLabel(byId('decan-speech'), decan.name, false);
    }
    byId('decan-previous').disabled = position === 0;
    byId('decan-next').firstChild.textContent = !decan ? 'Begin again ' : position === 35 ? 'Days upon the Year ' : 'Next decan ';
    if (announce) text('announcement', month.name + (decan ? '. Decan ' + decan.id + ' of 36: ' + decan.name + ', ' + decan.meaning + '.' : '. Days upon the Year, outside the 36 decans.'));
  }
  function moveMonth(direction) {
    const month = Math.floor(position / 3);
    position = direction > 0 && month === 12 ? 0 : Math.max(0, Math.min(12, month + direction)) * 3;
    render();
  }
  function moveDecan(direction) {
    position = direction > 0 && position === 36 ? 0 : Math.max(0, Math.min(36, position + direction)); render();
  }
  byId('month-previous').addEventListener('click', () => moveMonth(-1));
  byId('month-next').addEventListener('click', () => moveMonth(1));
  byId('decan-previous').addEventListener('click', () => moveDecan(-1));
  byId('decan-next').addEventListener('click', () => moveDecan(1));
  byId('month-speech').addEventListener('click', () => speak('month'));
  byId('decan-speech').addEventListener('click', () => speak('decan'));
  window.addEventListener('pagehide', stopAudio);
  window.addEventListener('hashchange', () => { if (location.hash === '#contact') stopAudio(); });
  document.addEventListener('visibilitychange', () => { if (document.hidden) stopAudio(); });
  document.addEventListener('play', event => { if (event.target.tagName === 'VIDEO') stopAudio(); }, true);
  document.addEventListener('click', event => { if (event.target.closest('[data-preview]')) stopAudio(); });
  if (typeof IntersectionObserver !== 'undefined') new IntersectionObserver(entries => {
    if (!entries[0].isIntersecting) stopAudio();
  }).observe(section);
  render(false);
})();'''
