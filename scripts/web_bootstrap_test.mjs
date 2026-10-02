import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';
import test from 'node:test';

// Execute the shipped scripts, with browser I/O fault injection and a fake clock.
// No copied implementation, browser storage, network, or timing-dependent sleeps.
const root = new URL('../', import.meta.url);
const html = readFileSync(new URL('web/index.html', root), 'utf8');
const bootstrap = readFileSync(new URL('web/flutter_bootstrap.js', root), 'utf8')
  .replace('{{flutter_js}}', '')
  .replace('{{flutter_build_config}}', '')
  .replaceAll('{{flutter_service_worker_version}}', '"test-build"');
function inlineScript(id) {
  const match = html.match(new RegExp(`<script id="${id}">([\\s\\S]*?)</script>`));
  assert.ok(match, `${id} must be present in the real index.html`);
  return match[1].replaceAll('{{flutter_service_worker_version}}', '"test-build"');
}
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
async function flush() {
  for (let i = 0; i < 24; i++) await Promise.resolve();
}
function harness({ registrations = [], deleteCache, savedReload = null, serviceWorker = true } = {}) {
  let clock = 0;
  let nextTimer = 0;
  const timers = new Map();
  const listeners = new Map();
  const session = new Map(savedReload ? [['kemetic.pwa.rootSwReset.v1', savedReload]] : []);
  session.set('unrelated-account-draft', 'preserve');
  const deletedCaches = [], scripts = [], redirects = [], errors = [], warnings = [];
  let reloads = 0;
  const surface = { dataset: {}, removed: false, remove() { this.removed = true; } };
  const retry = { addEventListener(type, callback) { this[type] = callback; } };
  const document = {
    baseURI: 'https://kemet-rc.pages.dev/',
    getElementById: (id) => id === 'haw-boot' ? surface : retry,
    createElement: (tag) => ({ tagName: tag.toUpperCase() }),
    body: { appendChild: (script) => scripts.push(script) },
  };
  const navigator = serviceWorker ? {
    serviceWorker: { getRegistrations: () => typeof registrations === 'function' ? registrations() : Promise.resolve(registrations) },
  } : {};
  const context = vm.createContext({
    document, navigator, URL, Promise, Date, Error,
    console: { warn: (...args) => warnings.push(args), error: (...args) => errors.push(args) },
    sessionStorage: {
      getItem: (key) => session.get(key) ?? null,
      setItem: (key, value) => session.set(key, value),
      removeItem: (key) => session.delete(key),
    },
    caches: { delete: (name) => { deletedCaches.push(name); return deleteCache ? deleteCache(name) : Promise.resolve(true); } },
    setTimeout: (callback, delay) => { const id = ++nextTimer; timers.set(id, { at: clock + delay, callback }); return id; },
    clearTimeout: (id) => timers.delete(id),
    location: {
      href: 'https://kemet-rc.pages.dev/?keep=this#account', origin: 'https://kemet-rc.pages.dev',
      replace: (url) => redirects.push(url), reload: () => reloads++,
    },
    addEventListener: (type, callback) => { if (!listeners.has(type)) listeners.set(type, new Set()); listeners.get(type).add(callback); },
    removeEventListener: (type, callback) => listeners.get(type)?.delete(callback),
  });
  context.window = context;
  const run = (id) => vm.runInContext(inlineScript(id), context, { filename: `web/index.html#${id}` });
  const emit = (type, event = {}) => { for (const listener of listeners.get(type) ?? []) listener(event); };
  const advance = async (milliseconds) => {
    const end = clock + milliseconds;
    await flush();
    while (true) {
      const next = [...timers.entries()].filter(([, timer]) => timer.at <= end).sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) break;
      clock = next[1].at; timers.delete(next[0]); next[1].callback(); await flush();
    }
    clock = end;
    await flush();
  };
  const start = () => {
    ['haw-stale-cache-cleanup', 'haw-boot-recovery', 'haw-flutter-loader']
      .sort((a, b) => html.indexOf(`id="${a}"`) - html.indexOf(`id="${b}"`))
      .forEach(run);
  };
  return { context, run, start, emit, advance, surface, retry, scripts, redirects, session, deletedCaches, errors, warnings, get reloads() { return reloads; } };
}
const flutterWorker = (unregister) => ({ active: { scriptURL: 'https://kemet-rc.pages.dev/flutter_service_worker.js?v=old' }, unregister });
const expectedCaches = ['flutter-app-manifest', 'flutter-temp-cache', 'flutter-app-cache'];

function expectBootstrap(h) {
  assert.equal(h.scripts.length, 1);
  assert.equal(h.scripts[0].src, 'flutter_bootstrap.js?v=test-build');
  assert.equal(h.session.get('unrelated-account-draft'), 'preserve');
}

test('normal startup cleans only legacy Flutter caches and preserves push workers', async () => {
  let pushUnregisters = 0;
  const h = harness({ registrations: [{ active: { scriptURL: 'https://kemet-rc.pages.dev/firebase-messaging-sw.js' }, unregister() { pushUnregisters++; } }] });
  h.start(); await flush();
  expectBootstrap(h);
  assert.deepEqual(h.deletedCaches, expectedCaches);
  assert.equal(pushUnregisters, 0);
  assert.equal(h.redirects.length, 0);
  assert.equal(h.surface.removed, false);
});

test('unavailable service worker API does not prevent startup', async () => {
  const h = harness({ serviceWorker: false }); h.start(); await flush();
  expectBootstrap(h); assert.deepEqual(h.deletedCaches, []);
});

test('pending registration lookup cannot block bootstrap or resume late cleanup', async () => {
  const lookup = deferred(); let unregisters = 0;
  const h = harness({ registrations: () => lookup.promise }); h.start(); await flush();
  assert.equal(h.scripts.length, 0);
  await h.advance(1500); expectBootstrap(h);
  lookup.resolve([flutterWorker(async () => { unregisters++; return true; })]); await flush();
  assert.equal(unregisters, 0); assert.deepEqual(h.deletedCaches, []); assert.deepEqual(h.redirects, []);
});

test('pending unregister cannot block bootstrap or reload the app after timeout', async () => {
  const removal = deferred(); const h = harness({ registrations: [flutterWorker(() => removal.promise)] });
  h.start(); await h.advance(1500); expectBootstrap(h);
  h.emit('flutter-first-frame'); removal.resolve(true); await flush();
  assert.deepEqual(h.deletedCaches, []); assert.deepEqual(h.redirects, []); assert.equal(h.surface.removed, true);
});

test('pending cache deletion cannot block bootstrap or reload after timeout', async () => {
  const deletion = deferred();
  const h = harness({ registrations: [flutterWorker(async () => true)], deleteCache: () => deletion.promise });
  h.start(); await h.advance(1500); expectBootstrap(h);
  assert.deepEqual(h.deletedCaches, expectedCaches);
  h.emit('flutter-first-frame'); deletion.resolve(true); await flush();
  assert.deepEqual(h.redirects, []); assert.equal(h.session.has('kemetic.pwa.rootSwReset.v1'), false);
});

for (const stage of ['lookup', 'unregister', 'cache']) {
  test(`rejected ${stage} cleanup remains best effort`, async () => {
    const reject = () => Promise.reject(new Error(`failed ${stage}`));
    const h = harness({ registrations: stage === 'lookup' ? reject : [flutterWorker(stage === 'unregister' ? reject : async () => false)], deleteCache: stage === 'cache' ? reject : undefined });
    h.start(); await flush(); expectBootstrap(h); assert.deepEqual(h.redirects, []);
  });
}

test('completed legacy worker removal reloads only once and preserves URL intent', async () => {
  const h = harness({ registrations: [flutterWorker(async () => true)] }); h.start(); await flush();
  assert.equal(h.scripts.length, 0); assert.equal(h.redirects.length, 1);
  const redirected = new URL(h.redirects[0]);
  assert.equal(redirected.searchParams.get('keep'), 'this'); assert.equal(redirected.hash, '#account');
  assert.equal(redirected.searchParams.has('_sw_reset'), true);
  const second = harness({ registrations: [flutterWorker(async () => true)], savedReload: '1' }); second.start(); await flush();
  expectBootstrap(second); assert.deepEqual(second.redirects, []); assert.equal(second.session.has('kemetic.pwa.rootSwReset.v1'), false);
});

test('bootstrap download failure displays recovery and Retry only reloads the document', async () => {
  const h = harness(); h.start(); await flush();
  h.scripts[0].onerror(); assert.equal(h.surface.dataset.state, 'error');
  h.retry.click(); assert.equal(h.reloads, 1); assert.equal(h.session.get('unrelated-account-draft'), 'preserve');
  assert.deepEqual(h.deletedCaches, expectedCaches);
});

test('entrypoint script download errors display recovery without catching unrelated resources', async () => {
  const h = harness(); h.start(); await flush();
  h.emit('error', { target: { tagName: 'IMG', src: '/image.png' } });
  h.emit('error', { target: { tagName: 'SCRIPT', src: 'https://kemet-rc.pages.dev/install.js' } });
  assert.equal(h.surface.dataset.state, undefined);
  h.emit('error', { target: { tagName: 'SCRIPT', src: 'https://kemet-rc.pages.dev/main.dart.js?v=build' } });
  assert.equal(h.surface.dataset.state, 'error');
});

test('first-frame watchdog provides recovery and a late first frame hands off permanently', async () => {
  const h = harness(); h.start(); await h.advance(30000);
  assert.equal(h.surface.dataset.state, 'error');
  h.emit('flutter-first-frame'); assert.equal(h.surface.removed, true);
  const failures = h.errors.length;
  h.context.__kemeticBootFailure(new Error('late engine error'));
  h.emit('error', { target: { tagName: 'SCRIPT', src: '/main.dart.js' } });
  await h.advance(60000); assert.equal(h.errors.length, failures);
});

test('successful first frame removes the loading surface and cancels watchdog', async () => {
  const h = harness(); h.start(); await flush(); h.emit('flutter-first-frame');
  await h.advance(60000); assert.equal(h.surface.removed, true); assert.equal(h.errors.length, 0);
});

for (const stage of ['loader-throw', 'loader-reject', 'engine-throw', 'engine-reject', 'run-throw', 'run-reject']) {
  test(`${stage} displays the existing recovery surface`, async () => {
    const h = harness(); h.start(); await flush();
    const failure = new Error(stage);
    h.context._flutter = { buildConfig: { builds: [{ mainJsPath: 'main.dart.js' }] }, loader: { load(options) {
      if (stage === 'loader-throw') throw failure;
      if (stage === 'loader-reject') return Promise.reject(failure);
      options.onEntrypointLoaded({ initializeEngine() {
        if (stage === 'engine-throw') throw failure;
        if (stage === 'engine-reject') return Promise.reject(failure);
        return Promise.resolve({ runApp() {
          if (stage === 'run-throw') throw failure;
          if (stage === 'run-reject') return Promise.reject(failure);
        } });
      } });
      return Promise.resolve();
    } } };
    vm.runInContext(bootstrap, h.context, { filename: fileURLToPath(new URL('web/flutter_bootstrap.js', root)) });
    await flush(); assert.equal(h.surface.dataset.state, 'error'); assert.equal(h.errors.length, 1);
  });
}

test('engine success starts exactly once, versions entrypoint, and waits for a rendered frame', async () => {
  const h = harness(); h.start(); await flush(); let initialized = 0, started = 0;
  h.context._flutter = { buildConfig: { builds: [{ mainJsPath: 'main.dart.js' }] }, loader: { load(options) {
    options.onEntrypointLoaded({ initializeEngine: async () => { initialized++; return { runApp: async () => { started++; } }; } });
    return Promise.resolve();
  } } };
  vm.runInContext(bootstrap, h.context); await flush();
  assert.equal(initialized, 1); assert.equal(started, 1); assert.equal(h.surface.removed, false);
  assert.equal(h.context._flutter.buildConfig.builds[0].mainJsPath, 'main.dart.js?v=test-build');
  h.emit('flutter-first-frame'); assert.equal(h.surface.removed, true);
});


test('broken diagnostics cannot prevent timeout continuation or the recovery surface', async () => {
  const h = harness({ registrations: () => new Promise(() => {}) });
  h.context.console.warn = () => { throw new Error('broken warning hook'); };
  h.context.console.error = () => { throw new Error('broken error hook'); };
  h.start(); await h.advance(1500); expectBootstrap(h);
  h.context.__kemeticBootFailure(new Error('failed startup'));
  assert.equal(h.surface.dataset.state, 'error');
});

test('recovery diagnostics never log exception details or OAuth callback values', async () => {
  const h = harness(); h.start(); await flush();
  h.context.__kemeticBootFailure(new Error('https://kemet-rc.pages.dev/?code=private-auth-code'));
  assert.deepEqual(h.errors, [['[boot] unable to start']]);
});
