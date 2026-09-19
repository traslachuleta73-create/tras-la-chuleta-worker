import { HttpError } from "./errors.js";

export async function loadUserContext(supabase, userId) {
  const response = await supabase.rest(
    `profiles?id=eq.${encodeURIComponent(userId)}&select=id,business_id,role_code,city,distinctive,display_name,is_active&limit=1`,
  );

  if (!response.ok) {
    throw new HttpError(500, "PROFILE_LOOKUP_FAILED", "No fue posible validar el perfil operativo");
  }

  const rows = await response.json();
  const profile = rows?.[0];

  if (!profile) {
    throw new HttpError(403, "PROFILE_NOT_FOUND", "El usuario no tiene perfil operativo");
  }

  if (!profile.is_active) {
    throw new HttpError(403, "USER_INACTIVE", "El usuario está desactivado");
  }

  return {
    userId: profile.id,
    businessId: profile.business_id,
    roleCode: profile.role_code,
    city: profile.city,
    distinctive: profile.distinctive,
    displayName: profile.display_name,
  };
}

export function requireRole(context, allowedRoles) {
  if (!allowedRoles.includes(context.roleCode)) {
    throw new HttpError(403, "FORBIDDEN", "Operación no autorizada para este rol");
  }
}
