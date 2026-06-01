# Agujetas legal consent contract

Estado: borrador técnico para test interno. No es asesoría legal.

Fecha vigente del contrato técnico: 1 de junio de 2026.

## Objetivo

Este documento define qué consentimiento debe aceptar un usuario autenticado antes de usar la versión comercial de Agujetas. La app lo implementa local-first en `LocalPrivacyConsent` y lo bloquea desde `PrivacyConsentGate`.

La demo sin guardado no exige este gate para mantener la preview rápida y evitar simular aceptación legal real.

## Versiones actuales

| Bloque | Versión |
| --- | --- |
| Esquema de consentimiento | `2` |
| Términos | `terms-2026-06-01-preview` |
| Privacidad | `privacy-2026-06-01-preview` |
| Sincronización/datos | `data-2026-06-01-preview` |
| Notificaciones | `notifications-2026-06-01-preview` |

Si cambia cualquier versión, `LocalPrivacyConsent.isCurrent` debe devolver `false` y la app debe volver a mostrar el gate.

## Requisitos aceptados por el usuario

1. Términos y política de privacidad.
   - Agujetas registra y planifica entrenamiento.
   - No reemplaza criterio médico ni profesional.
   - Sesiones, rutinas, peso corporal y ejercicios propios pertenecen a la cuenta del usuario.

2. Sincronización con Firebase.
   - Firebase Auth identifica la cuenta.
   - Firestore guarda datos propios cuando la sincronización está activa.
   - Firebase Storage no forma parte del plan gratuito actual.
   - Exportar, importar y borrar datos son requisitos de producción.

3. Imágenes locales.
   - La galería sólo se solicita cuando el usuario quiere asociar una imagen a un ejercicio personalizado.
   - Agujetas no debe incluir ni renderizar assets comerciales de Lyfta en builds comerciales.
   - Cualquier subida cloud futura requiere consentimiento específico.

4. Notificaciones.
   - Los avisos de descanso o peso se piden al activar esas funciones.
   - Pueden sonar o mostrarse en segundo plano si el sistema operativo lo permite.
   - Deben poder desactivarse desde Perfil y desde ajustes del sistema.

## Reglas para IA y desarrolladores

- No eliminar el gate para usuarios reales.
- No tratar la demo como consentimiento legal.
- No guardar consentimiento sin acción explícita del usuario.
- No aceptar parcialmente: los cuatro bloques deben estar confirmados.
- No cambiar textos sustanciales sin subir versión.
- No considerar listo para producción hasta reemplazar este borrador por textos revisados legalmente.
- No subir imágenes de usuario a cloud sin consentimiento nuevo y versión nueva.
- No usar Lyfta como fuente visual, base, prompt visual ni fallback comercial.

## Evidencia esperada

- Unit tests de `LocalPrivacyConsent` prueban persistencia, versiones vigentes y consentimiento viejo inválido.
- Widget tests prueban que el usuario autenticado queda bloqueado hasta aceptar.
- `clearAllLocalData` borra también el consentimiento local.
- El escaneo de mojibake no debe encontrar caracteres corruptos en Flutter/docs/tests.
