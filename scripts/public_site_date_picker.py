"""Website date wheels based on the app's Calendar math and Stone Register picker."""
from __future__ import annotations

import hashlib
import html
from datetime import date
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MATH_OWNER = 'lib/features/calendar/calendar_flow_models.dart'
EPOCH_OWNER = 'lib/features/calendar/kemetic_time_constants.dart'
PICKER_OWNER = 'lib/widgets/gregorian_date_picker.dart'
THEME_OWNER = 'lib/shared/date_picker/stone_register_date_picker_theme.dart'


def app_sources(root: Path = ROOT) -> tuple[str, str]:
    source = (root / MATH_OWNER).read_text()
    match = re.search(r'^class KemeticMath \{.*?^\}', source, re.M | re.S)
    if not match:
        raise ValueError('The canonical Calendar math owner changed.')
    return (root / EPOCH_OWNER).read_text(), match[0]


def metadata(root: Path = ROOT) -> tuple[dict, dict]:
    epoch, math = app_sources(root)
    picker = (root / PICKER_OWNER).read_text()
    theme = (root / THEME_OWNER).read_text()
    cycle = [int(v) for v in re.search(r'_cycle = \[([^]]+)\]', math)[1].split(',')]
    names = re.search(r'_gregMonthNames = \[(.*?)\];', picker, re.S)[1]
    names = [name for name in re.findall(r"'([^']*)'", names) if name]
    row = float(re.search(r'rowHeight = ([\d.]+)', theme)[1])
    visible = int(re.search(r'visibleRows = (\d+)', theme)[1])
    radius = int(re.search(r'yearStart: now.year - (\d+)', picker)[1])
    count = int(re.search(r'this.yearCount = (\d+)', picker)[1])
    if cycle != [365, 365, 366, 365] or len(names) != 12 or row != 48 or visible != 5 or count != radius * 2 + 1:
        raise ValueError('Review the website date picker against the changed app contract.')
    data = dict(epoch=[int(re.search(rf'kEpoch{part} = (\d+)', epoch)[1]) for part in ('Year', 'Month', 'Day')],
                cycle=cycle, gregorianMonths=names, yearRadius=radius, rowHeight=int(row))
    sources = {EPOCH_OWNER: epoch, MATH_OWNER + '#KemeticMath': math,
               PICKER_OWNER: picker, THEME_OWNER: theme}
    provenance = {name: hashlib.sha256(body.encode()).hexdigest() for name, body in sources.items()}
    return data, provenance


def write_oracle(destination: Path, *, first_year: int | None = None, last_year: int | None = None) -> None:
    """Execute the actual, unmodified Dart owner as an independent daily oracle."""
    epoch, math = app_sources()
    radius = metadata()[0]['yearRadius']
    first_year = first_year if first_year is not None else date.today().year - radius
    last_year = last_year if last_year is not None else date.today().year + radius
    program = "import 'dart:convert';\n" + epoch + '\n' + math + f'''
void main() {{
  final rows = <List<int>>[];
  for (var date = DateTime.utc({first_year}, 1, 1);
       date.isBefore(DateTime.utc({last_year + 1}, 1, 1));
       date = date.add(const Duration(days: 1))) {{
    final k = KemeticMath.fromGregorian(date);
    rows.add([date.year, date.month, date.day, k.kYear, k.kMonth, k.kDay]);
  }}
  print(jsonEncode(rows));
}}
'''
    entry = destination.with_suffix('.dart')
    entry.write_text(program)
    dart = shutil.which('dart')
    if not dart:
        raise ValueError('The installed Dart SDK is required to verify app date parity.')
    bundled = Path(dart).resolve().parent / 'cache/dart-sdk/bin/dart'
    if bundled.is_file():
        dart = str(bundled)
    with destination.open('w') as output:
        subprocess.run([dart, str(entry)], stdout=output, check=True)


CSS = '''
.year-date-picker{border:1px solid #b795573d;border-radius:12px;background:#100e0a;margin-bottom:38px;overflow:hidden}
.year-date-heading{padding:24px 30px 0;display:flex;align-items:center;justify-content:space-between;gap:20px}.year-date-heading h3{font:30px/1.15 var(--serif);color:#eee0c6}.year-date-heading>button{min-height:44px;padding:8px 14px;border:1px solid #b7955740;border-radius:30px;font-size:12px;color:#d5b77e;white-space:nowrap}
.year-date-pair{display:grid;grid-template-columns:minmax(0,1fr) 54px minmax(0,1fr);align-items:center;padding:24px 30px 28px;gap:24px}
.year-date-label{font-size:11px;line-height:1.6;letter-spacing:.14em;text-transform:uppercase;margin-bottom:14px;color:#a6e2f4}.year-date-label span{display:block;letter-spacing:0;text-transform:none;font-size:13px;color:#a89c86;margin-top:4px}
.year-date-columns{display:grid;grid-template-columns:5fr 3fr 4fr;gap:4px;border:1px solid #2e2616;border-radius:6px;background:linear-gradient(#191309,#110d07);position:relative;padding-inline:10px}
.year-date-columns:before{content:"";position:absolute;top:96px;height:48px;left:8px;right:8px;border-block:1px solid #6fc9e84a;background:linear-gradient(90deg,#6fc9e808,#6fc9e818,#6fc9e808);pointer-events:none}
.year-date-wheel{height:240px;overflow-y:auto;overscroll-behavior:contain;scroll-snap-type:y mandatory;scrollbar-width:none;padding-block:96px;position:relative;mask-image:linear-gradient(transparent,#000 30%,#000 70%,transparent)}
.year-date-wheel::-webkit-scrollbar{display:none}.year-date-wheel[data-static]{padding:0}.year-date-wheel:focus-visible{outline:2px solid #6fc9e8;outline-offset:-2px;border-radius:4px}
.year-date-option{height:48px;display:flex;align-items:center;justify-content:center;scroll-snap-align:center;font:23px/1 var(--serif);color:#9e9a94;cursor:pointer;white-space:nowrap}.year-date-option[aria-selected="true"]{font-size:28px;color:#a6e2f4}.year-date-wheel[data-date-field="month"] .year-date-option{font-size:20px}.year-date-wheel[data-date-field="month"] .year-date-option[aria-selected="true"]{font-size:23px}
.year-date-gregorian{font-size:13px;line-height:1.6;color:#b6a68a;margin-top:13px;min-height:21px}.year-date-bridge{font:34px/1 var(--serif);color:#b59b66;text-align:center;pointer-events:none}
.year-date-kemetic{align-self:stretch;display:flex;flex-direction:column;justify-content:center;padding:22px 30px;border:1px solid #d4ae432e;border-radius:8px;background:radial-gradient(ellipse at 50% 35%,#d4ae4315,transparent 80%),#15120b;text-align:center;min-width:0}
.year-date-kemetic .year-date-label{color:#e8c868}.year-date-output{display:block;color:#e8c868}.year-date-output strong{display:block;font:84px/.95 var(--serif);font-weight:400}.year-date-output span{display:block;font:36px/1.15 var(--serif);margin-top:8px;overflow-wrap:anywhere}.year-date-context{font-size:12px;line-height:1.65;color:#bda781;margin-top:16px}.year-date-caption{font:italic 22px/1.3 var(--serif);color:#d1c09b;margin:18px 0}
.year-date-days{display:flex;align-items:center;justify-content:space-between;gap:18px;border-top:1px solid #b7955730;padding-top:10px;margin-top:auto}.year-date-days button{min-height:44px;min-width:44px;color:#e1cba2;font-size:12px}.year-date-days button:disabled{opacity:.3;cursor:default}
@media(max-width:1000px){.year-date-pair{gap:14px;grid-template-columns:minmax(0,1fr) 26px minmax(0,1fr);padding-inline:24px}.year-date-kemetic{padding:20px}.year-date-output span{font-size:30px}}
@media(max-width:650px){.year-date-heading{padding:22px 20px 0;align-items:start;gap:12px}.year-date-heading h3{font-size:27px;max-width:180px}.year-date-heading>button{padding-inline:10px;font-size:11px}.year-date-pair{grid-template-columns:1fr;gap:16px;padding:24px 20px 20px}.year-date-bridge{font-size:28px;transform:rotate(90deg);height:25px}.year-date-kemetic{padding:23px 20px 14px}.year-date-output strong{font-size:64px}.year-date-output span{font-size:32px}.year-date-caption{margin:14px 0}.year-date-days{margin-top:10px}.year-date-picker{margin-bottom:30px}}
@media(max-width:360px){.year-date-heading{padding-inline:16px}.year-date-heading h3{font-size:24px}.year-date-pair{padding-inline:16px}.year-date-columns{padding-inline:6px}.year-date-wheel[data-date-field="month"] .year-date-option{font-size:18px}.year-date-wheel[data-date-field="month"] .year-date-option[aria-selected="true"]{font-size:21px}}
.year-month-star:disabled{opacity:.3;cursor:default}
@media(max-width:650px){.year-date-bridge{width:30px;justify-self:center}.year-date-output{display:flex;justify-content:center;align-items:baseline;gap:12px;flex-wrap:wrap}.year-date-output span{margin-top:0;max-width:100%}.year-date-kemetic .year-date-label span{display:none}.year-date-caption{font-size:20px;margin:12px 0}.year-date-context{margin-top:10px}}
'''


def markup() -> str:
    wheels = []
    samples = [('month', 'Gregorian month', ['January', 'February', 'March', 'April', 'May']),
               ('day', 'Gregorian day', ['18', '19', '20', '21', '22']),
               ('year', 'Gregorian year', ['2023', '2024', '2025', '2026', '2027'])]
    for field, label, values in samples:
        options = ''.join(f'<div class="year-date-option" role="option" aria-selected="{str(i == 2).lower()}">{html.escape(value)}</div>' for i,value in enumerate(values))
        wheels.append(f'<div class="year-date-wheel" id="year-date-{field}" data-date-field="{field}" data-static role="listbox" aria-label="{label}" tabindex="0">{options}</div>')
    return f'''<div class="year-date-picker" aria-labelledby="year-date-title">
<div class="year-date-heading"><h3 id="year-date-title">One day. Two rhythms.</h3><button type="button" id="year-date-today">Back to today</button></div>
<div class="year-date-pair"><div><p class="year-date-label">Gregorian<span>Scroll a month, day, or year.</span></p><div class="year-date-columns">{''.join(wheels)}</div><p class="year-date-gregorian" id="year-date-gregorian">March 20, 2025</p></div>
<div class="year-date-bridge" aria-hidden="true">↔</div><div class="year-date-kemetic"><p class="year-date-label">Kemetic<span>The same day, through another calendar.</span></p><output class="year-date-output" id="year-date-output"><strong id="year-date-kday">1</strong><span id="year-date-kmonth">Thoth</span></output><p class="year-date-context" id="year-date-context">Akhet · Decan 01 · Day 1 of 10</p><p class="year-date-caption">Same day. A different rhythm.</p><div class="year-date-days"><button type="button" id="year-date-previous" aria-label="Previous Gregorian day">← Previous day</button><button type="button" id="year-date-next" aria-label="Next Gregorian day">Next day →</button></div></div></div>
<p class="year-live" id="year-date-announcement" role="status" aria-live="polite" aria-atomic="true"></p></div>'''


# This is a direct browser translation of KemeticMath.fromGregorian, including
# its pre-epoch cycle behavior. Daily parity is checked against that Dart owner.
CONTROLLER = r'''function hawKemeticFromGregorian(year, month, day, rules) {
  const diff = Math.trunc((Date.UTC(year, month - 1, day) - Date.UTC(...[rules.epoch[0], rules.epoch[1] - 1, rules.epoch[2]])) / 86400000);
  const cycle = rules.cycle, cycleSum = cycle.reduce((a, b) => a + b, 0);
  function result(kYear, dayOfYear) {
    return {kYear, kMonth:dayOfYear < 360 ? Math.floor(dayOfYear / 30) + 1 : 13,
      kDay:dayOfYear < 360 ? dayOfYear % 30 + 1 : dayOfYear - 360 + 1};
  }
  if (diff >= 0) {
    const cycles = Math.floor(diff / cycleSum);
    let kYear = 1 + cycles * 4, rem = diff - cycles * cycleSum, index = 0;
    while (rem >= cycle[index]) { rem -= cycle[index]; kYear++; index = (index + 1) & 3; }
    return result(kYear, rem);
  }
  let rem = (-diff - 1) % cycleSum;
  const reverse = [...cycle].reverse();
  for (let i = 0; i < 4; i++) {
    if (rem < reverse[i]) return result(0 - i, reverse[i] - 1 - rem);
    rem -= reverse[i];
  }
  return {kYear:-3, kMonth:13, kDay:1};
}

function createHawDatePicker({rules, months, onChange}) {
  const byId = name => document.getElementById('year-date-' + name);
  const dayMs = 86400000, rowHeight = rules.rowHeight;
  const now = new Date(), firstYear = now.getFullYear() - rules.yearRadius, lastYear = now.getFullYear() + rules.yearRadius;
  const utcDay = (year, month, day) => Date.UTC(year, month - 1, day) / dayMs;
  const minimum = utcDay(firstYear, 1, 1), maximum = utcDay(lastYear, 12, 31);
  const daysInMonth = (year, month) => new Date(Date.UTC(year, month, 0)).getUTCDate();
  const pad = n => String(n).padStart(2, '0');
  const views = Object.fromEntries(['month', 'day', 'year'].map(field => [field, {element:byId(field), options:[], timer:null, index:0}]));
  let selected = utcDay(now.getFullYear(), now.getMonth() + 1, now.getDate());
  function civil() {
    const d = new Date(selected * dayMs);
    return {year:d.getUTCFullYear(), month:d.getUTCMonth() + 1, day:d.getUTCDate()};
  }
  function kemetic() { const d = civil(); return hawKemeticFromGregorian(d.year, d.month, d.day, rules); }
  function yearStart() { const k = kemetic(); return selected - ((k.kMonth - 1) * 30 + k.kDay - 1); }
  function canSelectPosition(position) { const target = yearStart() + position * 10; return target >= minimum && target <= maximum; }
  function render(announce) {
    const d = civil(), k = kemetic();
    const values = {month:rules.gregorianMonths, day:Array.from({length:daysInMonth(d.year,d.month)}, (_, i) => String(i + 1)), year:Array.from({length:lastYear - firstYear + 1}, (_, i) => String(firstYear + i))};
    const indexes = {month:d.month - 1, day:d.day - 1, year:d.year - firstYear};
    for (const [field, view] of Object.entries(views)) {
      clearTimeout(view.timer);
      if (view.options.length !== values[field].length) {
        view.options = values[field].map((value, index) => {
          const option = document.createElement('div'); option.className = 'year-date-option';
          option.id = 'year-date-' + field + '-option-' + index; option.dataset.dateIndex = String(index);
          option.setAttribute('role', 'option'); option.textContent = value; return option;
        });
        view.element.replaceChildren(...view.options);
      }
      view.index = indexes[field];
      view.options.forEach((option, index) => option.setAttribute('aria-selected', String(index === view.index)));
      view.element.removeAttribute('data-static');
      view.element.setAttribute('aria-activedescendant', view.options[view.index].id);
      view.element.scrollTop = view.index * rowHeight;
    }
    const gregorian = rules.gregorianMonths[d.month - 1] + ' ' + d.day + ', ' + d.year;
    byId('gregorian').textContent = gregorian;
    byId('kday').textContent = String(k.kDay); byId('kmonth').textContent = months[k.kMonth - 1].name;
    const season = months[k.kMonth - 1].season;
    byId('context').textContent = k.kMonth === 13 ? 'Day ' + k.kDay + ' between years · Outside the 36 decans' :
      season[0].toUpperCase() + season.slice(1) + ' · Decan ' + pad((k.kMonth - 1) * 3 + Math.floor((k.kDay - 1) / 10) + 1) + ' · Day ' + ((k.kDay - 1) % 10 + 1) + ' of 10';
    byId('previous').disabled = selected <= minimum; byId('next').disabled = selected >= maximum;
    if (announce) byId('announcement').textContent = gregorian + ' is ' + months[k.kMonth - 1].name + ' ' + k.kDay + '.';
    onChange(k, announce);
  }
  function selectDay(next, announce = true) { selected = Math.max(minimum, Math.min(maximum, next)); render(announce); }
  function choose(field, index) {
    const view = views[field];
    index = Math.max(0, Math.min(view.options.length - 1, index));
    if (index === view.index) return;
    const d = civil();
    if (field === 'month') d.month = index + 1;
    if (field === 'day') d.day = index + 1;
    if (field === 'year') d.year = firstYear + index;
    d.day = Math.min(d.day, daysInMonth(d.year, d.month));
    selectDay(utcDay(d.year, d.month, d.day));
  }
  for (const [field, view] of Object.entries(views)) {
    view.element.addEventListener('scroll', () => {
      clearTimeout(view.timer);
      view.timer = setTimeout(() => choose(field, Math.round(view.element.scrollTop / rowHeight)), 90);
    }, {passive:true});
    view.element.addEventListener('click', event => {
      const option = event.target.closest('[data-date-index]');
      if (option) { view.element.focus({preventScroll:true}); choose(field, Number(option.dataset.dateIndex)); }
    });
    view.element.addEventListener('keydown', event => {
      const changes = {ArrowDown:1, ArrowUp:-1, PageDown:10, PageUp:-10};
      if (!(event.key in changes) && event.key !== 'Home' && event.key !== 'End') return;
      event.preventDefault();
      choose(field, event.key === 'Home' ? 0 : event.key === 'End' ? view.options.length - 1 : view.index + changes[event.key]);
    });
  }
  byId('previous').addEventListener('click', () => selectDay(selected - 1));
  byId('next').addEventListener('click', () => selectDay(selected + 1));
  function today(announce = true) { const d = new Date(); selectDay(utcDay(d.getFullYear(), d.getMonth() + 1, d.getDate()), announce); }
  byId('today').addEventListener('click', () => today());
  window.addEventListener('pagehide', () => Object.values(views).forEach(view => clearTimeout(view.timer)));
  return {today, canSelectPosition, selectPosition(position) { if (canSelectPosition(position)) selectDay(yearStart() + position * 10); }};
}'''
