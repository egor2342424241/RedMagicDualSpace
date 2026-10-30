import test from 'node:test';
import assert from 'node:assert/strict';
import { exec } from '../webroot/kernelsu-api.js';

test('exec delegates to KernelSU and resolves stdout, stderr and errno', async () => {
  const calls = [];
  globalThis.window = {
    ksu: {
      exec(command, optionsJson, callbackName) {
        calls.push({ command, optionsJson, callbackName });
        queueMicrotask(() => globalThis.window[callbackName](0, 'device ok', ''));
      },
    },
  };

  try {
    const result = await exec('getprop ro.product.model', { cwd: '/data/adb' });
    assert.deepEqual(result, { errno: 0, stdout: 'device ok', stderr: '' });
    assert.equal(calls.length, 1);
    assert.equal(calls[0].command, 'getprop ro.product.model');
    assert.deepEqual(JSON.parse(calls[0].optionsJson), { cwd: '/data/adb' });
    assert.equal(typeof calls[0].callbackName, 'string');
    assert.equal(Object.hasOwn(globalThis.window, calls[0].callbackName), false);
  } finally {
    delete globalThis.window;
  }
});

test('exec rejects when the KernelSU bridge is unavailable', async () => {
  globalThis.window = {};
  try {
    await assert.rejects(exec('getprop ro.product.model'), /bridge is unavailable/);
  } finally {
    delete globalThis.window;
  }
});

test('exec rejects an empty command', async () => {
  globalThis.window = { ksu: { exec() { assert.fail('exec must not be invoked'); } } };
  try {
    await assert.rejects(exec(''), /requires a command string/);
  } finally {
    delete globalThis.window;
  }
});
