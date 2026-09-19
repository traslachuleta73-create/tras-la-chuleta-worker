# TRAS LA CHULETA — Worker/API V1

Esqueleto inicial del Worker nuevo. No reutiliza el Worker V51.

## Principios
- Supabase Auth/JWT como identidad operativa.
- El Worker valida autenticación y contexto de usuario.
- BUSINESS es el límite de aislamiento.
- Supabase/RLS y RPC son la autoridad de datos y operaciones críticas.
- No se usa `SUPABASE_SERVICE_ROLE_KEY` en esta versión.
- No hay escrituras directas a tablas operativas.
- Las operaciones críticas llaman RPC autorizadas.

## Secrets requeridos
Configurar con Wrangler Secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Nunca guardar secretos en Git.

## Desarrollo

```bash
npm install
npm run check
npm run dev
```

## Estado
Este paquete es solamente el esqueleto y middleware de autenticación/contexto. Las rutas operativas se incorporarán por fases después de probar el perímetro de seguridad.


## Presencia de negocio / WhatsApp

Se agregó `GET /api/business/me` para consultar la identidad del BUSINESS y sus canales habilitados.
El endpoint deja explícitamente el username de WhatsApp como `NOT_CONFIGURED` hasta que el CORE defina su persistencia y reglas.

No se reutiliza `business.slug` como username de WhatsApp.
Ver `docs/whatsapp-username.md`.
