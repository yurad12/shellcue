const vscode = require('vscode');
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');

exports.activate = async function(context) {
  if (process.platform !== 'darwin' || vscode.env.remoteName) return;
  const directory = path.join(os.homedir(), 'Library/Application Support/ShellCue/vscode');
  await fs.mkdir(directory, {recursive:true, mode:0o700});
  const windowID = crypto.randomUUID();
  const file = path.join(directory, windowID + '.json');
  const terminals = new Map();
  const running = new Set();
  let busy = false, disposed = false;
  const idFor = terminal => {
    if (!terminals.has(terminal)) terminals.set(terminal, crypto.randomUUID());
    return terminals.get(terminal);
  };
  async function atomic(file, value) {
    await fs.writeFile(file + '.tmp', JSON.stringify(value), {mode:0o600});
    await fs.rename(file + '.tmp', file);
  }
  async function tick() {
    if (busy || disposed) return;
    busy = true;
    try {
      const live = vscode.window.terminals;
      for (const terminal of terminals.keys()) if (!live.includes(terminal)) terminals.delete(terminal);
      const snapshots = live.map(terminal => ({
        id:idFor(terminal), name:terminal.name,
        cwd:terminal.shellIntegration?.cwd?.scheme === 'file' ? terminal.shellIntegration.cwd.fsPath : null,
        state:running.has(terminal) ? 'running' : 'unknown'
      }));
      await atomic(file, {version:1, windowID, updatedAt:Date.now()/1000, terminals:snapshots});
      const requestFile = path.join(directory, windowID + '.request');
      let request;
      try { request = JSON.parse(await fs.readFile(requestFile, 'utf8')); }
      catch (error) { if (error.code === 'ENOENT') return; throw error; }
      await fs.unlink(requestFile);
      const terminal = live.find(t => terminals.get(t) === request.terminalID);
      const valid = terminal && typeof request.nonce === 'string' && Date.now()/1000 - request.createdAt < 5;
      let success = false;
      if (valid) {
        try {
          await vscode.commands.executeCommand('workbench.action.focusWindow');
          terminal.show(false);
          success = true;
        } catch (_) {}
      }
      await atomic(path.join(directory, windowID + '.response'), {nonce:request.nonce, success});
    } catch (error) { console.warn('ShellCue bridge:', error.message); }
    finally { busy = false; }
  }
  context.subscriptions.push(vscode.window.onDidStartTerminalShellExecution(e => {running.add(e.terminal); void tick();}));
  context.subscriptions.push(vscode.window.onDidEndTerminalShellExecution(e => {running.delete(e.terminal); void tick();}));
  context.subscriptions.push(vscode.window.onDidCloseTerminal(t => {running.delete(t); void tick();}));
  const timer = setInterval(() => void tick(), 500);
  context.subscriptions.push({dispose() { disposed=true; clearInterval(timer); void fs.unlink(file).catch(()=>{}); }});
  await tick();
};
