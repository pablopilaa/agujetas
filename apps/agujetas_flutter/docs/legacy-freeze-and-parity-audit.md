# Agujetas Legacy Freeze And Functional Parity Audit

Fecha de auditoría: 2026-05-31  
Rama de trabajo: `codex/flutter-firebase-test`

Este documento fija el criterio de trabajo desde este punto: la app Expo / React Native de la raíz queda congelada como referencia funcional legacy, y la app nueva Flutter debe recuperar primero la funcionalidad real que ya existía antes de seguir agregando capas comerciales o visuales.

## Regla Principal

- No seguir parchando la app Expo legacy como producto principal.
- No borrar ni revertir archivos legacy sin instrucción explícita.
- Usar la legacy como fuente de comportamiento: leer, entender, portar.
- Todo trabajo nuevo de producto vive en `apps/agujetas_flutter`.
- Si una pantalla Flutter se ve bien pero no permite hacer lo que hacía Agujetas legacy, no se considera terminada.

## Estado Del Repo

La app nueva está en:

- `apps/agujetas_flutter/`

La app legacy sigue en la raíz:

- `App.tsx`
- `components/`
- `utils/`
- `assets/`
- `package.json`

Hay cambios locales sin commit en archivos legacy de raíz. Esos cambios no forman parte de los últimos commits Flutter y deben tratarse como worktree sucio externo hasta que se decida qué hacer con ellos.

## Fuente Legacy Observada

Archivos principales con comportamiento real:

- `App.tsx`
  - sesión activa
  - borrador de sesión en curso con `AsyncStorage`
  - timers
  - notificaciones Expo
  - alerta semanal de peso corporal
  - conexión de `TimerBar`, `SessionSelector`, `ExerciseList`, analytics
- `components/ExerciseList.tsx`
  - edición de ejercicios y series
  - grip dots para reorder
  - thumbnails por ejercicio
  - ejercicios personalizados
  - asignación de imágenes desde galería o biblioteca interna
  - minimizar/expandir ejercicios
  - historial/record previo
  - tipos de serie
  - unilateralidad
- `utils/storage.ts`
  - sesiones guardadas
  - rutinas
  - sesiones personalizadas
  - overrides por tipo de sesión
  - catálogo editable
  - imágenes asociadas a ejercicios
  - historial por ejercicio
  - índice histórico reconstruido desde sesiones
  - peso corporal
  - importación/normalización de datos históricos
- `utils/timerEngine.ts`
  - lógica separada de timer total y descanso

Archivos de usuario disponibles:

- `archivos_usuario/catalogo_ejercicios_2026-05-13.json`
- `archivos_usuario/historico_2025-12-31_a_2026-05-13.json`

## Estado Flutter Actual

Operativo o parcialmente operativo:

- Persistencia local-first base con `shared_preferences`.
- Restauración de sesión activa local al abrir la app.
- Guardado de historial local mínimo al finalizar sesión.
- Login con Google vía Firebase Auth.
- Demo sin guardar.
- Bottom navigation: Inicio, Entrenar, Progreso, Biblioteca, Perfil.
- Selector de modo de sesión: Fuerza, Hipertrofia, Técnica, Libre.
- Entrenar con tarjetas de ejercicios.
- Campos `Kg`, `Reps`, `RIR`.
- Series con `setType`: normal, calentamiento, dropset.
- Segundo peso/reps por serie mediante `segments`.
- Ejercicio unilateral/bilateral.
- Grip dots para reorder en Entrenar y Biblioteca.
- Miniaturas propias locales mediante `ExerciseImageResolver`.
- Detalle de ejercicio como bottom sheet.
- Calendario mensual como bottom sheet.
- Peso corporal básico.
- Notificaciones locales en estructura Flutter.
- Repositorios Firebase y demo.
- Build Android APK debug.
- GitHub Actions con analyze, test y APK debug.

No terminado:

- Paridad completa de sesión activa legacy.
- Persistencia local-first robusta para todos los módulos.
- Historial real por ejercicio en UI.
- Rutinas y sesiones personalizadas equivalentes a legacy.
- Calendario mensual con acceso real a entrenamientos previos.
- Importación completa de JSON de usuario al modelo Flutter.
- Analíticas por ejercicio equivalentes a `ExerciseAnalyticsSection`.
- Gestión completa de imágenes de calidad comercial.
- Trainer mode real con asignaciones detalladas.
- RevenueCat / suscripciones.
- Tests de reglas Firestore con emulator.
- iOS instalable.

## Matriz De Paridad Funcional

| Área | Legacy Expo | Flutter actual | Estado | Próxima acción |
| --- | --- | --- | --- | --- |
| Sesión activa | Existe sesión viva con ejercicios, timers y borrador `AsyncStorage` | Hay pantalla Entrenar y guardado Firestore/demo | Parcial | Implementar persistencia local de sesión activa y restauración |
| Guardado de sesión | `saveSession`, historial por ejercicio y sesiones listables | Guardado local mínimo + intento de sync Firestore | Parcial | Listar historial y reconstruir índice |
| Rutinas | CRUD de rutinas y sesiones personalizadas en storage | `saveRoutineTemplate` básico | Parcial bajo | Crear CRUD real de rutinas en Flutter |
| Calendario | Histórico mensual esperado por usuario | Bottom sheet visual con datos mock/parciales | Parcial bajo | Conectar calendario a sesiones reales |
| Ejercicios | Agregar, editar, custom, imágenes, alias, catálogo | Catálogo, custom básico, imagen local/repo | Parcial | Migrar edición avanzada y catálogo local-first |
| Series | kg/reps/RIR, tipos, comportamiento usado en sesión | kg/reps/RIR, tipos, segments | Bueno base | Persistir y mostrar historial por serie |
| Reorder | Grip dots manual en legacy | Grip dots en Flutter | Bueno base | Ajustar UX táctil en Android real |
| Timers | Timer total/rest con engine y notificaciones Expo | Timers Flutter y servicio local | Parcial | Validar background/lockscreen Android |
| Peso corporal | Storage, alerta semanal, historial | Card y stream básico | Parcial | Local-first + alertas configurables |
| Progreso | Analytics por ejercicio | Dashboard visual inicial | Parcial bajo | Rehacer con datos reales |
| Imágenes | Lyfta/galería/biblioteca app | Assets propios básicos | Insuficiente | Definir estrategia visual final |
| Auth | Uso personal sin login comercial | Google Auth + demo | Bueno base | Validar Android real con SHA |
| Pro/Trainer | No era foco legacy | UI/modelo básico | Conceptual | Postergar hasta paridad usuario normal |

## Orden De Trabajo Recomendado

### Fase 1: Recuperar App Personal Funcional

Objetivo: que la Flutter nueva sirva para entrenar como servía la app anterior.

1. Implementar persistencia local-first.
2. Restaurar sesión activa al reabrir app.
3. Guardar sesión local y mostrar historial.
4. Conectar calendario mensual a sesiones reales.
5. Reconstruir historial por ejercicio.
6. Mostrar record previo y progreso por ejercicio.
7. Migrar rutinas y sesiones personalizadas.
8. Importar JSON de usuario.

### Fase 2: Pulir UX De Entrenamiento

1. Ajustar layout de exercise cards en Android real.
2. Mejorar interacción de timers.
3. Validar grip dots en dispositivo táctil.
4. Reducir pasos para iniciar rutina.
5. Hacer que todas las tarjetas clicables tengan destino claro.

### Fase 3: Imágenes

1. Congelar assets vectoriales actuales como placeholders técnicos.
2. Definir estilo final.
3. Crear imágenes buenas para ejercicios usados en histórico.
4. Recién después cubrir catálogo completo.

### Fase 4: Sync, Comercial Y Trainer

1. Firestore sync opt-in o por login.
2. Reglas Firestore con emulator.
3. RevenueCat.
4. Plan Pro.
5. Trainer dashboard real.
6. Asignación de rutinas, schedules, tareas y metas.

## Decisión Técnica Recomendada

Para no depender de costos cloud ni de conexión, la nueva Agujetas debería ser:

- local-first para entrenamiento, historial, rutinas, catálogo custom y peso corporal;
- Firebase Auth para identidad;
- Firestore para sync/backup y funciones comerciales cuando el usuario inicia sesión;
- sin Firebase Storage en la primera versión;
- imágenes incluidas localmente o cacheadas por el usuario, no servidas desde Firebase Storage.

## Próximo Bloque Implementable

El próximo bloque concreto debe ser:

**Conectar historial local al calendario mensual y al progreso por ejercicio.**

Criterios de aceptación:

- El calendario mensual muestra días con sesiones reales guardadas.
- Tocar un día muestra las sesiones de ese día.
- Un ejercicio puede mostrar al menos su último registro previo.
- Progreso deja de depender de datos mock para volumen reciente.
- Todo funciona en demo sin Google y sin Firestore.

## Avance 2026-05-31

Primer bloque local-first implementado:

- `LocalWorkoutStore` guarda/restaura draft activo por usuario.
- `LocalWorkoutStore` guarda historial local mínimo.
- `HomeShell` restaura draft al iniciar y persiste cambios de entrenamiento.
- `TrainScreen` guarda primero local y luego intenta sincronizar con el repositorio.
- Tests unitarios cubren draft e historial local.

Pendiente inmediato:

- Reconstruir índice completo por ejercicio.
- Convertir la importación histórica en flujo visible/configurable antes de distribuir una build comercial.
- Agregar CRUD local-first completo para editar, borrar y reordenar rutinas importadas.

Segundo bloque local-first implementado:

- `HomeShell` carga sesiones locales del dispositivo y las distribuye a Entrenar, Progreso y Calendario.
- El calendario mensual deja de depender de datos demo: marca días con sesiones locales reales y permite abrir el detalle del día.
- La sección de entrenos recientes muestra sesiones guardadas localmente.
- Progreso calcula sesiones totales, racha, actividad semanal, volumen semanal, dropsets y mejores series a partir del historial local cuando existe.
- Las tarjetas de ejercicio en Entrenar muestran el último registro local disponible.
- El detalle de ejercicio muestra historial reciente real cuando existe, o estado vacío honesto cuando todavía no hay datos.
- Las notificaciones locales hacen no-op defensivo si el canal nativo no existe en tests, sin romper el guardado de sesión.

Tercer bloque local-first implementado:

- `LegacyHistoryImporter` lee `assets/user_data/historico_2025-12-31_a_2026-05-13.json` sin depender de `rootBundle.loadString`, para preservar UTF-8 y evitar cuelgues en tests con assets grandes.
- El histórico exportado se agrupa en sesiones locales: 354 filas pasan a 20 sesiones.
- Las filas con pesos tipo `25-15` se importan como `segments`, preservando el segundo peso/backoff sin inventar reps que no estaban en el CSV/JSON original.
- `LocalWorkoutStore.saveImportedSessions` deduplica por id estable para no duplicar sesiones al reabrir la app.
- En una instalación local sin historial previo, `HomeShell` importa el histórico incluido como asset y lo deja disponible para calendario, progreso y últimos registros por ejercicio.

Cuarto bloque local-first implementado:

- `LegacyHistoryImporter.loadBundledRoutines` lee el catálogo exportado legacy y recupera sesiones personalizadas como `RoutineTemplate`.
- Las rutinas legacy con referencias a sesiones custom se importan como plantillas compuestas, deduplicando ejercicios por nombre.
- `LocalWorkoutStore` persiste rutinas importadas con deduplicación por id estable.
- Home muestra “Rutinas importadas” y permite iniciar una rutina legacy.
- Biblioteca, en “Mis ejercicios”, muestra las rutinas legacy importadas y permite iniciar una plantilla desde ahí.
- Entrenar muestra el nombre de la rutina activa en el encabezado, en lugar de dejar fijo “Empuje A”.
