import { exec } from './kernelsu-api.js';

const SCRIPT = 'sh /data/adb/modules/redmagicdualspace/scripts/dualspace.sh';
const ALLOWED_ACTIONS = new Set(['status', 'create', 'switch-owner', 'switch-space']);
const buttons = Array.from(document.querySelectorAll('button[data-action]'));
const output = document.getElementById('output');
const indicator = document.getElementById('status-indicator');

function setBusy(busy) {
  for (const button of buttons) button.disabled = busy;
  document.body.classList.toggle('busy', busy);
}

function showResult(action, result) {
  const stdout = (result.stdout || '').trim();
  const stderr = (result.stderr || '').trim();
  const messages = [];
  if (stdout) messages.push(stdout);
  if (stderr) messages.push(`STDERR:\n${stderr}`);
  if (!messages.length) messages.push(`Команда ${action} завершилась без текстового вывода.`);
  output.textContent = messages.join('\n\n');
  if (result.errno === 0) {
    indicator.textContent = 'Команда выполнена';
    indicator.dataset.state = 'success';
  } else {
    indicator.textContent = `Ошибка · код ${result.errno}`;
    indicator.dataset.state = 'error';
  }
}

async function runAction(action) {
  if (!ALLOWED_ACTIONS.has(action)) {
    output.textContent = 'Отклонена неизвестная операция.';
    indicator.textContent = 'Недопустимая операция';
    indicator.dataset.state = 'error';
    return;
  }

  if (action === 'create') {
    const approved = window.confirm(
      'Создать отдельного пользователя Android «RedMagic DualSpace»? Это займёт часть внутренней памяти. Основной профиль не удаляется.'
    );
    if (!approved) return;
  }

  setBusy(true);
  indicator.textContent = 'Выполняется…';
  indicator.dataset.state = 'busy';
  output.textContent = `Выполняется операция: ${action}`;

  try {
    const result = await exec(`${SCRIPT} ${action}`);
    showResult(action, result);
  } catch (error) {
    output.textContent = String(error?.message || error);
    indicator.textContent = 'Ошибка вызова KernelSU';
    indicator.dataset.state = 'error';
  } finally {
    setBusy(false);
  }
}

for (const button of buttons) {
  button.addEventListener('click', () => runAction(button.dataset.action));
}

runAction('status');
