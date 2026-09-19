export function ok(data = null, status = 200, extra = {}) {
  return json({ ok: true, data, ...extra }, status);
}

export function fail(code, message, status = 400, details = undefined) {
  const error = { code, message };
  if (details !== undefined) error.details = details;
  return json({ ok: false, error }, status);
}

export function json(body, status = 200, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...headers,
    },
  });
}
