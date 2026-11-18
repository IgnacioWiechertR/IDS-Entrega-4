# B4 · Eliminar material

Épica 2: Gestionar la actividad académica de un curso.

## Regla confirmada

La usuaria confirmó que únicamente el profesor que subió el material puede eliminarlo, igual que en B3. Debe seguir siendo profesor de la universidad correspondiente y participar como docente o coordinador del curso.

Otro profesor o coordinador no puede eliminar material ajeno. Director, administrativo, ayudante y alumno no reciben este permiso. Los materiales anteriores sin autor identificado permanecen protegidos; no se asignan propietarios supuestos.

## Comportamiento

1. El autor encuentra «Eliminar mi material» en el curso y «Eliminar» junto a su material en la sección.
2. El listado incluye únicamente materiales que puede eliminar y excluye los de otros autores y los registros sin autor.
3. «Eliminar» abre una pantalla que muestra curso, título, archivo y el aviso de que la acción no se puede deshacer. Un GET nunca elimina, aunque incluya parámetros de confirmación.
4. «Cancelar» vuelve al listado sin cambios.
5. «Eliminar definitivamente» envía DELETE con la confirmación explícita. Sin ella, el servidor vuelve a la pantalla de confirmación sin borrar.
6. Tras eliminar, vuelve al listado con «Material eliminado correctamente» y respuesta 303. Si la destrucción se aborta, conserva material y adjunto y muestra un error.

Las respuestas llevan `Cache-Control: private, no-store`. El título se escapa en la confirmación. Los parámetros enviados no pueden sustituir el curso, autor, material o blob que se eliminará.

## Autorización y rutas

```text
GET    /courses/:course_id/material_deletions
GET    /courses/:course_id/material_deletions/:id
DELETE /courses/:course_id/material_deletions/:id
```

`MaterialDeletionsController` busca el curso dentro de la universidad activa y comprueba su lectura. El material se obtiene con `@course.materials.find` y se autoriza mediante `MaterialDeletionPolicy`, que exige autoría y participación. La autorización se repite al confirmar y al eliminar; revocar la participación o cambiar el rol invalida enlaces guardados.

El listado usa `accessible_by` para filtrar también en SQL. Un ID de otra universidad o un material anidado bajo otro curso responde 404. Una segunda eliminación responde 404 y no agenda otra purga. La ruta global del scaffold permanece cerrada.

## Limpieza del archivo

Se usa `Material#destroy` y el ciclo de vida existente de Active Storage. La eliminación de material y adjunto participa en la transacción. Si esta se aborta, no se borra el adjunto ni se encola su purga.

Después del commit, Active Storage encola `ActiveStorage::PurgeJob` en la infraestructura de trabajos existente. El material desaparece de los listados antes de que termine la limpieza física. El worker debe consumir la cola para eliminar el blob y el objeto del almacenamiento. No se descargan ni convierten archivos para eliminarlos.

Un blob que continúa asociado a otro material no se borra físicamente; Active Storage y sus claves foráneas protegen las referencias restantes. Se comprueba también la eliminación de materiales cuyo archivo físico ya falta o que no tienen adjunto.

En la integración con B5, sus rutas protegidas dejan de servir un material eliminado inmediatamente, antes de la purga física. B5 conserva el cierre de las rutas públicas de Active Storage; B4 no agrega nuevas rutas públicas de archivos.

## Autoría compartida con B3

B4 utiliza exactamente la misma migración `20261116180000_add_uploaded_by_to_materials.rb` de B3: campo nullable, índice y clave foránea a usuarios. Se conserva el mismo archivo y versión al integrar ambas ramas; no debe crearse otra migración que agregue la columna nuevamente.

También conserva las asociaciones, autoría y curso inmutables y la restricción de eliminar cuentas con materiales atribuidos. Los registros antiguos con autor nulo no se vuelven eliminables automáticamente. Para probar la demo se debe subir material nuevo después de integrar el registro de autoría.

## Integración con B1–B5

La rama `feature/b4-eliminar-material` nace de `origin/Develop` en `8ac3eac`. No contiene commits de las otras features pendientes ni las ha mergeado.

- En el `create` de B1 conservar `@material.uploaded_by = current_user` antes de guardar. B4 añade esa asignación al controlador actual de Develop; B1 lo reemplaza y debe mantenerla en su versión.
- Conservar el modelo de B3 con sus validaciones de archivo y selección del servicio, junto a la autoría compartida. Active Storage mantiene la purga posterior a la eliminación.
- `Ability` debe componer `MaterialPolicy`, `MaterialEditPolicy` y `MaterialDeletionPolicy`: subir, editar y eliminar son permisos diferentes.
- Conservar las rutas independientes de subida B1, lectura B2, edición B3, eliminación B4 y descarga B5, manteniendo cerrado el scaffold global y las rutas públicas de archivos que cierra B5.
- En curso y sección conservar los accesos de cada tarjeta y sus comprobaciones de permisos. El enlace al título de B2, el botón de descarga de B5, la edición de B3 y la eliminación de B4 cumplen propósitos distintos.

Se preparó una exportación temporal con esos puntos de integración resueltos y se ejecutó su suite completa. El flujo adicional sube un archivo, lo edita su autor, lo visualiza y descarga un alumno, rechaza la eliminación por otro profesor y permite al autor eliminarlo. Después, los accesos de B2 y B5 responden 404 y el trabajo de purga retira el archivo físico. Esta comprobación no reemplaza CI ni la revisión del merge real del equipo.

Al reunir las tarjetas se ajustaron pruebas de B2 para construir registros históricos fuera de las reglas actuales de subida y reconocer tanto rutas globales denegadas como eliminadas. La prueba de B3 sobre ausencia de permisos de eliminación se limita a `MaterialEditPolicy`, de modo que no contradiga el permiso que agrega B4. Esas correcciones se guardan en las ramas correspondientes, sin cambiar la funcionalidad de B2 o B3.

## Verificación

```sh
bin/rails db:migrate
bin/rails test test/integration/material_deletions_test.rb test/models/material_deletion_policy_test.rb
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

Resultados locales:

- B4: 28 pruebas y 388 aserciones, sin fallos, errores ni omisiones.
- Suite completa de la rama: 459 pruebas y 2.807 aserciones, sin fallos, errores ni omisiones.
- Exportación temporal B1–B5: 590 pruebas y 4.191 aserciones, sin fallos, errores ni omisiones.
- RuboCop: 213 archivos, sin infracciones.
- Brakeman: 0 errores y 0 advertencias de seguridad.
- Purga real de los archivos de prueba en disco, conservación de archivos compartidos y rollback sin purga.

El entorno utiliza Ruby 4.0.0, Rails 8.1.4.1 y PostgreSQL 18, con las dependencias exactas de Gemfile.lock. Se añadió `benchmark` solo a la ruta de carga de los procesos de prueba; CI debe verificar Ruby 3.4.5, declarado por el proyecto. Todas las migraciones y eliminaciones se ejecutaron en bases y archivos temporales. No se modificaron datos de desarrollo, producción o S3 real.

No se hicieron pruebas de carga a 512 MB ni se construyó Docker por falta de integración de Docker Desktop con esta distribución WSL. B4 no añade dependencias, procesos de conversión, cambios de Dockerfile ni cambios en CI.

## Revisión

Abrir el PR hacia `Develop` con el template Feature y el enlace de Trello. La descripción está en `docs/pull_requests/B4-eliminar-material.md`. Mantener En revisión después del merge a Develop hasta obtener las aprobaciones y el release integrado en main.
