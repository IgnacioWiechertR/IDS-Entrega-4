# B1 · Subir material

Épica 2: Gestionar la actividad académica de un curso.

## Historia de usuario

Como profesor, quiero subir un archivo asociado a uno de mis cursos para disponer de material académico en la plataforma de mi universidad.

## Reglas y alcance

- La regla confirmada para B1 es que solo una cuenta de profesor puede subir material.
- Se mantiene el acceso existente a los cursos: el profesor participa como docente de una sección o como coordinador del curso. Ser profesor de la universidad no habilita a subir a cualquier curso.
- Director, administrativo, ayudante y alumno no reciben permiso de subida, aunque puedan administrar o consultar el curso.
- El curso se obtiene de la ruta y de la universidad activa. No se acepta cambiarlo mediante los campos del formulario.
- El material pertenece al curso, como establece el modelo existente; B1 no añade una selección de sección ni período.
- El formulario solicita título y un archivo no vacío. Se reutiliza la asociación `has_one_attached :file` existente.
- El tamaño máximo confirmado es 50 MB por archivo (50.000.000 bytes), inclusive.

## Formatos permitidos

La regla confirmada incluye PDF, Excel, Word, PowerPoint, texto y documentos de características similares. Se implementa mediante esta lista explícita:

- PDF: `.pdf`.
- Word y equivalentes: `.doc`, `.docx`, `.rtf`, `.odt`, `.pages`.
- Excel y equivalentes: `.xls`, `.xlsx`, `.ods`, `.numbers`.
- PowerPoint y equivalentes: `.ppt`, `.pptx`, `.pps`, `.ppsx`, `.odp`, `.key`.
- Texto: `.txt`, `.csv`, `.tsv`, `.md`, incluido texto UTF-16.

Google Docs, Sheets y Slides se admiten mediante sus exportaciones a PDF, Office, OpenDocument o texto. Un enlace web o un archivo `.gdoc`, `.gsheet` o `.gslides` es una referencia al documento de Google, no una copia de su contenido: se debe exportar el documento antes de subirlo.

El servidor comprueba el tamaño, la extensión y la firma de contenido detectada con Marcel. Los documentos Office y otros formatos comparten contenedores; esta comprobación reconoce el tipo de archivo, sin intentar abrirlo como una aplicación de ofimática. El formulario muestra las restricciones y filtra las extensiones en el selector, pero la validación del servidor también se aplica a solicitudes enviadas directamente.

## Comportamiento implementado

1. El profesor encuentra «Subir material» en el curso o sección a la que tiene acceso.
2. `GET /courses/:course_id/materials/new` muestra el curso y el formulario.
3. `POST /courses/:course_id/materials` recibe un archivo multipart nuevo y su título. Al guardar, se confirma la subida y se vuelve al formulario mediante una redirección 303.
4. Un archivo ausente, vacío, mayor de 50 MB o con formato no admitido, y un título vacío, producen errores visibles sin persistir material, blob ni adjunto. El título se conserva y se indica que el archivo debe seleccionarse nuevamente. El tamaño y el formato también se validan al reemplazar un adjunto.
5. Se rechazan profesores sin participación en el curso, cuentas de otros roles y cursos de otra universidad. Los recursos de otra universidad responden 404.
6. Las cuentas de profesores de ambas universidades pueden subir independientemente. No se puede reutilizar un signed ID para adjuntar un archivo ya almacenado por otra cuenta o institución.
7. El endpoint global de Active Storage para direct uploads se dirige al acceso global cerrado de materiales: las subidas pasan por la autorización del curso.

## Almacenamiento y aislamiento

`MaterialStorageService` reutiliza la configuración de T5. Con almacenamiento S3 activado mediante `amazon_u1` o `amazon_u2`, selecciona `amazon_u1` para el slug `ucv` y `amazon_u2` para `iusa`, independientemente de cuál de los dos esté configurado como predeterminado.

En desarrollo y pruebas conserva el servicio local configurado. Si S3 está activado y la universidad no tiene correspondencia, se rechaza la operación en lugar de utilizar el bucket de otra universidad. No se modifican credenciales, buckets ni variables de producción.

Las pruebas verifican la selección de servicios sin hacer cargas a S3 real, y comprueban la persistencia y lectura de los bytes en almacenamiento de pruebas.

## Relación con otras tarjetas

- B1 se desarrolla en `feature/b1-subir-material`, desde Develop, sin integrar la rama de A15 ni otras features pendientes.
- Reutiliza autenticación, CanCanCan, A3, los cursos y el almacenamiento existente.
- B2, B3, B4 y B5 mantienen su propio alcance. No se habilitan acciones globales de listado, edición, eliminación o descarga desde el scaffold de materiales.
- La sección ya contiene una presentación de material que se conserva. B5 debe completar y verificar sus reglas de descarga autenticada y aislamiento de archivos; B1 no certifica terminado ese flujo.
- No se agregan migraciones ni se modifica Gemfile.lock.

## Verificación

Con las dependencias del proyecto y PostgreSQL configurados:

```sh
bin/rails test test/models/material_test.rb test/models/material_policy_test.rb test/services/material_storage_service_test.rb test/services/material_file_format_test.rb test/integration/material_uploads_test.rb
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

## Revisión del equipo

El PR debe dirigirse a Develop y utilizar el template feature, enlazando B1 y describiendo el alcance y las pruebas. Se mantiene En revisión después de integrar a Develop; pasa a Hecho al cumplir la DoD, incluidas las aprobaciones acordadas y el release integrado en main.

## Comprobaciones realizadas al preparar la rama

- B1: 45 pruebas y 269 aserciones, sin fallos ni errores, incluidas fronteras de 50 MB y formatos.
- Suite completa: 370 pruebas y 2.067 aserciones, sin fallos ni errores.
- RuboCop: 203 archivos inspeccionados, sin infracciones.
- Brakeman: 0 advertencias de seguridad.
- Dependencias exactas de Gemfile.lock, con Rails 8.1.4.1, y PostgreSQL 18 temporal. No se tocaron bases existentes ni buckets reales.
- El entorno disponible usa Ruby 4.0.0. Para la suite general se añadió la biblioteca instalada `benchmark` a la ruta de carga del proceso de pruebas, sin cambiar el proyecto. CI o un entorno con Ruby 3.4.5 deben verificar la versión declarada en el repositorio.
