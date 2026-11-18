# B3 · Editar material

Épica 2: Gestionar la actividad académica de un curso.

## Regla confirmada

La usuaria confirmó: «Solo quien subió el archivo» puede editar el material.

El autor debe conservar una cuenta de profesor, pertenecer a la universidad del curso y seguir participando como docente o coordinador. Otro profesor o coordinador del curso no puede editar material ajeno. Director, administrativo, ayudante y alumno no reciben permisos de edición.

## Comportamiento

- El profesor encuentra «Editar mi material» desde la vista del curso y «Editar» junto a su material en la sección.
- El listado de edición incluye únicamente sus materiales autorizados; excluye los de otros profesores y los registros sin autor.
- Puede cambiar el título, reemplazar el archivo o hacer ambas cosas. Si no selecciona otro archivo, se conserva el existente.
- El reemplazo tiene el mismo máximo de 50.000.000 bytes y los mismos formatos de B1, comprobados en el servidor por extensión y contenido.
- Una validación rechazada no modifica el título o archivo guardados, ni crea un nuevo blob o adjunto. Se conservan los valores enviados en el formulario y se pide seleccionar nuevamente el archivo.
- Se rechazan signed IDs y referencias a blobs existentes: el reemplazo debe ser una subida multipart nueva.
- El formulario no permite cambiar autor, curso ni universidad ni eliminar el adjunto. Los parámetros manipulados para esas operaciones se ignoran.
- Tras guardar se confirma la actualización y se vuelve al formulario con una redirección 303.

Las respuestas del formulario y listado llevan `Cache-Control: private, no-store`. No se agregan rutas públicas de edición ni permisos al scaffold global de materiales.

## Autoría y migración

`20261116180000_add_uploaded_by_to_materials.rb` incorpora `materials.uploaded_by_id`, índice y clave foránea a `users`. La asociación es nullable porque los registros anteriores no permiten conocer su autor real. No se rellena el campo con un profesor supuesto.

- Los materiales antiguos permanecen visibles para las tarjetas de lectura y descarga, pero no son editables si no tienen autor identificado.
- Las subidas nuevas deben asignar `uploaded_by` desde `current_user`, nunca desde los parámetros del formulario.
- `uploaded_by_id` y `course_id` son inmutables después de crear el material.
- Un autor identificado debe ser profesor de la universidad correspondiente al crear el material.
- La eliminación de una cuenta con materiales atribuidos queda restringida para no perder la autoría.

Para probar la edición en la demo, se debe subir un material nuevo después de integrar el registro de autoría de B1 y B3. No hay una pantalla para reclamar o reasignar materiales antiguos.

La migración y las pruebas locales se ejecutaron únicamente en bases temporales. No se modificaron bases de desarrollo, producción ni buckets.

## Rutas y autorización

```text
GET   /courses/:course_id/material_edits
GET   /courses/:course_id/material_edits/:id/edit
PATCH /courses/:course_id/material_edits/:id
```

`MaterialEditsController` busca el curso dentro de la universidad activa, comprueba su lectura y obtiene el material mediante `@course.materials.find`. Después autoriza la actualización con `MaterialEditPolicy`, que comprueba autoría y participación. Cada solicitud vuelve a verificar esos permisos; quitar la participación o cambiar el rol revoca el acceso a enlaces guardados.

El listado usa `accessible_by` para aplicar los permisos también en la consulta. Los IDs de otra universidad y los materiales anidados bajo un curso incorrecto responden 404.

## Integración con las otras tarjetas

La rama `feature/b3-editar-material` nace de `origin/Develop` en `8ac3eac`. No incorpora commits de las ramas pendientes ni las modifica.

Se reutilizan los archivos `MaterialFileFormat`, `MaterialStorageService` y la traducción `materials.es.yml` con el mismo contenido que B1. El modelo de B3 conserva sus validaciones de archivo y selección del servicio, añadiendo la autoría. No añade dependencias, conversiones de oficina ni cambios en Docker o CI.

Al integrar:

1. Conservar el modelo de B3 con la asociación de autor, campos inmutables y validaciones compartidas de B1.
2. Conservar tanto `MaterialPolicy` de B1 como `MaterialEditPolicy` de B3 en `Ability`.
3. En el `create` de B1 conservar esta asignación antes de guardar:

   ```ruby
   @material.title = attributes[:title]
   @material.uploaded_by = current_user
   ```

   B3 añade la asignación al `create` de Develop. Como B1 reemplaza ese controlador, la resolución del conflicto debe conservarla en su implementación. Es necesaria para que las nuevas subidas sean editables por su autor.

4. Conservar las rutas de subida B1, lectura B2, edición B3 y descarga B5, con sus controladores independientes. El scaffold global se mantiene limitado al índice denegado.
5. Conservar los enlaces y comprobaciones de permiso de cada acción en curso y sección: título hacia el detalle de B2, descarga de B5, edición de B3 solo para su autor y subida de B1 para el profesor autorizado.

Se comprobó una exportación temporal de las implementaciones con esos puntos de integración resueltos, sin merges ni cambios en las otras ramas. El flujo verifica que B1 registra el usuario de la sesión aun si se envía otro autor por parámetros, otro profesor no puede editar, el autor reemplaza el archivo, B2 muestra el contenido nuevo y B5 descarga los mismos bytes. Esto no reemplaza CI ni la revisión del merge real.

## Verificación

```sh
bin/rails db:migrate
bin/rails test test/integration/material_edits_test.rb test/models/material_authorship_test.rb
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

Resultados locales:

- B3: 28 pruebas y 353 aserciones, sin fallos, errores ni omisiones.
- Suite completa: 459 pruebas y 2.772 aserciones, sin fallos, errores ni omisiones.
- Ensamble temporal B1/B2/B3/B5: 98 pruebas y 971 aserciones, sin fallos, errores ni omisiones.
- RuboCop: 215 archivos, sin infracciones.
- Brakeman: 0 errores y 0 advertencias de seguridad.
- Se aplicó la migración sobre un esquema existente en una base temporal y se generó `db/schema.rb`.

El entorno local usa Ruby 4.0.0, Rails 8.1.4.1 y PostgreSQL 18, con las versiones exactas de Gemfile.lock. Se añadió `benchmark` solo a la ruta de carga de los procesos de prueba; CI debe verificar Ruby 3.4.5, declarado por el proyecto. No se probaron fallos de red ni sustituciones contra S3 real. No se construyó Docker porque Docker Desktop no tiene integración con esta distribución WSL.

## Revisión y entrega

Abrir el PR hacia `Develop` siguiendo el template Feature. La descripción preparada está en `docs/pull_requests/B3-editar-material.md`. Añadir el enlace de Trello y obtener las aprobaciones del equipo. Después del merge a Develop, mantener En revisión hasta que el release llegue a main.
