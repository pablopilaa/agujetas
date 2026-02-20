const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const TARGETS = ['App.tsx', 'components', 'utils'];
const EXTENSIONS = new Set(['.ts', '.tsx']);

const MOJIBAKE_PATTERN = /[\u00C2\u00C3\u00E2\u00F0][\u0080-\u00BF]/g;

const files = [];

const walk = (relativePath) => {
  const fullPath = path.join(ROOT, relativePath);
  if (!fs.existsSync(fullPath)) return;

  const stat = fs.statSync(fullPath);
  if (stat.isFile()) {
    const ext = path.extname(fullPath).toLowerCase();
    if (EXTENSIONS.has(ext)) files.push(fullPath);
    return;
  }

  for (const entry of fs.readdirSync(fullPath)) {
    walk(path.join(relativePath, entry));
  }
};

TARGETS.forEach(walk);

const issues = [];

for (const file of files) {
  const content = fs.readFileSync(file, 'utf8');

  const mojibakeMatches = content.match(MOJIBAKE_PATTERN);
  if (mojibakeMatches?.length) {
    issues.push({
      file: path.relative(ROOT, file),
      type: 'mojibake',
      count: mojibakeMatches.length,
    });
  }

  const lines = content.split(/\r?\n/);
  let jsxEscapeCount = 0;
  for (const line of lines) {
    const match = line.match(/<[^>]*>\s*(?!\{)[^<{]*\\u[0-9a-fA-F]{4}[^<{]*/);
    if (match) jsxEscapeCount += 1;
  }
  if (jsxEscapeCount > 0) {
    issues.push({
      file: path.relative(ROOT, file),
      type: 'jsx_literal_unicode_escape',
      count: jsxEscapeCount,
    });
  }
}

if (!issues.length) {
  console.log('text-integrity: OK (sin mojibake ni escapes literales en JSX).');
  process.exit(0);
}

console.warn('text-integrity: se detectaron problemas de texto:');
for (const issue of issues) {
  console.warn(`- ${issue.file} [${issue.type}] x${issue.count}`);
}
process.exit(1);
