#!/usr/bin/env node
'use strict';
// plumblines CLI. Usage:
//   plumblines init [--team] [--dir <p>] [--src-globs "<g>"] [--hooks] [--ci] [--obsidian]
//   plumblines check [<since>] [<until>]      # completeness (blocking) + staleness (report)
//   plumblines check-completeness [<since>] [<until>]
//   plumblines check-staleness
//   plumblines help | --version

const path = require('path');
const L = require('./lib');

function usage() {
  console.log(`plumblines — project continuity framework for AI coding agents

Usage:
  plumblines init [options]            Scaffold .agent_files into this project
  plumblines check [since] [until]     Completeness (blocking) + staleness (report)
  plumblines check-completeness [since] [until]
  plumblines check-staleness
  plumblines help | --version

init options:
  --team               Team layout (shared/ + domains/)
  --dir <path>         Memory directory (default: .agent_files)
  --src-globs "<g>"    Override source globs instead of auto-detecting
  --hooks              Install .git/hooks/pre-push completeness gate
  --ci                 Write .github/workflows/plumblines.yml
  --obsidian           Drop Obsidian dashboards into <dir>/dashboards/

check defaults: since=origin/main until=HEAD`);
}

function parseInit(args) {
  const opts = { team: false, dir: '', srcGlobs: '', hooks: false, ci: false, obsidian: false };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    switch (a) {
      case '--team': opts.team = true; break;
      case '--minimal': opts.team = false; break;
      case '--hooks': opts.hooks = true; break;
      case '--ci': opts.ci = true; break;
      case '--obsidian': opts.obsidian = true; break;
      case '--dir': opts.dir = args[++i]; break;
      case '--src-globs': opts.srcGlobs = args[++i]; break;
      default:
        console.error('unknown option: ' + a);
        usage();
        process.exit(2);
    }
  }
  return opts;
}

function main() {
  const [, , cmd, ...rest] = process.argv;

  if (!cmd || cmd === 'help' || cmd === '--help' || cmd === '-h') { usage(); process.exit(0); }
  if (cmd === '--version' || cmd === 'version') {
    console.log(require(path.join(__dirname, '..', 'package.json')).version);
    process.exit(0);
  }

  if (cmd === 'init') {
    const init = require('./init');
    process.exit(init.run(parseInit(rest)));
  }

  const cfg = L.loadConfig();
  const checks = require('./checks');

  if (cmd === 'check-staleness') {
    process.exit(checks.staleness(cfg));
  }
  if (cmd === 'check-completeness') {
    const since = rest[0] || 'origin/main';
    const until = rest[1] || 'HEAD';
    process.exit(checks.completeness(since, until, cfg));
  }
  if (cmd === 'check') {
    const since = rest[0] || 'origin/main';
    const until = rest[1] || 'HEAD';
    const code = checks.completeness(since, until, cfg);
    console.log('');
    checks.staleness(cfg); // non-blocking report
    process.exit(code);
  }

  console.error('unknown command: ' + cmd);
  usage();
  process.exit(2);
}

main();
