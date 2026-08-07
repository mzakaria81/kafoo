#!/usr/bin/env node
/**
 * Fails if a service-role key reaches the built web surface.
 *
 * `verify.sh` already fails on a service-role key TRACKED BY GIT, and this
 * surface does not inherit that protection: a build output is not a tracked
 * file, and a key can arrive through an environment variable that is perfectly
 * safe on a server and fatal in a bundle. So the check has to look at what was
 * actually produced.
 *
 * A Supabase service-role JWT carries `"role":"service_role"` in its payload,
 * which base64url-encodes to a fixed substring — that is what is searched for,
 * along with the literal names, so a key is caught even when nothing near it is
 * called "service role".
 */
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

const ROOTS = ['.open-next', '.next'];
const NEEDLES = [
  'service_role',
  'SERVICE_ROLE',
  // base64url of {"role":"service_role" — present in the JWT itself
  'InJvbGUiOiJzZXJ2aWNlX3JvbGUi',
];

function* files(dir) {
  let entries;
  try {
    entries = readdirSync(dir);
  } catch {
    return;
  }
  for (const entry of entries) {
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) yield* files(path);
    else yield path;
  }
}

const hits = [];
let scanned = 0;
for (const root of ROOTS) {
  for (const path of files(root)) {
    if (!/\.(js|mjs|cjs|json|html|txt|map)$/.test(path)) continue;
    scanned++;
    const body = readFileSync(path, 'utf8');
    for (const needle of NEEDLES) {
      if (body.includes(needle)) hits.push(`${path}: ${needle}`);
    }
  }
}

// A check that passes because it inspected nothing is the failure mode this
// repository keeps meeting. Say so out loud rather than printing OK.
if (scanned === 0) {
  console.error('check:no-secret found no build output to scan. Run the build first.');
  process.exit(1);
}

if (hits.length) {
  console.error('SERVICE-ROLE KEY IN THE BUILD OUTPUT — rotate it, then fix the build:');
  for (const hit of hits) console.error(`  ${hit}`);
  process.exit(1);
}

console.log(`check:no-secret ok — ${scanned} build files scanned, no service-role key`);
