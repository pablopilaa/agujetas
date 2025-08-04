const fs = require('fs');
const path = require('path');
const { createCanvas, loadImage } = require('canvas');

async function createTransparentLogos() {
  try {
    console.log('Creando logos transparentes...');
    
    // Crear versión transparente del logo claro
    await createTransparentLogo('./assets/logo.png', './assets/logo-transparent.png', 'Logo claro transparente', '#FFFFFF');
    
    // Crear versión transparente del logo oscuro
    await createTransparentLogo('./assets/logo-dark.png', './assets/logo-dark-transparent.png', 'Logo oscuro transparente', '#000000');
    
    console.log('✅ Todos los logos transparentes creados exitosamente!');
    
  } catch (error) {
    console.error('❌ Error creando los logos transparentes:', error);
    console.log('\n💡 Si no tienes la librería canvas instalada, ejecuta:');
    console.log('npm install canvas');
  }
}

async function createTransparentLogo(inputPath, outputPath, description, backgroundColor) {
  try {
    console.log(`\n🔄 Creando ${description}...`);
    
    // Cargar el logo original
    const logo = await loadImage(inputPath);
    
    // Crear canvas con fondo transparente
    const canvas = createCanvas(logo.width, logo.height);
    const ctx = canvas.getContext('2d');
    
    // Hacer el fondo transparente
    ctx.clearRect(0, 0, logo.width, logo.height);
    
    // Dibujar el logo original
    ctx.drawImage(logo, 0, 0);
    
    // Obtener los datos de la imagen
    const imageData = ctx.getImageData(0, 0, logo.width, logo.height);
    const data = imageData.data;
    
    // Convertir el color de fondo a transparente
    const targetColor = hexToRgb(backgroundColor);
    const tolerance = 30; // Tolerancia para variaciones de color
    
    for (let i = 0; i < data.length; i += 4) {
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];
      
      // Verificar si el píxel es similar al color de fondo
      if (isColorSimilar([r, g, b], targetColor, tolerance)) {
        data[i + 3] = 0; // Hacer transparente
      }
    }
    
    // Aplicar los cambios
    ctx.putImageData(imageData, 0, 0);
    
    // Guardar como PNG con transparencia
    const buffer = canvas.toBuffer('image/png');
    fs.writeFileSync(outputPath, buffer);
    
    console.log(`✅ ${description} creado: ${outputPath}`);
    console.log(`📏 Tamaño: ${logo.width}x${logo.height} píxeles`);
    console.log(`🎨 Fondo removido: ${backgroundColor}`);
    
  } catch (error) {
    console.error(`❌ Error creando ${description}:`, error);
  }
}

function hexToRgb(hex) {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result ? [
    parseInt(result[1], 16),
    parseInt(result[2], 16),
    parseInt(result[3], 16)
  ] : null;
}

function isColorSimilar(color1, color2, tolerance) {
  return Math.abs(color1[0] - color2[0]) <= tolerance &&
         Math.abs(color1[1] - color2[1]) <= tolerance &&
         Math.abs(color1[2] - color2[2]) <= tolerance;
}

createTransparentLogos(); 