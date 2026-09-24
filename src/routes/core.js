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
    p_space_id: required(body, "space_id"),
    p_service_mode_id: required(body, "service_mode_id"),
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
  return callRpc(request, env, "receive_order", {
    p_order_id: required(body, "order_id"),
  });
}

export async function startPreparation(request, env) {
  const body = await readJson(request);
  return callRpc(request, env, "start_order_preparation", {
    p_order_id: required(body, "order_id"),
  });
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
