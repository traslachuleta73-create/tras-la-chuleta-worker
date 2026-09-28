import { requireAuth } from "../auth.js";
import { requireRole } from "../context.js";
import { HttpError } from "../errors.js";
import { ok } from "../response.js";

async function readJson(request) {
  try {
    const body = await request.json();
    if (!body || typeof body !== "object" || Array.isArray(body)) {
      throw new HttpError(400, "INVALID_BODY", "El cuerpo debe ser un objeto JSON");
    }
    return body;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(400, "INVALID_JSON", "JSON inválido");
  }
}

function required(body, field) {
  if (body[field] === undefined || body[field] === null || body[field] === "") {
    throw new HttpError(400, "MISSING_FIELD", `Falta el campo ${field}`);
  }
  return body[field];
}

async function callRpc(request, env, rpcName, args = {}) {
  const { supabase } = await requireAuth(request, env);
  const response = await supabase.rpc(rpcName, args);

  let payload = null;
  try {
    payload = await response.json();
  } catch {
    payload = null;
  }

  if (!response.ok) {
    const message =
      payload?.message ||
      payload?.error_description ||
      payload?.error ||
      `RPC ${rpcName} rechazado`;

    const code =
      payload?.code ||
      payload?.error ||
      `RPC_${rpcName.toUpperCase()}_FAILED`;

    throw new HttpError(
      response.status >= 400 && response.status < 500 ? response.status : 400,
      code,
      message,
      payload,
    );
  }

  return ok(payload);
}

export async function openConsumption(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "open_consumption", {
    p_space_id: body.space_id ?? null,
    p_service_mode_id: body.service_mode_id ?? null,
  });
}

export async function requestConsumptionClose(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "request_consumption_close", {
    p_consumption_id: required(body, "consumption_id"),
  });
}

export async function closeConsumption(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "close_consumption", {
    p_consumption_id: required(body, "consumption_id"),
  });
}

export async function cancelConsumption(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "cancel_consumption", {
    p_consumption_id: required(body, "consumption_id"),
    p_reason: required(body, "reason"),
  });
}

export async function createOrder(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "create_order", {
    p_consumption_id: required(body, "consumption_id"),
    p_channel_code: required(body, "channel_code"),
    p_notes: body.notes ?? null,
  });
}

export async function validateOrder(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "validate_order", {
    p_order_id: required(body, "order_id"),
  });
}

export async function addOrderItem(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "add_order_item", {
    p_order_id: required(body, "order_id"),
    p_product_id: required(body, "product_id"),
    p_station_id: required(body, "station_id"),
    p_quantity: required(body, "quantity"),
    p_notes: body.notes ?? null,
  });
}

export async function receiveOrder(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "receive_order_station", {
    p_order_id: required(body, "order_id"),
    p_station_id: required(body, "station_id"),
  });
}

export async function startPreparation(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "start_order_station_preparation", {
    p_order_id: required(body, "order_id"),
    p_station_id: required(body, "station_id"),
  });
}

async function listRest(request, env, path, errorCode, errorMessage) {
  const { supabase } = await requireAuth(request, env);
  const response = await supabase.rest(path);
  let payload = null;
  try { payload = await response.json(); } catch { payload = null; }
  if (!response.ok) {
    throw new HttpError(
      response.status >= 400 && response.status < 500 ? response.status : 502,
      payload?.code || errorCode,
      payload?.message || errorMessage,
    );
  }
  return ok(payload);
}

export async function listStationOrders(request, env) {
  const url = new URL(request.url);
  const stationId = url.searchParams.get("station_id");
  const stationFilter = stationId ? `&station_id=eq.${encodeURIComponent(stationId)}` : "";
  return listRest(
    request, env,
    `order_station_work?select=id,business_id,order_id,station_id,status,received_at,preparing_at,ready_at,station:stations(id,code,name,station_type),order:orders!inner(id,order_number,channel_code,status,note,created_at,consumption_id,items:order_items(id,product_id,station_id,quantity,unit_price,notes,ready_at,product:products(id,name)) )&status=in.(PENDING,RECEIVED,PREPARING,READY)${stationFilter}&order.status=in.(RECEIVED,PREPARING,READY_FOR_CASHIER)&order=created_at.asc`,
    "STATION_ORDERS_FAILED", "No se pudieron consultar las comandas por estación",
  );
}

export async function listActiveOrders(request, env) {
  return listRest(
    request, env,
    "orders?select=id,order_number,channel_code,status,note,created_at,consumption_id,items:order_items(id,product_id,station_id,quantity,unit_price,notes,ready_at,product:products(id,name),station:stations(id,code,name,station_type))&status=in.(NEW,RECEIVED,PREPARING,READY_FOR_CASHIER,CASHIER_ASSEMBLING,READY)&order=created_at.asc",
    "ORDERS_LIST_FAILED", "No se pudieron consultar los pedidos activos",
  );
}

async function resourceJson(response, label) {
  let payload = null;
  try { payload = await response.json(); } catch { payload = null; }
  if (!response.ok) {
    throw new HttpError(502, "RESOURCE_LOOKUP_FAILED", `No se pudo consultar ${label}`);
  }
  return payload || [];
}

export async function listOperationalCatalog(request, env) {
  const { supabase } = await requireAuth(request, env);
  const paths = {
    products: "products?select=id,name,price,is_available,unavailable_reason,is_active&is_active=eq.true&order=name.asc",
    stations: "stations?select=id,code,name,station_type,is_active&is_active=eq.true&order=name.asc",
    productStations: "product_stations?select=product_id,station_id",
    spaces: "spaces?select=id,name,space_type,is_active&is_active=eq.true&order=name.asc",
    serviceModes: "service_modes?select=id,code,name,is_active&is_active=eq.true&order=name.asc",
    paymentMethods: "business_payment_methods?select=method_code,display_name,is_enabled&is_enabled=eq.true&order=display_name.asc",
    channels: "business_channels?select=channel_code,is_enabled&is_enabled=eq.true&order=channel_code.asc",
  };
  const entries = await Promise.all(Object.entries(paths).map(async ([key, path]) => [
    key, await resourceJson(await supabase.rest(path), key),
  ]));
  return ok(Object.fromEntries(entries));
}

export async function listOpenConsumptions(request, env) {
  return listRest(
    request, env,
    "consumptions?select=id,consumption_number,status,opened_at,space_id,service_mode_id,space:spaces(name),service_mode:service_modes(name,code),orders:orders(id,order_number,channel_code,status,note,created_at,items:order_items(id,product_id,station_id,quantity,unit_price,notes,product:products(id,name),station:stations(id,code,name,station_type))),payments:payments(id,status,method_code,amount,created_at,confirmed_at)&status=in.(OPEN,PENDING_CLOSE)&order=opened_at.desc&limit=100",
    "CONSUMPTIONS_LIST_FAILED", "No se pudieron consultar los consumos abiertos",
  );
}

export async function markStationReady(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "mark_order_station_ready", {
    p_order_item_id: required(body, "order_item_id"),
  });
}

export async function deliverOrder(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "deliver_order", {
    p_order_id: required(body, "order_id"),
  });
}

export async function cancelOrder(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "cancel_order", {
    p_order_id: required(body, "order_id"),
    p_reason: required(body, "reason"),
  });
}

export async function replaceOrder(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "replace_order", {
    p_order_id: required(body, "order_id"),
    p_reason: required(body, "reason"),
    p_notes: body.notes ?? null,
    p_items: required(body, "items"),
  });
}

export async function createPayment(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "create_payment", {
    p_consumption_id: required(body, "consumption_id"),
    p_method_code: required(body, "method_code"),
    p_amount: required(body, "amount"),
    p_external_reference: body.external_reference ?? null,
  });
}

export async function confirmPayment(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "confirm_payment", {
    p_payment_id: required(body, "payment_id"),
  });
}

export async function listCuts(request, env) {
  const { supabase } = await requireAuth(request, env);
  const response = await supabase.rest(
    "cuts?select=id,status,opened_at,executed_at,operator_user_id,totals&order=opened_at.desc",
  );

  let payload = null;
  try {
    payload = await response.json();
  } catch {
    payload = null;
  }

  if (!response.ok) {
    const message = payload?.message || "No se pudieron consultar los cortes";
    const code = payload?.code || "CUT_LIST_FAILED";
    throw new HttpError(
      response.status >= 400 && response.status < 500 ? response.status : 502,
      code,
      message,
    );
  }

  return ok(payload);
}

export async function listAdminOverview(request, env) {
  const { supabase, context } = await requireAuth(request, env);
  requireRole(context, ["ADMIN"]);
  const [users, audit, payments, refunds, deliveredOrders, serviceModes, fichaVersions, platformResponse] = await Promise.all([
    resourceJson(await supabase.rest("profiles?select=id,display_name,role_code,city,distinctive,is_active,created_at&order=role_code.asc,display_name.asc"), "usuarios"),
    resourceJson(await supabase.rest("audit_log?select=id,actor_user_id,action,entity_type,entity_id,occurred_at,reason&order=occurred_at.desc&limit=100"), "auditoría"),
    resourceJson(await supabase.rest("payments?select=id,amount,status,method_code,consumption_id,confirmed_at&status=eq.CONFIRMED&order=confirmed_at.desc&limit=50"), "cobros"),
    resourceJson(await supabase.rest("payment_refunds?select=id,payment_id,amount,reason,external_reference,recorded_at&order=recorded_at.desc&limit=100"), "devoluciones"),
    resourceJson(await supabase.rest("orders?select=id,order_number,status,delivered_at,voided_after_delivery_at,voided_after_delivery_reason&status=eq.DELIVERED&order=delivered_at.desc&limit=50"), "pedidos entregados"),
    resourceJson(await supabase.rest("service_modes?select=id,code,name,is_active&order=name.asc"), "modalidades"),
    resourceJson(await supabase.rest("business_ficha_versions?select=id,version,tlc_approved,client_approved,created_at,document_path&order=version.desc&limit=20"), "fichas técnicas"),
    supabase.rpc("is_platform_operator"),
  ]);
  const isPlatformOperator = platformResponse.ok && await platformResponse.json().catch(() => false) === true;
  return ok({ users, audit, payments, refunds, deliveredOrders, serviceModes, fichaVersions,
    userProvisioningEnabled: Boolean(env.SUPABASE_SECRET_KEY), isPlatformOperator });
}

export async function deactivateUser(request, env) {
  const { context } = await requireAuth(request, env);
  requireRole(context, ["ADMIN"]);
  const body = await readJson(request);
  return callRpc(request, env, "deactivate_business_user", {
    p_user_id: required(body, "user_id"),
    p_reason: required(body, "reason"),
  });
}

async function adminAction(request, env, name, args) {
  const { context } = await requireAuth(request, env);
  requireRole(context, ["ADMIN"]);
  return callRpc(request, env, name, args);
}

export async function editUser(request, env) {
  const body = await readJson(request);
  return adminAction(request, env, "edit_business_user", {
    p_user_id: required(body, "user_id"), p_display_name: required(body, "display_name"),
    p_role_code: required(body, "role_code"), p_city: required(body, "city"),
    p_distinctive: body.distinctive ?? null, p_reason: required(body, "reason"),
  });
}

export async function createBusinessUser(request, env) {
  const { context } = await requireAuth(request, env);
  requireRole(context, ["ADMIN"]);
  if (!env.SUPABASE_SECRET_KEY) {
    throw new HttpError(503, "USER_PROVISIONING_NOT_CONFIGURED", "Falta configurar la clave privada de creación de usuarios");
  }
  const body = await readJson(request);
  const email = String(required(body, "email")).trim().toLowerCase();
  const password = String(required(body, "password"));
  const role = String(required(body, "role_code"));
  const displayName = String(required(body, "display_name")).trim();
  const city = String(required(body, "city")).trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || password.length < 12 || !displayName || !city ||
      !["ADMIN", "CAJA", "MESERO", "BARRA", "COCINA"].includes(role)) {
    throw new HttpError(400, "INVALID_USER_DETAILS", "Revisa correo, clave de al menos 12 caracteres, nombre, ciudad y rol");
  }
  const baseUrl = env.SUPABASE_URL.replace(/\/$/, "");
  const adminHeaders = {
    apikey: env.SUPABASE_SECRET_KEY,
    authorization: `Bearer ${env.SUPABASE_SECRET_KEY}`,
    "content-type": "application/json",
  };
  const created = await fetch(`${baseUrl}/auth/v1/admin/users`, {
    method: "POST", headers: adminHeaders,
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  const authRecord = await created.json().catch(() => ({}));
  if (!created.ok || !(authRecord.id || authRecord.user?.id)) {
    throw new HttpError(created.status === 422 ? 409 : 502, "AUTH_USER_CREATE_FAILED", "No se pudo crear el acceso. Revisa si el correo ya existe.");
  }
  const userId = authRecord.id || authRecord.user.id;
  try {
    return await callRpc(request, env, "attach_business_user", {
      p_user_id: userId, p_display_name: displayName, p_role_code: role,
      p_city: city, p_distinctive: body.distinctive ?? null,
    });
  } catch (error) {
    const cleanup = await fetch(`${baseUrl}/auth/v1/admin/users/${encodeURIComponent(userId)}`, {
      method: "DELETE", headers: adminHeaders,
    }).catch(() => null);
    if (!cleanup?.ok) {
      throw new HttpError(502, "USER_CREATION_NEEDS_REVIEW", "El perfil falló y el acceso recién creado requiere revisión administrativa");
    }
    throw error;
  }
}

export async function recordRefund(request, env) {
  const body = await readJson(request);
  return adminAction(request, env, "record_payment_refund", {
    p_payment_id: required(body, "payment_id"), p_amount: required(body, "amount"),
    p_reason: required(body, "reason"), p_external_reference: body.external_reference ?? null,
  });
}

export async function voidDeliveredOrder(request, env) {
  const body = await readJson(request);
  return adminAction(request, env, "void_delivered_order", {
    p_order_id: required(body, "order_id"), p_reason: required(body, "reason"),
  });
}

export async function setServiceModeEnabled(request, env) {
  const body = await readJson(request);
  return adminAction(request, env, "configure_service_mode", {
    p_code: required(body, "code"), p_name: required(body, "name"),
    p_enabled: required(body, "enabled"),
    p_reason: required(body, "reason"),
  });
}

export async function updateProductConfig(request, env) {
  const body = await readJson(request);
  return adminAction(request, env, "update_product_config", {
    p_product_id: required(body, "product_id"), p_name: required(body, "name"),
    p_price: required(body, "price"), p_available: required(body, "available"),
    p_unavailable_reason: body.unavailable_reason ?? null, p_reason: required(body, "reason"),
  });
}

export async function approveFicha(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "approve_ficha_version", {
    p_ficha_id: required(body, "ficha_id"), p_side: required(body, "side"),
  });
}

function storageAdminHeaders(env) {
  if (!env.SUPABASE_SECRET_KEY) throw new HttpError(503, "STORAGE_NOT_CONFIGURED", "Falta configurar acceso privado para la Ficha Técnica");
  return { apikey: env.SUPABASE_SECRET_KEY, authorization: `Bearer ${env.SUPABASE_SECRET_KEY}` };
}

export async function uploadFicha(request, env) {
  const { supabase, context } = await requireAuth(request, env);
  requireRole(context, ["ADMIN"]);
  const platform = await supabase.rpc("is_platform_operator");
  if (!platform.ok || await platform.json().catch(() => false) !== true) {
    throw new HttpError(403, "PLATFORM_ROLE_REQUIRED", "Solo Tras La Chuleta crea versiones de Ficha Técnica");
  }
  const headers = storageAdminHeaders(env);
  const form = await request.formData();
  const businessId = String(form.get("business_id") || "");
  const file = form.get("pdf");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(businessId)
      || !file || typeof file.arrayBuffer !== "function" || file.size > 5242880 || file.size < 5) {
    throw new HttpError(400, "INVALID_FICHA_PDF", "Adjunta un PDF de hasta 5 MB y un negocio válido");
  }
  const bytes = await file.arrayBuffer();
  if (new TextDecoder().decode(bytes.slice(0, 5)) !== "%PDF-") {
    throw new HttpError(400, "INVALID_FICHA_PDF", "El archivo no parece ser un PDF");
  }
  const base = env.SUPABASE_URL.replace(/\/$/, "");
  const versionsResponse = await fetch(`${base}/rest/v1/business_ficha_versions?select=version&business_id=eq.${businessId}&order=version.desc&limit=1`, { headers });
  if (!versionsResponse.ok) throw new HttpError(502, "FICHA_VERSION_LOOKUP_FAILED", "No se pudo consultar la versión de Ficha");
  const versions = await versionsResponse.json();
  const path = `${businessId}/${(versions?.[0]?.version || 0) + 1}.pdf`;
  const upload = await fetch(`${base}/storage/v1/object/fichas/${path}`, {
    method: "POST", headers: { ...headers, "content-type": "application/pdf", "x-upsert": "false" }, body: bytes,
  });
  if (!upload.ok) throw new HttpError(502, "FICHA_UPLOAD_FAILED", "No se pudo guardar el PDF de la Ficha");
  return callRpc(request, env, "create_ficha_version", { p_business_id: businessId, p_document_path: path });
}

export async function fichaDownloadLink(request, env) {
  const { supabase, context } = await requireAuth(request, env);
  requireRole(context, ["ADMIN", "CAJA"]);
  const fichaId = new URL(request.url).searchParams.get("ficha_id");
  if (!fichaId) throw new HttpError(400, "MISSING_FIELD", "Falta ficha_id");
  const rows = await resourceJson(await supabase.rest(`business_ficha_versions?id=eq.${encodeURIComponent(fichaId)}&select=id,document_path,tlc_approved,client_approved&limit=1`), "Ficha Técnica");
  const ficha = rows[0];
  if (!ficha || !ficha.tlc_approved || !ficha.client_approved || !ficha.document_path) {
    throw new HttpError(403, "FICHA_NOT_APPROVED", "Solo se descarga una versión aprobada por ambas partes");
  }
  const base = env.SUPABASE_URL.replace(/\/$/, "");
  const response = await fetch(`${base}/storage/v1/object/sign/fichas/${ficha.document_path}`, {
    method: "POST", headers: { ...storageAdminHeaders(env), "content-type": "application/json" },
    body: JSON.stringify({ expiresIn: 60 }),
  });
  const data = await response.json().catch(() => ({}));
  const signed = data.signedURL || data.signedUrl;
  if (!response.ok || !signed) throw new HttpError(502, "FICHA_DOWNLOAD_FAILED", "No se pudo generar el enlace al PDF");
  return ok({ url: new URL(signed, base).toString() });
}

export async function openCut(request, env) {
  const body = await readJson(request);
  const args = {};
  if (body.operator_user_id !== undefined && body.operator_user_id !== null && body.operator_user_id !== "") {
    args.p_operator_user_id = body.operator_user_id;
  }
  return callRpc(request, env, "open_cut", args);
}

export async function executeCut(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "execute_cut", {
    p_cut_id: required(body, "cut_id"),
    p_totals: body.totals ?? {},
  });
}

export async function printDocument(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "get_print_document", {
    p_document_type: required(body, "document_type"),
    p_order_id: body.order_id ?? null,
    p_consumption_id: body.consumption_id ?? null,
    p_cut_id: body.cut_id ?? null,
    p_station_id: body.station_id ?? null,
  });
}

export async function setOrderNotificationPreference(request, env) {
  const body = await readJson(request);

  return callRpc(request, env, "set_order_notification_preference", {
    p_order_id: required(body, "order_id"),
    p_channel_code: required(body, "channel_code"),
    p_target: required(body, "target"),
    p_is_active: body.is_active ?? true,
  });
}
