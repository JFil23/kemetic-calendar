import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('../public-site/index.html', import.meta.url), 'utf8');
const script = id => page.match(new RegExp(`<script[^>]*id="${id}"[^>]*>([\\s\\S]*?)</script>`))[1];
const data = JSON.parse(script('haw-calendar-data'));

function assetBytes(path) {
  assert.match(path,/^\/assets\/[a-f0-9]{64}\.m4a$/,'Pronunciation must use an approved local recording');
  return readFileSync(new URL('../public-site'+path,import.meta.url));
}

function harness({deferFetch=false,autoReveal=true,reduced=true,storage=new Map(),storageDenied=false}={}) {
  const elements = new Map(), events = {}, audio = [], timers = new Map(), requests=[],blobs=[],revoked=[];
  let clock=0;
  function advance() {
    const entry=[...timers].sort((a,b)=>a[1].at-b[1].at)[0];
    if(!entry)return null;
    const [id,timer]=entry;timers.delete(id);clock=timer.at;timer.fn();return timer.delay;
  }
  function element(id = '') {
    const classes=new Set();
    return {classList:{add:(...names)=>names.forEach(n=>classes.add(n)),remove:(...names)=>names.forEach(n=>classes.delete(n)),contains:n=>classes.has(n)}, getClientRects(){return [{}];}, scrollIntoView() {}, id, hidden:false, disabled:false, paused:true, textContent:'', dataset:{}, attrs:{}, listeners:{},
      firstChild:{textContent:''}, children:[], parentElement:{setAttribute() {}},
      setAttribute(key,value) { this.attrs[key] = value; },
      removeAttribute(key) { delete this.attrs[key]; },
      addEventListener(key,fn) {
        const previous=this.listeners[key];
        const wrapped=(...args)=>{const result=fn(...args);if(autoReveal&&key==='keydown'&&/^year-date-(month|day|year)$/.test(id))get('year-reveal').listeners.click();return result;};
        this.listeners[key]=previous?(...args)=>{previous(...args);return wrapped(...args);}:wrapped;
      },
      replaceChildren(...items) { this.children = items; },
      toggleAttribute(key,on) { if (on) this.attrs[key] = ''; else delete this.attrs[key]; },
      append(item) { this.children.push(item); }, remove() { this.removed = true; },
      pause() { this.paused = true; }, load() {},
      focus() {},
      play() { this.paused = false; return new Promise((resolve,reject) => { this.resolve = resolve; this.reject = reject; }); },
    };
  }
  const get = id => {
    assert.ok(page.includes(`id="${id}"`), `The shipped page must contain ${id}`);
    if (!elements.has(id)) elements.set(id,element(id));
    return elements.get(id);
  };
  get('haw-calendar-data').textContent = JSON.stringify(data);
  const seasons = ['akhet','peret','shemu'].map(season => ({...element(),dataset:{season}}));
  const monthStars = Array.from({length:13},(_,i)=>({...element(),dataset:{yearMonth:String(i)}}));
  const decanStars = Array.from({length:3},(_,i)=>({...element(),dataset:{yearDecan:String(i)}}));
  const discoveryBars=Array.from({length:37},(_,i)=>({...element(),dataset:{discoverySlot:String(i)}}));
  get('explore-the-year').querySelector=()=>element();
  get('explore-the-year').querySelectorAll = selector => selector === '[data-year-month]' ? monthStars : selector === '[data-year-decan]' ? decanStars : selector==='[data-discovery-slot]'?discoveryBars:seasons;
  const document = {hidden:false, getElementById:get,
    querySelectorAll: () => [get('brand-film'),get('flow-film')],
    createElement(type) { const result = element(); if (type === 'audio') audio.push(result); return result; },
    addEventListener(key,fn) {const previous=events['document:'+key];events['document:'+key]=previous?(...args)=>{previous(...args);return fn(...args);}:fn;},
  };
  const location = {hash:''};
  let intersection;
  const context={document,location,matchMedia:query=>({matches:query.includes('reduced-motion')&&reduced}),
    Blob, URL:{createObjectURL(blob){const url='blob:haw-'+(blobs.length+1);blobs.push({url,blob});return url;},revokeObjectURL:url=>revoked.push(url)},
    fetch(path) {
      const request={path};requests.push(request);
      return new Promise((resolve,reject)=>{
        request.resolve=response=>resolve(response??{ok:true,arrayBuffer:async()=>assetBytes(path)});
        request.reject=reject;
        if(!deferFetch)request.resolve();
      });
    },
    Date:class extends Date { constructor(...args) { super(...(args.length ? args : [2025,2,20])); } },
    setTimeout(fn,delay=0) { const id=Symbol();timers.set(id,{fn,delay,at:clock+delay});return id; }, clearTimeout(id) { timers.delete(id); },
    window:{localStorage:{getItem(key){if(storageDenied)throw Error('Unavailable');return storage.get(key)??null;},setItem(key,value){if(storageDenied)throw Error('Unavailable');storage.set(key,value);}},addEventListener(key,fn) { const previous=events['window:'+key];events['window:'+key]=previous?(...args)=>{previous(...args);fn(...args);}:fn; }},
    IntersectionObserver:class { constructor(callback) { intersection = callback; } observe() {} },
  };
  vm.runInNewContext(script('haw-date-picker-logic')+'\n'+script('haw-calendar-controller'),context);
  return {get, data, audio, document, location, events, seasons,monthStars,decanStars,requests,blobs,revoked,storage,discoveryBars,
    ready:()=>new Promise(resolve=>setImmediate(resolve)),
    convert:context.hawKemeticFromGregorian,
    pick:(field,index)=>{get('year-date-'+field).listeners.click({target:{closest:()=>({dataset:{dateIndex:String(index)}})}});if(autoReveal)get('year-reveal').listeners.click();},
    advance,
    flush:()=>{let limit=1000;while(timers.size){assert.ok(limit-->0,'Timers must settle');advance();}if(autoReveal)get('year-reveal').listeners.click();},
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
    assert.equal(h.get('year-month-day').textContent,String(i%3*10+1));
    assert.equal(h.get('year-decan-position').textContent,`Decan ${String(i+1).padStart(2,'0')} of 36`);
    assert.equal(h.get('year-decan-days').textContent,`Days ${i%3*10+1}–${(i%3+1)*10}`);
    assert.deepEqual(Array.from(h.get('year-decan-prose').children,p=>p.textContent),d.paragraphs);
    assert.deepEqual(Array.from(h.get('year-month-prose').children,p=>p.textContent),month.paragraphs);
    h.click('decan-next');
  }
  assert.equal(h.get('year-decan-detail').hidden,true);
  assert.equal(h.get('year-threshold').hidden,false);
  assert.equal(h.get('year-month-name').textContent,'Heriu Renpet');
  assert.equal(h.get('year-month-day').textContent,'1');
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

test('Gregorian date wheels clamp month lengths and keep the Kemetic cards synchronized',()=>{
  const h=harness();
  h.pick('month',0);h.pick('day',30);
  assert.equal(h.get('year-date-gregorian').textContent,'January 31, 2025');
  h.pick('year',203);h.pick('month',1);
  assert.equal(h.get('year-date-gregorian').textContent,'February 29, 2028');
  assert.equal(h.get('year-date-day').children.length,29);
  h.pick('year',204);
  assert.equal(h.get('year-date-gregorian').textContent,'February 28, 2029');
  assert.equal(h.get('year-date-day').children.length,28);
  const k=h.convert(2029,2,28,data.dateConversion);
  assert.equal(h.get('year-month-name').textContent,data.months[k.kMonth-1].name);
  assert.equal(h.get('year-month-day').textContent,String(k.kDay));
  assert.equal(h.get('year-date-announcement').textContent,`February 28, 2029 is ${data.months[k.kMonth-1].name} ${k.kDay}.`);
  assert.equal(h.get('year-decan-name').textContent,data.decans[(k.kMonth-1)*3+Math.floor((k.kDay-1)/10)].name);
});

test('date scrolling, keyboard input, day stepping and today share one selection',()=>{
  const h=harness(),day=h.get('year-date-day');
  day.scrollTop=20*48;day.listeners.scroll();h.flush();
  assert.equal(h.get('year-date-gregorian').textContent,'March 21, 2025');
  assert.equal(h.get('year-month-day').textContent,'2');
  day.listeners.keydown({key:'ArrowDown',preventDefault(){}});
  assert.equal(h.get('year-date-gregorian').textContent,'March 22, 2025');
  assert.equal(h.get('year-month-day').textContent,'3');
  day.listeners.keydown({key:'ArrowUp',preventDefault(){}});
  assert.equal(h.get('year-date-gregorian').textContent,'March 21, 2025');
  h.get('year-date-today').listeners.click();
  assert.equal(h.get('year-date-gregorian').textContent,'March 20, 2025');
  assert.equal(h.get('year-month-day').textContent,'1');
  assert.equal(h.get('year-decan-name').textContent,data.decans[0].name);
  h.click('decan-next');
  assert.equal(h.get('year-date-gregorian').textContent,'March 30, 2025');
  assert.equal(h.get('year-month-day').textContent,'11');
});

test('sixth day between years and the New Year match the app and range boundaries remain coherent',()=>{
  const h=harness();h.pick('year',203);h.pick('month',2);h.pick('day',18);
  assert.equal(h.get('year-date-gregorian').textContent,'March 19, 2028');
  assert.equal(h.get('year-month-name').textContent,'Heriu Renpet');
  assert.equal(h.get('year-month-day').textContent,'6');
  assert.equal(h.get('year-date-announcement').textContent,'March 19, 2028 is Heriu Renpet 6.');
  assert.equal(h.get('year-threshold').hidden,false);
  h.get('year-date-day').listeners.keydown({key:'ArrowDown',preventDefault(){}});
  assert.equal(h.get('year-date-gregorian').textContent,'March 20, 2028');
  assert.equal(h.get('year-month-name').textContent,'Thoth');
  assert.equal(h.get('year-month-day').textContent,'1');
  assert.equal(h.get('year-date-announcement').textContent,'March 20, 2028 is Thoth 1.');
  assert.equal(h.get('year-decan-name').textContent,data.decans[0].name);
  assert.equal(h.get('year-threshold').hidden,true);
  h.pick('year',0);h.pick('month',0);h.pick('day',0);
  assert.equal(h.get('year-date-day').children[0].attrs['aria-selected'],'true');
  assert.ok(h.monthStars.some(button=>button.disabled));
  for (const field of ['day','month','year']) h.get('year-date-'+field).listeners.keydown({key:'ArrowUp',preventDefault(){}});
  assert.equal(h.get('year-date-gregorian').textContent,'January 1, 1825');
  h.pick('year',400);h.pick('month',11);h.pick('day',30);
  assert.equal(h.get('year-date-day').children[30].attrs['aria-selected'],'true');
  for (const field of ['day','month','year']) h.get('year-date-'+field).listeners.keydown({key:'ArrowDown',preventDefault(){}});
  assert.equal(h.get('year-date-gregorian').textContent,'December 31, 2225');
});

test('browser conversion matches the actual app Dart oracle, including pre-epoch and century dates',()=>{
  const h=harness();
  const rows=process.env.HAW_DATE_ORACLE?JSON.parse(readFileSync(process.env.HAW_DATE_ORACLE,'utf8')):
    [[2025,3,20,1,1,1],[2025,3,19,0,13,5],[2026,3,19,1,13,5],[2028,3,19,3,13,6],[2028,3,20,4,1,1]];
  for(const [year,month,day,...expected] of rows){
    const k=h.convert(year,month,day,data.dateConversion);
    assert.deepEqual([k.kYear,k.kMonth,k.kDay],expected,year+'-'+month+'-'+day);
  }
  if(process.env.HAW_DATE_ORACLE)assert.ok(rows.length>146000,'Verify the complete 401-year range');
});

test('recorded speech toggles, replaces previous playback, and ignores stale completion', async () => {
  const h = harness();
  const first = h.click('month-speech'), a = h.audio[0];
  await h.ready();
  assert.equal(h.get('brand-film').paused,true);
  assert.equal(h.get('flow-film').paused,true);
  assert.equal(h.requests[0].path,data.months[0].audio);
  assert.equal(a.src,h.blobs[0].url);
  assert.equal(h.blobs[0].blob.size,assetBytes(data.months[0].audio).byteLength);
  assert.equal(h.get('year-month-speech').attrs['aria-pressed'],'true');
  const second = h.click('decan-speech'), b = h.audio[1];
  await h.ready();
  assert.equal(a.paused,true); assert.equal(a.removed,true);
  assert.equal(h.requests[1].path,data.decans[0].audio);
  assert.equal(b.src,h.blobs[1].url);
  assert.ok(h.revoked.includes(a.src));
  a.reject(new Error('superseded')); await first;
  assert.equal(h.get('year-audio-status').hidden,true);
  assert.equal(h.get('year-decan-speech').attrs['aria-pressed'],'true');
  b.resolve(); await second; b.listeners.ended();
  assert.equal(h.get('year-decan-speech').attrs['aria-pressed'],'false');
  const third = h.click('month-speech'); await h.ready(); h.audio[2].resolve(); await third;
  await h.click('month-speech');
  assert.equal(h.audio[2].paused,true);
});

test('month stars and decan stars use the same year position and preserve every complete story',()=>{
  const h=harness();
  for(let month=0;month<12;month++) {
    h.monthStars[month].listeners.click();
    assert.equal(h.get('year-month-name').textContent,data.months[month].name);
    assert.equal(h.get('explore-the-year').dataset.season,data.months[month].season);
    assert.equal(h.monthStars.filter(button=>button.attrs['aria-pressed']==='true').length,1);
    for(let offset=0;offset<3;offset++) {
      h.decanStars[offset].listeners.click();
      const decan=data.decans[month*3+offset];
      assert.equal(h.get('year-decan-name').textContent,decan.name);
      assert.equal(h.get('year-decan-meaning').textContent,decan.meaning);
      assert.equal(h.get('year-choice-number-'+offset).textContent,String(decan.id).padStart(2,'0'));
      assert.ok(decan.paragraphs[0].startsWith(h.get('year-decan-glimpse').textContent));
      assert.deepEqual(Array.from(h.get('year-decan-prose').children,p=>p.textContent),decan.paragraphs);
      assert.equal(h.decanStars.filter(button=>button.attrs['aria-pressed']==='true').length,1);
    }
  }
  h.monthStars[12].listeners.click();
  assert.equal(h.get('year-month-name').textContent,'Heriu Renpet');
  assert.equal(h.get('year-decan-detail').hidden,true);
  assert.ok(h.decanStars.every(button=>button.disabled));
  assert.deepEqual(Array.from(h.get('year-month-prose').children,p=>p.textContent),data.months[12].paragraphs);
  h.monthStars[0].listeners.click();
  assert.equal(h.get('year-decan-detail').hidden,false);
  assert.ok(h.decanStars.every(button=>!button.disabled));
  assert.equal(h.get('year-decan-name').textContent,data.decans[0].name);
});

test('navigation, leaving the panel, hiding the page and contact stop audio', async () => {
  const actions = [h=>h.click('decan-next'),h=>h.click('month-next'),h=>h.monthStars[5].listeners.click(),h=>h.decanStars[1].listeners.click(),h=>h.pick('day',20),h=>h.outside(),
    h=>h.events['window:pagehide'](),h=>h.events['document:play']({target:{tagName:'VIDEO'}}),
    h=>{h.document.hidden=true;h.events['document:visibilitychange']();},
    h=>{h.location.hash='#contact';h.events['window:hashchange']();}];
  for (const action of actions) {
    const h=harness(),pending=h.click('month-speech'),a=h.audio[0];
    await h.ready();
    action(h); a.reject(new Error('cancelled')); await pending;
    assert.equal(a.paused,true); assert.equal(a.removed,true);
    assert.equal(h.get('year-month-speech').attrs['aria-pressed'],'false');
    assert.equal(h.get('year-audio-status').hidden,true);
  }
});

test('an unavailable recording restores the play button and permits a user retry', async () => {
  const h=harness(),pending=h.click('decan-speech');
  await h.ready();
  h.audio[0].reject(new Error('unavailable')); await pending;
  assert.equal(h.get('year-audio-status').hidden,false);
  assert.match(h.get('year-audio-status').textContent,/could not play/);
  assert.equal(h.get('year-decan-speech').attrs['aria-pressed'],'false');
  const retry=h.click('decan-speech');await h.ready();h.audio[1].resolve();await retry;
  assert.equal(h.get('year-audio-status').hidden,true);
});

test('pronunciation audio does not stop itself when its own play event is captured',async()=>{
  const h=harness(),pending=h.click('month-speech'),a=h.audio[0];
  await h.ready();
  h.events['document:play']({target:{tagName:'AUDIO'}});
  assert.equal(h.get('year-month-speech').attrs['aria-pressed'],'true');
  assert.equal(a.paused,false);
  a.resolve();await pending;
  h.events['document:play']({target:{tagName:'VIDEO'}});
  assert.equal(h.get('year-month-speech').attrs['aria-pressed'],'false');
  assert.equal(a.paused,true);
});

test('the opening repeats on every home visit and restored visit, respects reduced motion and leaves deep links alone', () => {
  function visit({seen=false,reduced=false,hash='',storageFails=false}={}) {
    const classes=[],saved=[],removed=[],events={},location={hash};
    vm.runInNewContext(script('haw-opening-visit'),{
      matchMedia:()=>({matches:reduced}),location,
      document:{documentElement:{classList:{add:value=>classes.push(value),remove:value=>removed.push(value)}}},
      window:{addEventListener:(key,fn)=>events[key]=fn},requestAnimationFrame:fn=>fn(),
      localStorage:{getItem(){if(storageFails)throw Error();return seen?'seen':null;},setItem:(...args)=>saved.push(args)},
    });return {classes,saved,removed,events,location};
  }
  assert.deepEqual(visit().classes,['haw-opening']);
  assert.deepEqual(visit({seen:true}).classes,['haw-opening']);
  assert.deepEqual(visit({reduced:true}).classes,[]);
  assert.deepEqual(visit({hash:'#explore-the-year'}).classes,[]);
  assert.deepEqual(visit({hash:'#contact'}).classes,[]);
  assert.deepEqual(visit({storageFails:true}).classes,['haw-opening']);
  assert.deepEqual(visit({seen:true}).saved,[]);
  const restored=visit({seen:true});
  restored.events.pageshow({persisted:false});
  assert.equal(restored.classes.length,1);
  restored.events.pageshow({persisted:true});
  assert.deepEqual(restored.removed,['haw-opening']);
  assert.equal(restored.classes.length,2);
  restored.location.hash='#our-story';restored.events.hashchange();
  assert.equal(restored.classes.length,2);
  restored.location.hash='#top';restored.events.hashchange();
  assert.equal(restored.classes.length,3);
  const reduced=visit({reduced:true});reduced.events.pageshow({persisted:true});
  assert.deepEqual(reduced.classes,[]);
});

test('speech waits for the complete recording, reuses downloaded bytes, and releases playback URLs',async()=>{
  const h=harness({deferFetch:true});let complete;
  const body=new Promise(resolve=>complete=resolve);
  h.requests[0].resolve({ok:true,arrayBuffer:()=>body});
  const pending=h.click('month-speech'),a=h.audio[0];await h.ready();
  assert.equal(a.paused,true);assert.equal(a.src,undefined);assert.equal(h.blobs.length,0);
  const bytes=assetBytes(data.months[0].audio);
  complete(bytes);await h.ready();
  assert.equal(a.paused,false);assert.equal(h.blobs[0].blob.size,bytes.length);
  a.resolve();await pending;a.listeners.ended();
  assert.deepEqual(h.revoked,[a.src]);
  const replay=h.click('month-speech');await h.ready();
  assert.equal(h.requests.filter(r=>r.path===data.months[0].audio).length,1);
  assert.notEqual(h.audio[1].src,a.src);
  h.audio[1].resolve();await replay;await h.click('month-speech');
  assert.deepEqual(h.revoked,h.blobs.map(b=>b.url));
});

test('cancelling while speech downloads cannot start a stale recording',async()=>{
  const h=harness({deferFetch:true}),pending=h.click('month-speech'),a=h.audio[0];
  h.pick('day',20);h.requests[0].resolve();await h.ready();await pending;
  assert.equal(a.paused,true);assert.equal(a.removed,true);assert.equal(a.src,undefined);
  assert.equal(h.blobs.length,0);assert.equal(h.get('year-month-speech').attrs['aria-pressed'],'false');
});

test('failed pronunciation downloads can be retried without caching a failed response',async()=>{
  const h=harness({deferFetch:true}),pending=h.click('month-speech');
  h.requests[0].resolve({ok:false});await pending;
  assert.equal(h.get('year-audio-status').hidden,false);
  const retry=h.click('month-speech');
  assert.equal(h.requests.filter(r=>r.path===data.months[0].audio).length,2);
  h.requests.at(-1).resolve();await h.ready();h.audio[1].resolve();await retry;
  assert.equal(h.get('year-audio-status').hidden,true);
});


test('a date stays pending until reveal and both windows commit the same exact day',()=>{
  const h=harness({autoReveal:false});
  assert.equal(h.get('year-discovery-number').textContent,'0');
  h.pick('month',9);h.pick('day',28);
  assert.equal(h.get('year-month-name').textContent,'Thoth');
  assert.equal(h.get('year-month-day').textContent,'1');
  assert.match(h.get('year-reveal-status').textContent,/Reveal to update/);
  assert.equal(h.get('year-discovery-number').textContent,'0');
  h.click('reveal');
  const k=h.convert(2025,10,29,data.dateConversion);
  assert.equal(h.get('year-month-name').textContent,data.months[k.kMonth-1].name);
  assert.equal(h.get('year-month-day').textContent,String(k.kDay));
  assert.equal(h.get('year-decan-name').textContent,data.decans[(k.kMonth-1)*3+Math.floor((k.kDay-1)/10)].name);
  assert.equal(h.get('year-discovery-number').textContent,'1');
  assert.equal(h.get('year-reveal').attrs['aria-busy'],'false');
});

test('discoveries persist without duplicates and the between-year threshold is outside the count',()=>{
  const storage=new Map(),h=harness({storage});
  h.click('reveal');h.click('reveal');
  assert.equal(h.get('year-discovery-number').textContent,'1');
  h.click('decan-next');
  assert.equal(h.get('year-discovery-number').textContent,'2');
  h.monthStars[12].listeners.click();
  assert.equal(h.get('year-threshold').hidden,false);
  assert.equal(h.get('year-discovery-number').textContent,'2');
  assert.equal(h.discoveryBars[36].attrs['data-found'],'');
  const restored=harness({storage});
  assert.equal(restored.get('year-discovery-number').textContent,'2');
  assert.equal(restored.discoveryBars[0].attrs['data-found'],'');
  assert.equal(restored.discoveryBars[1].attrs['data-found'],'');
});

test('storage denial or malformed saved progress cannot block the explorer',()=>{
  const h=harness({storageDenied:true});h.click('reveal');h.click('decan-next');
  assert.equal(h.get('year-discovery-number').textContent,'2');
  const invalid=harness({storage:new Map([['haw.mockup.discovery.v1','{broken']])});
  invalid.click('reveal');assert.equal(invalid.get('year-discovery-number').textContent,'1');
  const filtered=harness({storage:new Map([['haw.mockup.discovery.v1',JSON.stringify({version:1,slots:[0,0,1,-1,99,'2',null]})]])});
  assert.equal(filtered.get('year-discovery-number').textContent,'2');
});

test('changing date or navigating during reveal cancels stale results',()=>{
  const h=harness({autoReveal:false,reduced:false});
  h.pick('month',9);h.click('reveal');
  assert.equal(h.get('year-reveal').attrs['aria-busy'],'true');
  h.pick('month',10);h.flush();
  assert.equal(h.get('year-month-name').textContent,'Thoth');
  assert.equal(h.get('year-discovery-number').textContent,'0');
  assert.equal(h.get('year-reveal').attrs['aria-busy'],'false');
  h.click('reveal');h.click('decan-next');
  const name=h.get('year-month-name').textContent,day=h.get('year-month-day').textContent;
  h.flush();
  assert.equal(h.get('year-month-name').textContent,name);
  assert.equal(h.get('year-month-day').textContent,day);
  assert.equal(h.get('year-discovery-number').textContent,'1');
});

test('Reveal settles a wheel before its scroll debounce and reduced motion commits immediately',()=>{
  const h=harness({autoReveal:false});
  const day=h.get('year-date-day');day.scrollTop=20*48;day.listeners.scroll();
  h.click('reveal');
  assert.equal(h.get('year-date-gregorian').textContent,'March 21, 2025');
  assert.equal(h.get('year-month-day').textContent,'2');
  assert.equal(h.get('year-discovery-number').textContent,'1');
  assert.equal(h.get('year-reveal').attrs['aria-busy'],'false');
  h.flush();assert.equal(h.get('year-month-day').textContent,'2');
});


test('leaving during a reveal restores a usable pending state without a late discovery',()=>{
 const h=harness({autoReveal:false,reduced:false});
 h.pick('day',20);h.click('reveal');h.events['window:pagehide']();h.flush();
 assert.equal(h.get('year-reveal').attrs['aria-busy'],'false');
 assert.match(h.get('year-reveal-status').textContent,/Reveal to update/);
 assert.equal(h.get('year-discovery-number').textContent,'0');
 h.click('reveal');h.flush();
 assert.equal(h.get('year-month-day').textContent,'2');
 assert.equal(h.get('year-discovery-number').textContent,'1');
});


test('the separate year chooser retains its selected year while hidden and realigns on reopening',()=>{
 const h=harness({autoReveal:false}),wheel=h.get('year-date-year');
 wheel.getClientRects=()=>h.get('year-year-popover').hidden?[]:[{}];
 assert.equal(h.get('year-year-value').textContent,'2025');
 h.click('year-toggle');assert.equal(h.get('year-year-popover').hidden,false);
 assert.equal(wheel.scrollTop,200*48);
 h.pick('year',203);h.click('year-close');
 assert.equal(h.get('year-year-popover').hidden,true);
 wheel.scrollTop=0;wheel.listeners.scroll();h.flush();h.click('reveal');
 assert.equal(h.get('year-date-gregorian').textContent,'March 20, 2028');
 assert.equal(h.get('year-month-name').textContent,'Thoth');
 assert.equal(h.get('year-month-day').textContent,'1');
 assert.equal(h.get('year-year-value').textContent,'2028');
 h.click('year-toggle');assert.equal(wheel.scrollTop,203*48);
 h.events['document:keydown']({key:'Escape'});
 assert.equal(h.get('year-year-popover').hidden,true);
 assert.equal(h.get('year-year-toggle').attrs['aria-expanded'],'false');
});

test('decan headings show the authored name and meaning without a separate theme header',()=>{
 assert.equal(page.includes('id="year-decan-theme"'),false);
 const h=harness();
 for(let i=0;i<36;i++){
  assert.equal(h.get('year-decan-name').textContent,data.decans[i].name);
  assert.equal(h.get('year-decan-meaning').textContent,data.decans[i].meaning);
  h.click('decan-next');
 }
});


test('closing the year chooser settles its last visible scroll and ignores hidden scroll resets',()=>{
 const h=harness({autoReveal:false}),wheel=h.get('year-date-year');
 wheel.getClientRects=()=>h.get('year-year-popover').hidden?[]:[{}];
 h.click('year-toggle');wheel.scrollTop=203*48;wheel.listeners.scroll();
 h.click('year-close');
 assert.equal(h.get('year-year-value').textContent,'2028');
 wheel.scrollTop=0;wheel.listeners.scroll();h.flush();
 h.click('reveal');h.flush();
 assert.equal(h.get('year-date-gregorian').textContent,'March 20, 2028');
 assert.equal(h.get('year-month-name').textContent,'Thoth');
 assert.equal(h.get('year-month-day').textContent,'1');
});

function referenceSweep(from,target) {
  const reveal=readFileSync(new URL('./fixtures/public_site_discovery_sweep_reference.js',import.meta.url),'utf8');
  const scan=[],delays=[],queue=[];
  const cells=Array.from({length:37},(_,i)=>({classList:{remove(){},add(name){if(name==='scan')scan.push(i);}}}));
  let landed=null;
  const context={state:{busy:false,shown:from,month:0},wMonth:{timer:null,index:0},wDay:{timer:null,index:0},
    clearTimeout(){},daysIn:()=>31,slotOf:()=>target,dayNum(){},reduced:false,cells,
    $:()=>({setAttribute(){},removeAttribute(){}}),
    setTimeout(fn,delay){delays.push(delay);queue.push(fn);},
    land(slot){landed=slot;},Math};
  vm.runInNewContext(reveal+'\nreveal();',context);
  let limit=100;
  while(queue.length){assert.ok(limit-->0);queue.shift()();}
  assert.equal(landed,target);
  return {scan,delays};
}

function captureSweep(h) {
  const scan=[],delays=[];
  const current=()=>h.discoveryBars.findIndex(bar=>'data-target' in bar.attrs);
  h.click('reveal');scan.push(current());
  let limit=100;
  while(h.get('year-reveal').attrs['aria-busy']==='true'){
    assert.ok(limit-->0,'Sweep must land');
    assert.equal(h.discoveryBars.filter(bar=>'data-current' in bar.attrs).length,0,'Outline waits for landing');
    delays.push(h.advance());
    if(h.get('year-reveal').attrs['aria-busy']==='true')scan.push(current());
  }
  assert.equal(h.discoveryBars.filter(bar=>'data-target' in bar.attrs).length,0);
  return {scan,delays};
}

test('the light sweep matches the supplied reference path, deceleration and landing hold',()=>{
  const h=harness({autoReveal:false,reduced:false});
  h.pick('month',9);h.pick('day',28);
  const k=h.convert(2025,10,29,data.dateConversion),target=(k.kMonth-1)*3+Math.floor((k.kDay-1)/10);
  assert.deepEqual(captureSweep(h),referenceSweep(0,target));
  assert.equal(h.discoveryBars[target].attrs['data-current'],'');
  assert.equal(h.get('year-discovery-number').attrs['data-pop'],'');
  h.flush();assert.equal(h.get('year-discovery-number').attrs['data-pop'],undefined);
  assert.deepEqual(captureSweep(h),referenceSweep(target,target),'Repeated date still sweeps a full year');
  assert.equal(h.get('year-discovery-number').textContent,'1');
  assert.equal(h.get('year-discovery-number').attrs['data-pop'],undefined,'Already found decans do not pulse the count');
  h.monthStars[12].listeners.click();
  assert.deepEqual(captureSweep(h),referenceSweep(36,36),'Between-year marker participates in the sweep');
  assert.equal(h.get('year-discovery-number').textContent,'1');
  assert.equal(h.get('year-discovery-number').attrs['data-pop'],undefined);
  h.pick('month',2);h.pick('day',19);
  assert.deepEqual(captureSweep(h),referenceSweep(36,0),'Sweep wraps into the first decan');
  assert.equal(h.get('year-discovery-number').textContent,'2');
});

test('repeat clicks cannot restart the sweep and cancellation restores the previous outline',()=>{
  const h=harness({autoReveal:false,reduced:false});
  h.pick('month',9);h.click('reveal');
  const first=h.discoveryBars.findIndex(bar=>'data-target' in bar.attrs);
  h.click('reveal');assert.equal(h.discoveryBars.findIndex(bar=>'data-target' in bar.attrs),first);
  h.advance();assert.equal(h.discoveryBars.findIndex(bar=>'data-target' in bar.attrs),(first+1)%37);
  h.pick('month',10);
  assert.equal(h.get('year-reveal').attrs['aria-busy'],'false');
  assert.equal(h.discoveryBars[0].attrs['data-current'],'');
  assert.equal(h.discoveryBars.filter(bar=>'data-target' in bar.attrs).length,0);
  h.flush();assert.equal(h.get('year-discovery-number').textContent,'0');
});

test('reduced motion skips the sweep and discovery-count pulse',()=>{
  const h=harness({autoReveal:false,reduced:true});h.pick('month',9);h.click('reveal');
  assert.equal(h.get('year-reveal').attrs['aria-busy'],'false');
  assert.equal(h.discoveryBars.filter(bar=>'data-target' in bar.attrs).length,0);
  assert.equal(h.get('year-discovery-number').attrs['data-pop'],undefined);
  assert.equal(h.get('year-discovery-number').textContent,'1');
});
