const express = require('express');
const Docker  = require('dockerode');
const fs      = require('fs');
const path    = require('path');

const app    = express();
const docker = new Docker({ socketPath: '/var/run/docker.sock' });

const CONTAINER_NAME = process.env.HERMES_CONTAINER || 'hermes-agent';
const ENV_FILE       = process.env.HERMES_ENV_FILE  || '/hermes_env/.env';
const PORT           = process.env.DASHBOARD_PORT   || 3000;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────
async function getContainer() {
  const containers = await docker.listContainers({ all: true });
  const info = containers.find(c =>
    c.Names.some(n => n.replace('/', '') === CONTAINER_NAME)
  );
  if (!info) return null;
  return docker.getContainer(info.Id);
}

async function getStatus() {
  const containers = await docker.listContainers({ all: true });
  const info = containers.find(c =>
    c.Names.some(n => n.replace('/', '') === CONTAINER_NAME)
  );
  if (!info) return { status: 'not_found', uptime: null };
  return { status: info.State, uptime: info.Status };
}

function parseEnv(content) {
  const vars = {};
  content.split('\n').forEach(line => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return;
    const idx = trimmed.indexOf('=');
    if (idx === -1) return;
    const key = trimmed.slice(0, idx).trim();
    const val = trimmed.slice(idx + 1).trim().replace(/^["']|["']$/g, '');
    vars[key] = val;
  });
  return vars;
}

function buildEnvContent(existing, updates) {
  const lines = existing.split('\n');
  const result = lines.map(line => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) return line;
    const idx = trimmed.indexOf('=');
    if (idx === -1) return line;
    const key = trimmed.slice(0, idx).trim();
    if (key in updates) {
      const val = updates[key];
      delete updates[key];
      return `${key}=${val}`;
    }
    return line;
  });
  // Append any new keys not found in original
  Object.entries(updates).forEach(([k, v]) => {
    result.push(`${k}=${v}`);
  });
  return result.join('\n');
}

// ─────────────────────────────────────────────
// API Routes
// ─────────────────────────────────────────────

// Status do container
app.get('/api/status', async (req, res) => {
  try {
    const s = await getStatus();
    res.json(s);
  } catch (e) {
    res.json({ status: 'error', message: e.message });
  }
});

// Logs (últimas 200 linhas)
app.get('/api/logs', async (req, res) => {
  try {
    const c = await getContainer();
    if (!c) return res.json({ logs: 'Container não encontrado.' });
    const logs = await c.logs({ stdout: true, stderr: true, tail: 200 });
    // Remove non-printable Docker mux header bytes
    const clean = logs.toString('utf8').replace(/[\x00-\x08\x0e-\x1f]/g, '');
    res.json({ logs: clean });
  } catch (e) {
    res.json({ logs: `Erro: ${e.message}` });
  }
});

// Start
app.post('/api/start', async (req, res) => {
  try {
    const c = await getContainer();
    if (!c) return res.json({ ok: false, msg: 'Container não encontrado' });
    await c.start();
    res.json({ ok: true });
  } catch (e) {
    res.json({ ok: false, msg: e.message });
  }
});

// Stop
app.post('/api/stop', async (req, res) => {
  try {
    const c = await getContainer();
    if (!c) return res.json({ ok: false, msg: 'Container não encontrado' });
    await c.stop();
    res.json({ ok: true });
  } catch (e) {
    res.json({ ok: false, msg: e.message });
  }
});

// Restart
app.post('/api/restart', async (req, res) => {
  try {
    const c = await getContainer();
    if (!c) return res.json({ ok: false, msg: 'Container não encontrado' });
    await c.restart();
    res.json({ ok: true });
  } catch (e) {
    res.json({ ok: false, msg: e.message });
  }
});

// Ler config (filtra chaves sensíveis para exibição parcial)
app.get('/api/config', (req, res) => {
  try {
    if (!fs.existsSync(ENV_FILE)) return res.json({ vars: {} });
    const content  = fs.readFileSync(ENV_FILE, 'utf8');
    const vars     = parseEnv(content);
    // Mask secret values
    const SECRETS  = ['API_KEY', 'TOKEN', 'PASSWORD', 'SECRET'];
    const masked   = {};
    for (const [k, v] of Object.entries(vars)) {
      if (SECRETS.some(s => k.includes(s)) && v.length > 4) {
        masked[k] = v.slice(0, 4) + '••••••••••••';
      } else {
        masked[k] = v;
      }
    }
    res.json({ vars: masked });
  } catch (e) {
    res.json({ vars: {}, error: e.message });
  }
});

// Salvar config (só as chaves enviadas)
app.post('/api/config', (req, res) => {
  try {
    const updates = req.body || {};
    // Remove masked values (não sobrescrever com mask) e valores nulos/vazios
    for (const [k, v] of Object.entries(updates)) {
      if (String(v).includes('••••')) delete updates[k];
      // Bug fix: apenas remover se for realmente vazio/nulo — não remover "false", "0", etc.
      if (v === '' || v === null || v === undefined) delete updates[k];
    }
    let existing = '';
    if (fs.existsSync(ENV_FILE)) existing = fs.readFileSync(ENV_FILE, 'utf8');
    const newContent = buildEnvContent(existing, updates);
    fs.writeFileSync(ENV_FILE, newContent, 'utf8');
    res.json({ ok: true });
  } catch (e) {
    res.json({ ok: false, msg: e.message });
  }
});

app.listen(PORT, () => {
  console.log(`[Dashboard] Rodando em http://0.0.0.0:${PORT}`);
  console.log(`[Dashboard] Container monitorado: ${CONTAINER_NAME}`);
  console.log(`[Dashboard] Arquivo .env: ${ENV_FILE}`);
});
