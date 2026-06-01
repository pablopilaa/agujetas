# Agujetas Flutter + Firebase

Nueva app comercial side-by-side. La app Expo previa queda como referencia legacy; el trabajo nuevo vive en `apps/agujetas_flutter`.

## Regla de migracion

La app Expo/React Native de la raiz del repo queda congelada como referencia funcional. No es la base de nuevos parches de producto. Para avanzar, leer la legacy, portar comportamiento y verificar paridad en Flutter.

Contrato de migracion: `docs/legacy-freeze-and-parity-audit.md`.

## Alcance actual

- Flutter Android/iOS/Web con Material 3, light/dark mode y logo SVG.
- Firebase project `agujetas`.
- Android package: `com.pablopilaa.Agujetas`.
- iOS bundle id: `com.pablopilaa.agujetas`.
- Login con Google mediante Firebase Auth.
- Consentimiento post-login local-first y versionado para términos, privacidad, sincronización Firebase, galería local y notificaciones antes de entrar a la app comercial. Contrato técnico documentado en `docs/legal-consent-contract.md`.
- Preferencias de perfil sincronizadas local-first y Firebase-ready: tema, alertas de descanso, seguimiento de peso, recordatorios de agenda y galería local se guardan en el dispositivo y en `/users/{uid}/preferences/app` para usuarios autenticados.
- Persistencia local-first base con `shared_preferences` para borrador de sesion activa e historial local minimo.
- Calendario mensual navegable, progreso y tarjetas de entrenamiento conectados al historial local guardado en el dispositivo, con detalle de sesión, series, segmentos y RIR.
- El historial local permite repetir una sesión guardada como entrenamiento activo o guardarla como rutina local reutilizable.
- Sesiones/historial con sincronizacion bidireccional local-first + Firestore: carga local inmediata, push best-effort, merge de snapshots remotos por `ownerId` y eliminacion remota por ownership.
- La ficha de ejercicio muestra historial local profundo, mejores marcas y permite aplicar el último registro como defaults en Entrenar.
- El historial local permite editar nombre/nota de una sesión guardada y borrar sesiones locales con confirmación.
- Perfil permite exportar/importar un respaldo JSON local con sesiones, rutinas, peso corporal, ejercicios personalizados y favoritos.
- Perfil permite reimportar manualmente los datos legacy incluidos de Agujetas 1.x, con deduplicación local.
- Perfil muestra un sheet de seguridad de cuenta con email, UID copiable, plan, rol, permisos comerciales y estado de sincronización.
- Perfil permite eliminar cuenta con reautenticación Google, borrado local, limpieza de documentos remotos conocidos, subcolecciones conocidas de `users/{uid}` y eliminación de Firebase Auth.
- El borrador de sesión activa persiste y restaura relojes de tiempo total/descanso, incluyendo timers que estaban corriendo.
- Seguimiento de peso corporal local-first con estado semanal visible, edición de fecha/kg/nota, borrado de registros, recordatorio diario automático al activar el toggle de Perfil y sync best-effort si hay backend disponible.
- Recordatorios locales para schedules asignados: la app programa alertas de agenda en el dispositivo, cancela schedules vencidos/cancelados y respeta el toggle de Perfil.
- Calendario mensual marca schedules planificados con sesión local el mismo día como `con sesión registrada`, sin mutar el estado remoto.
- Peso corporal con sincronización bidireccional local-first + Firestore: carga local inmediata, push best-effort de registros locales recientes y merge de snapshots remotos sin borrar entradas locales no sincronizadas.
- Importacion local del historico exportado desde la app Expo legacy incluido en `assets/user_data`.
- Importacion local de rutinas y sesiones personalizadas legacy desde `assets/user_data/catalogo_ejercicios_2026-05-13.json`.
- CRUD local-first basico de rutinas: guardar, renombrar/descartar borrador activo, renombrar plantillas, duplicar, borrar y reordenar sin depender de Firestore.
- Rutinas con sincronizacion bidireccional local-first + Firestore: carga local inmediata, push best-effort, merge de snapshots remotos por `ownerId`, orden remoto por `orderIndex` y eliminacion remota por ownership.
- Editor local aislado de rutinas: abrir una plantilla importada, modificar su lista de ejercicios/orden/defaults de series, guardar cambios o guardar una copia sin tocar la sesion activa.
- Ejercicios personalizados local-first: crear, editar, borrar, buscar, asociar imagen de galeria o asset interno propio, operar offline y sincronizar best-effort si hay backend disponible.
- Imágenes de ejercicios locales con resolver seguro: `app-image://` legacy queda bloqueado, `agujetas-image://` resuelve contra manifest propio, y la UI marca assets generados pendientes de revisión para no confundirlos con arte final.
- Perfil incluye una auditoría interna de imágenes para ver cobertura del manifest, prioridad de revisión, pendientes y placeholders sin inspeccionar JSON a mano.
- Ejercicios personalizados con sincronización bidireccional local-first + Firestore: carga local inmediata, push best-effort, merge de snapshots remotos y eliminación remota por ownership.
- Entrenamiento permite editar ejercicios personalizados ya agregados a la sesion, manteniendo el catalogo local sincronizado.
- Entrenar y Biblioteca permiten quitar ejercicios de la sesion/rutina local con confirmacion, sin borrar historial ni catalogo.
- Biblioteca permite marcar ejercicios del catálogo o personalizados como favoritos local-first y filtrar por favoritos reales.
- Roles:
  - `normal`: usuario autogestionado.
  - `trainer`: entrenador que tambien puede entrenar como usuario normal.
- Vinculacion entrenador-entrenado por codigo de invitacion.
- Modo entrenador Pro con primera asignacion real de rutinas, tareas, schedules y metas: el entrenador puede asignar una plantilla existente a un entrenado vinculado, enviar una tarea puntual, agendar una sesion, asignar una meta medible y revisar seguimiento por entrenado desde `assignedRoutines`, `tasks`, `schedules` y `goals`.
- El usuario normal puede accionar asignaciones recibidas desde flujos detallados: completar tareas con comentario para el entrenador, cancelar o reprogramar schedules y actualizar progreso de metas con valor manual persistido en Firestore/demo.
- Timeline de asignaciones filtrable por rutinas, tareas, schedules y metas para usuario normal y entrenador, con comentarios textuales y referencia/link de evidencia por evento sin depender de Storage.
- Series con:
  - `setType`: `normal`, `warmup`, `dropset`.
  - `segments`: pesos/reps multiples, por ejemplo `20 kg x 8 + 10 kg x 6`.
  - `isUnilateral` por ejercicio.
- Reorder con dot grip handle en Entrenar y Biblioteca.
- Sin Firebase Storage para mantener el proyecto en Spark/free.

## Estructura Firestore

Colecciones principales:

- `users`
- `trainerProfiles`
- `trainerInvites`
- `trainerClientLinks`
- `routineTemplates`
- `assignedRoutines`
- `tasks`
- `schedules`
- `goals`
- `assignmentEvents`
- `sessions`

Las reglas estan en `firebase/firestore.rules`. Criterio:

- Cada usuario lee/escribe sus datos.
- Un entrenador solo accede a un entrenado si existe `trainerClientLinks/{trainerId}_{clientId}` con `status: active`.
- Crear perfiles e invitaciones de entrenador requiere `plan == pro` y rol `trainer` en `users/{uid}`.
- El cliente no puede autoasignarse `plan` ni `roles`; Pro queda reservado para backend/admin/RevenueCat.
- El borrado de perfil/invitaciones/vínculos de entrenador permite limpieza de privacidad aunque el usuario pierda Pro; crear/editar sigue bloqueado por entitlement.
- Catalogos publicos solo lectura: `publicExerciseCatalog`, `exerciseMediaIndex`, `appConfig`.
- Los eventos de asignaciones se guardan en `assignmentEvents` con `trainerId`, `assignedClientId`, `targetType`, `targetId`, `action`, `actorRole`, resumen legible y `evidenceUri` opcional; los comentarios usan `action = commented`.
- Escritura admin solo con custom claim `admin == true`.

## Desarrollo local

Desde este directorio:

```powershell
$env:PATH='C:\Users\Pila\tools\flutter\bin;'+$env:PATH
$env:GIT_SSL_NO_VERIFY='true'
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Preview estatica despues de `flutter build web`:

```powershell
node scripts/preview-server.mjs build/web 53627
```

Android:

```powershell
$env:JAVA_TOOL_OPTIONS='-Djavax.net.ssl.trustStoreType=Windows-ROOT'
flutter build apk --debug
```

El `JAVA_TOOL_OPTIONS` anterior es necesario en este equipo Windows si Gradle falla descargando dependencias Maven con `PKIX path building failed`. No se deja fijo en `gradle.properties` para no afectar CI/Linux.

iOS queda source-ready, pero un build instalable/TestFlight requiere macOS, Xcode y Apple Developer Program.

## GitHub Actions

Workflow: `.github/workflows/flutter-test-build.yml`.

Hace:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- sube `agujetas-debug-apk` como artifact

Para APK release firmado, configurar estos secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Despues de firmar, registrar el SHA-1/SHA-256 del keystore en Firebase Authentication para Google Sign-In Android.

## Pendientes antes de test masivo

- Instalar Android command-line tools localmente si el equipo no tiene `sdkmanager`.
- Convertir importaciones legacy en flujo visible/configurable antes de publicar una build comercial.
- Mejorar ergonomia del editor profundo de rutinas y peso corporal en Android real: gestos, foco de campos y acciones mas visibles.
- Ejecutar tests de reglas con Firebase Emulator Suite.
- Expandir historial/auditoria con respuestas del entrenador y adjuntos reales de evidencia.
- Reemplazar el contrato técnico preliminar de consentimiento por términos y política de privacidad finales con asesoría legal antes de producción.
- Crear Cloud Function/admin cleanup para subcolecciones futuras no listables desde cliente.
- Definir política de conflictos de sesiones si dos dispositivos editan la misma nota/título offline antes de sincronizar.
- Mejorar el contrato de orden remoto de rutinas si se quiere que el reorder se replique 1:1 entre dispositivos.
- Cuando exista Apple Developer: agregar workflow macOS firmado y TestFlight.
