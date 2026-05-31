'use strict';
// lib.js — Node port of scripts/plumblines-lib.sh.
// Pure Node built-ins (fs/path/child_process), no npm deps, to mirror the
// shell lib's "no yq/jq" philosophy. Keep this in lockstep with the bash lib:
// the frontmatter contract and trust ranks must not drift between the two.

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

// Run git, returning trimmed stdout, or null on failure.
function git(args, opts = {}) {
  try {
    return execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], ...opts }).trim();
  } catch {
    return null;
  }
}

function isGitRepo() {
  return git(['rev-parse', '--git-dir']) !== null;
}

// Resolve a ref/sha to a full commit sha, or null if it isn't in history.
function resolveCommit(sha) {
  return git(['rev-parse', '--verify', '--quiet', `${sha}^{commit}`]);
}

// Lines of the YAML frontmatter block (between the first two `---` lines).
function frontmatter(content) {
  const lines = content.split(/\r?\n/);
  if (lines[0] !== '---') return [];
  const out = [];
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === '---') break;
    out.push(lines[i]);
  }
  return out;
}

function stripQuotes(s) {
  return s.replace(/^["']/, '').replace(/["']$/, '');
}

// Scalar field: field(fm, "trust").
function field(fm, key) {
  const re = new RegExp('^' + key + ':');
  for (const line of fm) {
    if (re.test(line)) {
      return stripQuotes(line.replace(new RegExp('^' + key + ':[ \\t]*'), '').replace(/[ \t]+$/, ''));
    }
  }
  return '';
}

// Block list: list(fm, "depends_on") -> array of values.
function list(fm, key) {
  const head = new RegExp('^' + key + ':[ \\t]*$');
  const item = /^[ \t]+-[ \t]*(.*)$/;
  const out = [];
  let inList = false;
  for (const line of fm) {
    if (!inList) {
      if (head.test(line)) inList = true;
      continue;
    }
    const m = item.exec(line);
    if (m) { out.push(stripQuotes(m[1])); continue; }
    if (/^[^ \t]/.test(line)) break; // dedented out of the block
  }
  return out;
}

// Trust levels found inside the `provenance:` block items.
function provenanceTrust(fm) {
  const out = [];
  let inProv = false;
  for (const line of fm) {
    if (/^provenance:/.test(line)) { inProv = true; continue; }
    if (!inProv) continue;
    const m = /trust:[ \t]*([A-Za-z-]+)/.exec(line);
    if (m) { out.push(m[1]); continue; }
    if (/^[^ \t-]/.test(line)) break;
  }
  return out;
}

// Higher = more trusted. Unknown -> -1.
function trustRank(t) {
  switch (t) {
    case 'verified': return 3;
    case 'inferred': return 2;
    case 'assumed': return 1;
    default: return -1;
  }
}

// Load .plumblines config. Precedence: env var > config file > built-in default.
function loadConfig(cwd = process.cwd()) {
  const cfgPath = process.env.PLUMBLINES_CONFIG || path.join(cwd, '.plumblines');
  let dirCfg = '';
  let globsCfg = '';
  if (fs.existsSync(cfgPath)) {
    for (let line of fs.readFileSync(cfgPath, 'utf8').split(/\r?\n/)) {
      if (line === '' || line.startsWith('#')) continue;
      const eq = line.indexOf('=');
      if (eq < 0) continue;
      const key = line.slice(0, eq).trim();
      const val = stripQuotes(line.slice(eq + 1).trim());
      if (key === 'agent_dir') dirCfg = val;
      else if (key === 'src_globs') globsCfg = val;
    }
  }
  const agentDir = process.env.PLUMBLINES_DIR || dirCfg || '.agent_files';
  const srcGlobs = process.env.PLUMBLINES_SRC_GLOBS || globsCfg || 'src/ lib/ app/ packages/';
  return { agentDir, srcGlobs };
}

// All record files under the memory tree, pruning non-record subtrees
// (templates/ holds blank scaffolds, dashboards/ holds Obsidian views).
function records(root) {
  const out = [];
  const skip = new Set(['templates', 'dashboards']);
  function walk(dir) {
    let entries;
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      const full = path.join(dir, e.name);
      if (e.isDirectory()) {
        if (skip.has(e.name)) continue;
        walk(full);
      } else if (e.isFile() && e.name.endsWith('.md')) {
        out.push(full.split(path.sep).join('/')); // forward slashes to match the shell lib
      }
    }
  }
  walk(root);
  return out;
}

module.exports = {
  git, isGitRepo, resolveCommit, frontmatter, field, list,
  provenanceTrust, trustRank, loadConfig, records,
};
