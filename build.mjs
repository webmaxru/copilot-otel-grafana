// Bundle src/analytics.js -> docs/analytics.js and inject the Application Insights
// connection string (a PUBLIC client key) at build time.
//
//   Local:  put APPINSIGHTS_CONNECTION_STRING=... in .env  (git-ignored)
//   CI:     pass it from the repo variable vars.APPINSIGHTS_CONNECTION_STRING
//
// The output docs/analytics.js is a build artifact (git-ignored) — it is generated
// fresh by CI and deployed with the site; it is never committed.

import { build } from 'esbuild';
import { readFileSync, existsSync } from 'node:fs';

// Minimal .env loader for local builds (no dependency on dotenv).
if (existsSync('.env')) {
  for (const line of readFileSync('.env', 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_.]*)\s*=\s*(.*)\s*$/);
    if (m && process.env[m[1]] === undefined) {
      process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
  }
}

const conn = process.env.APPINSIGHTS_CONNECTION_STRING || '';
if (!conn) {
  console.warn('[build] APPINSIGHTS_CONNECTION_STRING is empty — analytics.js will be inert.');
}

await build({
  entryPoints: ['src/analytics.js'],
  bundle: true,
  minify: true,
  format: 'iife',
  target: ['es2019'],
  outfile: 'docs/analytics.js',
  define: { __APPINSIGHTS_CONNECTION_STRING__: JSON.stringify(conn) },
  legalComments: 'none',
  logLevel: 'info',
});

console.log(
  `[build] wrote docs/analytics.js (${conn ? 'analytics enabled' : 'inert — no connection string'})`
);
