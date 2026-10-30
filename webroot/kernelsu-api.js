// Promise adapter for KernelSU Manager's documented WebUI JavaScript bridge.
// The manager exposes window.ksu.exec(command, optionsJson, callbackName).
let callbackCounter = 0;

export function exec(command, options = {}) {
  if (typeof command !== 'string' || command.length === 0) {
    return Promise.reject(new TypeError('KernelSU exec requires a command string'));
  }
  if (typeof window === 'undefined' || !window.ksu || typeof window.ksu.exec !== 'function') {
    return Promise.reject(new Error('KernelSU WebUI bridge is unavailable'));
  }

  return new Promise((resolve, reject) => {
    const callbackName = `__redmagicDualSpaceExec_${Date.now()}_${callbackCounter++}`;
    const cleanup = () => { delete window[callbackName]; };

    window[callbackName] = (errno, stdout, stderr) => {
      cleanup();
      resolve({
        errno: Number(errno),
        stdout: String(stdout ?? ''),
        stderr: String(stderr ?? ''),
      });
    };

    try {
      window.ksu.exec(command, JSON.stringify(options), callbackName);
    } catch (error) {
      cleanup();
      reject(error);
    }
  });
}
