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
    return new Response(null, { status: 204, headers: corsHeaders(request, env) });
  }

  if (request.method === "GET" && path === "/health") {
    return withCors(health(env), request, env);
  }

  if (request.method === "GET" && path === "/api/auth/me") {
    return withCors(await me(request, env), request, env);
  }

  if (request.method === "GET" && path === "/api/business/me") {
    return withCors(await getBusiness(request, env), request, env);
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

function allowedOrigins(env) {
  return String(env?.ALLOWED_ORIGINS || "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
}

function corsHeaders(request, env) {
  const headers = new Headers({
    "access-control-allow-headers": "authorization, content-type",
    "access-control-allow-methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS",
  });

  const origin = request.headers.get("Origin");
  if (origin) {
    headers.set("Vary", "Origin");
    if (allowedOrigins(env).includes(origin)) {
      headers.set("access-control-allow-origin", origin);
    }
  }

  return headers;
}

function withCors(response, request, env) {
  const headers = new Headers(response.headers);
  for (const [key, value] of corsHeaders(request, env).entries()) headers.set(key, value);
  return new Response(response.body, { status: response.status, headers });
}

export async function handleError(error, request, env) {
  if (error instanceof HttpError) {
    return withCors(fail(error.code, error.message, error.status, error.details), request, env);
  }

  return withCors(fail("INTERNAL_ERROR", "Error interno", 500), request, env);
}
