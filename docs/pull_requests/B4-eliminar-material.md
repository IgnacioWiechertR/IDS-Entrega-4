Feature → Develop

Rama: feature/b4-eliminar-material → Develop

## Necesidad

Permitir eliminar un material exclusivamente a quien lo subió, retirando su registro y limpiando el archivo sin afectar otros materiales ni universidades.

## Solución

- Eliminación exclusiva del autor mientras siga siendo profesor con participación en el curso.
- Listado de material propio y acceso desde el curso y la sección.
- Pantalla de confirmación con cancelar; el servidor exige confirmación explícita para DELETE.
- Autorización por curso y universidad en cada solicitud; otro profesor, coordinador o personal administrativo no puede eliminar material ajeno.
- Eliminación transaccional del material y adjunto, y purga posterior mediante Active Storage y la cola existente.
- Protección de blobs compartidos y conservación del adjunto si la destrucción se aborta.
- Materiales antiguos sin autor identificado protegidos; el formulario no permite reclamar autoría ni sustituir IDs de archivo.
- Scaffold global de eliminación cerrado y respuestas privadas sin caché compartida.

La migración de autoría es el mismo archivo y versión de B3; conservar una sola copia al integrar. En la subida B1 se debe conservar `@material.uploaded_by = current_user` antes de guardar. Las indicaciones de integración de modelos, políticas, rutas y vistas están en `docs/cards/B4-eliminar-material.md`.

La rama nace de Develop sin mergear las otras features. No agrega dependencias ni cambios de Dockerfile o CI. El material se retira al confirmar la transacción y el archivo físico se limpia después, mediante el worker existente.

## Verificación

- B4: 28 pruebas y 388 aserciones, sin fallos.
- Suite completa de la rama: 459 pruebas y 2.807 aserciones, sin fallos, errores ni omisiones.
- Exportación temporal B1–B5: 590 pruebas y 4.191 aserciones, incluido el flujo completo y la retirada del acceso tras eliminar. Ninguna rama fue mergeada.
- Purga real en almacenamiento de pruebas, cancelación sin cambios, rollback sin purga y conservación de blobs compartidos.
- RuboCop: 213 archivos, sin infracciones. Brakeman: 0 advertencias de seguridad.
- Bases temporales, Ruby 4.0.0 y PostgreSQL 18; CI debe verificar Ruby 3.4.5. Sin modificaciones de datos reales o buckets.
- Sin pruebas de carga a 512 MB ni build de Docker en este entorno WSL.

## Tarjeta relacionada

B4 · Eliminar material

**Reemplazar esta línea por el enlace de la tarjeta de Trello antes de abrir el PR.**

## Checklist

- [x] La rama nace de Develop, no de main
- [x] Se cumple la regla confirmada: solo quien subió el material puede eliminarlo
- [x] Verifiqué que la funcionalidad opera correctamente
- [x] Verifiqué que no rompí otra cosa mediante la suite completa
- [x] Se respetan los permisos por rol y el aislamiento por university_id
- [x] Los commits siguen Conventional Commits
- [ ] El PR cuenta con las aprobaciones acordadas por el equipo

## Después de mergear

- [ ] Marcar la tarjeta con la etiqueta “Merge a develop”
- [ ] Mantener la tarjeta en En revisión hasta que su release llegue a main
- [ ] Borrar la rama feature/b4-eliminar-material
