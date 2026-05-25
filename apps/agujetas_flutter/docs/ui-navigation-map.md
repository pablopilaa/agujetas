# Agujetas Flutter UI Navigation Map

Este documento describe la estructura navegable de la app Flutter. Debe usarse como contrato de producto para revisar si una pantalla, tarjeta o boton clicable lleva a un destino claro.

## Mapa General

```mermaid
flowchart TD
  A["Login"] -->|Continuar con Google| B["Inicio"]
  A -->|Ver demo sin guardar| B

  B["Inicio / Home"] --> C["Entrenar"]
  B --> D["Calendario de sesiones"]
  B --> E["Modo Entrenador"]
  B --> F["Menu lateral"]

  F --> B
  F --> C
  F --> G["Progreso"]
  F --> H["Biblioteca"]
  F --> I["Perfil"]

  C["Entrenar"] --> C1["Exercise cards"]
  C1 --> C2["Editar series: kg / reps / RIR"]
  C1 --> C3["Tipo de serie: normal / calentamiento / dropset"]
  C1 --> C4["Reordenar con six-dot grip"]
  C --> C5["Guardar sesion"]
  C --> C6["Timer descanso / notificacion"]

  G["Progreso"] --> G1["Volumen efectivo"]
  G --> G2["Dropsets registrados"]
  G --> G3["Peso corporal"]
  G3 --> G4["Registrar peso"]
  G3 --> G5["Alerta diaria de peso"]
  G --> D

  H["Biblioteca"] --> H1["Buscar catalogo"]
  H --> H2["Crear ejercicio personalizado"]
  H2 --> H3["Elegir imagen de galeria"]
  H2 --> H4["Elegir imagen del repositorio"]
  H --> H5["Agregar ejercicio a rutina"]
  H --> H6["Reordenar rutina con six-dot grip"]

  I["Perfil"] --> I1["Apariencia: sistema / claro / oscuro"]
  I --> I2["Cerrar sesion"]

  E["Modo Entrenador"] --> E1["Crear codigo de invitacion"]
  E --> E2["Entrenados activos"]
```

## Pantallas Principales

| Pantalla | Entrada | Acciones principales | Destino esperado |
| --- | --- | --- | --- |
| Login | App sin usuario autenticado | Continuar con Google | Inicio autenticado |
| Login | App sin usuario autenticado | Ver demo sin guardar | Inicio con `DemoAgujetasRepository` |
| Inicio | Bottom nav, login, menu lateral | Iniciar entrenamiento | Entrenar |
| Inicio | Card calendario | Ver calendario de sesiones | Bottom sheet de calendario |
| Inicio | Modo de uso | Cambiar Normal / Entrenador | Inicio en modo elegido |
| Entrenar | Bottom nav, CTA inicio, menu lateral | Editar kg / reps / RIR | Misma pantalla, estado actualizado |
| Entrenar | Grip six dots | Reordenar ejercicios | Misma pantalla, orden actualizado |
| Entrenar | Menu mover | Mover arriba / abajo | Misma pantalla, orden actualizado |
| Entrenar | Guardar | Persistir sesion | Firestore `sessions` y snackbar |
| Entrenar | Timer descanso | Programar alerta | Notificacion local |
| Progreso | Bottom nav, menu lateral | Registrar peso | Bottom sheet de peso |
| Progreso | Alertarme cada manana | Programar alerta diaria | Notificacion local diaria |
| Progreso | Calendario | Ver calendario de sesiones | Bottom sheet de calendario |
| Biblioteca | Bottom nav, menu lateral | Buscar catalogo | Lista filtrada |
| Biblioteca | Crear ejercicio personalizado | Formulario de ejercicio | Nuevo ejercicio en rutina y Firestore |
| Biblioteca | Elegir imagen de galeria | Selector nativo | `imageUri` local asociado |
| Biblioteca | Elegir imagen del repositorio | Selector interno | `app-image://...` asociado |
| Biblioteca | Agregar ejercicio | Agregar a rutina activa | Entrenamiento actual actualizado |
| Biblioteca | Grip six dots | Reordenar rutina | Misma pantalla, orden actualizado |
| Perfil | Bottom nav, menu lateral | Cambiar tema | ThemeMode actualizado |
| Perfil | Cerrar sesion | Sign out | Login |
| Panel entrenador | Inicio en modo entrenador | Crear codigo | Firestore `trainerInvites` |
| Panel entrenador | Inicio en modo entrenador | Ver entrenados activos | Lista desde `trainerClientLinks` |

## Reglas De Interaccion

- El grip six dots es el unico punto que debe iniciar drag and drop.
- Tocar la tarjeta debe abrir, editar o ejecutar la accion principal; no debe competir con el gesto de arrastre.
- El drag debe iniciar de forma inmediata desde el handle, sin long-press perceptible.
- El area tactil minima del handle debe ser 44 x 44 px.
- Todo reorder debe tener alternativa accesible: mover arriba y mover abajo.
- Cada tarjeta clicable debe tener feedback visual y destino claro.
- Las transiciones deben ser cortas, reversibles y no bloquear el flujo de entrenamiento.

## Pendientes UX

- Validar drag and drop en Android real con grabacion de pantalla, no solo con screenshot.
- Definir detalle de ejercicio como pantalla propia si el usuario necesita historial por ejercicio.
- Decidir si el calendario debe pasar de bottom sheet a pantalla completa cuando haya schedules reales.
- Agregar rutas declarativas si la app crece mas alla de cinco tabs y modales.
