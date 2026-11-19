import type { Config, Context } from '@netlify/functions';
import { getPostgresStore } from '../lib/repository.js';
import { handleApiRequest } from '../lib/router.js';

export default async (req: Request, _context: Context): Promise<Response> => {
  return handleApiRequest(req, getPostgresStore());
};

export const config: Config = {
  path: '/api/*',
};
