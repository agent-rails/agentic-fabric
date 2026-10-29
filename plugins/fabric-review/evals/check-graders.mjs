import { readdirSync, readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
let passed = 0;
const failures = [];

function frontmatter(text, name) {
  const m = text.match(/^---\n([\s\S]*?)\n---/);
  if (!m) throw new Error("no frontmatter");
  const out = { name };
  for (const line of m[1].split("\n")) {
    const kv = line.match(/^([A-Za-z_]+):\s*(.*)$/);
    if (!kv) continue;
    let v = kv[2].trim();
    if ((v.startsWith("'") && v.endsWith("'")) || (v.startsWith('"') && v.endsWith('"'))) v = v.slice(1, -1);
    out[kv[1]] = v;
  }
  return out;
}

function grade(g, output) {
  const flags = g.flags || "";
  const re = new RegExp(g.pattern, flags);
  const matches = [...output.matchAll(new RegExp(g.pattern, flags.includes("g") ? flags : flags + "g"))].length;
  const match = g.match || "contains";
  if (match === "contains") return re.test(output);
  if (match === "not_contains") return !re.test(output);
  const count = match.match(/^count:(\d+)$/);
  if (count) return matches === Number(count[1]);
  throw new Error(`unsupported match ${match}`);
}

function score(graders, output) {
  const results = graders.map((g) => grade(g, output));
  return results.filter(Boolean).length / results.length;
}

function check(name, got, want) {
  if (got === want) passed += 1;
  else failures.push(`${name}: expected ${want}, got ${got}`);
}

function newFileLines(diff) {
  const header = diff.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/m);
  let n = Number(header[1]);
  const added = new Set();
  for (const line of diff.split("\n").slice(diff.split("\n").findIndex((l) => l.startsWith("@@")) + 1)) {
    if (line.startsWith("+")) { added.add(n); n += 1; }
    else if (line.startsWith(" ")) n += 1;
  }
  return added;
}

const cases = readdirSync(root, { withFileTypes: true }).filter((d) => d.isDirectory() && existsSync(join(root, d.name, "prompt.md")));
check("corpus has seeded and clean cases", cases.length >= 4, true);

for (const c of cases) {
  const dir = join(root, c.name);
  const prompt = readFileSync(join(dir, "prompt.md"), "utf8");
  const tag = frontmatter(prompt).tags;
  const graders = readdirSync(join(dir, "graders")).sort().map((f) => frontmatter(readFileSync(join(dir, "graders", f), "utf8"), f.replace(/\.md$/, "")));
  check(`${c.name}: has a grader`, graders.length >= 1, true);
  const diff = prompt.match(/```diff\n([\s\S]*?)\n```/)[1];

  if (tag.includes("trap")) {
    const g = graders[0];
    const trapKlass = g.pattern.match(/\(\?:([^)]*)\)'?$/)[1].split("|")[0].replace(/\.\?/g, "-");
    check(`${c.name}: the trapped claim scores 0`, score(graders, `FINDING: x.py:1 ${trapKlass} high - invented`), 0);
    check(`${c.name}: another finding scores 1`, score(graders, "FINDING: x.py:1 error-handling low - unrelated"), 1);
    check(`${c.name}: NO DEFECTS scores 1`, score(graders, "NO DEFECTS"), 1);
    check(`${c.name}: the word traced is not the trapped class`, score(graders, "FINDING: x.py:1 logic low - traced the call"), 1);
    continue;
  }

  if (tag.includes("clean")) {
    check(`${c.name}: NO DEFECTS scores 1`, score(graders, "NO DEFECTS"), 1);
    check(`${c.name}: a finding scores 0`, score(graders, "FINDING: x.py:1 logic low - invented"), 0);
    check(`${c.name}: both scores 0.5`, score(graders, "NO DEFECTS\nFINDING: x.py:1 logic low - invented"), 0.5);
    continue;
  }

  const hit = graders.find((g) => g.name === "located");
  const m = hit.pattern.match(/\[\^\\n\]\*([^:]+):\(\?:([0-9|]+)\)\\b.*\(\?:([^)]*)\)'?$/);
  const base = m[1].replace(/\\\./g, ".");
  const lines = m[2].split("|").map(Number);
  const klass = m[3].split("|")[0].replace(/\\./g, "x").replace(/\.\?/g, "-");
  const added = newFileLines(diff);
  check(`${c.name}: an accepted line is an added line of the diff`, lines.some((l) => added.has(l)), true);

  const oracle = `FINDING: ${base}:${lines[0]} ${klass} high - traced`;
  check(`${c.name}: correct finding scores 1`, score(graders, oracle), 1);
  check(`${c.name}: finding after prose still scores 1`, score(graders, `Reviewed the diff.\n${oracle}`), 1);
  check(`${c.name}: wrong line is detected but not located`, score(graders, `FINDING: ${base}:${Math.max(...lines) + 9} ${klass} high - traced`), 0.5);
  check(`${c.name}: wrong class misses`, score(graders, `FINDING: ${base}:${lines[0]} zzz-unrelated high - traced`), 0);
  check(`${c.name}: wrong file misses`, score(graders, `FINDING: other.py:${lines[0]} ${klass} high - traced`), 0);
  check(`${c.name}: an extra finding on a seeded case is not scored`, score(graders, `${oracle}\nFINDING: x.py:1 logic low - other`), 1);
  check(`${c.name}: the earliest accepted line still hits`, score(graders, `FINDING: ${base}:${Math.min(...lines)} ${klass} high - traced`), 1);
  check(`${c.name}: two lines before the seed is detected but not located`, score(graders, `FINDING: ${base}:${Math.min(...lines) - 1} ${klass} high - traced`), 0.5);
  check(`${c.name}: NO DEFECTS scores 0`, score(graders, "NO DEFECTS"), 0);
}

if (failures.length) {
  console.error(failures.map((f) => `FAIL: ${f}`).join("\n"));
  process.exit(1);
}
console.log(`all ${passed} tests passed`);
