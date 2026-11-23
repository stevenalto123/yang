import { getPostgresStore } from '../netlify/lib/repository.js';
import { handleApiRequest } from '../netlify/lib/router.js';

export default {
  async fetch(request: Request): Promise<Response> {
    return handleApiRequest(request, getPostgresStore());
  },
};
