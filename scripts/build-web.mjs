import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { execSync } from 'node:child_process';
import { dirname, relative, resolve } from 'node:path';

const buildWebDir = resolve(process.cwd(), 'build', 'web');
const webIndex = resolve(buildWebDir, 'index.html');
const isCloudCi =
  process.env.NETLIFY === 'true' ||
  process.env.VERCEL === '1' ||
  process.env.VERCEL === 'true';

function hasFlutterCli() {
  try {
    execSync('flutter --version', { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

function run(cmd, env = process.env) {
  execSync(cmd, { stdio: 'inherit', env });
}

function getBuildHelp(flutterBin, env) {
  try {
    return execSync(`"${flutterBin}" build web --help`, {
      encoding: 'utf8',
      env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch {
    return '';
  }
}

function buildFlutterWeb(flutterBin, env = process.env) {
  const help = getBuildHelp(flutterBin, env);
  const flags = ['--release', '--base-href', '/'];
  // Bundle CanvasKit & runtime resources locally so offline mode never needs gstatic.com
  if (help.includes('--no-web-resources-cdn')) {
    flags.push('--no-web-resources-cdn');
  }
  // Avoid generating a legacy flutter_service_worker.js that conflicts with our custom sw.js
  if (help.includes('--pwa-strategy')) {
    flags.push('--pwa-strategy=none');
  }
  console.log(`Running: ${flutterBin} build web ${flags.join(' ')}`);
  run(`"${flutterBin}" build web ${flags.join(' ')}`, env);
}

function collectPrecacheUrls(dir) {
  const urls = new Set(['./', './index.html']);

  function walk(current) {
    for (const entry of readdirSync(current)) {
      const full = resolve(current, entry);
      const st = statSync(full);
      if (st.isDirectory()) {
        walk(full);
        continue;
      }
      const rel = relative(dir, full).replace(/\\/g, '/');
      // Skip service workers, source maps, huge skwasm/debug artifacts, and build metadata
      if (
        rel === 'sw.js' ||
        rel === 'flutter_service_worker.js' ||
        rel.startsWith('.') ||
        rel.endsWith('.map') ||
        rel.endsWith('.symbols') ||
        rel.endsWith('NOTICES') ||
        rel.includes('skwasm')
      ) {
        continue;
      }
      urls.add(`./${rel}`);
    }
  }

  walk(dir);
  return [...urls].sort();
}

function finalizeOfflineServiceWorker(dir) {
  // Remove legacy flutter_service_worker.js if generated so only sw.js controls the PWA
  const legacySw = resolve(dir, 'flutter_service_worker.js');
  if (existsSync(legacySw)) {
    rmSync(legacySw, { force: true });
    console.log('Removed conflicting flutter_service_worker.js.');
  }

  const swPath = resolve(dir, 'sw.js');
  if (!existsSync(swPath)) {
    console.warn('Warning: build/web/sw.js not found — skipping precache manifest injection.');
    return;
  }

  const urls = collectPrecacheUrls(dir);
  const swContent = readFileSync(swPath, 'utf8');
  const injected = swContent.replace(
    /const PRECACHE_URLS = \[[\s\S]*?\];/,
    `const PRECACHE_URLS = ${JSON.stringify(urls, null, 2)};`,
  );

  if (injected === swContent) {
    console.warn('Warning: PRECACHE_URLS placeholder not matched in build/web/sw.js.');
  } else {
    writeFileSync(swPath, injected, 'utf8');
    console.log(`Injected ${urls.length} offline precache assets into build/web/sw.js.`);
  }
}

if (!isCloudCi && hasFlutterCli()) {
  console.log('Local Flutter SDK detected — building production Web PWA...');
  buildFlutterWeb('flutter');
  finalizeOfflineServiceWorker(buildWebDir);
} else if (isCloudCi) {
  const flutterRoot = existsSync('/opt/build/cache')
    ? '/opt/build/cache/flutter-sdk'
    : '/tmp/flutter-sdk';
  const flutterBin = `${flutterRoot}/bin/flutter`;

  if (!existsSync(flutterBin)) {
    console.log(`Installing Flutter stable SDK into ${flutterRoot}...`);
    mkdirSync(dirname(flutterRoot), { recursive: true });
    run(
      `git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${flutterRoot}"`,
    );
  } else {
    console.log(`Using cached Flutter SDK at ${flutterRoot}...`);
  }

  const buildEnv = {
    ...process.env,
    PATH: `${flutterRoot}/bin:${process.env.PATH || ''}`,
    PUB_CACHE: existsSync('/opt/build/cache')
      ? '/opt/build/cache/pub-cache'
      : process.env.PUB_CACHE,
  };

  run(`"${flutterBin}" --suppress-analytics config --enable-web`, buildEnv);
  run(`"${flutterBin}" --suppress-analytics pub get`, buildEnv);
  buildFlutterWeb(flutterBin, buildEnv);
  finalizeOfflineServiceWorker(buildWebDir);
} else if (existsSync(webIndex)) {
  console.log('Prebuilt Flutter Web bundle detected at build/web/index.html.');
  finalizeOfflineServiceWorker(buildWebDir);
} else {
  console.error(
    'ERROR: Neither Flutter SDK nor prebuilt build/web/index.html was found.',
  );
  process.exit(1);
}
