# Fase 1: auditoría del repositorio original

Se revisó la copia local de ffpsj-gestor-actas: todos los archivos de src, ambas migraciones SQL, configuración Vite y Electron, README y package.json. No se leyó el valor del archivo .env, porque puede contener una clave. También se comprobó que el README cita un .env.example que no existe.

| Web | Permiso | iPhone |
| --- | --- | --- |
| Acceso, registro, recuperación | público | AuthenticationView |
| Cuenta restringida | sesión inactiva | RestrictedAccessView |
| Resumen | usuario activo | DashboardView |
| Partidos | RLS | MatchListView |
| Crear y editar partidos | admin | AdminMatchEditor |
| Acta y detalle | admin o árbitro asignado | MatchDetailScreen |
| Equipos | lectura activa, escritura admin | TeamsView |
| Usuarios | admin | UsersView |
| Sistema | admin | SettingsView |

## Hallazgos de negocio

- Auth usa contraseña, alta y recuperación; un trigger crea perfil y usuario árbitro inactivo.
- Los únicos estados de partido son scheduled, in_progress, finished y cancelled. No existen descanso ni suspendido; iPhone no los inventa.
- El trigger de eventos recalcula los marcadores contando goles. La app no calcula un marcador propio.
- El acta incluye alineación, goles, amarillas, rojas, sustituciones, notas, observaciones y PDF.
- Audit logs registra equipos, jugadores, partidos, alineaciones, eventos y usuarios.

## Diferencias detectadas

La web no tiene instante de inicio persistente, idempotencia de eventos ni modelo completo de sustitución entrada/salida. La migración iOS es aditiva: introduce esos elementos sin romper columnas ni lecturas existentes.

## Identidad visual

Fuente de sistema con Inter como preferencia. Colores comprobados: azul #1769E0, azul marino #123B7C, tinta #192434 y fondo #F5F7FB. El logo es una F creada con CSS; no hay logotipos, escudos, tipografías ni imágenes propias en el repositorio. Si teams.logo_url existe, iPhone utiliza el escudo; si no, reproduce monograma y color institucional.
