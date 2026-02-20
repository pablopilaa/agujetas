const fs = require('fs');
const path = require('path');

const sourcePath = path.join(__dirname, '..', 'assets', 'exercises-images', 'catalog.es.json');
const outputPath = path.join(__dirname, '..', 'assets', 'exercises-images', 'catalog.preindexed.json');

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

const normalizeExerciseKey = (name) => normalizeExerciseName(name).replace(/\s+/g, '');

const mapLyftaBodyPartToMuscle = (bodyPart) => {
  const value = normalizeExerciseName(bodyPart);
  if (!value || value === 'n u l l') return 'General';
  if (value.includes('chest')) return 'Pectoral';
  if (value.includes('back')) return 'Espalda';
  if (value.includes('shoulders')) return 'Hombros';
  if (value.includes('biceps')) return 'Bíceps';
  if (value.includes('triceps')) return 'Tríceps';
  if (value.includes('quadriceps')) return 'Cuádriceps';
  if (value.includes('hamstrings')) return 'Femoral';
  if (value.includes('thighs')) return 'Piernas';
  if (value.includes('hips')) return 'Glúteos';
  if (value.includes('calves')) return 'Gemelos';
  if (value.includes('waist') || value.includes('abs')) return 'Abdomen';
  if (value.includes('forearms')) return 'Antebrazos';
  if (value.includes('neck')) return 'Cuello';
  if (value.includes('cardio')) return 'Aeróbico';
  if (value.includes('full body')) return 'General';
  return 'General';
};

const isExcludedExerciseName = (name) => {
  const normalized = normalizeExerciseName(name);
  return (
    normalized.startsWith('musculos del cuerpo') ||
    normalized.startsWith('musculo corporal') ||
    normalized.startsWith('medicion de')
  );
};

const toImageId = (raw) => String(raw ?? '').replace(/\D/g, '').padStart(8, '0').slice(-8);

const rawSource = fs.readFileSync(sourcePath, 'utf8').replace(/^\uFEFF/, '');
const rows = JSON.parse(rawSource);
const seen = new Set();
const out = [];
const exactImageIdByNormalized = {};
const imageNamesById = {};

for (const row of rows) {
  const ejercicio = String(row?.name || '').trim();
  if (!ejercicio || isExcludedExerciseName(ejercicio)) continue;
  const key = normalizeExerciseKey(ejercicio);
  if (!key || seen.has(key)) continue;
  seen.add(key);

  const imageId = toImageId(row?.id);
  const thumbnailUrl = String(row?.image_url || '').trim();
  const normalizedName = normalizeExerciseName(ejercicio);

  out.push({
    key,
    ejercicio,
    musculo: mapLyftaBodyPartToMuscle(row?.body_part),
    ...(imageId ? { imageId } : {}),
    ...(thumbnailUrl ? { thumbnailUrl } : {}),
    normalizedName,
  });

  if (imageId) {
    if (!exactImageIdByNormalized[normalizedName]) {
      exactImageIdByNormalized[normalizedName] = imageId;
    }
    if (!imageNamesById[imageId]) imageNamesById[imageId] = [];
    imageNamesById[imageId].push(ejercicio);
  }
}

out.sort((a, b) => {
  const byMuscle = a.musculo.localeCompare(b.musculo, 'es', { sensitivity: 'base' });
  if (byMuscle !== 0) return byMuscle;
  return a.ejercicio.localeCompare(b.ejercicio, 'es', { sensitivity: 'base' });
});

fs.writeFileSync(
  outputPath,
  JSON.stringify({
    version: 1,
    generatedAtISO: new Date().toISOString(),
    exercises: out,
    exactImageIdByNormalized,
    imageNamesById,
  })
);
console.log(`Wrote ${out.length} rows to ${outputPath}`);
