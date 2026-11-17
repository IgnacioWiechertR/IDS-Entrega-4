# B5 · Descargar material

Épica 2: Gestionar la actividad académica de un curso.

## Historia y alcance

Como integrante autorizado de un curso, quiero descargar sus archivos originales para consultarlos fuera de la aplicación.

- La descarga conserva los bytes y la extensión del original, incluidos documentos de oficina que B2 no previsualiza.
- Se usa el nombre del archivo almacenado, saneado por Active Storage para evitar rutas o inyección de cabeceras.
- El archivo se entrega como adjunto (`Content-Disposition: attachment`) y `application/octet-stream`.
- El curso tiene un acceso «Descargar material» que ofrece las descargas disponibles. La sección tiene enlaces directos y un botón «Descargar» junto a cada archivo adjunto.
- Un material sin adjunto no ofrece botón. Si se solicita su URL, o el archivo ya no existe en el almacenamiento, responde 404 con «El archivo no está disponible para descargar».
- No modifica las reglas de subida de B1, no convierte documentos y no agrega edición ni eliminación.

## Permisos y universidad

Se reutiliza `CoursePolicy` y se comprueba sesión y acceso en cada solicitud:

- Profesor o ayudante asignado al curso mediante sus secciones.
- Profesor coordinador, aunque no dicte una sección.
- Alumno con matrícula activa, o cuenta de alumno asignada como ayudante.
- Administrativo dentro de su universidad.
- Director dentro de la universidad activa; el selector permite cambiar entre ambas.

El curso se busca con la universidad activa y se autoriza mediante `authorize! :read, @course`. El material se busca dentro de `@course.materials`. No se aceptan parámetros para sustituir el blob, el archivo, la universidad o la disposición de descarga.

Desactivar la matrícula o retirar docencia y coordinación revoca el acceso a un enlace guardado. La autorización se realiza antes de consultar el almacenamiento, también para peticiones HEAD y condicionales. Los IDs de otras universidades responden 404; los cursos de la misma universidad sin participación se deniegan según el comportamiento vigente de autorización.

## Rutas

```text
GET  /courses/:course_id/material_downloads
GET  /courses/:course_id/materials/:material_id/download
HEAD /courses/:course_id/materials/:material_id/download
```

`MaterialDownloadsController` es independiente de los controladores de subida B1 y lectura B2. El helper `material_download_link(course, material)` se puede reutilizar en las vistas de B2 después de integrar sus ramas.

## Cierre del acceso público a adjuntos

`config.active_storage.draw_routes = false` deshabilita las rutas estándar de blobs, proxy, representaciones, lectura de disco y carga a disco. Un signed ID válido ya no permite saltarse la autorización del curso. Los adjuntos del proyecto corresponden a materiales; las nuevas funcionalidades que adjunten otros recursos deberán definir sus propios accesos autorizados.

Se mantiene el helper `rails_direct_uploads_path` con una ruta explícita que dirige al índice global denegado de materiales. Esto conserva la compatibilidad con las comprobaciones de B1 y no habilita direct uploads: las subidas multipart siguen usando su formulario autorizado.

B5 no genera URLs de descarga firmadas ni redirige al bucket. Utiliza el servicio guardado en el blob, compatible con la selección de almacenamiento de B1. No cambia credenciales, buckets ni objetos existentes.

## Uso de memoria y caché

`MaterialDownloadBody` entrega el contenido a Rack mediante `blob.download` con bloque. Active Storage transmite por partes en lugar de crear un String con el archivo completo. Las pruebas con disco verifican que un archivo de 12 MB se entrega en varios bloques de hasta 5 MiB y conserva su SHA-256.

Las cabeceras incluyen `Cache-Control: private, no-store`, `X-Content-Type-Options: nosniff` y el tamaño almacenado. `Last-Modified` evita que Rack::ETag lea y acumule el cuerpo para calcular un digest. HEAD no descarga bytes. No hay conversores, archivos temporales de descarga, procesos adicionales ni dependencias nuevas.

No se implementa reanudación mediante Range: se anuncia `Accept-Ranges: none` y se entrega el archivo completo. Si el almacenamiento falla después de iniciar la transmisión, la descarga puede interrumpirse y necesitar un nuevo intento. No se han realizado pruebas de carga del despliegue de 512 MB ni descargas contra buckets reales.

## Integración con B1 y B2

La rama `feature/b5-descargar-material` nace de `origin/Develop` en `8ac3eac`, sin incorporar commits de las otras features pendientes. No se hicieron merges ni se modificaron sus ramas.

- Conservar los bloques de rutas de B1, B2 y B5: subida, lectura/vista previa y descarga tienen controladores separados.
- Conservar la configuración que deshabilita las rutas públicas de Active Storage.
- En `sections/show.html.erb`, B2 y B5 modifican el enlace del título. Al integrar, conservar el título dirigido a `course_material_path(@course, material)` de B2 y el botón `material_download_link(@course, material)` de B5. El botón de subida de B1 también se conserva.
- En el detalle de B2 se puede reutilizar el helper de descarga; la página de descargas del curso funciona por sí sola mientras las otras features esperan revisión.
- El equipo mantiene el orden de integración y las aprobaciones acordadas. Esta tarjeta no integra ni publica otras tarjetas.

Se preparó una exportación temporal de las tres implementaciones, adaptando sus puntos de integración en las vistas y rutas. En esa copia se ejecutaron las pruebas de B1 y B5 y un flujo completo de subida, vista previa PDF de B2, descarga y revocación de matrícula. Esto no reemplaza la revisión y CI del merge real del equipo.

## Verificación

```sh
bin/rails test test/integration/material_downloads_test.rb test/integration/private_attachment_routes_test.rb test/services/material_download_body_test.rb
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

Comprobaciones realizadas:

- B5: 24 pruebas y 329 aserciones, sin fallos, errores ni omisiones.
- Suite completa: 455 pruebas y 2.748 aserciones, sin fallos, errores ni omisiones.
- Copia temporal con B1/B2/B5: 70 pruebas y 614 aserciones, sin fallos, errores ni omisiones.
- RuboCop: 214 archivos, sin infracciones.
- Brakeman: 0 errores y 0 advertencias de seguridad.
- Dependencias exactas de Gemfile.lock, PostgreSQL 18 y bases desechables; sin cambios en bases existentes ni buckets.

El entorno local usa Ruby 4.0.0. Se añadió `benchmark` solo a la ruta de carga de los procesos de prueba; CI debe verificar Ruby 3.4.5, declarado por el proyecto. No se construyó la imagen Docker porque Docker Desktop no tiene integración con esta distribución WSL. B5 no modifica Dockerfile, CI, Gemfile.lock ni el esquema de la base.

## Revisión

PR hacia `Develop`, siguiendo `docs/PULL_REQUEST_TEMPLATE/feature.md`. La descripción preparada está en `docs/pull_requests/B5-descargar-material.md`; falta enlazar la tarjeta de Trello y obtener las aprobaciones del equipo. Se mantiene En revisión después del merge a Develop hasta que el release llegue a main.
