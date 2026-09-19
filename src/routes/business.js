import { requireAuth } from "../auth.js";
import { HttpError } from "../errors.js";
import { ok } from "../response.js";

export async function getBusiness(request, env) {
  const { supabase, context } = await requireAuth(request, env);
  const businessId = encodeURIComponent(context.businessId);

  const businessResponse = await supabase.rest(
    `businesses?id=eq.${businessId}&select=id,legal_name,trade_name,slug,city,distinctive,is_active&limit=1`,
  );
  if (!businessResponse.ok) {
    throw new HttpError(500, "BUSINESS_LOOKUP_FAILED", "No fue posible consultar el negocio");
  }

  const businesses = await businessResponse.json();
  const business = businesses?.[0];
  if (!business || !business.is_active) {
    throw new HttpError(403, "BUSINESS_INACTIVE", "El negocio no está activo");
  }

  const channelsResponse = await supabase.rest(
    `business_channels?business_id=eq.${businessId}&select=channel_code,is_enabled`,
  );
  if (!channelsResponse.ok) {
    throw new HttpError(500, "CHANNELS_LOOKUP_FAILED", "No fue posible consultar los canales");
  }

  const channels = await channelsResponse.json();

  return ok({
    ...business,
    channels,
    whatsapp: {
      channelEnabled: channels?.some(
        (channel) => channel.channel_code === "WHATSAPP" && channel.is_enabled === true,
      ) ?? false,
      username: null,
      usernameStatus: "NOT_CONFIGURED",
    },
  });
}
