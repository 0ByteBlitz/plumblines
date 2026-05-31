'use strict';
// checks.js — Node ports of check-completeness.sh and check-staleness.sh.
// Behaviour must match the shell gates exactly.

const fs = require('fs');
const L = require('./lib');

function note(s) { console.log('  - ' + s); }

// Returns 0 clean, 1 violations, 2 not a git repo.
function completeness(since, until, cfg) {
  const { agentDir, srcGlobs } = cfg;
  if (!L.isGitRepo()) { console.log('not a git repo'); return 2; }

  let fail = 0;

  const recorded = new Set();
  for (const rec of L.records(agentDir)) {
    const fm = L.frontmatter(fs.readFileSync(rec, 'utf8'));
    const sha = L.field(fm, 'valid_as_of_commit');
    if (!sha) continue;
    const full = L.resolveCommit(sha);
    if (full) recorded.add(full);
  }

  console.log(`[1/2] Coverage: source commits in ${since}..${until} must have a record`);
  let rangeOk = true;
  if (L.git(['rev-parse', '--verify', '--quiet', since]) === null) {
    console.log(`  (skip) ref '${since}' not found — pass it explicitly on first run`);
    rangeOk = false;
  }

  if (rangeOk) {
    const globs = srcGlobs.trim().split(/\s+/).filter(Boolean);
    const out = L.git(['log', '--format=%H', `${since}..${until}`, '--', ...globs]);
    const srcCommits = out ? out.split('\n').filter(Boolean) : [];
    if (srcCommits.length === 0) {
      console.log('  ok — no source-touching commits in range');
    } else {
      let any = false;
      for (const c of srcCommits) {
        if (!recorded.has(c)) {
          const short = L.git(['rev-parse', '--short', c]);
          const subj = L.git(['log', '-1', '--format=%s', c]);
          note(`uncovered commit ${short} — ${subj}`);
          fail = 1; any = true;
        }
      }
      if (!any) console.log('  ok — every source commit has a change record');
    }
  }

  console.log('[2/2] Provenance: record trust <= lowest input trust');
  let provFail = 0;
  for (const rec of L.records(agentDir)) {
    const fm = L.frontmatter(fs.readFileSync(rec, 'utf8'));
    const trust = L.field(fm, 'trust');
    if (!trust) continue;
    if (trust === 'needs-review' || trust === 'stale') continue;
    const rrank = L.trustRank(trust);
    if (rrank < 0) continue;
    let lowest = 99;
    for (const pt of L.provenanceTrust(fm)) {
      const prank = L.trustRank(pt);
      if (prank >= 0 && prank < lowest) lowest = prank;
    }
    if (lowest !== 99 && rrank > lowest) {
      note(`${rec} claims trust=${trust} but has a lower-trust input`);
      provFail = 1; fail = 1;
    }
  }
  if (provFail === 0) console.log('  ok — no trust escalation found');

  if (fail !== 0) {
    console.log('\nFAIL: Plumblines completeness checks found issues above.');
    console.log('Add the missing change record(s) or correct the trust labels, then re-run.');
    return 1;
  }
  console.log('\nPASS: Plumblines completeness checks clean.');
  return 0;
}

// Returns 0 nothing stale, 1 stale found, 2 not a git repo.
function staleness(cfg) {
  const { agentDir } = cfg;
  if (!L.isGitRepo()) { console.log('not a git repo'); return 2; }

  let stale = 0;
  console.log('Staleness scan (depends_on changed since valid_as_of_commit)');
  for (const rec of L.records(agentDir)) {
    const fm = L.frontmatter(fs.readFileSync(rec, 'utf8'));
    const sha = L.field(fm, 'valid_as_of_commit');
    if (!sha) continue;
    const full = L.resolveCommit(sha);
    if (!full) {
      console.log(`  ? ${rec} — valid_as_of_commit ${sha} not found in history`);
      stale = 1; continue;
    }
    const deps = L.list(fm, 'depends_on');
    if (deps.length === 0) continue;
    const changed = L.git(['diff', '--name-only', `${full}..HEAD`, '--', ...deps]);
    if (changed) {
      const trust = L.field(fm, 'trust') || '?';
      const short = L.git(['rev-parse', '--short', full]);
      console.log(`  ! ${rec} (trust=${trust}) — dependencies changed since ${short}:`);
      for (const f of changed.split('\n').filter(Boolean)) console.log('      ' + f);
      stale = 1;
    }
  }

  if (stale !== 0) {
    console.log('\nReview the records above and re-label as needs-review or update them.');
    return 1;
  }
  console.log('  ok — no stale records detected.');
  return 0;
}

module.exports = { completeness, staleness };
