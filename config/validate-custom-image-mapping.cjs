const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const csvPath = path.join(root, 'assets', 'exercises-images', 'custom_exercises_manual_mapping.csv');
const imagesDir = path.join(root, 'assets', 'exercises-images', 'images-webp');
const reportPath = path.join(root, 'assets', 'exercises-images', 'custom_exercises_manual_mapping_validation.json');

const PLACEHOLDER_VALUES = new Set([
  'lyfta_entry_without_local_image',
  'not_in_lyfta_catalog',
]);

function parseCsvLine(line) {
  const out = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (ch === '"') {
      const next = line[i + 1];
      if (inQuotes && next === '"') {
        current += '"';
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (ch === ';' && !inQuotes) {
      out.push(current);
      current = '';
      continue;
    }
    current += ch;
  }

  out.push(current);
  return out;
}

function normalizeKey(value) {
  return String(value || '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, '_');
}

function readCsvRows() {
  const raw = fs.readFileSync(csvPath, 'utf8').replace(/^\uFEFF/, '');
  const lines = raw.split(/\r?\n/).filter((line, idx) => idx === 0 || line.trim() !== '');
  if (lines.length === 0) return [];

  const headers = parseCsvLine(lines[0]).map((h) => h.trim());
  const rows = [];

  for (let i = 1; i < lines.length; i += 1) {
    const values = parseCsvLine(lines[i]);
    const row = { _row: i + 1 };
    headers.forEach((header, idx) => {
      row[header] = (values[idx] || '').trim();
    });
    rows.push(row);
  }

  return rows;
}

function buildImageIndexes() {
  const fileNames = fs
    .readdirSync(imagesDir)
    .filter((name) => name.toLowerCase().endsWith('.webp'));

  const byFileLower = new Map();
  const byBaseLower = new Map();
  const byNormalizedBase = new Map();
  const byId = new Map();

  for (const fileName of fileNames) {
    const lower = fileName.toLowerCase();
    const base = fileName.slice(0, -5);
    const baseLower = base.toLowerCase();
    const normalizedBase = normalizeKey(base);
    const idMatch = fileName.match(/(\d{8})(?=\.webp$)/i);

    byFileLower.set(lower, fileName);
    if (!byBaseLower.has(baseLower)) byBaseLower.set(baseLower, fileName);
    if (!byNormalizedBase.has(normalizedBase)) byNormalizedBase.set(normalizedBase, fileName);

    if (idMatch && idMatch[1]) {
      const id = idMatch[1];
      const arr = byId.get(id) || [];
      arr.push(fileName);
      byId.set(id, arr);
    }
  }

  return { fileNames, byFileLower, byBaseLower, byNormalizedBase, byId };
}

function extractId(ref) {
  const match = String(ref || '').match(/(\d{8})/);
  return match ? match[1] : null;
}

function resolveImageFile(imageRef, indexes) {
  const ref = String(imageRef || '').trim();
  if (!ref) return { ok: false, reason: 'image_id_selected vacío', suggestions: [] };

  const lowerRef = ref.toLowerCase();
  if (PLACEHOLDER_VALUES.has(lowerRef)) {
    return { ok: false, reason: 'image_id_selected es un placeholder', suggestions: [] };
  }

  if (lowerRef.endsWith('.webp')) {
    const file = indexes.byFileLower.get(lowerRef);
    if (file) return { ok: true, file };
  } else {
    const exactBase = indexes.byBaseLower.get(lowerRef);
    if (exactBase) return { ok: true, file: exactBase };

    const normalizedBase = indexes.byNormalizedBase.get(normalizeKey(ref));
    if (normalizedBase) return { ok: true, file: normalizedBase };
  }

  const id = extractId(ref);
  if (id) {
    const candidates = indexes.byId.get(id) || [];
    if (candidates.length === 1) return { ok: true, file: candidates[0] };
    if (candidates.length > 1) {
      return {
        ok: false,
        reason: `ID ${id} es ambiguo (${candidates.length} archivos)`,
        suggestions: candidates.slice(0, 10),
      };
    }
  }

  const simplified = normalizeKey(ref).replace(/\.webp$/, '');
  const similar = indexes.fileNames
    .filter((file) => normalizeKey(file.slice(0, -5)).includes(simplified) || simplified.includes(normalizeKey(file.slice(0, -5))))
    .slice(0, 10);

  return {
    ok: false,
    reason: 'No se encontró un archivo .webp para image_id_selected',
    suggestions: similar,
  };
}

function main() {
  if (!fs.existsSync(csvPath)) {
    console.error(`No existe CSV: ${csvPath}`);
    process.exit(1);
  }
  if (!fs.existsSync(imagesDir)) {
    console.error(`No existe carpeta de imágenes: ${imagesDir}`);
    process.exit(1);
  }

  const rows = readCsvRows();
  const indexes = buildImageIndexes();

  const validMappings = [];
  const invalidMappings = [];
  let ignoredWithoutExercise = 0;

  for (const row of rows) {
    const exerciseName = String(row.exercise_name || '').trim();
    const imageRef = String(row.image_id_selected || '').trim();
    const muscle = String(row.musculo || '').trim();

    if (!exerciseName) {
      ignoredWithoutExercise += 1;
      continue;
    }

    const result = resolveImageFile(imageRef, indexes);
    if (result.ok) {
      validMappings.push({
        row: row._row,
        exercise_name: exerciseName,
        musculo: muscle,
        image_id_selected: imageRef,
        resolved_image_file: result.file,
      });
    } else {
      invalidMappings.push({
        row: row._row,
        exercise_name: exerciseName,
        musculo: muscle,
        image_id_selected: imageRef,
        reason: result.reason,
        suggestions: result.suggestions || [],
      });
    }
  }

  const report = {
    generatedAtISO: new Date().toISOString(),
    csvPath: path.relative(root, csvPath).replace(/\\/g, '/'),
    imagesDir: path.relative(root, imagesDir).replace(/\\/g, '/'),
    totals: {
      rows: rows.length,
      checked: rows.length - ignoredWithoutExercise,
      valid: validMappings.length,
      invalid: invalidMappings.length,
      ignoredWithoutExercise,
      availableImages: indexes.fileNames.length,
    },
    validMappings,
    invalidMappings,
  };

  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n', 'utf8');

  console.log(`Validación finalizada. Válidos: ${validMappings.length}, inválidos: ${invalidMappings.length}`);
  console.log(`Reporte: ${path.relative(root, reportPath)}`);

  if (invalidMappings.length > 0) {
    process.exitCode = 1;
  }
}

main();
