import { ok } from "../response.js";

export function health(env) {
  return ok({
    service: "tras-la-chuleta-api",
    version: "v1",
    environment: env.ENVIRONMENT ?? "unknown",
  });
}
