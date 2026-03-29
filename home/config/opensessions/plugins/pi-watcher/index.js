const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const POLL_MS = 2000;
const SESSION_ROOT = path.join(process.env.HOME || '', '.pi', 'agent', 'sessions');
const MAX_FILES_PER_DIR = 6;
const TAIL_BYTES = 128 * 1024;

function run(cmd, args) {
  try {
    return execFileSync(cmd, args, { encoding: 'utf8' });
  } catch {
    return '';
  }
}

function realpathSafe(p) {
  try {
    return fs.realpathSync(p);
  } catch {
    return p;
  }
}

function normalizeThreadName(title, cwd, paneId, windowIndex, paneIndex, session, sessionFile) {
  const trimmed = (title || '').trim();
  let base = '';

  if (trimmed.startsWith('π - ')) base = trimmed.slice(4).trim();
  else if (trimmed.startsWith('pi - ')) base = trimmed.slice(5).trim();
  else if (trimmed && !trimmed.startsWith('Gm=')) base = trimmed;
  else if (cwd) base = path.basename(cwd);
  else base = paneId;

  const instance = sessionFile ? path.basename(sessionFile, '.jsonl').split('_').pop().slice(0, 8) : `${windowIndex}.${paneIndex}`;

  if (!base || base === session || base.startsWith('Gm=')) {
    return `${session}:${instance}`;
  }
  return `${base} · ${instance}`;
}

function listPanes() {
  const out = run('tmux', ['list-panes', '-a', '-F', '#{session_name}\t#{window_index}\t#{pane_index}\t#{pane_id}\t#{pane_pid}\t#{pane_title}\t#{pane_current_path}']);
  return out
    .split('\n')
    .filter(Boolean)
    .map((line) => {
      const [session, windowIndex, paneIndex, paneId, panePid, title, cwd] = line.split('\t');
      return {
        session,
        windowIndex: Number(windowIndex),
        paneIndex: Number(paneIndex),
        paneId,
        panePid: Number(panePid),
        title: title || '',
        cwd: cwd || '',
        cwdReal: realpathSafe(cwd || ''),
      };
    })
    .filter((pane) => pane.session && pane.paneId && Number.isFinite(pane.panePid) && pane.panePid > 0)
    .filter((pane) => pane.session !== '_os_stash');
}

function processSnapshot() {
  const out = run('ps', ['-axo', 'pid=,ppid=,state=,comm=,args=']);
  const byParent = new Map();
  const byPid = new Map();

  for (const rawLine of out.split('\n')) {
    const line = rawLine.trim();
    if (!line) continue;
    const match = line.match(/^(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s*(.*)$/);
    if (!match) continue;
    const [, pidRaw, ppidRaw, state, comm, args] = match;
    const proc = {
      pid: Number(pidRaw),
      ppid: Number(ppidRaw),
      state,
      comm,
      args: args || '',
    };
    byPid.set(proc.pid, proc);
    const list = byParent.get(proc.ppid) || [];
    list.push(proc);
    byParent.set(proc.ppid, list);
  }

  return { byPid, byParent };
}

function findPiDescendants(rootPid, procSnapshot) {
  const { byPid, byParent } = procSnapshot;
  const queue = [rootPid];
  const seen = new Set();
  const found = [];

  while (queue.length > 0) {
    const pid = queue.shift();
    if (seen.has(pid)) continue;
    seen.add(pid);

    const proc = byPid.get(pid);
    if (proc && proc.comm === 'pi' && !proc.state.includes('Z') && !proc.state.includes('T')) {
      found.push(proc);
    }

    const children = byParent.get(pid) || [];
    for (const child of children) queue.push(child.pid);
  }

  return found;
}

function readSessionHeader(filePath) {
  try {
    const fd = fs.openSync(filePath, 'r');
    const buf = Buffer.alloc(4096);
    const bytes = fs.readSync(fd, buf, 0, buf.length, 0);
    fs.closeSync(fd);
    const firstLine = buf.toString('utf8', 0, bytes).split('\n')[0];
    if (!firstLine) return null;
    const obj = JSON.parse(firstLine);
    if (obj.type !== 'session' || !obj.cwd) return null;
    return { cwd: obj.cwd, cwdReal: realpathSafe(obj.cwd), id: obj.id };
  } catch {
    return null;
  }
}

function collectCandidatesByRealpath() {
  const byRealpath = new Map();
  let dirs = [];
  try {
    dirs = fs.readdirSync(SESSION_ROOT, { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && !entry.name.startsWith('.'))
      .map((entry) => path.join(SESSION_ROOT, entry.name));
  } catch {
    return byRealpath;
  }

  for (const dir of dirs) {
    let files = [];
    try {
      files = fs.readdirSync(dir)
        .filter((name) => name.endsWith('.jsonl'))
        .map((name) => path.join(dir, name))
        .map((filePath) => ({ filePath, mtimeMs: fs.statSync(filePath).mtimeMs }))
        .sort((a, b) => b.mtimeMs - a.mtimeMs)
        .slice(0, MAX_FILES_PER_DIR);
    } catch {
      continue;
    }

    for (const file of files) {
      const header = readSessionHeader(file.filePath);
      if (!header?.cwdReal) continue;
      const list = byRealpath.get(header.cwdReal) || [];
      list.push({ filePath: file.filePath, mtimeMs: file.mtimeMs, sessionId: header.id, cwd: header.cwd });
      byRealpath.set(header.cwdReal, list);
    }
  }

  for (const list of byRealpath.values()) {
    list.sort((a, b) => b.mtimeMs - a.mtimeMs);
  }

  return byRealpath;
}

function parseSessionStatus(filePath) {
  try {
    const stat = fs.statSync(filePath);
    const size = stat.size;
    const start = Math.max(0, size - TAIL_BYTES);
    const fd = fs.openSync(filePath, 'r');
    const buf = Buffer.alloc(size - start);
    fs.readSync(fd, buf, 0, buf.length, start);
    fs.closeSync(fd);

    const lines = buf.toString('utf8').split('\n').filter(Boolean);
    for (let i = lines.length - 1; i >= 0; i--) {
      let obj;
      try {
        obj = JSON.parse(lines[i]);
      } catch {
        continue;
      }
      if (obj.type !== 'message' || !obj.message) continue;

      const msg = obj.message;
      const role = msg.role;
      const content = Array.isArray(msg.content) ? msg.content : [];
      const hasToolCall = content.some((item) => item && item.type === 'toolCall');

      if (role === 'assistant') {
        if (msg.stopReason === 'toolUse' || hasToolCall) return { status: 'running', ts: Date.parse(obj.timestamp) || stat.mtimeMs };
        if (msg.stopReason === 'stop') return { status: 'idle', ts: Date.parse(obj.timestamp) || stat.mtimeMs };
        return { status: 'running', ts: Date.parse(obj.timestamp) || stat.mtimeMs };
      }

      if (role === 'toolResult') {
        return { status: msg.isError ? 'error' : 'running', ts: Date.parse(obj.timestamp) || stat.mtimeMs };
      }

      if (role === 'user') {
        return { status: 'running', ts: Date.parse(obj.timestamp) || stat.mtimeMs };
      }
    }
  } catch {}

  return { status: 'idle', ts: Date.now() };
}

class PiWatcher {
  constructor() {
    this.name = 'pi';
    this.ctx = null;
    this.timer = null;
    this.active = new Map();
  }

  start(ctx) {
    this.ctx = ctx;
    this.scan();
    // Re-scan shortly after start so the sidebar picks up agents
    // even if the UI wasn't ready for the first emit
    setTimeout(() => this.scan(), 500);
    this.timer = setInterval(() => this.scan(), POLL_MS);
  }

  stop() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
    this.ctx = null;
    this.active.clear();
  }

  scan() {
    if (!this.ctx) return;

    const panes = listPanes();
    const procSnapshot = processSnapshot();
    const filesByRealpath = collectCandidatesByRealpath();
    const nextActive = new Map();
    const panesByCwd = new Map();

    for (const pane of panes) {
      const piProcs = findPiDescendants(pane.panePid, procSnapshot);
      if (piProcs.length === 0) continue;
      const key = pane.cwdReal || pane.cwd || pane.paneId;
      const list = panesByCwd.get(key) || [];
      list.push(pane);
      panesByCwd.set(key, list);
    }

    for (const [cwdKey, paneGroup] of panesByCwd) {
      paneGroup.sort((a, b) => a.windowIndex - b.windowIndex || a.paneIndex - b.paneIndex || a.paneId.localeCompare(b.paneId));
      const candidates = [...(filesByRealpath.get(cwdKey) || [])];

      for (let index = 0; index < paneGroup.length; index++) {
        const pane = paneGroup[index];
        const file = candidates[index] || null;
        const key = pane.paneId;
        const parsed = file ? parseSessionStatus(file.filePath) : { status: 'idle', ts: Date.now() };
        const threadName = normalizeThreadName(
          pane.title,
          pane.cwd,
          pane.paneId,
          pane.windowIndex,
          pane.paneIndex,
          pane.session,
          file?.filePath,
        );

        nextActive.set(key, {
          session: pane.session,
          paneId: pane.paneId,
          threadName,
          status: parsed.status,
          filePath: file?.filePath || null,
        });

        this.ctx.emit({
          agent: 'pi',
          session: pane.session,
          status: parsed.status,
          ts: parsed.ts,
          threadId: key,
          threadName,
          paneId: pane.paneId,
        });
      }
    }

    for (const [key, prev] of this.active) {
      if (nextActive.has(key)) continue;
      this.ctx.emit({
        agent: 'pi',
        session: prev.session,
        status: 'done',
        ts: Date.now(),
        threadId: key,
        threadName: prev.threadName,
        paneId: prev.paneId,
      });
    }

    this.active = nextActive;
  }
}

module.exports = function register(api) {
  api.registerWatcher(new PiWatcher());
};
