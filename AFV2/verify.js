// Local verification for the AFV2 sources. Nothing is published from here —
// the game loads AFV2/init.lua, which assembles the same chunk at runtime.
//
// Three jobs:
//   1. assemble the chunk exactly as init.lua would, so it can be parsed or
//      diffed offline
//   2. enforce the dependency direction between modules, so the architecture
//      is a rule that runs rather than a comment that decays
//   3. catch a qualified name used where only a bare table key is valid
//
// Git may check the sources out with CRLF, but GitHub serves the stored blob,
// which is LF. Line endings are normalised here so the result models what the
// loader actually receives rather than what is on this disk.
//
//   node AFV2/verify.js                 write dist/AutoFarmingV2.lua, run checks
//   node AFV2/verify.js --compare FILE  also diff the result against FILE
//   node AFV2/verify.js --graph         print the dependency graph and stop

const fs = require("fs");
const path = require("path");

const DIR = __dirname;
const INIT = path.join(DIR, "init.lua");

const NEWLINE = String.fromCharCode(10);

const lf = (text) => text.replace(/\r\n/g, NEWLINE);
const read = (p) => lf(fs.readFileSync(p, "utf8"));

//==============================================================
// Architecture
//
// A module may call anything above it in this list and nothing below it.
// header, state, build, wire and main are the composition root: they wire the
// modules together, so they are allowed to reach anywhere.
//==============================================================
const LAYERS = [
  { module: "AFConfig", file: "config.lua" },
  { module: "AFCombatUtils", file: "combatutils.lua" },
  { module: "AFCombat", file: "combat.lua" },
  { module: "AFFeature", file: "feature.lua" },
  { module: "AFProfile", file: "profile.lua" },
  { module: "AFDebug", file: "debug.lua" },
  { module: "AFUI", file: "ui.lua" },
];

const COMPOSITION_ROOT = ["header.lua", "state.lua", "build.lua", "wire.lua", "main.lua"];

//==============================================================
// Blank out comments and strings so references are only counted in code.
//==============================================================
function stripNoise(src) {
  const out = src.split("");
  const n = src.length;
  let i = 0;
  const blank = (a, b) => {
    for (let k = a; k < Math.min(b, n); k++) if (out[k] !== NEWLINE) out[k] = " ";
  };
  while (i < n) {
    const c = src[i];
    if (c === "-" && src.startsWith("--", i)) {
      const m = /^--\[(=*)\[/.exec(src.slice(i, i + 40));
      if (m) {
        const close = "]" + m[1] + "]";
        let j = src.indexOf(close, i);
        j = j === -1 ? n : j + close.length;
        blank(i, j); i = j; continue;
      }
      let j = src.indexOf(NEWLINE, i);
      j = j === -1 ? n : j;
      blank(i, j); i = j; continue;
    }
    const lm = /^\[(=*)\[/.exec(src.slice(i, i + 40));
    if (lm) {
      const close = "]" + lm[1] + "]";
      let j = src.indexOf(close, i);
      j = j === -1 ? n : j + close.length;
      blank(i, j); i = j; continue;
    }
    if (c === '"' || c === "'" || c === "`") {
      let j = i + 1;
      while (j < n) {
        if (src[j] === "\\") { j += 2; continue; }
        if (src[j] === c) { j++; break; }
        if (src[j] === NEWLINE) break;
        j++;
      }
      blank(i, j); i = j; continue;
    }
    i++;
  }
  return out.join("");
}

const isWord = (c) => c !== undefined && /[A-Za-z0-9_]/.test(c);

// Every standalone reference to `Module.` in a file, with its line number.
function referencesIn(clean, moduleName) {
  const needle = moduleName + ".";
  const hits = [];
  let i = 0;
  while ((i = clean.indexOf(needle, i)) !== -1) {
    const before = clean[i - 1];
    if (!isWord(before) && before !== "." && before !== ":") {
      hits.push(clean.slice(0, i).split(NEWLINE).length);
    }
    i += needle.length;
  }
  return hits;
}

function checkDependencies() {
  const rank = new Map(LAYERS.map((l, i) => [l.module, i]));
  const violations = [];
  const graph = [];

  for (const layer of LAYERS) {
    const p = path.join(DIR, layer.file);
    if (!fs.existsSync(p)) throw new Error("missing module file: " + layer.file);
    const clean = stripNoise(read(p));
    const calls = [];

    for (const other of LAYERS) {
      if (other.module === layer.module) continue;
      const hits = referencesIn(clean, other.module);
      if (hits.length === 0) continue;
      calls.push(other.module);
      if (rank.get(other.module) > rank.get(layer.module)) {
        violations.push({
          from: layer.module,
          file: layer.file,
          to: other.module,
          lines: hits.slice(0, 5),
          count: hits.length,
        });
      }
    }

    graph.push({ module: layer.module, calls });
  }

  return { graph, violations };
}

// A table key is a bare name, so renaming identifiers in bulk can turn
//   { Enabled = true }
// into
//   { AFFeature.S.Enabled = true }
// which is not valid Lua, and which a brace-balance check will not notice.
// This has broken the build once already; it is cheap to keep looking for.
const QUALIFIED_ASSIGN = /^\s*((?:AF[A-Za-z]+\.(?:S\.)?|UIRef\.|PatrolState\.)[A-Za-z_]\w*)\s*=[^=]/;

function checkTableKeys() {
  const bad = [];
  const sources = fs.readdirSync(DIR).filter((f) => f.endsWith(".lua") && f !== "init.lua");

  for (const f of sources) {
    const src = read(path.join(DIR, f));
    const clean = stripNoise(src);
    const lines = src.split(NEWLINE);
    const cleanLines = clean.split(NEWLINE);
    let depth = 0;

    for (let i = 0; i < cleanLines.length; i++) {
      const outer = depth;
      for (const ch of cleanLines[i]) {
        if (ch === "{") depth++;
        else if (ch === "}") depth--;
      }
      if (outer <= 0) continue;
      if (QUALIFIED_ASSIGN.test(lines[i])) {
        bad.push({ file: f, line: i + 1, text: lines[i].trim() });
      }
    }
  }

  return bad;
}

function printGraph(graph) {
  console.log("dependency graph (each may call only what is above it):");
  for (const row of graph) {
    console.log("  " + row.module.padEnd(15) + "-> " + (row.calls.join(", ") || "(nothing)"));
  }
}

//==============================================================
// Assemble
//==============================================================
const initSource = read(INIT);
const block = /local ORDER = \{([\s\S]*?)\n\}/.exec(initSource);
if (!block) throw new Error("could not read ORDER from init.lua");

const ORDER = [...block[1].matchAll(/"([^"]+\.lua)"/g)].map((m) => m[1]);
if (ORDER.length === 0) throw new Error("ORDER in init.lua is empty");

const known = new Set(LAYERS.map((l) => l.file).concat(COMPOSITION_ROOT));
for (const f of ORDER) {
  if (!known.has(f)) {
    console.log("note: " + f + " is in ORDER but not described in verify.js");
  }
}

const { graph, violations } = checkDependencies();

if (process.argv.includes("--graph")) {
  printGraph(graph);
  process.exit(violations.length ? 1 : 0);
}

const parts = ORDER.map((name) => {
  const p = path.join(DIR, name);
  if (!fs.existsSync(p)) throw new Error("missing source file: " + name);
  return read(p).replace(/\n$/, "");
});

const assembled = parts.join(NEWLINE);

const outDir = path.join(DIR, "dist");
fs.mkdirSync(outDir, { recursive: true });
const outFile = path.join(outDir, "AutoFarmingV2.lua");
fs.writeFileSync(outFile, assembled);

console.log(`assembled ${ORDER.length} sources`);
console.log(`  ${assembled.split(NEWLINE).length} lines, ${Buffer.byteLength(assembled, "utf8")} bytes`);
console.log(`  wrote ${path.relative(process.cwd(), outFile)}`);

const badKeys = checkTableKeys();

if (badKeys.length === 0) {
  console.log("  table keys: OK");
} else {
  console.log(`  table keys: ${badKeys.length} qualified name(s) used as a table key`);
  for (const b of badKeys.slice(0, 8)) {
    console.log(`   - ${b.file}:${b.line}  ${b.text.slice(0, 80)}`);
  }
  process.exitCode = 1;
}

if (violations.length === 0) {
  console.log("  dependency direction: OK");
} else {
  console.log(`  dependency direction: ${violations.length} violation(s)`);
  for (const v of violations) {
    console.log(`   - ${v.file} (${v.from}) calls ${v.to} x${v.count}, lines ${v.lines.join(", ")}`);
  }
  process.exitCode = 1;
}

const flag = process.argv.indexOf("--compare");
if (flag !== -1) {
  const ref = process.argv[flag + 1];
  if (!ref) throw new Error("--compare needs a file path");
  const expected = read(ref);
  if (expected === assembled) {
    console.log(`  identical to ${ref}`);
  } else {
    console.log(`  DIFFERS from ${ref}`);
    console.log(`    reference ${Buffer.byteLength(expected, "utf8")} bytes, assembled ${Buffer.byteLength(assembled, "utf8")} bytes`);
    process.exitCode = 1;
  }
}
