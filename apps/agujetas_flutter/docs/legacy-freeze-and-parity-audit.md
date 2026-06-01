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

- `LocalWorkoutStore` exporta un respaldo JSON versionado con sesiones, rutinas, peso corporal, ejercicios personalizados y favoritos.
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

Cuadragésimo tercer bloque Preferencias Firebase-ready:

- `LocalUserPreferences` ahora incluye `preferredTheme` además de permisos de descanso, peso y galería local.
- `HomeShell` carga preferencias local-first, aplica el tema guardado y luego intenta traer la versión remota desde Firebase.
- `FirebaseAgujetasRepository` guarda preferencias en `/users/{uid}/preferences/app` y espeja `preferredTheme` en `users/{uid}` bajo campos ya permitidos por reglas.
- Si Firebase falla, la app mantiene preferencias locales y muestra aviso sin bloquear entrenamiento.
- La demo implementa el mismo contrato en memoria para que preview y tests sigan funcionando.

Cuadragésimo cuarto bloque Peso corporal bidireccional:

- `HomeShell` carga peso corporal local inmediatamente y, para usuarios reales, activa sync Firestore en segundo plano.
- Los registros locales recientes se suben best-effort a `bodyWeights` sin bloquear la UI.
- `watchBodyWeights` escucha snapshots remotos del usuario y los fusiona localmente por `id`, normalizando `userId` y preservando registros offline no sincronizados.
- `LocalWorkoutStore.mergeBodyWeightsLocal` agrega el contrato reutilizable de merge local-first que luego puede repetirse para otros dominios.
- Tests cubren merge local/remoto, ownership Firestore de `bodyWeights` y que el flujo siga pasando con 77 tests.

Cuadragésimo quinto bloque Ejercicios personalizados bidireccionales:

- `HomeShell` carga ejercicios personalizados locales inmediatamente y activa sync Firestore para usuarios reales.
- Los ejercicios locales se suben best-effort a `customExercises` con `ownerId` del usuario autenticado.
- `watchCustomExercises` escucha snapshots remotos por `ownerId` y los fusiona localmente por `id`, preservando imágenes locales permitidas o `agujetas-image://...`.
- El borrado de un ejercicio personalizado ahora intenta eliminar también el documento remoto para evitar que reaparezca desde Firestore.
- `LocalWorkoutStore.mergeCustomExercisesLocal` agrega el contrato reutilizable de merge local-first para catálogo propio.

Cuadragésimo sexto bloque Rutinas bidireccionales:

- `AgujetasRepository` ahora expone `watchRoutineTemplates` y `deleteRoutineTemplate`, completando el contrato remoto de CRUD de plantillas.
- `HomeShell` carga rutinas locales inmediatamente, sube plantillas locales best-effort a Firestore y escucha snapshots remotos para usuarios reales.
- `watchRoutineTemplates` consulta `routineTemplates` por `ownerId`; cada documento remoto se normaliza con el id del documento para evitar ownership implícito incorrecto.
- `LocalWorkoutStore.mergeRoutineTemplatesLocal` fusiona por `id`, actualiza cambios remotos y conserva plantillas offline no sincronizadas.
- El borrado de una rutina local intenta eliminar también el documento remoto para que no reaparezca desde Firestore.
- El orden local se preserva durante merges; desde el sexagésimo cuarto bloque se modela `orderIndex` remoto para replicar reorder entre dispositivos.

Cuadragésimo séptimo bloque Sesiones bidireccionales:

- `AgujetasRepository.saveSession` dejó de usar `add()` y ahora escribe `sessions/{session.id}` para que el id local sea el id remoto estable.
- `AgujetasRepository` expone `watchSessions` y `deleteSession`, completando el contrato remoto de historial.
- `HomeShell` carga historial local inmediatamente, sube sesiones recientes best-effort a Firestore y escucha snapshots remotos para usuarios reales.
- Editar o borrar una sesión histórica desde calendario actualiza primero el dispositivo y luego intenta sincronizar el cambio remoto.
- `LocalWorkoutStore.mergeSessionsLocal` fusiona por `id`, normaliza `userId`, conserva historial offline no sincronizado y evita renderizar sesiones remotas sin ejercicios.
- Importar backup local o datos legacy refresca la UI y empuja sesiones locales best-effort si el usuario está autenticado.
- Queda pendiente definir política de conflictos más fina para edición simultánea de título/nota entre dos dispositivos offline.

Cuadragésimo octavo bloque Asignación inicial entrenador-entrenado:

- Se agregó el modelo `AssignedRoutine` como contrato de asignación de rutina desde entrenador hacia entrenado.
- `AgujetasRepository` expone `assignRoutineToClient` y `watchAssignedRoutinesForClient`.
- Firebase escribe asignaciones en `assignedRoutines/{id}` con `trainerId`, `ownerId`, `clientId`, `assignedClientId`, snapshot de ejercicios y estado `assigned`.
- El panel entrenador muestra un botón `Asignar` por entrenado activo y crea una asignación usando una rutina existente.
- El usuario normal tiene una sección `Rutinas asignadas` que lee `assignedRoutines` por `assignedClientId`.
- Este bloque vuelve real la primera parte de “compartir rutinas”; tareas, schedules y metas todavía quedan para los siguientes bloques usando el mismo patrón.

Cuadragésimo noveno bloque Tareas entrenador-entrenado:

- Se agregó el modelo `AssignedTask` como contrato de tarea puntual enviada por entrenador.
- `AgujetasRepository` expone `assignTaskToClient` y `watchAssignedTasksForClient`.
- Firebase escribe tareas en `tasks/{id}` con `trainerId`, `ownerId`, `clientId`, `assignedClientId`, estado `pending`, descripción y vencimiento opcional.
- El panel entrenador muestra `Enviar tarea` por entrenado activo y crea una tarea de control de peso semanal.
- El usuario normal tiene una sección `Tareas del entrenador` que lee `tasks` por `assignedClientId`.
- Quedan pendientes edición de tareas, marcar completada, comentarios de seguimiento y schedules/metas con calendario.

Quincuagésimo bloque Schedules entrenador-entrenado:

- Se agregó el modelo `AssignedSchedule` como contrato de sesión planificada por entrenador.
- `AgujetasRepository` expone `assignScheduleToClient` y `watchAssignedSchedulesForClient`.
- Firebase escribe schedules en `schedules/{id}` con `trainerId`, `ownerId`, `clientId`, `assignedClientId`, fecha `scheduledFor`, nota y rutina opcional.
- El panel entrenador muestra `Agendar` por entrenado activo y crea una sesión planificada.
- El usuario normal tiene una sección `Schedules asignados` y el calendario mensual recibe esos schedules por `assignedClientId`.
- El calendario mensual ahora marca días con schedules, lista los schedules del mes y abre detalle con nota y rutina sugerida.
- Desde el sexagésimo sexto bloque el calendario marca schedules planificados que ya tienen una sesión local registrada ese mismo día. Queda pendiente eventual push remoto si se necesita servidor.

Quincuagésimo primer bloque Metas entrenador-entrenado:

- Se agregó el modelo `AssignedGoal` como contrato de meta medible asignada por entrenador.
- `AgujetasRepository` expone `assignGoalToClient` y `watchAssignedGoalsForClient`.
- Firebase escribe metas en `goals/{id}` con `trainerId`, `ownerId`, `clientId`, `assignedClientId`, métrica, valor objetivo, progreso actual, unidad y vencimiento opcional.
- El panel entrenador muestra `Meta` por entrenado activo y crea una meta de volumen semanal.
- El usuario normal tiene una sección `Metas del entrenador` con porcentaje y barra de progreso.
- Quedan pendientes edición de progreso, cierre de meta, metas derivadas automáticamente del historial y notificaciones por desvíos.

Quincuagésimo segundo bloque Acciones del entrenado sobre asignaciones:

- `AgujetasRepository` expone updates para tareas, schedules y metas asignadas: `updateAssignedTaskStatus`, `updateAssignedScheduleStatus` y `updateAssignedGoalProgress`.
- Firebase actualiza `tasks/{id}`, `schedules/{id}` y `goals/{id}` solo si el documento pertenece al usuario vinculado o a su entrenador activo según reglas existentes.
- La demo actualiza sus listas en memoria y emite streams para que preview/tests no dependan de Firestore.
- El usuario normal puede tocar `Completar` en una tarea, `Cancelar` en un schedule y `+25%` en una meta.
- Quedan pendientes edición fina: comentarios de entrega, reprogramación de schedule, input manual de progreso de meta y auditoría de cambios por entrenador.

Quincuagésimo tercer bloque Acciones detalladas y calendario de schedules:

- Las tareas asignadas ya no se completan desde un botón rápido: abren una hoja de revisión con descripción, vencimiento y acción explícita.
- Los schedules asignados abren una hoja de gestión con estado, nota, cancelación y reprogramación mediante selector de fecha/hora.
- `updateAssignedScheduleStatus` acepta `scheduledFor` opcional para persistir reprogramaciones en Firestore/demo sin crear documentos duplicados.
- Las metas asignadas reemplazan el avance fijo `+25%` por un diálogo de carga manual del valor actual y completan la meta si alcanza el objetivo.
- El calendario mensual diferencia schedules planificados, completados y cancelados con chips/resumen de estado y marcas de color por día.
- Quedan pendientes comentarios/evidencia de entrega por tarea, auditoría visible para entrenador y recordatorios locales de schedules planificados.

Quincuagésimo cuarto bloque Seguimiento visible para entrenador:

- `AssignedTask` guarda `completionNote` y `completedAt`, y `updateAssignedTaskStatus` persiste el comentario de cierre en Firestore/demo.
- La hoja de tarea del entrenado permite escribir un comentario para el entrenador antes de marcarla como completada.
- Cada entrenado activo en el panel entrenador muestra un bloque `Seguimiento` con tareas completas, schedules activos y avance de metas usando los streams existentes por `assignedClientId`.
- El entrenador puede ver el último comentario de una tarea completada sin salir del panel principal.
- Quedan pendientes adjuntos reales de evidencia, historial cronológico/auditoría de cambios y respuestas del entrenador sobre cada tarea.

Quincuagésimo quinto bloque Auditoría cronológica de asignaciones:

- Se agregó `AssignmentEvent` como contrato de auditoría para rutinas, tareas, schedules y metas asignadas.
- Firestore/demo crean eventos en `assignmentEvents` cuando el entrenador asigna rutina/tarea/schedule/meta y cuando el entrenado completa, cancela, reprograma o actualiza progreso.
- `AgujetasRepository.watchAssignmentEventsForClient` expone el timeline por `assignedClientId`, ordenado de más reciente a más antiguo.
- Las reglas Firestore permiten leer/escribir `assignmentEvents` con el mismo criterio de vínculo activo usado en asignaciones.
- El usuario normal ve una tarjeta `Actividad de asignaciones`; el panel entrenador muestra el último cambio dentro de `Seguimiento`.
- Quedan pendientes respuestas del entrenador por evento, adjuntos/evidencia real y una pantalla completa de auditoría filtrable.

Quincuagésimo sexto bloque Timeline filtrable de asignaciones:

- `Actividad de asignaciones` ahora abre una hoja completa con filtros por `Todo`, `Rutinas`, `Tareas`, `Schedules` y `Metas`.
- El panel entrenador agrega `Ver historial` por entrenado activo y abre el mismo timeline filtrable scoped al `assignedClientId`.
- La hoja muestra conteo filtrado, actor, fecha/hora, tipo de asignación y resumen del evento.
- Tests de widget cubren enviar tarea, abrir historial del entrenado y filtrar por tareas.
- Quedan pendientes pantalla full-route si el timeline crece, respuestas del entrenador por evento y adjuntos/evidencia.

Quincuagésimo séptimo bloque Comentarios en asignaciones:

- `AgujetasRepository` expone `addAssignmentComment` para guardar feedback textual sobre cualquier evento de rutina, tarea, schedule o meta.
- Firebase/demo reutilizan `assignmentEvents` con `action = commented`, `actorRole` y `summary`, evitando Storage y costos cloud.
- La hoja completa del timeline agrega `Comentar` por evento, abre un formulario con límite de 500 caracteres y refleja el comentario como nuevo evento cronológico.
- El flujo funciona tanto para entrenador como para entrenado siempre que el usuario pertenezca al vínculo de asignación.
- Tests de widget cubren enviar tarea, abrir historial, comentar y ver el nuevo evento comentado.
- Quedan pendientes adjuntos/evidencia real y una pantalla full-route si el historial crece demasiado para un bottom sheet.

Quincuagésimo octavo bloque Evidencia liviana sin Storage:

- `AssignmentEvent` agrega `evidenceUri` opcional para guardar un link o referencia externa junto al comentario.
- `addAssignmentComment` acepta comentario textual, evidencia o ambos; si ambos están vacíos no crea evento.
- La hoja de comentario incluye `Evidencia opcional` con límite de 300 caracteres y aclara que no sube archivos.
- El timeline muestra un botón de evidencia cuando existe `evidenceUri` y permite copiar la referencia al portapapeles.
- Esta estrategia evita Firebase Storage/Blaze y sirve para MVP o test interno; no reemplaza un flujo definitivo de subida segura de archivos.
- Quedan pendientes permisos nativos de galería para evidencia real, expiración de links externos y política de retención/borrado de archivos si luego se usa R2, Storage u otro bucket.

Quincuagésimo noveno bloque Auditoría visual de imágenes de ejercicios:

- `ExerciseImageResolver` expone `reviewStatus`, `qualityLabel`, `needsReview` y `auditSummary` además del asset local resuelto.
- La normalización de nombres se reemplazó por un mapa UTF-8 explícito sin mojibake para que búsquedas con tildes como `Jalón` sigan resolviendo contra el manifest.
- `ExerciseImageBadge` muestra una marca pequeña `Revisar`, `Prioridad` o `Sin asset` cuando el asset todavía no está aprobado o cuando cae a placeholder.
- Los tests validan que el manifest tiene más de 2.000 entradas, que la deuda de revisión sigue visible y que el badge no oculta el estado de calidad.
- Este bloque no mejora la calidad artística de los SVG generados; evita que la app trate esos thumbnails básicos como definitivos.
- Queda pendiente definir el pipeline real de arte final: generación/ilustración por lotes, revisión humana, reemplazo de rechazados, y eventualmente masters fuera del APK si pesan demasiado.

Sexagésimo bloque Auditoría interna de imágenes en Perfil:

- Perfil suma la acción `Auditoría de imágenes` dentro de Privacidad y datos.
- La acción abre un sheet con conteos reales del manifest: assets propios, prioridad, pendientes, placeholders y porcentaje revisado/aprobado.
- `ExerciseImageResolver.auditEntries()` expone muestras limitadas por `reviewStatus` para revisar prioridad y pendientes sin abrir el JSON.
- Este bloque no aprueba ni mejora el arte; hace visible la deuda para poder decidir lotes de reemplazo visual con criterio.

Sexagésimo primer bloque Favoritos reales en Biblioteca:

- La estrella del catálogo deja de ser no-op y marca/quita favoritos persistidos localmente por usuario.
- El chip `Favoritos` deja de significar “usados” y pasa a filtrar sólo ejercicios favoritos reales.
- El mismo filtro aplica a ejercicios personalizados; sus opciones permiten agregarlos o quitarlos de favoritos.
- La preferencia local se borra al eliminar cuenta desde Perfil y no depende de Firestore.

Sexagésimo segundo bloque Favoritos en backup local:

- El respaldo local sube a `schemaVersion: 2` e incluye `favoriteExerciseIds`.
- Importar un respaldo fusiona favoritos entrantes con favoritos existentes del usuario destino.
- El resultado de importación y el texto de Perfil ahora contabilizan favoritos junto a sesiones, rutinas, peso corporal y ejercicios propios.

Sexagésimo tercer bloque Seguridad de cuenta accionable:

- La fila `Cuenta Google verificada` en Perfil deja de ser no-op.
- Ahora abre un sheet con email, nombre visible, UID copiable, plan, rol activo, estado de sincronización y permisos comerciales.
- El sheet diferencia demo local de sesión autenticada para no prometer sync remoto en `demo-user`.

Sexagésimo cuarto bloque Orden remoto de rutinas:

- `RoutineTemplate` incorpora `orderIndex` serializable para Firestore y backups locales.
- El store local normaliza índices al guardar, duplicar, borrar o reordenar rutinas.
- El merge remoto respeta `orderIndex` entrante y el watcher Firebase devuelve rutinas ordenadas, cerrando la brecha de reorder multi-dispositivo.

Sexagésimo quinto bloque Recordatorios locales de schedules:

- `LocalUserPreferences` suma `scheduleAlertsEnabled`, persistido local-first y Firebase-ready junto al resto de preferencias.
- Perfil expone el toggle `Recordatorios de agenda`.
- `HomeShell` programa recordatorios locales para schedules futuros activos, cancela los que vencen o dejan de estar activos y respeta el toggle sin usar Firebase Storage ni servicios pagos.
- `NotificationService` agrega IDs estables por schedule y un canal local `assigned_schedules` con fallback exacto/inexacto.

Sexagésimo sexto bloque Cobertura visual de schedules:

- El calendario mensual detecta schedules `scheduled` con una sesión local registrada el mismo día.
- Esos schedules se muestran como `con sesión registrada` en resumen mensual, lista, detalle y color del día.
- El detalle del schedule muestra la sesión local que lo cubre sin cambiar el estado remoto, evitando marcar como completado algo que todavía no fue confirmado contra Firestore.

Sexagésimo séptimo bloque Alertas automáticas de peso:

- El toggle `Seguimiento de peso` en Perfil ahora programa o cancela automáticamente el recordatorio local diario de peso a las 09:00.
- `NotificationService` agrega cancelación explícita del recordatorio de peso para respetar el opt-out del usuario.
- La tarjeta `Peso corporal` marca si el seguimiento semanal está al día o si el último registro ya quedó vencido.
- El usuario sigue pudiendo forzar la programación desde la tarjeta, pero el flujo principal ya no depende de ese botón manual.

Sexagésimo octavo bloque Corrección de peso corporal:

- El historial reciente de `Peso corporal` ahora muestra acciones para editar o eliminar registros cargados.
- Editar conserva el mismo `id`, permite corregir fecha, kg y nota, y sincroniza el mismo documento remoto si hay sesión Google.
- Borrar elimina local-first y luego intenta borrar `bodyWeights/{id}` en Firestore para usuarios autenticados.
- `LocalWorkoutStore` suma `deleteBodyWeightLocal`; `AgujetasRepository` suma `deleteBodyWeight` con implementación Firebase y demo.

Sexagésimo noveno bloque Editor de rutinas:

- El editor de Biblioteca ahora permite renombrar el borrador de rutina activo antes de guardarlo.
- La edición de título actualiza el estado local del borrador y se usa al guardar, copiar o iniciar esa rutina desde el editor.
- Esto reduce una brecha de paridad del CRUD de rutinas: el usuario no queda obligado a guardar primero y volver a la lista para corregir el nombre.

Septuagésimo bloque Descarte de edición de rutina:

- El editor de Biblioteca ahora permite descartar explícitamente el borrador activo.
- La acción pide confirmación, cierra el editor, limpia ejercicios/título del borrador y no toca la sesión activa ni las rutinas ya guardadas.
- Esto evita que el usuario quede atrapado en modo edición después de abrir una plantilla o crear una rutina nueva.
