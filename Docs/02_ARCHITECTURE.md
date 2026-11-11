# Fases 2 a 6: arquitectura e implementación

FFPSJApp contiene SwiftUI, sesión, navegación, PDF y ActivityKit. FFPSJData contiene Supabase Auth, PostgREST, Realtime y pendientes. FFPSJDomain contiene modelos, reglas, repositorios, deep links y atributos. FFPSJLiveActivity contiene WidgetKit y Dynamic Island, sólo como representación.

Las vistas no escriben tablas. El contenedor valida, espera confirmación, vuelve a leer el acta oficial y después actualiza SwiftUI y Live Activity.

La migración iOS añade:

1. started_at y finished_at;
2. jugador entrante e identificador de solicitud de evento;
3. RPC para inicio, final, evento, alineación y observaciones;
4. bloqueo de fila y verificación de can_manage_match;
5. transacciones que conservan evento, trigger de marcador y auditoría;
6. publicación necesaria para Realtime.

No se eliminan las policies directas de la web. Para endurecer todo el sistema, primero hay que actualizar la SPA para usar los mismos RPC y sólo entonces retirar escrituras directas.
