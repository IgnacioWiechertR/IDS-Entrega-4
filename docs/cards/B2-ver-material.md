# B2 · Ver material del curso

Épica 2: Gestionar la actividad académica de un curso.

## Historia y criterios

Como integrante de un curso autorizado, quiero consultar el material académico y ver su contenido dentro de la aplicación.

- Acceso al material desde el curso y desde sus secciones.
- Listado del curso, ordenado por fecha de publicación descendente y por ID descendente en caso de empate.
- Detalle con título, nombre del archivo, tamaño y fecha de publicación.
- Vista previa de contenido PDF y texto; los documentos de oficina conservan listado y detalle, con un aviso de vista previa no disponible.
- Mensajes para cursos sin material, adjuntos ausentes y vistas previas no disponibles.
- Acceso sujeto a los permisos vigentes de lectura del curso y al aislamiento entre universidades.

## Permisos

B2 reutiliza `CoursePolicy`, sin añadir permisos de administración:

- Profesor o ayudante asignado a una sección del curso.
- Profesor coordinador, aunque no dicte una sección.
- Alumno con matrícula activa; una cuenta de alumno asignada como ayudante también conserva su acceso.
- Administrativo dentro de su universidad.
- Director dentro de la universidad activa; debe cambiar el selector para consultar la otra.

Ser profesor, ayudante o alumno de la universidad no concede acceso a todos sus cursos. Cada solicitud de listado, detalle o contenido busca primero el curso dentro de la universidad activa y verifica `authorize! :read, @course`. El material se obtiene mediante `@course.materials.find`, nunca mediante un ID global.

## Vista previa

- PDF: se entrega con `Content-Disposition: inline` tras comprobar su tipo real.
- Texto `.txt`, `.csv`, `.tsv`, `.md`: se muestra escapado como texto, incluidos saltos de línea y UTF-16 con BOM. Se limita a los primeros 256.000 bytes y se informa si se recortó.
- Word, Excel, PowerPoint, RTF, OpenDocument y documentos de oficina equivalentes: se muestran sus datos y el aviso «La vista previa no está disponible para este archivo». La ruta de contenido rechaza estos formatos antes de leer el almacenamiento, incluso si se solicita directamente.
- Google Docs, Sheets y Slides se consultan a partir de sus archivos exportados. Las exportaciones PDF o texto tienen vista previa; los formatos de oficina muestran el mismo aviso que los demás documentos de oficina.

La vista previa admite originales de hasta 50.000.000 bytes, alineado con B1. No se modifica el original ni se generan adjuntos derivados.

Las respuestas de B2 llevan `Cache-Control: private, no-store`. El contenido se sirve desde una ruta autenticada de la aplicación; B2 no entrega URLs firmadas de Active Storage ni URLs del bucket a visores externos.

## Recursos y despliegue

La revisión del equipo reportó que conversiones concurrentes dentro del contenedor de 512 MB pueden agotar la memoria y derribar toda la aplicación. La versión final retira LibreOffice de Docker y CI y elimina el conversor síncrono. Tampoco intenta convertir documentos aunque LibreOffice esté instalado en el equipo.

No se descargan archivos de oficina desde S3 al abrir su detalle ni al intentar obtener su vista previa. El listado y el detalle solo consultan metadatos. El texto lee un rango acotado. Los PDF continúan leyendo el original desde el almacenamiento al solicitar su contenido; esta tarjeta no añade una caché ni certifica pruebas de carga de ese flujo.

La conversión de oficina queda pendiente para una tarjeta posterior: procesar en segundo plano con concurrencia limitada y guardar el PDF generado, verificando los recursos y el aislamiento antes de habilitarla. El equipo debe validar que el alcance de B2 para esta entrega sea listado y detalle para todos los materiales, y vista previa para PDF y texto.

## Relación con B1 y otras tarjetas

La rama `feature/b2-ver-material` nace de `origin/Develop` en `fc1cf00`, sin incorporar commits de B1 ni de otras features pendientes.

`CourseMaterialsController` atiende las consultas de B2; `MaterialsController` queda disponible para el trabajo de B1. No se cambian el modelo Material, sus validaciones, el almacenamiento de originales, Gemfile.lock ni el esquema de la base.

Las rutas de lectura están en un bloque independiente para conservar las de subida de B1. La vista de sección mantiene el lugar de inserción del botón de B1. La comparación de tres versiones con B1 combina `config/routes.rb` y `app/views/sections/show.html.erb` sin conflictos y conserva tanto la subida como los enlaces de lectura.

Hay además un conflicto en `app/views/courses/show.html.erb` entre el botón de subida de B1 y el botón «Publicar anuncio» que ya está en Develop. Al integrar B1 se deben conservar ambos bloques, cada uno con su verificación de permisos. El equipo debe acordar el orden de integración; no se ha mergeado ninguna rama desde este trabajo.

B3, B4 y B5 conservan su alcance. El visor del navegador puede ofrecer guardar o imprimir el PDF mostrado; B2 no implementa la descarga dedicada del original. B5 debe completar y verificar sus propias reglas, incluidas las rutas estándar de Active Storage existentes en el proyecto.

## Verificación

```sh
bin/rails test test/integration/course_materials_test.rb test/integration/office_material_previews_test.rb test/services/material_preview_service_test.rb
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

Las pruebas cubren permisos y revocación de acceso, consultas cruzadas entre cursos y universidades, director y selector, PDF inline, texto escapado y truncado, archivos ausentes o falsificados y documentos de oficina rechazados sin descargar el archivo.

Las pruebas no necesitan LibreOffice. Se conserva un conjunto de documentos de prueba `.docx`, `.xlsx`, `.pptx` y `.odp` para verificar la presentación de sus datos y la ausencia de lecturas del almacenamiento.

Comprobaciones locales realizadas:

- B2: 33 pruebas y 410 aserciones, sin fallos, errores ni omisiones.
- Suite completa: 423 pruebas y 2.574 aserciones, sin fallos, errores ni omisiones.
- RuboCop: 212 archivos, sin infracciones.
- Brakeman: 0 errores y 0 advertencias de seguridad.
- Rutas combinadas en memoria con B1: listado, detalle y vista previa llegan a `CourseMaterialsController`; formulario y subida llegan a `MaterialsController`.
- PostgreSQL 18 temporal y las versiones exactas de Gemfile.lock; sin acceso a buckets reales ni a bases existentes.

El entorno disponible usa Ruby 4.0.0; se añadió `benchmark` únicamente a la ruta de carga del proceso de pruebas. CI debe verificar la versión 3.4.5 declarada en el proyecto. No se ha construido la imagen Docker actualizada: Docker Desktop no tiene integración con esta distribución WSL. Las mediciones de la imagen anterior compartidas por el revisor no se atribuyen a esta versión.

## Revisión y entrega

Abrir el PR hacia `Develop`, usar el template Feature y enlazar la tarjeta B2. La descripción preparada está en `docs/pull_requests/B2-ver-material.md`. Mantener En revisión hasta cumplir las aprobaciones y el release integrado en main, según la DoD del equipo.
