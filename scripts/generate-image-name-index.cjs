const fs = require('fs');
const path = require('path');

const thumbsDir = path.join(__dirname, '..', 'assets', 'exercises-images', 'images-webp-thumbs');
const outputPath = path.join(__dirname, '..', 'assets', 'exercises-images', 'localImageNameIndex.json');

const normalizeExerciseName = (text) =>
  String(text || '')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[-_/]+/g, ' ')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\bextensiones?\s+de\s+/g, 'extension ')
    .replace(/\bextensiones?\s+/g, 'extension ')
    .replace(/^empuje de cadera\b/g, 'hip thrust')
    .replace(/^empuje_de_cadera\b/g, 'hip_thrust')
    .replace(/\s+/g, ' ')
    .trim();

const files = fs.readdirSync(thumbsDir).filter((name) => name.toLowerCase().endsWith('.webp'));
const nameToId = {};

for (const filename of files) {
  const base = filename.slice(0, -5);
  const idMatch = base.match(/_(\d{8})$/);
  if (!idMatch) continue;
  const imageId = idMatch[1];
  const namePart = base.slice(0, -9);
  const normalizedName = normalizeExerciseName(namePart);
  if (!normalizedName) continue;
  if (!nameToId[normalizedName]) {
    nameToId[normalizedName] = imageId;
  }
}

fs.writeFileSync(
  outputPath,
  JSON.stringify(
    {
      version: 1,
      generatedAtISO: new Date().toISOString(),
      nameToId,
    },
    null,
    2
  )
);

console.log(`Wrote ${Object.keys(nameToId).length} name mappings to ${outputPath}`);
