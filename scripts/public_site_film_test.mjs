import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFileSync } from 'node:fs';

const page=readFileSync(new URL('../public-site/index.html',import.meta.url),'utf8');
const start=page.indexOf('/* Shared film controls:');
const end=page.indexOf('/* End shared film controls. */',start);
assert.ok(start>0&&end>start,'Exercise the shipped shared film controller');
const controller=page.slice(start,end);

function harness({reject=false}={}) {
  const windowEvents={},documentEvents={},document={hidden:false,activeElement:null};
  function target() {
    return {listeners:{},hidden:false,controls:false,paused:true,src:'',
      addEventListener(type,fn) { (this.listeners[type]??=[]).push(fn); },
      emit(type) { for(const fn of this.listeners[type]??[])fn(); },
      pause() { this.paused=true; },
      focus() { document.activeElement=this; },
      getAttribute(name) { return this[name]||null; },
      play() { this.paused=false; if(reject)return Promise.reject(Error('unavailable'));this.emit('play');return Promise.resolve(); },
    };
  }
  const brand=target(),flow=target(),brandCover=target(),flowCover=target();
  document.querySelectorAll=()=>[brand,flow];
  document.addEventListener=(type,fn)=>(documentEvents[type]??=[]).push(fn);
  const location={hash:''};
  vm.runInNewContext(controller,{video:brand,cover:brandCover,document,location,
    loadFilm:()=>{if(!brand.src)brand.src='/existing-film.mp4';},
    $:selector=>selector==='#flow-film'?flow:flowCover,
    window:{addEventListener:(type,fn)=>(windowEvents[type]??=[]).push(fn)},
  });
  return {brand,flow,brandCover,flowCover,document,location,
    click:cover=>cover.emit('click'),
    windowEvent:type=>windowEvents[type].forEach(fn=>fn()),
    documentEvent:type=>documentEvents[type].forEach(fn=>fn()),
  };
}

test('both players load on demand, expose native controls and restore their covers on completion',()=>{
  const h=harness();
  assert.equal(h.brand.src,'');assert.equal(h.flow.src,'');
  for(const [video,cover]of [[h.brand,h.brandCover],[h.flow,h.flowCover]]) {
    h.click(cover);
    assert.ok(video.src.endsWith('.mp4'));assert.equal(video.paused,false);
    assert.equal(video.controls,true);assert.equal(cover.hidden,true);
    assert.equal(h.document.activeElement,video);
    video.emit('ended');
    assert.equal(video.controls,false);assert.equal(cover.hidden,false);
  }
});

test('starting either film pauses the other through the same controller',()=>{
  const h=harness();h.click(h.brandCover);h.click(h.flowCover);
  assert.equal(h.brand.paused,true);assert.equal(h.flow.paused,false);
  h.brand.play();
  assert.equal(h.flow.paused,true);assert.equal(h.brand.paused,false);
});

test('a failed play restores the cover and keyboard focus for retry',async()=>{
  const h=harness({reject:true});
  h.click(h.flowCover);await Promise.resolve();
  assert.equal(h.flowCover.hidden,false);assert.equal(h.flow.controls,false);
  assert.equal(h.document.activeElement,h.flowCover);
});

test('contact navigation, page departure and hidden documents pause both films',()=>{
  for(const action of [h=>h.windowEvent('pagehide'),
    h=>{h.location.hash='#contact';h.windowEvent('hashchange');},
    h=>{h.document.hidden=true;h.documentEvent('visibilitychange');}]) {
    const h=harness();h.brand.paused=false;h.flow.paused=false;action(h);
    assert.equal(h.brand.paused,true);assert.equal(h.flow.paused,true);
  }
});
