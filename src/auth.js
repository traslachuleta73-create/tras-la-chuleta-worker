import { HttpError } from "./errors.js";
import { createSupabaseClient } from "./supabase/client.js";
import { loadUserContext } from "./context.js";

function bearerToken(request) {
  const value = request.headers.get("authorization") || "";
  const match = value.match(/^Bearer\s+(.+)$/i);
  return match?.[1] || null;
}

export async function requireAuth(request, env) {
  const token = bearerToken(request);
  if (!token) {
    throw new HttpError(401, "UNAUTHENTICATED", "Autenticación requerida");
  }

  const supabase = createSupabaseClient(env, token);
  const user = await supabase.authUser();

  if (!user?.id) {
    throw new HttpError(401, "UNAUTHENTICATED", "Sesión inválida o expirada");
  }

  const context = await loadUserContext(supabase, user.id);

  return { token, supabase, user, context };
}
