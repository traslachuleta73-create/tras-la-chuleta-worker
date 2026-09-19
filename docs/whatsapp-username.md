# WhatsApp username — integración preparada

## Decisión

El nombre de usuario de WhatsApp (`@usuario`) se considera **identidad de presencia del BUSINESS dentro del canal WHATSAPP**.

No es:
- un usuario operativo del sistema;
- un sustituto del `business_id`;
- un teléfono;
- un rol;
- un canal de pedidos independiente.

## Estado actual

El CORE actual ya contempla `WHATSAPP` como canal mediante `business_channels`.
El esquema actual **no tiene todavía un campo persistente para el username de WhatsApp**. Por eso esta versión del Worker no inventa ni reutiliza `slug` como username.

`GET /api/business/me` devuelve actualmente:
- identidad básica del BUSINESS;
- canales habilitados;
- estado del canal WhatsApp;
- `username: null` y `usernameStatus: NOT_CONFIGURED` mientras no exista una decisión/migración de datos para almacenarlo.

## Próximo cambio controlado

Antes de persistir el username debe definirse formalmente en el CORE:
1. campo y tabla/estructura de configuración;
2. unicidad del username;
3. validación de formato;
4. estado de reserva/activo si aplica;
5. quién puede modificarlo;
6. auditoría del cambio;
7. exposición pública mediante URL/QR.

No se implementa ninguna de estas reglas por suposición en esta versión.
