import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import sharp from 'sharp';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Simple SVG icon generator for Ouest
const generateSVGIcon = (size) => `
<svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#6366f1;stop-opacity:1" />
      <stop offset="50%" style="stop-color:#a855f7;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#ec4899;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="${size}" height="${size}" rx="${size * 0.2}" fill="url(#grad)"/>
  <text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" 
        font-family="system-ui, -apple-system, sans-serif" 
        font-size="${size * 0.6}" 
        font-weight="700" 
        fill="white">O</text>
</svg>`;

const publicDir = path.join(__dirname, '..', 'public');

// Create icons for different sizes
const sizes = [192, 256, 384, 512];

async function generateIcons() {
  for (const size of sizes) {
    const svgContent = generateSVGIcon(size);
    const pngFilename = `icon-${size}x${size}.png`;
    const pngFilepath = path.join(publicDir, pngFilename);
    
    try {
      await sharp(Buffer.from(svgContent))
        .resize(size, size)
        .png()
        .toFile(pngFilepath);
      
      console.log(`✓ Created ${pngFilename}`);
    } catch (error) {
      console.error(`✗ Failed to create ${pngFilename}:`, error.message);
    }
  }
  
  console.log('\n✅ All PWA icons created successfully!');
}

generateIcons();

