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
- Completar editor profundo de rutinas para modificar ejercicios, series y defaults dentro de cada plantilla.

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

Quinto bloque local-first implementado:

- `RoutineTemplate.copyWith` permite editar plantillas sin reconstruir manualmente el modelo.
- `LocalWorkoutStore` preserva el orden de rutinas guardadas y agrega operaciones locales para guardar, borrar y reemplazar plantillas.
- Biblioteca permite guardar la rutina base actual como plantilla local.
- Biblioteca permite renombrar, duplicar, borrar y subir/bajar rutinas importadas o guardadas localmente.
- Las rutinas se mantienen offline y no dependen de Firestore para operar en modo demo.
- Tests unitarios cubren guardado, renombrado, reordenamiento y borrado local de rutinas.

Sexto bloque local-first implementado:

- Biblioteca permite abrir una rutina importada o guardada en un editor local.
- El editor carga los ejercicios de la plantilla, habilita cambios de orden y permite agregar ejercicios desde el catálogo.
- La plantilla en edición puede guardarse sobre el mismo `RoutineTemplate` o guardarse como copia.
- La rutina editada puede iniciarse directamente desde Biblioteca sin pasar por Firestore.
- Tests de widget cubren que una rutina importada entra al editor local y expone acciones de guardado.

Séptimo bloque local-first implementado:

- El editor de rutinas usa una lista propia separada de la sesión activa.
- Abrir una rutina para editar ya no reemplaza el entrenamiento actual ni persiste un draft de sesión.
- Agregar o reordenar ejercicios dentro de una plantilla en edición afecta sólo al editor hasta guardar o iniciar esa rutina.
- Tests de widget cubren que cargar una rutina en el editor no cambia la sesión activa `Empuje A`.

Octavo bloque local-first implementado:

- Biblioteca permite tocar un ejercicio dentro de una rutina en edición y abrir una hoja de defaults.
- Esa hoja edita unilateralidad, `setType`, `kg`, `reps`, `RIR` y segundo peso/backoff por serie usando el mismo modelo que Entrenar.
- Se pueden agregar series predeterminadas a la plantilla sin iniciar ni modificar la sesión activa.
- Tests de widget cubren la apertura del editor de defaults y la incorporación de una cuarta serie antes de guardar.

Noveno bloque local-first implementado:

- `LocalWorkoutStore` persiste historial de peso corporal por usuario en `shared_preferences`.
- `HomeShell` carga esos registros al iniciar y actualiza Progreso sin depender de Firestore ni del repositorio demo.
- `BodyWeightCard` guarda primero localmente y deja el sync con Firebase como intento secundario.
- La UI mantiene la alerta diaria de peso corporal y muestra el último peso local más el delta contra el registro anterior.
- Tests unitarios y de widget cubren persistencia local y guardado desde la tarjeta de peso corporal.

Decimo bloque local-first implementado:

- `LocalWorkoutStore` persiste ejercicios personalizados por usuario en `shared_preferences`.
- `HomeShell` carga esos ejercicios al iniciar y los entrega a Biblioteca sin depender del stream de Firestore.
- Biblioteca muestra `Tus ejercicios` desde estado local, incluso en demo/offline.
- El modal de nuevo ejercicio guarda local-first, conserva 3 series por defecto y permite imagen de galeria o asset interno propio.
- El sync a Firebase queda como intento secundario best-effort cuando hay backend disponible.
- Tests unitarios y de widget cubren persistencia local y creacion de ejercicio personalizado.

Onceavo bloque local-first implementado:

- Los ejercicios personalizados locales pueden editarse sin cambiar su `id`, preservando historial futuro y referencias.
- Los ejercicios personalizados locales pueden borrarse del dispositivo sin borrar sesiones historicas donde ya fueron usados.
- La pestaña `Mis ejercicios` filtra `Tus ejercicios` con la misma busqueda de Biblioteca.
- El modal `CustomExerciseSheet` soporta modo crear y modo editar, con campos precargados e imagen asociada preservada.
- Tests cubren edicion/borrado en `LocalWorkoutStore` y edicion desde la hoja de ejercicio personalizado.

Doceavo bloque local-first implementado:

- Entrenar expone opciones por ejercicio y permite editar ejercicios personalizados ya agregados a la sesion activa.
- La edicion desde Entrenar reutiliza `CustomExerciseSheet`, guarda primero el catalogo custom local y despues actualiza la instancia activa.
- La accion no aparece en ejercicios del catalogo base, evitando editar por accidente datos importados/legacy.
- Tests de widget cubren crear un ejercicio personalizado, agregarlo a la sesion, editarlo desde Entrenar y ver el cambio en la tarjeta activa.

Decimotercer bloque local-first implementado:

- Entrenar permite quitar ejercicios de la sesion activa con confirmacion.
- Biblioteca permite quitar ejercicios del orden de rutina local con confirmacion.
- En ambos casos la accion no borra historial guardado ni elimina el ejercicio del catalogo.
- Tests de widget cubren el flujo de quitar desde Entrenar y desde Biblioteca.

Decimocuarto bloque local-first implementado:

- El calendario mensual ya no queda fijo al mes actual: permite navegar mes anterior, mes siguiente y volver a hoy.
- El resumen del calendario muestra sesiones, duración y volumen acumulado del mes visible.
- La lista de sesiones del mes permite abrir cada entrenamiento guardado.
- El detalle de sesión histórica muestra ejercicios, miniatura local, unilateralidad, series registradas, tipo de serie, pesos/reps por segmento y RIR.
- Esto acerca la paridad con el calendario mensual heredado de Agujetas legacy sin depender de Firestore ni cloud.
- Tests de widget cubren navegación de meses y apertura de detalle histórico completo.

Decimoquinto bloque local-first implementado:

- El detalle de sesión histórica permite repetir una sesión guardada cargándola como entrenamiento activo.
- Si la sesión legacy trae un modo que no existe en el selector actual, se carga como `Libre` para no romper el dropdown, conservando el nombre histórico en el título de rutina activa.
- El detalle de sesión histórica permite guardar esa sesión como una rutina local reutilizable.
- La rutina creada desde historial queda persistida en `shared_preferences` junto con las demás plantillas offline.
- Tests de widget cubren repetir una sesión histórica y guardarla como rutina local visible desde Biblioteca.

Decimosexto bloque local-first implementado:

- La ficha de ejercicio ahora puede leer todo el historial local del ejercicio, no solo el último registro.
- El detalle muestra cantidad de registros, mejor peso, mejor volumen y registros recientes con fecha y sesión.
- Desde Entrenar, la ficha permite aplicar el último registro como defaults del ejercicio activo, copiando series, kg, reps, RIR, tipo de serie y segmentos.
- Biblioteca y catálogo también pasan historial local a la ficha para consulta, sin depender de Firestore.
- Tests de widget cubren que el detalle muestra historial y que `Usar último` actualiza los defaults del ejercicio activo.

Decimoséptimo bloque local-first implementado:

- `LocalWorkoutSession` ahora soporta `title` y `note` opcionales con lectura backwards-compatible.
- `LocalWorkoutStore` puede actualizar metadata de una sesión local y borrar una sesión guardada del dispositivo.
- El detalle de sesión histórica permite editar nombre/nota y borrar la sesión con confirmación.
- El calendario actualiza su estado local después de editar o borrar sin depender de Firestore.
- Tests unitarios cubren editar/borrar sesiones en el store; tests de widget cubren el flujo desde calendario.

Decimoctavo bloque local-first implementado:

- `LocalWorkoutStore` exporta un respaldo JSON versionado con sesiones, rutinas, peso corporal y ejercicios personalizados.
- `LocalWorkoutStore` importa ese respaldo y normaliza la pertenencia al usuario/dispositivo que lo restaura.
- La importación fusiona por `id` para no pisar datos locales no relacionados y mantiene la app operativa sin Firestore ni Storage.
- Perfil expone acciones visibles para exportar el JSON, copiarlo y pegar un respaldo para restaurarlo.
- Tests unitarios cubren export/import y rechazo de JSON ajeno a Agujetas; tests de widget cubren el flujo visible desde Perfil.

Decimonoveno bloque local-first implementado:

- Perfil expone una acción explícita para reimportar los JSON legacy incluidos de Agujetas 1.x.
- La acción lee histórico y rutinas legacy, guarda sólo sesiones/rutinas faltantes y deja la operación como idempotente.
- `HomeShell` refresca calendario, progreso y biblioteca después de esa importación manual sin depender de Firestore.
- El usuario ya no depende sólo de la autoimportación silenciosa de instalaciones limpias para recuperar datos legacy.
- Tests de widget cubren el flujo visible con confirmación y resumen de sesiones/rutinas importadas.

Vigésimo bloque local-first implementado:

- `ActiveWorkoutDraft` ahora persiste `totalElapsed`, `restRemaining`, `totalRunning` y `restRunning` con lectura backwards-compatible.
- Al restaurar una sesión activa, si un reloj estaba corriendo se compensa el tiempo transcurrido desde el último guardado.
- `TrainScreen` reporta cambios de timers a `HomeShell`, que guarda el draft local junto con modo y ejercicios.
- Cambiar modo, iniciar rutina, repetir sesión histórica o finalizar entrenamiento reinicia también el estado local de timers.
- Tests unitarios cubren persistencia/restauración de timers; tests de widget cubren que Entrenar muestra los relojes restaurados.

Vigésimo primer bloque local-first implementado:

- El resolver de imágenes propias normaliza correctamente caracteres acentuados reales de español, incluyendo mayúsculas con tilde y diéresis.
- La búsqueda de miniaturas ya no depende de claves mal codificadas ni de texto mojibake para mapear nombres del catálogo.
- Se mantiene bloqueado `app-image://` legacy para no renderizar assets Lyfta en builds comerciales.
- Test unitario cubre que un nombre con tilde como `Jalón lateral alternativo` resuelve contra el asset local propio `ag_jalon_lateral_alternativo...`.

Vigésimo segundo bloque local-first implementado:

- Perfil deja de mostrar toggles de permisos meramente visuales: `Alertas de descanso`, `Seguimiento de peso` y `Galería local` ahora se guardan por usuario en `SharedPreferences`.
- `HomeShell` carga esas preferencias al iniciar y las vuelve a persistir cada vez que el usuario cambia un switch.
- El diseño sigue offline-first y no requiere Firestore, Storage ni RevenueCat para conservar estas decisiones del usuario.
- Tests unitarios cubren persistencia por usuario; tests de widget cubren que el switch de galería emite y refleja la preferencia actual.

Vigésimo tercer bloque local-first implementado:

- `Eliminar cuenta` en Perfil deja de ser una acción vacía y ahora abre una confirmación explícita.
- La confirmación borra del dispositivo sesiones, rutinas, peso corporal, ejercicios personalizados, preferencias y entrenamiento activo del usuario actual, y luego cierra sesión.
- En ese momento el texto evitaba prometer borrado remoto; desde el trigésimo octavo bloque ya existe limpieza cliente de documentos Firestore conocidos y eliminación de Firebase Auth cuando no exige reautenticación.
- Tests unitarios cubren limpieza local por usuario sin afectar otros usuarios; tests de widget cubren el diálogo y la acción confirmada.

Vigésimo cuarto bloque local-first implementado:

- La preferencia `Alertas de descanso` deja de ser sólo persistencia visual y ahora controla el comportamiento de Entrenar.
- El botón rápido de descanso siempre inicia el countdown local de 90 segundos, pero sólo programa una notificación nativa si la preferencia está activa.
- Si el usuario desactivó alertas, la app muestra un mensaje explícito: el descanso corre sin aviso y puede reactivarse desde Perfil.
- Test de widget cubre desactivar la preferencia desde Perfil, ir a Entrenar y arrancar descanso sin alerta.

Vigésimo quinto bloque local-first implementado:

- La preferencia `Galería local` deja de ser sólo persistencia visual y ahora controla el selector de imagen del dispositivo para ejercicios personalizados.
- Entrenar y Biblioteca pasan la preferencia vigente al flujo de creación/edición de ejercicios, manteniendo una sola fuente de verdad en Perfil.
- Si la galería local está desactivada, el botón sigue visible pero muestra un mensaje explícito para activarla desde Perfil en vez de abrir el picker nativo.
- La asociación con imágenes propias del repositorio interno sigue disponible aunque la galería local esté apagada.
- Test de widget cubre que el sheet de ejercicio personalizado respeta la preferencia y bloquea el acceso a galería con feedback visible.

Vigésimo sexto bloque local-first implementado:

- La preferencia `Seguimiento de peso` ahora controla el recordatorio diario de peso corporal en Progreso.
- Registrar peso corporal sigue funcionando offline aunque la alerta esté apagada; lo bloqueado es sólo la programación de notificaciones.
- Si el usuario intenta activar el recordatorio con la preferencia apagada, la app muestra un mensaje explícito para habilitarlo desde Perfil.
- El botón de recordatorio cambia a icono de candado cuando la preferencia está desactivada, manteniendo el affordance visible sin disparar permisos nativos.
- Test de widget cubre que el recordatorio respeta la preferencia y no intenta programarse cuando está apagado.

Vigésimo séptimo bloque local-first implementado:

- Los chips de Biblioteca dejan de ser decorativos y ahora filtran el catálogo y los ejercicios personalizados.
- `Grupo muscular` abre un selector real alimentado por catálogo local y ejercicios propios.
- `Equipamiento` filtra por heurísticas de nombre mientras no exista un campo estructurado en el catálogo.
- `Usados` filtra por `usageCount`, preservando el modo offline y sin depender de Firestore.
- El buscador permite limpiar filtros activos desde el icono de filtro apagado.
- Test de widget cubre filtros por grupo muscular, equipamiento y usados en ejercicios personalizados.

Vigésimo octavo bloque local-first implementado:

- El detalle de ejercicio incorpora una vista accionable de `Ver progreso`, alineada con el diseño Stitch de detalle.
- La vista usa historial local por ejercicio y muestra última serie, cambio de volumen, promedio reciente, mejor peso, mejor volumen y evolución en barras.
- El historial completo del ejercicio queda visible desde esa vista sin depender de Firestore ni de gráficos ubicados en configuración.
- La acción conserva `Usar último` para aplicar defaults desde el registro más reciente al entrenamiento activo.
- Test de widget cubre abrir detalle, entrar a progreso por ejercicio, ver métricas/tendencia y volver para aplicar el último registro.

Vigésimo noveno bloque Android test implementado:

- El manifest Android declara permisos de notificación, vibración, reinicio, alarma exacta opcional y lectura de imágenes para galería local en Android moderno y legacy.
- Se eliminó `USE_EXACT_ALARM` para evitar una categoría de permiso más restrictiva que no corresponde a una app fitness comercial común.
- `NotificationService.initialize()` deja de pedir permisos al abrir la app; las notificaciones se solicitan sólo cuando el usuario programa una alerta.
- Las alertas de descanso y peso intentan alarma exacta y caen a `inexactAllowWhileIdle` si Android deniega exact alarms, sin romper el entrenamiento ni el guardado local.
- Los snackbars distinguen alerta exacta, alerta inexacta, permiso denegado o disponibilidad nativa ausente.

Trigésimo bloque Biblioteca implementado:

- Biblioteca permite crear una rutina nueva con nombre propio como borrador local, sin depender de rutinas legacy ni de la rutina activa.
- Una rutina nueva puede alternar entre Mis ejercicios y Catálogo para agregar ejercicios antes de guardarse.
- El guardado de rutina editada bloquea plantillas vacías y pide al menos un ejercicio, evitando guardar rutinas inútiles.
- El módulo de edición muestra un botón explícito `Guardar cambios` además de las acciones de copia, entrenamiento y agregar desde catálogo.
- Si el catálogo JSON grande todavía no cargó, la pantalla muestra ejercicios semilla como fallback temporal para no quedar vacía.
- Test de widget cubre crear borrador de rutina, pasar al catálogo y agregar un ejercicio.

Trigésimo primer bloque Progreso implementado:

- La pantalla Progreso elimina barras fijas: volumen efectivo y dropsets ahora usan proporciones calculadas desde sesiones locales o desde la sesión activa como vista previa.
- El volumen semanal compara contra la semana previa cuando existe historial local comparable.
- El gráfico de volumen deja de etiquetar siempre `Press banca`; muestra `Historial local` y el ejercicio dominante por volumen de la semana.
- La tarjeta de dropsets muestra `N de M series efectivas` en vez de una barra estática.
- Test de widget cubre volumen semanal, comparación contra semana previa, ejercicio dominante, volumen efectivo y dropsets desde sesiones locales.

Trigésimo segundo bloque Peso corporal implementado:

- La tarjeta de peso corporal muestra último peso, promedio reciente, delta contra el registro anterior e historial local reciente.
- El cálculo ordena los registros por fecha, por lo que funciona aunque el store entregue entradas desordenadas.
- La tendencia de 30 días se muestra como cambio acumulado entre el último registro y el más antiguo de la ventana reciente.
- El registro de peso sigue siendo local-first y la alerta diaria sigue respetando la preferencia de Perfil.
- Test de widget cubre tendencia, promedio e historial local de peso.

Trigésimo tercer bloque Encoding implementado:

- Se agregó un test de CI que recorre archivos de texto del proyecto Flutter y exige UTF-8 válido.
- El mismo test falla si detecta marcadores típicos de mojibake o el carácter de reemplazo Unicode.
- Esto protege textos en español latinoamericano con tildes reales dentro de `lib`, `test`, `docs` y archivos de configuración.

Trigésimo cuarto bloque Pro/Entitlements implementado:

- `AppPlan` ahora expone entitlements comerciales explícitos: modo entrenador, gestión de entrenados y rutinas compartidas.
- Un usuario Free puede conservar metadata histórica de rol entrenador, pero la app no lo deja activar ese modo sin entitlement Pro.
- Perfil suma la tarjeta `Plan y suscripción` y `Ver planes` abre un sheet real con Agujetas Free y Agujetas Pro.
- La build demo permite activar Pro demo desde ese sheet para probar el panel entrenador sin cobrar ni conectar RevenueCat todavía.
- Tests de modelo cubren entitlements Free/Pro; tests de widget cubren el sheet de planes y la activación Pro demo.

Trigésimo quinto bloque Firestore seguridad implementado:

- Las reglas de Firestore ahora exigen `plan == pro` y rol `trainer` en `users/{uid}` para crear/editar perfil de entrenador o invitaciones.
- El acceso cruzado entrenador-entrenado sigue atado a `trainerClientLinks/{trainerId}_{clientId}` con `status: active`, pero ahora también exige entitlement Pro del entrenador.
- Se agregó un test de contrato que inspecciona `firebase/firestore.rules` desde la suite Flutter para evitar que el gate Pro/Trainer se remueva sin romper CI.

Trigésimo sexto bloque Anti-escalada Pro implementado:

- `users/{uid}` ya no permite que el cliente cambie `plan` ni `roles`; esas propiedades quedan reservadas para backend/admin.
- La creación inicial de usuario queda limitada a `plan: free`, rol `normal` y `activeRole: normal`.
- Cambiar `activeRole` a entrenador sólo es válido si el usuario ya tiene entitlement Pro en Firestore.
- `FirebaseAgujetasRepository.setActiveRole` dejó de escribir `roles`; sólo actualiza `activeRole` y `updatedAt`.
- El test de contrato de reglas ahora cubre que no se pueda escalar de Free a Pro desde el cliente.

Trigésimo séptimo bloque Limpieza y ownership implementado:

- Las reglas permiten borrar perfil, invitaciones y vínculos de entrenador como operación de limpieza/privacidad aunque el usuario haya perdido Pro.
- Crear o editar perfil/invitaciones sigue exigiendo `plan == pro` y rol `trainer`, por lo que la limpieza no reabre el uso comercial del modo entrenador.
- `trainerClientLinks` separa `update` y `delete`; el borrado ya no depende de `request.resource`, que no corresponde al contrato mental de una eliminación.
- `FirebaseAgujetasRepository.saveRoutineTemplate` normaliza `ownerId` contra el usuario autenticado antes de escribir en Firestore, evitando escrituras rechazadas o ownership accidentalmente incorrecto.
- El test de contrato de reglas cubre cleanup sin Pro y separación explícita de update/delete.

Trigésimo octavo bloque Borrado de cuenta remoto implementado:

- `AgujetasRepository` incorpora `deleteAccount(AppUser user)` como contrato explícito para borrar una cuenta, en vez de limitar Perfil a limpiar datos locales.
- El repositorio Firebase reautentica con Google antes de borrar documentos conocidos del usuario en `sessions`, `routineTemplates`, `customExercises`, `bodyWeights`, `assignedRoutines`, `tasks`, `schedules`, `goals`, `trainerProfiles`, `trainerInvites`, `trainerClientLinks` y `users/{uid}`.
- Después de la limpieza Firestore conocida, elimina Firebase Auth; si Google/Firebase no permite reautenticar, la UI muestra un mensaje específico y no avanza con el borrado remoto.
- El modo demo también implementa `deleteAccount`, limpiando streams locales y cerrando la sesión demo.
- El diálogo de Perfil deja de prometer sólo borrado local y comunica el alcance real: dispositivo, Firestore conocido y Firebase Auth.
- Queda pendiente para producción una Cloud Function/admin cleanup para subcolecciones futuras no listables desde cliente.

Trigésimo noveno bloque Reautenticación segura de borrado implementado:

- `FirebaseAgujetasRepository.deleteAccount` ahora reautentica con Google antes de borrar Firestore, evitando que un `requires-recent-login` deje documentos remotos parcialmente eliminados con Auth todavía activo.
- En web usa el provider de Google desde Firebase Auth; en Android/iOS vuelve a autenticar con `google_sign_in` y valida que el `uid` reautenticado coincida con la cuenta actual.
- El diálogo de Perfil avisa que el flujo puede pedir volver a ingresar con Google antes de proceder.
- El test de widget conserva la cobertura del caso de reautenticación requerida y valida el nuevo texto preventivo.

Cuadragésimo bloque Cobertura de cleanup remoto implementado:

- El borrado remoto de cuenta usa un mapa explícito de colecciones raíz y campos de ownership, evitando que `sessions` quede cubierto sólo por `ownerId`.
- `sessions`, `routineTemplates`, `assignedRoutines`, `tasks`, `schedules` y `goals` se limpian por `ownerId`, `clientId` y `assignedClientId` cuando esos campos existen.
- El cleanup cliente borra subcolecciones conocidas bajo `/users/{uid}` antes de borrar el documento `users/{uid}`: sesiones, rutinas, plantillas, peso, ejercicios propios, historial, borradores, exports, consentimientos, dispositivos y preferencias.
- Se agregó un test de contrato de repositorio para que futuras ediciones no reduzcan sin querer la cobertura de campos ni el orden subcolecciones-antes-documento.
- Sigue pendiente una Cloud Function/admin cleanup para subcolecciones futuras o rutas nuevas que no estén en este contrato cliente.

Cuadragésimo primer bloque Consentimiento implementado:

- Se agregó un gate post-login de privacidad y datos antes de entrar a Home para usuarios reales.
- El consentimiento exige aceptar términos/política de privacidad, sincronización Firebase, uso de galería local y notificaciones antes de operar la app comercial.
- El consentimiento se guarda local-first por usuario en `SharedPreferences` con versión de esquema y se borra junto con `clearAllLocalData`.
- La demo conserva navegación directa para no romper la experiencia de preview sin guardado.
- Tests unitarios cubren persistencia/limpieza del consentimiento y tests de widget cubren que Home queda bloqueado hasta aceptar.
- Queda pendiente reemplazar estos textos internos por términos y política de privacidad legales finales antes de producción.

Cuadragésimo segundo bloque Contrato de consentimiento versionado:

- Se agregó `legal_contract.dart` como fuente técnica única de versiones vigentes: términos, privacidad, datos y notificaciones.
- `LocalPrivacyConsent.isCurrent` ya no depende sólo de booleans; también exige que las versiones aceptadas coincidan con el contrato actual.
- Un consentimiento viejo, sin versión o con términos anteriores vuelve a bloquear `HomeShell` y fuerza reaceptación.
- `docs/legal-consent-contract.md` documenta las reglas para humanos e IA: no bypass para usuarios reales, no aceptación parcial, no cloud de imágenes sin consentimiento nuevo y no Lyfta en builds comerciales.
- Tests unitarios y widget tests verifican versión vigente, consentimiento viejo inválido y bloqueo post-login.
