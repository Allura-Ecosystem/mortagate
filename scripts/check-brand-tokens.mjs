#!/usr/bin/env node
/**
 * Veridact brand-token guard  (ADR-UX-01, 2026-07-01)
 * Static gate enforcing WCAG AA palette rules that jsdom/axe cannot check,
 * because CSS-variable colors from the static resource are not computed at test time.
 *
 * Fails the build (exit 1) if any LWC stylesheet:
 *   1. hardcodes a hex color        -> must reference a --veridact-* token
 *   2. uses --veridact-white-60 as a `color:` (text)  -> decorative only, 3.15:1
 *   3. uses --veridact-proof-amber (#E25D22) as a `color:` (normal text) -> 3.18:1;
 *      normal-size orange text / white-on-orange must use --veridact-accent-strong (#B8441A)
 *
 * Usage:  node scripts/check-brand-tokens.mjs   (wired as `npm run test:tokens`)
 */
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, extname } from 'node:path';

const LWC_ROOT = 'force-app/main/default/lwc';
const IGNORE = ['.worktrees', '.claude', 'vibefore-audit', 'node_modules'];

// Hex allowed only inside the token source of truth, not in components.
const HEX = /#[0-9a-fA-F]{3,8}\b/;
const WHITE60_AS_TEXT = /color\s*:\s*[^;]*--veridact-white-60/i;
const AMBER_AS_TEXT = /(?<!background[^;:]{0,40})\bcolor\s*:\s*[^;]*--veridact-proof-amber/i;

function walk(dir, out = []) {
    for (const name of readdirSync(dir)) {
        if (IGNORE.includes(name)) continue;
        const p = join(dir, name);
        const s = statSync(p);
        if (s.isDirectory()) walk(p, out);
        else if (extname(p) === '.css') out.push(p);
    }
    return out;
}

const violations = [];
let files = [];
try {
    files = walk(LWC_ROOT);
} catch {
    console.error(`check-brand-tokens: ${LWC_ROOT} not found — run from repo root.`);
    process.exit(2);
}

for (const file of files) {
    const lines = readFileSync(file, 'utf8').split('\n');
    lines.forEach((line, i) => {
        const n = i + 1;
        const code = line.replace(/\/\*.*?\*\//g, '').trim();
        if (!code) return;
        if (HEX.test(code))
            violations.push(`${file}:${n}  hardcoded hex — use a --veridact-* token  » ${code}`);
        if (WHITE60_AS_TEXT.test(code))
            violations.push(`${file}:${n}  --veridact-white-60 as text (3.15:1 FAIL) — use --veridact-ink-muted  » ${code}`);
        if (AMBER_AS_TEXT.test(code))
            violations.push(`${file}:${n}  --veridact-proof-amber as text (3.18:1 FAIL) — use --veridact-accent-strong  » ${code}`);
    });
}

if (violations.length) {
    console.error(`\n✗ Veridact token guard: ${violations.length} violation(s)\n`);
    for (const v of violations) console.error('  ' + v);
    console.error('\nSee my-project/_bmad-output/test/UX-WCAG-QA-REPORT.md (ADR-UX-01).\n');
    process.exit(1);
}
console.log(`✓ Veridact token guard: ${files.length} LWC stylesheet(s) clean (ADR-UX-01).`);
