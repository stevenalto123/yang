/**
 * Reads runtime environment variables uniformly across Netlify Functions and Node.js.
 */
export function getEnv(name: string): string | undefined {
  const netlifyGlobal = (globalThis as { Netlify?: { env?: { get?: (key: string) => string | undefined } } }).Netlify;
  const fromNetlify = netlifyGlobal?.env?.get?.(name);
  if (fromNetlify !== undefined && fromNetlify !== '') {
    return fromNetlify;
  }
  const fromProcess = process.env[name];
  return fromProcess !== undefined && fromProcess !== '' ? fromProcess : undefined;
}

export function getRequiredEnv(name: string, fallbackNames: string[] = []): string {
  const candidates = [name, ...fallbackNames];
  for (const key of candidates) {
    const val = getEnv(key);
    if (val) return val;
  }
  throw new Error(`Missing required environment variable: ${candidates.join(' or ')}`);
}
