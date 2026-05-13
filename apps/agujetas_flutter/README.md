# Agujetas Flutter + Firebase

Nueva app comercial side-by-side. La app Expo previa queda como referencia legacy; el trabajo nuevo vive en `apps/agujetas_flutter`.

## Alcance actual

- Flutter Android/iOS/Web con Material 3, light/dark mode y logo SVG.
- Firebase project `agujetas`.
- Android package: `com.pablopilaa.Agujetas`.
- iOS bundle id: `com.pablopilaa.agujetas`.
- Login con Google mediante Firebase Auth.
- Roles:
  - `normal`: usuario autogestionado.
  - `trainer`: entrenador que tambien puede entrenar como usuario normal.
- Vinculacion entrenador-entrenado por codigo de invitacion.
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
- `sessions`

Las reglas estan en `firebase/firestore.rules`. Criterio:

- Cada usuario lee/escribe sus datos.
- Un entrenador solo accede a un entrenado si existe `trainerClientLinks/{trainerId}_{clientId}` con `status: active`.
- Catalogos publicos solo lectura: `publicExerciseCatalog`, `exerciseMediaIndex`, `appConfig`.
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
flutter build apk --debug
```

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
- Ejecutar tests de reglas con Firebase Emulator Suite.
- Crear pantallas reales de asignacion detallada de tareas/schedules/metas.
- Definir terminos, privacidad, consentimiento de datos y flujo de borrado de cuenta.
- Cuando exista Apple Developer: agregar workflow macOS firmado y TestFlight.
