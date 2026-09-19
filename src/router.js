import { requireAuth } from "./auth.js";
import { HttpError } from "./errors.js";
import { fail, ok } from "./response.js";
import { health } from "./routes/health.js";
import { me } from "./routes/auth.js";
import { getBusiness } from "./routes/business.js";

export async function router(request, env) {
  const url = new URL(request.url);
  const path = normalizePath(url.pathname);

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }

  if (request.method === "GET" && path === "/health") {
    return withCors(health(env));
  }

  if (request.method === "GET" && path === "/api/auth/me") {
    return withCors(await me(request, env));
  }

  if (request.method === "GET" && path === "/api/business/me") {
    return withCors(await getBusiness(request, env));
  }

  // Seguridad deliberada: no existen rutas operativas todavía en este esqueleto.
  if (path.startsWith("/api/")) {
    throw new HttpError(404, "NOT_FOUND", "Ruta API no implementada");
  }

  throw new HttpError(404, "NOT_FOUND", "Ruta no encontrada");
}

function normalizePath(pathname) {
  const value = pathname.replace(/\/+$/, "");
  return value || "/";
}

function corsHeaders() {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "authorization, content-type",
    "access-control-allow-methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS",
  };
}

function withCors(response) {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders())) headers.set(key, value);
  return new Response(response.body, { status: response.status, headers });
}

export async function handleError(error) {
  if (error instanceof HttpError) {
    return withCors(fail(error.code, error.message, error.status, error.details));
  }

  return withCors(fail("INTERNAL_ERROR", "Error interno", 500));
}
