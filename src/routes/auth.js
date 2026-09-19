import { requireAuth } from "../auth.js";
import { ok } from "../response.js";

export async function me(request, env) {
  const auth = await requireAuth(request, env);
  return ok({
    user: {
      id: auth.user.id,
      email: auth.user.email ?? null,
    },
    profile: auth.context,
  });
}
