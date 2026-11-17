Feature → Develop

Rama: feature/b3-editar-material → Develop

## Necesidad

Permitir corregir el título o reemplazar un archivo del curso exclusivamente a quien lo subió, respetando los permisos y el aislamiento entre universidades.

## Solución

- Registro del autor mediante `uploaded_by_id`, con índice y clave foránea.
- Edición exclusiva del autor mientras siga siendo profesor con participación en el curso; coordinarlo no habilita a editar material ajeno.
- Formulario para cambiar título y reemplazar opcionalmente el archivo, conservándolo si no se selecciona uno nuevo.
- Validaciones de 50 MB, formato y contenido compartidas con B1. Los reemplazos inválidos conservan el material guardado.
- Autor y curso inmutables; se rechazan signed IDs y no se permite eliminar el archivo desde B3.
- Materiales anteriores sin autor identificado permanecen sin permiso de edición. No se asignan propietarios supuestos.
- Restricción de eliminación de cuentas con materiales atribuidos.
- Rutas de edición por curso y cierre de la edición global del scaffold.

**Integración necesaria con B1:** conservar `@material.uploaded_by = current_user` antes de guardar en su `create`. B3 incorpora la asignación en el controlador actual de Develop; B1 lo reemplaza y la resolución del conflicto debe mantenerla. Las subidas anteriores sin autor no se vuelven editables automáticamente.

Conservar las políticas y rutas de las otras tarjetas junto a las de B3. No se integraron sus commits ni se modificaron sus ramas. Los detalles para resolver los archivos compartidos están en `docs/cards/B3-editar-material.md`.

Incluye migración y actualización de schema.rb. No agrega dependencias, conversiones ni cambios en Dockerfile o CI.

## Verificación

- B3: 28 pruebas y 353 aserciones, sin fallos.
- Suite completa: 459 pruebas y 2.772 aserciones, sin fallos, errores ni omisiones.
- Copia temporal B1/B2/B3/B5: 98 pruebas y 971 aserciones, incluido el registro del autor de la sesión, rechazo a otro profesor, reemplazo, vista previa y descarga del nuevo archivo.
- RuboCop: 215 archivos, sin infracciones. Brakeman: 0 advertencias de seguridad.
- Migración aplicada únicamente sobre una base temporal; sin cambios en bases existentes ni buckets.
- Entorno local: Ruby 4.0.0 y PostgreSQL 18; CI debe verificar Ruby 3.4.5, declarado por el proyecto. Sin pruebas de S3 real ni build de Docker en este entorno WSL.

## Tarjeta relacionada

B3 · Editar material

**Reemplazar esta línea por el enlace de la tarjeta de Trello antes de abrir el PR.**

## Checklist

- [x] La rama nace de Develop, no de main
- [x] Se cumple la regla confirmada: solo quien subió el material puede editarlo
- [x] Verifiqué que la funcionalidad opera correctamente
- [x] Verifiqué que no rompí otra cosa mediante la suite completa
- [x] Se respetan los permisos por rol y el aislamiento por university_id
- [x] Los commits siguen Conventional Commits
- [ ] El PR cuenta con las aprobaciones acordadas por el equipo

## Después de mergear

- [ ] Marcar la tarjeta con la etiqueta “Merge a develop”
- [ ] Mantener la tarjeta en En revisión hasta que su release llegue a main
- [ ] Borrar la rama feature/b3-editar-material
