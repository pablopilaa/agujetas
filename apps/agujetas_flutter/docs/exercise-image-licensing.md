# Agujetas Exercise Images

## Regla De Origen

La app comercial no debe incluir, renderizar ni distribuir imágenes Lyfta. Los assets de ejercicios de Agujetas se consideran válidos sólo si cumplen estas condiciones:

- `source` es `agujetas-generated`.
- La imagen fue creada desde metadatos textuales propios: nombre del ejercicio, músculo, equipo, patrón de movimiento y notas internas.
- No se usó una imagen, screenshot, URL, miniatura o asset de Lyfta como base, referencia visual, prompt visual ni material derivado.
- La imagen tiene trazabilidad en `assets/exercise_images/agujetas-image-manifest.json`: `imageId`, prompt textual, versión, fecha y estado de revisión.

## Runtime

Flutter resuelve imágenes con `ExerciseImageResolver`.

- `agujetas-image://IMAGE_ID` puede resolver a un asset local propio.
- `app-image://...` se acepta sólo como pista de migración legacy y nunca resuelve a assets Lyfta.
- Si una imagen propia no aparece en el manifiesto, la UI cae a un placeholder local por grupo muscular.
- Cada resolución expone `reviewStatus` y `qualityLabel`; la UI muestra `Revisar`, `Prioridad` o `Sin asset` cuando la miniatura todavía no está aprobada.
- `ExerciseImageResolver.auditSummary()` devuelve conteos del manifiesto para medir cobertura y deuda de revisión sin inspeccionar el JSON a mano.
- Los ejercicios personalizados pueden asociarse a una imagen local del usuario o a un asset propio del repositorio Agujetas.

## Pipeline

El pipeline se ejecuta con:

```bash
node apps/agujetas_flutter/tool/generate_exercise_image_manifest.mjs
```

Entrada:

- `assets/user_data/catalogo_ejercicios_2026-05-13.json`

Salida incluida en la app:

- `assets/exercise_images/agujetas-image-manifest.json`
- `assets/exercise_images/thumbs/*.svg`
- `assets/exercise_images/placeholders/*.svg`

Esta primera versión genera line-art técnico programático para cubrir todo el catálogo offline. Los SVG son originales y livianos, pero la revisión humana sigue siendo obligatoria antes de tratar una imagen como asset final de marca.

## Revisión Humana

Estados recomendados:

- `priority`: ejercicios usados en histórico o sesiones custom, revisar primero.
- `pending`: generado, usable como MVP seguro, pendiente de QA visual.
- `approved`: listo para producción cuando ya haya revisión humana.
- `rejected`: no usar; regenerar o reemplazar.

La UI no debe presentar `pending` como arte final. En builds de test se puede mostrar, pero siempre con marca visible de revisión para que el usuario y el equipo no confundan cobertura técnica con calidad visual definitiva.

## Futuro Cloud

La primera versión no necesita Firebase Storage ni Blaze: las miniaturas se distribuyen localmente. Si el APK crece demasiado o se agregan masters pesados, mover sólo masters o variantes grandes a un CDN barato. Cloudflare R2 es candidato; Firebase Storage queda reservado para cuando aceptes Blaze.
