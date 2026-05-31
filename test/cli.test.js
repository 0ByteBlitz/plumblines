'use strict';
// Dependency-free test for the plumblines CLI. Run: node test/cli.test.js
// Asserts init + gate behaviour, and (when bash is available) that the Node
// gates produce byte-identical output to the shell gates — the guard against
// the two implementations drifting apart.

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const CLI = path.resolve(__dirname, '..', 'cli', 'index.js');
const SCRIPTS = path.resolve(__dirname, '..', 'scripts');
let failures = 0;

function ok(cond, msg) {
  if (cond) console.log('  ok  ' + msg);
  else { console.log('  FAIL ' + msg); failures++; }
}

function git(args, cwd) {
  execFileSync('git', args, { cwd, stdio: 'ignore' });
}

// Run a command, returning { code, out } without throwing on non-zero exit.
function run(file, args, cwd) {
  try {
    const out = execFileSync(file, args, { cwd, encoding: 'utf8' });
    return { code: 0, out };
  } catch (e) {
    return { code: e.status == null ? 1 : e.status, out: (e.stdout || '') + (e.stderr || '') };
  }
}
const node = (args, cwd) => run('node', [CLI, ...args], cwd);

function hasBash() {
  try { execFileSync('bash', ['-c', 'true'], { stdio: 'ignore' }); return true; } catch { return false; }
}

function setupRepo() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pl-test-'));
  const proj = path.join(dir, 'proj');
  fs.mkdirSync(path.join(proj, 'src'), { recursive: true });
  fs.writeFileSync(path.join(proj, 'src', 'app.js'), 'export const x = 1;\n');
  git(['init', '-q'], proj);
  git(['-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-q', '--allow-empty', '-m', 'placeholder'], proj);
  // stage + commit the source so init has a HEAD to stamp
  git(['add', '-A'], proj);
  git(['-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-q', '-m', 'init src'], proj);
  return proj;
}

console.log('plumblines CLI test');

// --- init produces a clean, gate-passing tree -------------------------------
{
  const proj = setupRepo();
  const r = node(['init', '--obsidian'], proj);
  ok(r.code === 0, 'init exits 0');
  ok(fs.existsSync(path.join(proj, '.agent_files', 'PROJECT_STATE.md')), 'PROJECT_STATE.md created');
  ok(fs.existsSync(path.join(proj, '.plumblines')), '.plumblines written');
  ok(fs.existsSync(path.join(proj, '.agent_files', 'dashboards', 'plumblines.base')), 'obsidian dashboard copied');
  const ps = fs.readFileSync(path.join(proj, '.agent_files', 'PROJECT_STATE.md'), 'utf8');
  ok(!ps.includes('COMMIT_SHA'), 'PROJECT_STATE.md commit-stamped (no placeholder)');

  const clean = node(['check', 'HEAD', 'HEAD'], proj);
  ok(clean.code === 0, 'check passes on fresh scaffold');
  ok(/PASS: Plumblines completeness/.test(clean.out), 'completeness PASS printed');
  ok(/no stale records detected/.test(clean.out), 'staleness clean printed');
}

// --- gates detect violations ------------------------------------------------
{
  const proj = setupRepo();
  node(['init'], proj);
  const changes = path.join(proj, '.agent_files', 'local', 'changes');

  // trust escalation: verified record with an assumed input
  fs.writeFileSync(path.join(changes, 'bad.md'),
    '---\nrecord_type: change\nid: bad\ntrust: verified\n' +
    'provenance:\n  - { source: src/app.js, trust: assumed }\n---\nbad\n');
  const comp = node(['check-completeness', 'HEAD', 'HEAD'], proj);
  ok(comp.code === 1, 'completeness flags trust escalation (exit 1)');
  ok(/lower-trust input/.test(comp.out), 'escalation message printed');

  // staleness: a record whose dependency changes after its commit
  const sha = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: proj, encoding: 'utf8' }).trim();
  fs.writeFileSync(path.join(changes, 'st.md'),
    `---\nrecord_type: state\nid: st\nvalid_as_of_commit: ${sha}\n` +
    'depends_on:\n  - src/app.js\ntrust: inferred\n---\n');
  fs.appendFileSync(path.join(proj, 'src', 'app.js'), 'export const y = 2;\n');
  git(['add', '-A'], proj);
  git(['-c', 'user.email=t@t', '-c', 'user.name=t', 'commit', '-q', '-m', 'touch dep'], proj);
  const stale = node(['check-staleness'], proj);
  ok(stale.code === 1, 'staleness flags changed dependency (exit 1)');
  ok(/dependencies changed since/.test(stale.out), 'staleness message printed');
}

// --- parity with the shell gates (only where bash exists) -------------------
if (hasBash() && fs.existsSync(path.join(SCRIPTS, 'check-completeness.sh'))) {
  const proj = setupRepo();
  node(['init'], proj); // also drops scripts/ into proj
  const changes = path.join(proj, '.agent_files', 'local', 'changes');
  fs.writeFileSync(path.join(changes, 'bad.md'),
    '---\nrecord_type: change\nid: bad\ntrust: verified\n' +
    'provenance:\n  - { source: src/app.js, trust: assumed }\n---\nbad\n');

  const b = run('bash', ['scripts/check-completeness.sh', 'HEAD~1', 'HEAD'], proj);
  const n = node(['check-completeness', 'HEAD~1', 'HEAD'], proj);
  ok(b.out === n.out, 'completeness output byte-identical to shell gate');
  ok(b.code === n.code, 'completeness exit code matches shell gate');

  const bs = run('bash', ['scripts/check-staleness.sh'], proj);
  const ns = node(['check-staleness'], proj);
  ok(bs.out === ns.out, 'staleness output byte-identical to shell gate');
} else {
  console.log('  --  bash not available; skipping shell-parity checks');
}

console.log(failures === 0 ? '\nALL PASS' : `\n${failures} FAILURE(S)`);
process.exit(failures === 0 ? 0 : 1);
