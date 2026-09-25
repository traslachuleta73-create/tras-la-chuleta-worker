import { requireAuth } from "../auth.js";
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

export async function receivePreparedOrder(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "receive_prepared_order", {
    p_order_id: required(body, "order_id"),
  });
}

export async function markOrderReady(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "mark_order_ready", {
    p_order_id: required(body, "order_id"),
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
    `order_station_work?select=id,business_id,order_id,station_id,status,received_at,preparing_at,ready_at,station:stations(id,code,name,station_type),order:orders!inner(id,order_number,channel_code,status,note,created_at,consumption_id,items:order_items(id,product_id,station_id,quantity,unit_price,notes,ready_at,product:products(id,name)) )&status=in.(PENDING,RECEIVED,PREPARING,READY)${stationFilter}&order.status=in.(NEW,RECEIVED,PREPARING,READY_FOR_CASHIER,CASHIER_ASSEMBLING)&order=created_at.asc`,
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
    products: "products?select=id,name,price,is_available,is_active&is_active=eq.true&order=name.asc",
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
    "consumptions?select=id,consumption_number,status,opened_at,space_id,service_mode_id,space:spaces(name),service_mode:service_modes(name),orders:orders(id,order_number,channel_code,status,note,created_at,items:order_items(id,product_id,station_id,quantity,unit_price,notes,product:products(id,name),station:stations(id,code,name,station_type))),payments:payments(id,status,method_code,amount,created_at,confirmed_at)&status=in.(OPEN,PENDING_CLOSE)&order=opened_at.desc&limit=100",
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
