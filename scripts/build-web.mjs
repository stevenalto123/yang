import { existsSync, mkdirSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';

const webIndex = resolve(process.cwd(), 'build', 'web', 'index.html');
const isNetlify = process.env.NETLIFY === 'true';

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

if (!isNetlify && hasFlutterCli()) {
  console.log('Local Flutter SDK detected — building production Web PWA...');
  run('flutter build web --release --base-href /');
} else if (isNetlify) {
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
  run(`"${flutterBin}" --suppress-analytics build web --release --base-href /`, buildEnv);
} else if (existsSync(webIndex)) {
  console.log('Prebuilt Flutter Web bundle detected at build/web/index.html.');
} else {
  console.error(
    'ERROR: Neither Flutter SDK nor prebuilt build/web/index.html was found.',
  );
  process.exit(1);
}
