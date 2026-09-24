# Acuerdos operativos confirmados

Este registro complementa las fuentes maestras y debe incorporarse a ellas en su siguiente edición. No reemplaza `REGLAS_CORE.md`, la Matriz Maestra ni la Arquitectura.

Fecha: 2026-09-24

## Cortes de caja

- ADMIN puede abrir, ejecutar/cerrar y consultar/imprimir cortes.
- CAJA puede consultar e imprimir cortes; no puede abrir ni ejecutar/cerrar cortes.
- Cocina, Barra y Mesero no pueden consultar cortes ni sus discrepancias financieras.
- El total del corte se calcula únicamente con pagos CONFIRMED del periodo del corte.
- Consumos CANCELLED no se suman al corte. Una cancelación no es un pago.

## Apertura de consumos

ADMIN, CAJA y MESERO pueden abrir un consumo. Los identificadores de espacio y modalidad se permiten nulos cuando la modalidad del negocio no requiera alguno.

## Cierre y cancelación de consumos

- Flujo pagado: `OPEN → PENDING_CLOSE → CLOSED`.
- `PENDING_CLOSE` indica que se solicitó la cuenta. El pago se puede crear y confirmar en ese estado.
- Solo un pago CONFIRMED habilita el cierre del consumo.
- ADMIN o CAJA pueden cerrar un consumo con pago confirmado.
- ADMIN puede cancelar un consumo OPEN o PENDING_CLOSE, siempre con motivo y auditoría.
- No se puede cancelar un consumo con pago confirmado. Los intentos de pago aún PENDING se cancelan junto con el consumo.
- `CANCELLED` es un estado terminal separado de `CLOSED`; no representa cobro y no entra en el corte.
- ADMIN, CAJA y MESERO pueden solicitar el paso a `PENDING_CLOSE`. La autorización del cierre financiero y la confirmación del pago siguen limitadas a ADMIN/CAJA.

## Preparación y entrega de pedidos

- CAJA registra el pedido y el sistema genera/enruta las partidas a Cocina o Barra.
- Cada estación marca listas sus partidas.
- El pedido global pasa a `READY` solo cuando todas sus partidas están listas.
- Entrega al cliente es una acción distinta de marcar `READY`.

## Autorización y auditoría

- Cancelaciones y modificaciones requieren un actor con permiso explícito; el solicitante no puede ejecutar una operación para la que su rol no está autorizado.
- Las cancelaciones requieren motivo y registro de auditoría. Las modificaciones que reemplazan un pedido también requieren motivo y auditoría.

## Registro visual de formas de pago

- Las únicas formas que se seleccionan en el CORE son `CASH` (Efectivo), `CARD` (Tarjeta) y `TRANSFER` (Transferencia).
- La selección identifica el medio declarado por el negocio; no es una integración con el proveedor ni una validación automática del movimiento.
- ADMIN o CAJA registran la confirmación manualmente después de que el negocio verifica la recepción por su propio medio (efectivo recibido, terminal aprobada o fondos observados en su canal de transferencia).
- El CORE guarda método, monto, estado, usuario que confirma y fecha/hora. No procesa pagos, verifica liquidaciones, genera QR o enlaces, custodia fondos ni atiende disputas con proveedores.
- Cada negocio elige y opera sus terminales, bancos, aplicaciones o canales externos y es responsable de comprobar sus cobros.
- Códigos de métodos anteriores quedan deshabilitados para nuevos cobros y su historial no se reescribe.
- Integraciones o generación de QR/enlaces serían un alcance futuro separado, no parte de este CORE actual.
