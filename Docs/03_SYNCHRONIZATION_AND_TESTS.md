# Fases 7 a 9: sincronización y pruebas

Flujo: intención del árbitro, validación local de ayuda, RPC y RLS de Supabase, evento más marcador más auditoría en transacción, lectura oficial completa y después SwiftUI más Live Activity.

Cada evento tiene client_request_id. Antes de enviar o reintentar se consulta si el servidor ya lo registró. Ante timeout o pérdida de red sólo se guarda la intención pendiente: no cambia acta, marcador ni isla. Tras reconectar se consulta al servidor antes de cualquier reintento.

Realtime no aplica deltas locales. Cuando detecta cambio de partido o alineación vuelve a descargar el acta bajo RLS. Así un cambio desde la web se refleja en iPhone.

| Escenario | Resultado esperado |
| --- | --- |
| Gol iPhone | evento confirmado, trigger de marcador, acta e isla coinciden |
| Tarjeta | aparece sólo tras confirmación |
| Doble toque o timeout | un único evento por identificador |
| Sin conexión | pendiente explícito, no oficial |
| Cambio web | Realtime y relectura actualizan iPhone |
| Cierre y reapertura | carga estado oficial y no duplica marcador |
| Finalización | RPC cierra acta e isla conserva resultado final temporalmente |
| Falla ActivityKit | estado oficial intacto y reintento sólo visual |

Las pruebas de dominio cubren permiso, estados, sustitución, idempotencia y tiempo persistido. Auth, RLS, RPC, Realtime y ActivityKit requieren proyecto de pruebas y un iPhone físico.
