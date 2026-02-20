const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const SOURCE_DIR = path.join(__dirname, '..', 'assets', 'exercises-images', 'images-webp');
const OUTPUT_DIR = path.join(__dirname, '..', 'assets', 'exercises-images', 'images-webp-thumbs');
const OUTPUT_MAP = path.join(__dirname, '..', 'assets', 'exercises-images', 'localImageMapThumbs.ts');

const THUMB_SIZE = 96;
const THUMB_QUALITY = 80;
const CONCURRENCY = 8;

const ensureDir = (dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
};

const extractImageId = (filename) => {
  const match = filename.match(/(\d{8})(?=\.webp$)/i);
  return match ? match[1] : null;
};

const createThumb = async (sourcePath, outputPath) => {
  await sharp(sourcePath)
    .resize(THUMB_SIZE, THUMB_SIZE, {
      fit: 'contain',
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    })
    .webp({ quality: THUMB_QUALITY })
    .toFile(outputPath);
};

const main = async () => {
  if (!fs.existsSync(SOURCE_DIR)) {
    console.error(`Source dir not found: ${SOURCE_DIR}`);
    process.exit(1);
  }

  ensureDir(OUTPUT_DIR);

  const files = fs
    .readdirSync(SOURCE_DIR)
    .filter((file) => file.toLowerCase().endsWith('.webp'))
    .sort((a, b) => a.localeCompare(b, 'en'));

  let index = 0;
  const workers = Array.from({ length: CONCURRENCY }, async () => {
    while (index < files.length) {
      const file = files[index++];
      const sourcePath = path.join(SOURCE_DIR, file);
      const outputPath = path.join(OUTPUT_DIR, file);
      await createThumb(sourcePath, outputPath);
    }
  });

  await Promise.all(workers);

  const lines = files
    .map((file) => {
      const imageId = extractImageId(file);
      if (!imageId) return null;
      return `  '${imageId}': require('./images-webp-thumbs/${file}'),`;
    })
    .filter(Boolean);

  const output = `// Auto-generated from assets/exercises-images/images-webp\n` +
    `export const exerciseLocalImageMapThumbs: Record<string, any> = {\n` +
    `${lines.join('\n')}\n` +
    `};\n`;

  fs.writeFileSync(OUTPUT_MAP, output, 'utf8');

  console.log(`Generated ${files.length} thumbnails and map: ${OUTPUT_MAP}`);
};

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
