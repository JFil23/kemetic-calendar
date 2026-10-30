// Immutable timing reference from the user-supplied haw-find-your-decan.html.
// Full source SHA256: 265d98fb15acc5128e20e037f35f3a03a895798c986dfb47c60b857f3f01f587
function reveal() {
  if (state.busy) return;
  clearTimeout(wMonth.timer); clearTimeout(wDay.timer);
  state.month = wMonth.index; state.day = Math.min(wDay.index + 1, daysIn(state.month));
  const target = slotOf(dayNum(state.month, state.day));
  if (reduced) { land(target, true); return; }
  state.busy = true;
  const btn = $('reveal'); btn.setAttribute('aria-busy', 'true');
  const from = state.shown < 0 ? 0 : state.shown;
  const steps = 37 + ((target - from + 37) % 37);
  const base = 1500 / (steps * 3.4);
  cells.forEach(c => c.classList.remove('now'));
  let k = 0, prev = null;
  (function tick() {
    if (prev) prev.classList.remove('scan');
    k++;
    const cell = cells[(from + k) % 37];
    cell.classList.add('scan'); prev = cell;
    if (k >= steps) { setTimeout(() => { state.busy = false; btn.removeAttribute('aria-busy'); land(target, true); }, 120); return; }
    const t = k / steps;
    setTimeout(tick, base * (1 + 12 * Math.pow(t, 4)));
  })();
}

