const fs = require('fs');
const path = require('path');
const { createCanvas, loadImage } = require('canvas');

async function createOptimizedIcon() {
  try {
    console.log('Creando ícono optimizado...');
    
    const iconSize = 1024; // Tamaño estándar para íconos de app
    const padding = 120; // Padding para asegurar que el logo no se corte
    const logoSize = iconSize - (padding * 2);
    
    // Crear canvas
    const canvas = createCanvas(iconSize, iconSize);
    const ctx = canvas.getContext('2d');
    
    // Fondo blanco
    ctx.fillStyle = '#F8F6F2';
    ctx.fillRect(0, 0, iconSize, iconSize);
    
    // Cargar el logo
    const logo = await loadImage('./assets/logo.png');
    
    // Calcular dimensiones para mantener proporción
    const logoAspectRatio = logo.width / logo.height;
    let drawWidth = logoSize;
    let drawHeight = logoSize;
    
    if (logoAspectRatio > 1) {
      // Logo más ancho que alto
      drawHeight = logoSize / logoAspectRatio;
    } else {
      // Logo más alto que ancho
      drawWidth = logoSize * logoAspectRatio;
    }
    
    // Centrar el logo
    const x = (iconSize - drawWidth) / 2;
    const y = (iconSize - drawHeight) / 2;
    
    // Dibujar el logo
    ctx.drawImage(logo, x, y, drawWidth, drawHeight);
    
    // Guardar como PNG
    const buffer = canvas.toBuffer('image/png');
    fs.writeFileSync('./assets/icon-optimized.png', buffer);
    
    console.log('✅ Ícono optimizado creado: assets/icon-optimized.png');
    console.log(`📏 Tamaño: ${iconSize}x${iconSize} píxeles`);
    console.log(`📐 Logo centrado con padding de ${padding}px`);
    
    // También crear versión para adaptive icon de Android
    const adaptiveSize = 108; // Tamaño recomendado para adaptive icon
    const adaptiveCanvas = createCanvas(adaptiveSize, adaptiveSize);
    const adaptiveCtx = adaptiveCanvas.getContext('2d');
    
    // Fondo para adaptive icon
    adaptiveCtx.fillStyle = '#F8F6F2';
    adaptiveCtx.fillRect(0, 0, adaptiveSize, adaptiveSize);
    
    // Calcular dimensiones para adaptive icon
    const adaptiveLogoSize = adaptiveSize - 24; // Padding más pequeño para adaptive
    let adaptiveDrawWidth = adaptiveLogoSize;
    let adaptiveDrawHeight = adaptiveLogoSize;
    
    if (logoAspectRatio > 1) {
      adaptiveDrawHeight = adaptiveLogoSize / logoAspectRatio;
    } else {
      adaptiveDrawWidth = adaptiveLogoSize * logoAspectRatio;
    }
    
    // Centrar el logo
    const adaptiveX = (adaptiveSize - adaptiveDrawWidth) / 2;
    const adaptiveY = (adaptiveSize - adaptiveDrawHeight) / 2;
    
    // Dibujar el logo
    adaptiveCtx.drawImage(logo, adaptiveX, adaptiveY, adaptiveDrawWidth, adaptiveDrawHeight);
    
    // Guardar adaptive icon
    const adaptiveBuffer = adaptiveCanvas.toBuffer('image/png');
    fs.writeFileSync('./assets/adaptive-icon.png', adaptiveBuffer);
    
    console.log('✅ Adaptive icon creado: assets/adaptive-icon.png');
    console.log('📱 Optimizado para Android adaptive icons');
    
  } catch (error) {
    console.error('❌ Error creando el ícono:', error);
    console.log('\n💡 Si no tienes la librería canvas instalada, ejecuta:');
    console.log('npm install canvas');
  }
}

createOptimizedIcon(); 