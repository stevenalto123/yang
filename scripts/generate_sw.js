const fs = require('fs');
const path = require('path');

const BUILD_WEB = path.join(__dirname, '..', 'build', 'web');
const SW_PATH = path.join(BUILD_WEB, 'sw.js');
const FLUTTER_SW = path.join(BUILD_WEB, 'flutter_service_worker.js');

if (!fs.existsSync(BUILD_WEB)) {
  console.error('build/web directory not found. Run flutter build web first.');
  process.exit(1);
}

// Remove Flutter's self-unregistering service worker artifact if present
if (fs.existsSync(FLUTTER_SW)) {
  fs.unlinkSync(FLUTTER_SW);
}

function shouldPrecache(relPath) {
  if (
    relPath === 'sw.js' ||
    relPath === 'flutter_service_worker.js' ||
    relPath === '.last_build_id' ||
    relPath === 'assets/NOTICES' ||
    relPath.endsWith('.symbols') ||
    relPath.endsWith('.map')
  ) {
    return false;
  }
  // Only precache the active dart2js CanvasKit variants used across browsers
  if (
    relPath.startsWith('canvaskit/') &&
    relPath !== 'canvaskit/canvaskit.js' &&
    relPath !== 'canvaskit/canvaskit.wasm' &&
    relPath !== 'canvaskit/chromium/canvaskit.js' &&
    relPath !== 'canvaskit/chromium/canvaskit.wasm'
  ) {
    return false;
  }
  return true;
}

function walk(dir, base = '') {
  const results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const rel = base ? `${base}/${entry.name}` : entry.name;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walk(full, rel));
    } else if (entry.isFile() && shouldPrecache(rel)) {
      results.push(`./${rel}`);
    }
  }
  return results;
}

const precacheUrls = ['./', ...walk(BUILD_WEB).sort()];
const cacheVersion = `lifecheckpoint-pwa-${Date.now()}`;

let swContent = fs.readFileSync(SW_PATH, 'utf8');
swContent = swContent.replace(
  /const CACHE_NAME = '[^']+';/,
  `const CACHE_NAME = '${cacheVersion}';`
);
swContent = swContent.replace(
  /const PRECACHE_URLS = \[[\s\S]*?\];/,
  `const PRECACHE_URLS = ${JSON.stringify(precacheUrls, null, 2)};`
);

fs.writeFileSync(SW_PATH, swContent, 'utf8');
console.log(
  `Updated ${SW_PATH} with ${precacheUrls.length} precached URLs (${cacheVersion}).`
);
