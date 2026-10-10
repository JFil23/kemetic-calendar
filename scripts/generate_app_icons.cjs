#!/usr/bin/env node
// Regenerate the existing platform icon slots from one canonical SVG.
// Requires sharp 0.35.4 (SVG renderer: librsvg 2.62.91).
// Run: NODE_PATH=<directory containing sharp> node scripts/generate_app_icons.cjs
// Add --check to verify tracked exports without writing them.
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..');
const source = path.join(root, 'assets/branding/haw_app_icon.svg');
const check = process.argv.includes('--check');

async function main() {
  if (process.argv.slice(2).some((arg) => arg !== '--check')) {
    throw new Error('Usage: node scripts/generate_app_icons.cjs [--check]');
  }
  const svg = await fs.readFile(source, 'utf8');
  const wordmarkTransform = 'transform="translate(4 146) scale(4.33)"';
  if (svg.split(wordmarkTransform).length !== 2) {
    throw new Error('Expected exactly one canonical wordmark transform.');
  }
  // W3C maskable safe zone: a centered circle with radius 40% of the canvas.
  // Inset only the wordmark; leave the reference background full bleed.
  // https://www.w3.org/TR/appmanifest/#icon-masks
  const maskable = svg.replace(
    wordmarkTransform,
    'transform="translate(512 512) scale(.86) translate(-512 -512) translate(4 146) scale(4.33)"',
  );
  // Preserve the existing macOS tile housing (100px inset on a 1024px canvas).
  // All internal artwork comes from the same unmodified reference symbol.
  const mac = svg.replace(
    '<use href="#full-icon"/>',
    '<defs><clipPath id="mac-tile"><rect x="100" y="100" width="824" height="824" rx="182.928"/></clipPath></defs>' +
      '<g clip-path="url(#mac-tile)"><use href="#full-icon" x="100" y="100" width="824" height="824"/></g>',
  );
  const variants = { standard: svg, maskable, mac };
  const outputs = new Map();
  const add = (file, size, variant = 'standard') => outputs.set(file, { size, variant });
  for (const size of [192, 512]) {
    add(`web/icons/Icon-${size}.png`, size);
    add(`web/icons/Icon-maskable-${size}.png`, size, 'maskable');
  }
  add('web/favicon.png', 32);
  for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
    add(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`, size);
  }
  for (const platform of ['ios', 'macos']) {
    const directory = `${platform}/Runner/Assets.xcassets/AppIcon.appiconset`;
    const catalog = JSON.parse(await fs.readFile(path.join(root, directory, 'Contents.json'), 'utf8'));
    for (const entry of catalog.images) {
      const [width, height] = entry.size.split('x').map(Number);
      const size = width * Number(entry.scale.replace('x', ''));
      if (width !== height || !Number.isInteger(size)) throw new Error(`Invalid icon slot: ${entry.filename}`);
      add(`${directory}/${entry.filename}`, size, platform === 'macos' ? 'mac' : 'standard');
    }
  }
  const rendered = new Map();
  for (const [file, { size, variant }] of outputs) {
    // Web release authority requires RGBA PNGs, even for opaque artwork.
    // iOS exports omit alpha; macOS keeps its transparent exterior.
    const alpha = file.startsWith('web/') || variant === 'mac';
    const key = `${variant}:${size}:${alpha}`;
    if (!rendered.has(key)) {
      // Rasterize vectors at their target size, preserving the authored filters.
      const target = variants[variant].replace('width="1024" height="1024" viewBox=', `width="${size}" height="${size}" viewBox=`);
      let renderer = sharp(Buffer.from(target));
      renderer = alpha ? renderer.ensureAlpha() : renderer.removeAlpha();
      rendered.set(key, await renderer.png({ compressionLevel: 9 }).toBuffer());
    }
    const png = rendered.get(key);
    const destination = path.join(root, file);
    if (check) {
      const actual = await fs.readFile(destination);
      const expectedPixels = await sharp(png).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
      const actualPixels = await sharp(actual).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
      if (actualPixels.info.width !== size || actualPixels.info.height !== size || !actualPixels.data.equals(expectedPixels.data)) {
        throw new Error(`Icon differs from canonical artwork: ${file}`);
      }
    } else {
      await fs.writeFile(destination, png);
    }
  }
  console.log(`${check ? 'Verified' : 'Generated'} ${outputs.size} icon assets from assets/branding/haw_app_icon.svg`);
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; });
