import { getPostgresStore } from '../server/lib/repository.js';
import { handleApiRequest } from '../server/lib/router.js';

export default {
  async fetch(request: Request): Promise<Response> {
    return handleApiRequest(request, getPostgresStore());
  },
};
