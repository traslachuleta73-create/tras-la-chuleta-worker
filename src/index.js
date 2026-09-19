import { router, handleError } from "./router.js";

export default {
  async fetch(request, env, ctx) {
    try {
      return await router(request, env, ctx);
    } catch (error) {
      console.error("Worker error", error);
      return await handleError(error, request, env);
    }
  },
};
