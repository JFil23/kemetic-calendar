import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('../public-site/index.html', import.meta.url), 'utf8');
const start = page.indexOf("const submitButton=$('#support-submit');let submitting=false;");
const end = page.indexOf('window.hawPreviewReady=true;', start);
assert.ok(start > 0 && end > start, 'Test the shipped contact controller');
const controller = page.slice(start, end);

function harness(deliver, { timeout = false } = {}) {
  const listeners = {}, calls = [];
  const field = value => ({ value, disabled: false, validity: '', setCustomValidity(text) { this.validity = text; }, addEventListener() {} });
  const fields = { name: field('A visitor'), email: field('visitor@example.com'), topic: field('A suggestion'), message: field('A question about a flow.'), device: field('Mobile'), website: field('') };
  const button = { disabled: false, firstChild: { textContent: 'Submit ' } };
  const result = { hidden: true, dataset: {}, textContent: '', replaceChildren(node) { this.textContent = node.textContent; } };
  const attributes = new Map(); let resets = 0;
  const form = {
    elements: [...Object.values(fields), button],
    addEventListener(type, listener) { listeners[type] = listener; },
    reportValidity() { return !fields.message.validity; },
    setAttribute(key, value) { attributes.set(key, value); },
    removeAttribute(key) { attributes.delete(key); },
    reset() { resets++; Object.values(fields).forEach(item => item.value = ''); },
  };
  vm.runInNewContext(controller, {
    form, result,
    $: selector => selector === '#support-submit' ? button : selector === '#support-message' ? fields.message : undefined,
    FormData: class { [Symbol.iterator]() { return Object.entries(fields).map(([key, value]) => [key, value.value])[Symbol.iterator](); } },
    document: { createTextNode: text => ({ textContent: text }) },
    AbortController,
    setTimeout: timeout ? callback => setTimeout(callback, 0) : setTimeout,
    clearTimeout,
    fetch: async (url, options) => { calls.push({ url, options }); return deliver(url, options); },
  });
  return { form, fields, button, result, attributes, calls, get resets() { return resets; }, edit: () => listeners.input(), submit: () => listeners.submit({ preventDefault() {} }) };
}

test('Submit waits for acknowledgement, locks controls and prevents duplicate requests', async () => {
  let accept;
  const item = harness(() => new Promise(resolve => { accept = resolve; }));
  const pending = item.submit();
  assert.equal(item.calls.length, 1);
  assert.equal(item.result.hidden, true);
  assert.equal(item.attributes.get('aria-busy'), 'true');
  assert.equal(item.button.firstChild.textContent.trim(), 'Sending…');
  assert.ok(item.form.elements.every(control => control.disabled));
  await item.submit();
  assert.equal(item.calls.length, 1);
  accept(new Response(JSON.stringify({ ok: true }), { status: 200 }));
  await pending;
  assert.equal(item.resets, 1);
  assert.equal(item.result.dataset.status, 'success');
  assert.match(item.result.textContent, /Your message has been sent/);
  assert.ok(item.form.elements.every(control => !control.disabled));
  assert.equal(item.attributes.has('aria-busy'), false);
  assert.equal(item.button.firstChild.textContent.trim(), 'Submit');
  assert.equal(item.calls[0].url, '/api/contact');
  assert.equal(item.calls[0].options.method, 'POST');
  assert.equal(item.calls[0].options.redirect, 'error');
  assert.equal(JSON.parse(item.calls[0].options.body).email, 'visitor@example.com');
  item.edit();
  assert.equal(item.result.hidden, true, 'A new draft clears the previous confirmation.');
});

test('server errors, malformed receipts and network failures preserve every field', async () => {
  const failures = [
    async () => new Response(JSON.stringify({ ok: false }), { status: 503 }),
    async () => new Response(JSON.stringify({ ok: false }), { status: 200 }),
    async () => new Response('not JSON', { status: 200 }),
    async () => { throw new TypeError('Network unavailable'); },
  ];
  for (const deliver of failures) {
    const item = harness(deliver);
    const before = Object.values(item.fields).map(field => field.value);
    await item.submit();
    assert.equal(item.resets, 0);
    assert.deepEqual(Object.values(item.fields).map(field => field.value), before);
    assert.equal(item.result.dataset.status, 'error');
    assert.match(item.result.textContent, /Your message is still here/);
    assert.ok(item.form.elements.every(control => !control.disabled));
  }
});

test('rate limits explain when the visitor can retry without clearing the message', async () => {
  const item = harness(async () => new Response(JSON.stringify({ ok: false }), { status: 429 }));
  await item.submit();
  assert.equal(item.resets, 0);
  assert.equal(item.result.dataset.status, 'error');
  assert.match(item.result.textContent, /wait a minute/);
});

test('timeout restores a usable form without automatic retry or false success', async () => {
  const item = harness((url, options) => new Promise((resolve, reject) => {
    options.signal.addEventListener('abort', () => reject(new DOMException('Timeout', 'AbortError')));
  }), { timeout: true });
  await item.submit();
  assert.equal(item.calls.length, 1);
  assert.equal(item.resets, 0);
  assert.equal(item.result.dataset.status, 'error');
  assert.match(item.result.textContent, /Sending took too long/);
  assert.equal(item.button.disabled, false);
});

test('whitespace-only messages fail validation before any request', async () => {
  const item = harness(() => { throw new Error('Must not send'); });
  item.fields.message.value = ' \n ';
  await item.submit();
  assert.equal(item.calls.length, 0);
  assert.equal(item.resets, 0);
  assert.equal(item.button.disabled, false);
});
