const fs = require('fs');
const path = require('path');

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

sizes.forEach(size => {
  const svgContent = generateSVGIcon(size);
  const filename = `icon-${size}x${size}.svg`;
  const filepath = path.join(publicDir, filename);
  
  fs.writeFileSync(filepath, svgContent.trim());
  console.log(`✓ Created ${filename}`);
});

console.log('\nℹ️  SVG icons created. For production, consider converting to PNG using:');
console.log('   - Online tool: https://svgtopng.com/');
console.log('   - Or install sharp: yarn add -D sharp');
console.log('   - Then use an image conversion script');

