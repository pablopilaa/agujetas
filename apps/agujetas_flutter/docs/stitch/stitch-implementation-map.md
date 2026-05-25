# Stitch Implementation Map

Proyecto Stitch: https://stitch.withgoogle.com/projects/4994259168654281792

Este archivo define qué diseños de Stitch son fuente de verdad para la app Flutter. El objetivo no es embeber HTML de Stitch dentro de Flutter, sino traducir sus decisiones visuales a widgets nativos: jerarquía, espaciado, color, estados, navegación y contenido.

## Pantallas Canónicas

| Flujo | Stitch screen | Screen ID | Referencia local | Flutter |
| --- | --- | --- | --- | --- |
| Login | Agujetas - Login Light (Final Branding) | `faeb5e97dc724af286fef8edb8b5d768` | `login-light-final.html/.png` | `LoginScreen` |
| Inicio | Agujetas - Inicio Light (Final Branding) | `0e3cc82996a544e39ae9c28c4bfaaca6` | `inicio-light-final.html/.png` | `HomeDashboard` |
| Entrenar | Agujetas - Entrenar Light (Final Branding) | `d0b70be55a6a447f8c207d6e17a1a6f1` | `entrenar-light-final.html/.png` | `TrainScreen` |
| Entrenamiento activo | Agujetas - Entrenamiento Activo (Branded) | `114ba5aac078492f9757075a462121cc` | `entrenamiento-activo-branded.html/.png` | `TrainScreen` dark/active state |

## Reglas De Implementación

- Las pantallas Flutter deben conservar bottom navigation fijo como en Stitch.
- Inicio debe priorizar: resumen semanal, modos de sesión, próximo entrenamiento y CTA fijo inferior.
- Entrenar debe mostrar header compacto, strip de timers y logger de set como primer módulo operativo.
- Los botones principales usan verde Agujetas `#357C6D`; fondos light usan `#F7F8F5`; superficies usan blanco o `#EEF3EF`.
- Los textos deben mantener tildes y español latinoamericano en UTF-8.
- Cualquier desviación funcional frente a Stitch debe quedar explícita en este archivo antes de implementarse.

## Estado Actual

- Implementado: referencias locales de Stitch, header más cercano, CTA fijo en Inicio, tarjetas de rutina más compactas, pantalla Entrenar con header/timer strip y controles funcionales.
- Pendiente: aplicar la misma fidelidad a Biblioteca, Progreso, Perfil, Detalle de ejercicio y menú lateral/submenús.
