# Fases 10 y 11: xtool e instalación

Se revisó la documentación oficial de xtool el 27-10-2026. Usa SwiftPM, xtool.yml, productos library y extensiones declaradas. El flujo publicado es xtool setup y xtool dev.

El equipo actual no tiene WSL, Swift ni xtool. No se afirma compilación, firma o instalación local.

La configuración entregada declara app principal FFPSJApp, extensión FFPSJLiveActivity, Info plist con Live Activities y esquema ffpsj, entitlements vacíos y dependencia SPM supabase-swift.

La extensión requiere validación física: hay incidencias recientes en xtool relativas a firmado y binarios de extensiones. No se debe eliminar la extensión para obtener una compilación aparente. Tras xtool dev inspecciona el paquete y verifica que contiene la extensión y el Info plist de Live Activities.

Los accesos de la isla son enlaces profundos, no App Intents de escritura. Esto respeta formularios y confirmaciones. App Intents futuros requieren metadata válido en app y extensión, además de prueba real en iPhone.
