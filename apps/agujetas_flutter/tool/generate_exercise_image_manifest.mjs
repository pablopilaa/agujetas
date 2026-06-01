import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const catalogPath = path.join(
  root,
  'assets',
  'user_data',
  'catalogo_ejercicios_2026-05-13.json',
);
const outDir = path.join(root, 'assets', 'exercise_images');
const thumbsDir = path.join(outDir, 'thumbs');
const placeholdersDir = path.join(outDir, 'placeholders');
const manifestPath = path.join(outDir, 'agujetas-image-manifest.json');
const generatedAt = new Date().toISOString();

fs.mkdirSync(thumbsDir, { recursive: true });
fs.mkdirSync(placeholdersDir, { recursive: true });

const catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
const rows = Array.isArray(catalog.rows) ? catalog.rows : [];

const muscleStyles = new Map([
  ['abdomen', { token: 'core', color: '#357C6D', label: 'Abdomen' }],
  ['abductores', { token: 'legs', color: '#6D7F3F', label: 'Abductores' }],
  ['aductores', { token: 'legs', color: '#6D7F3F', label: 'Aductores' }],
  ['antebrazos', { token: 'arms', color: '#5F6F68', label: 'Antebrazos' }],
  ['biceps', { token: 'arms', color: '#2A6357', label: 'Biceps' }],
  ['espalda', { token: 'back', color: '#156355', label: 'Espalda' }],
  ['gluteos', { token: 'glutes', color: '#8B5007', label: 'Gluteos' }],
  ['hombros', { token: 'shoulders', color: '#B8752E', label: 'Hombros' }],
  ['pectoral', { token: 'chest', color: '#2A6357', label: 'Pectoral' }],
  ['pecho', { token: 'chest', color: '#2A6357', label: 'Pecho' }],
  ['piernas', { token: 'legs', color: '#357C6D', label: 'Piernas' }],
  ['triceps', { token: 'arms', color: '#844739', label: 'Triceps' }],
  ['general', { token: 'body', color: '#5F6F68', label: 'General' }],
]);

function normalize(value) {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 80);
}

function stableHash(value) {
  return crypto.createHash('sha1').update(String(value)).digest('hex').slice(0, 8);
}

function escapeXml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function shorten(value, maxLength) {
  const text = String(value || '').trim();
  if (text.length <= maxLength) return text;
  return `${text.slice(0, Math.max(0, maxLength - 1)).trim()}…`;
}

function styleFor(muscle) {
  const key = normalize(muscle) || 'general';
  return muscleStyles.get(key) || muscleStyles.get('general');
}

function equipmentToken(name) {
  const key = normalize(name);
  if (/mancuerna|dumbbell/.test(key)) return 'dumbbell';
  if (/barra|barbell|press|sentadilla|peso_muerto/.test(key)) return 'barbell';
  if (/polea|cable|maquina|palanca/.test(key)) return 'machine';
  if (/banda|elastic/.test(key)) return 'band';
  if (/cinta|bicicleta|eliptica|cardio|correr/.test(key)) return 'cardio';
  return 'bodyweight';
}

function baseFigure(color) {
  return `
  <circle cx="128" cy="74" r="17" fill="none" stroke="${color}" stroke-width="8"/>
  <path d="M128 94v54M93 118c21-16 49-16 70 0M103 198l25-50 25 50" fill="none" stroke="${color}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M76 147c20-12 35-22 52-22s32 10 52 22" fill="none" stroke="${color}" stroke-width="8" stroke-linecap="round"/>`;
}

function targetMarkup(token, color) {
  if (token === 'arms') {
    return `<path d="M70 143c24-24 44-29 60-16M186 143c-24-24-44-29-60-16" fill="none" stroke="${color}" stroke-width="9" stroke-linecap="round"/><circle cx="91" cy="130" r="10" fill="#FFFFFF" stroke="${color}" stroke-width="6"/><circle cx="165" cy="130" r="10" fill="#FFFFFF" stroke="${color}" stroke-width="6"/>`;
  }
  if (token === 'legs' || token === 'glutes') {
    return `<path d="M103 144c-3 22-8 42-18 60M153 144c3 22 8 42 18 60" fill="none" stroke="${color}" stroke-width="10" stroke-linecap="round"/><path d="M96 139c18 10 46 10 64 0" fill="none" stroke="${color}" stroke-width="8" stroke-linecap="round"/>`;
  }
  if (token === 'back') {
    return `<path d="M86 120c19-32 37-48 42-48s23 16 42 48c-28-7-56-7-84 0Z" fill="#FFFFFF" stroke="${color}" stroke-width="7" stroke-linejoin="round"/><path d="M92 151c24 15 48 15 72 0" fill="none" stroke="${color}" stroke-width="7" stroke-linecap="round"/>`;
  }
  if (token === 'chest') {
    return `<path d="M78 126c24-35 76-35 100 0-25 3-42 12-50 26-8-14-25-23-50-26Z" fill="#FFFFFF" stroke="${color}" stroke-width="7" stroke-linejoin="round"/><path d="M128 104v48" fill="none" stroke="${color}" stroke-width="7" stroke-linecap="round"/>`;
  }
  if (token === 'shoulders') {
    return `<path d="M69 139c17-34 35-51 59-51s42 17 59 51" fill="none" stroke="${color}" stroke-width="9" stroke-linecap="round"/><circle cx="73" cy="139" r="12" fill="#FFFFFF" stroke="${color}" stroke-width="6"/><circle cx="183" cy="139" r="12" fill="#FFFFFF" stroke="${color}" stroke-width="6"/>`;
  }
  if (token === 'core') {
    return `<path d="M128 97c-18 17-27 36-27 58s9 39 27 55c18-16 27-33 27-55s-9-41-27-58Z" fill="#FFFFFF" stroke="${color}" stroke-width="7"/><path d="M113 133h30M109 158h38M115 183h26" fill="none" stroke="${color}" stroke-width="6" stroke-linecap="round"/>`;
  }
  return `<path d="M81 136h94M99 196l29-48 29 48" fill="none" stroke="${color}" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>`;
}

function equipmentMarkup(token, color) {
  if (token === 'dumbbell') {
    return `<path d="M64 57h40M152 57h40M85 47v20M171 47v20" fill="none" stroke="${color}" stroke-width="7" stroke-linecap="round"/>`;
  }
  if (token === 'barbell') {
    return `<path d="M48 55h160M64 39v32M79 43v24M177 43v24M192 39v32" fill="none" stroke="${color}" stroke-width="7" stroke-linecap="round"/>`;
  }
  if (token === 'machine') {
    return `<path d="M51 54h154M60 54v38M196 54v38M79 75h98" fill="none" stroke="${color}" stroke-width="7" stroke-linecap="round"/><circle cx="128" cy="75" r="8" fill="#FFFFFF" stroke="${color}" stroke-width="5"/>`;
  }
  if (token === 'band') {
    return `<path d="M58 62c36-23 104-23 140 0" fill="none" stroke="${color}" stroke-width="7" stroke-linecap="round"/><path d="M74 79c30-15 78-15 108 0" fill="none" stroke="${color}" stroke-width="6" stroke-linecap="round"/>`;
  }
  if (token === 'cardio') {
    return `<path d="M75 63c18-22 44-23 62-2l17 20c8 9 19 12 31 7" fill="none" stroke="${color}" stroke-width="7" stroke-linecap="round"/><circle cx="82" cy="84" r="7" fill="${color}"/>`;
  }
  return `<path d="M58 58h140" fill="none" stroke="${color}" stroke-width="7" stroke-linecap="round"/><path d="M76 44v28M180 44v28" fill="none" stroke="${color}" stroke-width="6" stroke-linecap="round"/>`;
}

function svgFor({ title, muscle, imageId, placeholder = false }) {
  const style = styleFor(muscle);
  const label = escapeXml(shorten(title, 32));
  const subtitle = escapeXml(shorten(muscle || 'General', 22));
  const equipment = equipmentToken(title);
  const baseColor = style.color;
  const muted = placeholder ? '#DCE5DF' : '#E8EFEA';
  const bg = placeholder ? '#F3F6F2' : '#F7F8F5';

  return `<svg xmlns="http://www.w3.org/2000/svg" width="384" height="384" viewBox="0 0 256 256" role="img" aria-label="${label}">
  <rect width="256" height="256" rx="28" fill="${bg}"/>
  <rect x="14" y="14" width="228" height="228" rx="24" fill="#FFFFFF" stroke="#DCE5DF" stroke-width="2"/>
  <circle cx="128" cy="132" r="84" fill="${muted}"/>
  ${equipmentMarkup(equipment, baseColor)}
  ${baseFigure(baseColor)}
  ${targetMarkup(style.token, baseColor)}
  <text x="128" y="223" text-anchor="middle" font-family="Inter, Arial, sans-serif" font-size="12" font-weight="800" fill="#17211D">${label}</text>
  <text x="128" y="239" text-anchor="middle" font-family="Inter, Arial, sans-serif" font-size="9" font-weight="700" fill="#5F6F68">${subtitle}</text>
</svg>
`;
}

const placeholderByMuscle = new Map();
for (const [key, style] of muscleStyles.entries()) {
  const id = `placeholder_${key}`;
  const assetPath = `assets/exercise_images/placeholders/${id}.svg`;
  fs.writeFileSync(
    path.join(root, assetPath),
    svgFor({
      title: `${style.label} - placeholder`,
      muscle: style.label,
      imageId: id,
      placeholder: true,
    }),
    'utf8',
  );
  placeholderByMuscle.set(key, assetPath);
}

const entries = [];
const seenIds = new Set();

for (const row of rows) {
  const name = String(row.ejercicio || row.name || '').trim();
  if (!name) continue;

  const muscle = String(row.musculo || row.muscleGroup || 'General').trim() || 'General';
  const exerciseKey = normalize(row.key || row.id || name) || `exercise_${entries.length}`;
  const hash = stableHash(`${exerciseKey}|${name}|${muscle}`);
  let imageId = `ag_${exerciseKey}_${hash}`;
  while (seenIds.has(imageId)) {
    imageId = `ag_${exerciseKey}_${stableHash(`${imageId}|${seenIds.size}`)}`;
  }
  seenIds.add(imageId);

  const assetPath = `assets/exercise_images/thumbs/${imageId}.svg`;
  fs.writeFileSync(
    path.join(root, assetPath),
    svgFor({ title: name, muscle, imageId }),
    'utf8',
  );

  const muscleKey = normalize(muscle) || 'general';
  const placeholderAssetPath =
    placeholderByMuscle.get(muscleKey) || placeholderByMuscle.get('general');
  const usageCount = Number(row.usageCount || 0);
  const reviewStatus =
    usageCount > 0 || row.inCustomSession === true ? 'priority' : 'pending';

  entries.push({
    imageId,
    uri: `agujetas-image://${imageId}`,
    exerciseKey,
    exerciseName: name,
    normalizedName: normalize(name),
    muscleGroup: muscle,
    assetPath,
    placeholderAssetPath,
    status: 'generated',
    reviewStatus,
    source: 'agujetas-generated',
    version: 1,
    prompt:
      `Original technical line-art fitness illustration for "${name}", muscle group "${muscle}", Agujetas brand style. Text metadata only. Do not use third-party images, screenshots, URLs, or proprietary visual references.`,
    generatedAt,
  });
}

const manifest = {
  schema: 'agujetas-image-manifest-v1',
  generatedAt,
  legal: {
    sourcePolicy:
      'Agujetas-generated assets only. Lyfta images, screenshots, URLs, and proprietary visual references are prohibited for commercial builds.',
    allowedSource: 'Textual exercise metadata and Agujetas-owned generated artwork.',
    legacyAppImagePolicy:
      'app-image:// URIs are accepted only as migration hints and must never resolve to bundled Lyfta assets.',
  },
  counts: {
    entries: entries.length,
    generated: entries.length,
    priorityReview: entries.filter((entry) => entry.reviewStatus === 'priority').length,
    pendingReview: entries.filter((entry) => entry.reviewStatus === 'pending').length,
    placeholders: placeholderByMuscle.size,
  },
  entries,
};

fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
console.log(
  `Generated ${manifest.counts.entries} Agujetas image entries, ${manifest.counts.placeholders} placeholders.`,
);
