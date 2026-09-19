export function createSupabaseClient(env, accessToken) {
  if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) {
    throw new Error("Supabase environment is not configured");
  }

  const baseUrl = env.SUPABASE_URL.replace(/\/$/, "");
  const headers = {
    apikey: env.SUPABASE_ANON_KEY,
    Authorization: `Bearer ${accessToken}`,
    "content-type": "application/json",
  };

  return {
    async rest(path, init = {}) {
      const response = await fetch(`${baseUrl}/rest/v1/${path}`, {
        ...init,
        headers: { ...headers, ...(init.headers || {}) },
      });
      return response;
    },

    async rpc(name, args = {}) {
      const response = await fetch(`${baseUrl}/rest/v1/rpc/${name}`, {
        method: "POST",
        headers,
        body: JSON.stringify(args),
      });
      return response;
    },

    async authUser() {
      const response = await fetch(`${baseUrl}/auth/v1/user`, {
        headers: {
          apikey: env.SUPABASE_ANON_KEY,
          Authorization: `Bearer ${accessToken}`,
        },
      });

      if (!response.ok) return null;
      return response.json();
    },
  };
}
