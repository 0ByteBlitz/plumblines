'use strict';
// init.js — Node port of scripts/plumblines-init.sh, used by `plumblines init`.
// Unlike the shell scaffolder (which copies from an adjacent templates/), this
// reads bundled assets from the installed package, so it works via npx with
// nothing checked out. It also drops the shell scripts/ into the target so the
// bash/CI wiring still works for teammates who prefer it.

const fs = require('fs');
const path = require('path');
const L = require('./lib');

const PKG_ROOT = path.resolve(__dirname, '..');
const TPL = path.join(PKG_ROOT, 'templates');

function run(opts) {
  const layout = opts.team ? 'team' : 'minimal';
  const agentDir = opts.dir || '.agent_files';
  let srcGlobs = opts.srcGlobs || '';

  if (!fs.existsSync(TPL)) {
    console.error(`templates/ not found in package (${TPL})`);
    return 2;
  }

  let made = 0, skipped = 0;
  const mk = (p) => { if (!fs.existsSync(p)) { fs.mkdirSync(p, { recursive: true }); console.log('  + dir  ' + p); } };
  const cpT = (src, dst) => {
    if (fs.existsSync(dst)) { console.log('  = skip ' + dst + ' (exists)'); skipped++; return; }
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(src, dst); console.log('  + file ' + dst); made++;
  };

  console.log(`Plumblines init → layout=${layout} dir=${agentDir}\n`);

  // directory tree
  mk(agentDir);
  mk(path.join(agentDir, 'local/changes'));
  mk(path.join(agentDir, 'compacted'));
  mk(path.join(agentDir, 'templates'));
  if (layout === 'team') { mk(path.join(agentDir, 'shared')); mk(path.join(agentDir, 'domains')); }

  // canonical files (lowercase template -> UPPERCASE convention)
  cpT(path.join(TPL, 'AGENT_RULES.md'), path.join(agentDir, 'AGENT_RULES.md'));
  cpT(path.join(TPL, 'context-priority.md'), path.join(agentDir, 'CONTEXT_PRIORITY.md'));
  cpT(path.join(TPL, 'loading-policy.md'), path.join(agentDir, 'LOADING_POLICY.md'));
  cpT(path.join(TPL, 'project-state.md'), path.join(agentDir, 'PROJECT_STATE.md'));
  cpT(path.join(TPL, 'working-state.md'), path.join(agentDir, 'local/WORKING_STATE.md'));
  if (layout === 'team') {
    cpT(path.join(TPL, 'project-state.md'), path.join(agentDir, 'shared/PROJECT_STATE.md'));
    cpT(path.join(TPL, 'decisions.md'), path.join(agentDir, 'shared/DECISION_LOG.md'));
    cpT(path.join(TPL, 'risks.md'), path.join(agentDir, 'shared/KNOWN_RISKS.md'));
  }

  // stamp the current commit into freshly scaffolded state files
  const headSha = L.git(['rev-parse', 'HEAD']);
  if (headSha) {
    for (const rel of ['PROJECT_STATE.md', 'local/WORKING_STATE.md', 'shared/PROJECT_STATE.md', 'shared/DECISION_LOG.md']) {
      const s = path.join(agentDir, rel);
      if (fs.existsSync(s)) {
        const txt = fs.readFileSync(s, 'utf8');
        if (txt.includes('valid_as_of_commit: COMMIT_SHA')) {
          fs.writeFileSync(s, txt.replace('valid_as_of_commit: COMMIT_SHA', 'valid_as_of_commit: ' + headSha));
        }
      }
    }
  }

  // in-project copy of templates
  for (const f of fs.readdirSync(TPL)) {
    if (f.endsWith('.md')) cpT(path.join(TPL, f), path.join(agentDir, 'templates', f));
  }

  // bundled shell scripts, so bash/CI wiring keeps working
  const scriptsSrc = path.join(PKG_ROOT, 'scripts');
  if (fs.existsSync(scriptsSrc)) {
    mk('scripts');
    for (const f of fs.readdirSync(scriptsSrc)) cpT(path.join(scriptsSrc, f), path.join('scripts', f));
  }

  // source-glob detection
  if (!srcGlobs) {
    const detected = [];
    for (const d of ['src', 'lib', 'app', 'packages', 'services', 'cmd', 'pkg', 'internal', 'apps', 'source']) {
      if (fs.existsSync(d) && fs.statSync(d).isDirectory()) detected.push(d + '/');
    }
    srcGlobs = detected.length ? detected.join(' ') : 'src/ lib/ app/ packages/';
  }
  srcGlobs = srcGlobs.trim();
  console.log('  src globs: ' + srcGlobs);

  // .plumblines config
  if (fs.existsSync('.plumblines')) {
    console.log('  = skip .plumblines (exists)');
  } else {
    fs.writeFileSync('.plumblines',
      '# Plumblines config. Read by scripts/*.sh, the PowerShell scaffolder, the\n' +
      '# npx CLI, and CI. Environment variables of the same name override these.\n' +
      `agent_dir=${agentDir}\nsrc_globs=${srcGlobs}\n`);
    console.log('  + file .plumblines'); made++;
  }

  // .gitignore
  const giLine = `${agentDir}/local/`;
  const gi = fs.existsSync('.gitignore') ? fs.readFileSync('.gitignore', 'utf8') : '';
  if (gi.split(/\r?\n/).includes(giLine)) {
    console.log(`  = skip .gitignore (${giLine} already present)`);
  } else {
    fs.appendFileSync('.gitignore', `\n# Plumblines branch-local agent memory\n${giLine}\n`);
    console.log(`  + edit .gitignore (+ ${giLine})`);
  }

  // optional pre-push hook
  if (opts.hooks) {
    const gitdir = L.git(['rev-parse', '--git-dir']);
    if (!gitdir) {
      console.log('  ! --hooks: not a git repo, skipping');
    } else {
      const hook = path.join(gitdir, 'hooks/pre-push');
      if (fs.existsSync(hook)) {
        console.log('  = skip ' + hook + ' (exists)');
      } else {
        fs.mkdirSync(path.dirname(hook), { recursive: true });
        fs.writeFileSync(hook, '#!/usr/bin/env bash\nexec scripts/check-completeness.sh origin/main HEAD\n');
        try { fs.chmodSync(hook, 0o755); } catch {}
        console.log('  + file ' + hook); made++;
      }
    }
  }

  // optional Obsidian dashboards
  if (opts.obsidian) {
    const obsTpl = path.join(TPL, 'obsidian');
    if (fs.existsSync(obsTpl)) {
      mk(path.join(agentDir, 'dashboards'));
      for (const f of fs.readdirSync(obsTpl)) cpT(path.join(obsTpl, f), path.join(agentDir, 'dashboards', f));
      console.log(`  Obsidian: open '${agentDir}' as a vault (it's a dot-folder — see docs/obsidian.md),`);
      console.log('            then open dashboards/plumblines.base.');
    } else {
      console.log('  ! --obsidian: bundled dashboards not found, skipping');
    }
  }

  // optional CI workflow
  if (opts.ci) {
    const wf = '.github/workflows/plumblines.yml';
    if (fs.existsSync(wf)) {
      console.log('  = skip ' + wf + ' (exists)');
    } else {
      fs.mkdirSync(path.dirname(wf), { recursive: true });
      fs.writeFileSync(wf,
        'name: plumblines\n' +
        'on: pull_request\n' +
        'jobs:\n' +
        '  completeness:\n' +
        '    runs-on: ubuntu-latest\n' +
        '    steps:\n' +
        '      - uses: actions/checkout@v4\n' +
        '        with: { fetch-depth: 0 }\n' +
        '      - name: Completeness gate\n' +
        '        run: bash scripts/check-completeness.sh origin/${{ github.base_ref }} HEAD\n' +
        '      - name: Staleness report (non-blocking)\n' +
        '        run: bash scripts/check-staleness.sh || true\n');
      console.log('  + file ' + wf); made++;
    }
  }

  const short = L.git(['rev-parse', '--short', 'HEAD']) || '<commit>';
  console.log(`\nDone. created=${made} skipped=${skipped}`);
  console.log('Next:');
  console.log(`  1. Fill ${agentDir}/PROJECT_STATE.md (or run the plumblines-init agent skill to draft it).`);
  console.log(`  2. Set valid_as_of_commit in PROJECT_STATE.md to: ${short}`);
  console.log(`  3. Point your agent at ${agentDir}/AGENT_RULES.md, CONTEXT_PRIORITY.md, LOADING_POLICY.md.`);
  return 0;
}

module.exports = { run };
