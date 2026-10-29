import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('../public-site/index.html', import.meta.url), 'utf8');
const script = id => page.match(new RegExp(`<script[^>]*id="${id}"[^>]*>([\\s\\S]*?)</script>`))[1];
const data = JSON.parse(script('haw-calendar-data'));

function harness() {
  const elements = new Map(), events = {}, audio = [];
  function element(id = '') {
    return {id, hidden:false, disabled:false, textContent:'', dataset:{}, attrs:{}, listeners:{},
      firstChild:{textContent:''}, children:[], parentElement:{setAttribute() {}},
      setAttribute(key,value) { this.attrs[key] = value; },
      removeAttribute(key) { delete this.attrs[key]; },
      addEventListener(key,fn) { this.listeners[key] = fn; },
      replaceChildren(...items) { this.children = items; },
      toggleAttribute(key,on) { if (on) this.attrs[key] = ''; else delete this.attrs[key]; },
      append(item) { this.children.push(item); }, remove() { this.removed = true; },
      pause() { this.paused = true; }, load() {},
      play() { this.paused = false; return new Promise((resolve,reject) => { this.resolve = resolve; this.reject = reject; }); },
    };
  }
  const get = id => { if (!elements.has(id)) elements.set(id,element(id)); return elements.get(id); };
  get('haw-calendar-data').textContent = JSON.stringify(data);
  const seasons = ['akhet','peret','shemu'].map(season => ({...element(),dataset:{season}}));
  get('explore-the-year').querySelectorAll = () => seasons;
  const document = {hidden:false, getElementById:get,
    querySelectorAll: () => [get('brand-film'),get('flow-film')],
    createElement(type) { const result = element(); if (type === 'audio') audio.push(result); return result; },
    addEventListener(key,fn) { events['document:' + key] = fn; },
  };
  const location = {hash:''};
  let intersection;
  vm.runInNewContext(script('haw-calendar-controller'), {document,location,
    window:{addEventListener(key,fn) { events['window:' + key] = fn; }},
    IntersectionObserver:class { constructor(callback) { intersection = callback; } observe() {} },
  });
  return {get, data, audio, document, location, events, seasons,
    click: suffix => get('year-' + suffix).listeners.click(),
    outside: () => intersection([{isIntersecting:false}]),
  };
}

test('all 36 decans retain canonical order, descriptions, month and day boundaries', () => {
  const h = harness();
  for (let i=0;i<36;i++) {
    const d = data.decans[i], month = data.months[Math.floor(i/3)];
    assert.equal(h.get('year-decan-name').textContent,d.name);
    assert.equal(h.get('year-month-name').textContent,month.name);
    assert.equal(h.get('year-decan-position').textContent,`Decan ${String(i+1).padStart(2,'0')} of 36`);
    assert.equal(h.get('year-decan-days').textContent,`Days ${i%3*10+1}–${(i%3+1)*10}`);
    assert.deepEqual(Array.from(h.get('year-decan-prose').children,p=>p.textContent),d.paragraphs);
    assert.deepEqual(Array.from(h.get('year-month-prose').children,p=>p.textContent),month.paragraphs);
    h.click('decan-next');
  }
  assert.equal(h.get('year-decan-detail').hidden,true);
  assert.equal(h.get('year-threshold').hidden,false);
  assert.equal(h.get('year-month-name').textContent,'Heriu Renpet');
  assert.equal(h.get('year-decan-position').textContent,'Outside the 36 decans');
  h.click('decan-previous');
  assert.equal(h.get('year-decan-name').textContent,data.decans[35].name);
});

test('month navigation stays synchronized and the threshold explicitly begins again', () => {
  const h = harness();
  assert.equal(h.get('year-month-previous').disabled,true);
  assert.equal(h.get('year-decan-previous').disabled,true);
  for (let m=0;m<13;m++) {
    assert.equal(h.get('year-month-name').textContent,data.months[m].name);
    if (m<12) assert.equal(h.get('year-decan-name').textContent,data.decans[m*3].name);
    h.click('month-next');
  }
  assert.equal(h.get('year-month-name').textContent,data.months[0].name);
  h.click('month-next'); h.click('decan-previous');
  assert.equal(h.get('year-decan-name').textContent,data.decans[2].name);
  assert.equal(h.get('year-month-name').textContent,data.months[0].name);
  for(let i=0;i<34;i++) h.click('decan-next');
  assert.equal(h.get('year-month-name').textContent,'Heriu Renpet');
  h.click('decan-next');
  assert.equal(h.get('year-decan-name').textContent,data.decans[0].name);
});

test('recorded speech toggles, replaces previous playback, and ignores stale completion', async () => {
  const h = harness();
  const first = h.click('month-speech'), a = h.audio[0];
  assert.equal(h.get('brand-film').paused,true);
  assert.equal(h.get('flow-film').paused,true);
  assert.equal(a.src,data.months[0].audio);
  assert.equal(h.get('year-month-speech').attrs['aria-pressed'],'true');
  const second = h.click('decan-speech'), b = h.audio[1];
  assert.equal(a.paused,true); assert.equal(a.removed,true);
  assert.equal(b.src,data.decans[0].audio);
  a.reject(new Error('superseded')); await first;
  assert.equal(h.get('year-audio-status').hidden,true);
  assert.equal(h.get('year-decan-speech').attrs['aria-pressed'],'true');
  b.resolve(); await second; b.listeners.ended();
  assert.equal(h.get('year-decan-speech').attrs['aria-pressed'],'false');
  const third = h.click('month-speech'); h.audio[2].resolve(); await third;
  await h.click('month-speech');
  assert.equal(h.audio[2].paused,true);
});

test('navigation, leaving the panel, hiding the page and contact stop audio', async () => {
  const actions = [h=>h.click('decan-next'),h=>h.click('month-next'),h=>h.outside(),
    h=>h.events['window:pagehide'](),h=>h.events['document:play']({target:{tagName:'VIDEO'}}),
    h=>{h.document.hidden=true;h.events['document:visibilitychange']();},
    h=>{h.location.hash='#contact';h.events['window:hashchange']();}];
  for (const action of actions) {
    const h=harness(),pending=h.click('month-speech'),a=h.audio[0];
    action(h); a.reject(new Error('cancelled')); await pending;
    assert.equal(a.paused,true); assert.equal(a.removed,true);
    assert.equal(h.get('year-month-speech').attrs['aria-pressed'],'false');
    assert.equal(h.get('year-audio-status').hidden,true);
  }
});

test('an unavailable recording restores the play button and permits a user retry', async () => {
  const h=harness(),pending=h.click('decan-speech');
  h.audio[0].reject(new Error('unavailable')); await pending;
  assert.equal(h.get('year-audio-status').hidden,false);
  assert.match(h.get('year-audio-status').textContent,/could not play/);
  assert.equal(h.get('year-decan-speech').attrs['aria-pressed'],'false');
  const retry=h.click('decan-speech');h.audio[1].resolve();await retry;
  assert.equal(h.get('year-audio-status').hidden,true);
});

test('pronunciation audio does not stop itself when its own play event is captured',async()=>{
  const h=harness(),pending=h.click('month-speech'),a=h.audio[0];
  h.events['document:play']({target:{tagName:'AUDIO'}});
  assert.equal(h.get('year-month-speech').attrs['aria-pressed'],'true');
  assert.equal(a.paused,false);
  a.resolve();await pending;
  h.events['document:play']({target:{tagName:'VIDEO'}});
  assert.equal(h.get('year-month-speech').attrs['aria-pressed'],'false');
  assert.equal(a.paused,true);
});

test('the opening is first-visit only, reduced-motion safe, and leaves deep links alone', () => {
  function visit({seen=false,reduced=false,hash='',storageFails=false}={}) {
    const classes=[],saved=[];
    vm.runInNewContext(script('haw-opening-visit'),{
      matchMedia:()=>({matches:reduced}),location:{hash},
      document:{documentElement:{classList:{add:value=>classes.push(value)}}},
      localStorage:{getItem(){if(storageFails)throw Error();return seen?'seen':null;},setItem:(...args)=>saved.push(args)},
    });return {classes,saved};
  }
  assert.deepEqual(visit().classes,['haw-opening']);
  assert.deepEqual(visit({seen:true}).classes,[]);
  assert.deepEqual(visit({reduced:true}).classes,[]);
  assert.deepEqual(visit({hash:'#explore-the-year'}).classes,[]);
  assert.deepEqual(visit({hash:'#contact'}).classes,[]);
  assert.deepEqual(visit({storageFails:true}).classes,['haw-opening']);
});
