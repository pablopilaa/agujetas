# 🧭 Flujo de Trabajo Agujetas

## 🌿 Ramas
- `main`: ✅ versión estable (builds de producción).
- `dev`: 🧪 integración de cambios ya probados.
- `feature/<tema>`: 🛠️ trabajo en progreso por tarea.

## 🔁 Ciclo recomendado
1. **Crear rama de trabajo**
   ```bash
   git checkout dev
   git checkout -b feature/mi-cambio
   ```
2. **Hacer cambios y commitear**
   ```bash
   git add -A
   git commit -m "feat: descripción corta"
   ```
3. **Integrar a `dev`**
   ```bash
   git checkout dev
   git merge feature/mi-cambio
   ```
4. **Release cuando `dev` esté sólido**
   ```bash
   git checkout main
   git merge dev
   git tag vX.Y.Z
   ```

## 🚀 Build prod (desde `main`)
```bash
git checkout main
git status -sb
npx expo start -c
eas build --platform android --profile production
```

## ⏪ Rollback rápido
- **Volver a un tag**
  ```bash
  git checkout vX.Y.Z
  ```
- **Revertir un commit**
  ```bash
  git revert <hash>
  ```

## ✅ Convención de commits
- `feat:` nueva funcionalidad
- `fix:` corrección
- `chore:` cambios menores/infra
- `refactor:` cambios sin alterar comportamiento
