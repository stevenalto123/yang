/**
 * Reads runtime environment variables uniformly across Vercel Serverless and Node.js.
 */
export function getEnv(name: string): string | undefined {
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
