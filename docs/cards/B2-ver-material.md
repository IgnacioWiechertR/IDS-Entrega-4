# B2 · Ver material del curso

Épica 2: Gestionar la actividad académica de un curso.

## Historia y criterios

Como integrante de un curso autorizado, quiero consultar el material académico y ver su contenido dentro de la aplicación.

- Acceso al material desde el curso y desde sus secciones.
- Listado del curso, ordenado por fecha de publicación descendente y por ID descendente en caso de empate.
- Detalle con título, nombre del archivo, tamaño y fecha de publicación.
- Vista previa del contenido, confirmada por la usuaria para B2.
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
- Word, Excel, PowerPoint, RTF, OpenDocument y documentos de oficina equivalentes: se solicita una conversión local a PDF mediante LibreOffice. Se contemplan `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx`, `.pps`, `.ppsx`, `.rtf`, `.odt`, `.ods`, `.odp`, `.pages`, `.numbers` y `.key`.
- Google Docs, Sheets y Slides se consultan a partir de sus archivos exportados, igual que en B1.
- La compatibilidad de documentos de oficina depende de los filtros de LibreOffice. Documentos cifrados, dañados o variantes no compatibles muestran un mensaje; no se promete fidelidad exacta del formato original.

Los documentos se procesan en un directorio temporal privado y se eliminan al terminar. Cada conversión usa un perfil independiente con ejecución de macros y contenido activo desactivados, un máximo de 30 segundos y un máximo de 50 MB para el PDF generado. La vista previa admite originales de hasta 50.000.000 bytes, alineado con B1. No se guarda un nuevo adjunto ni se modifica el original.

Las respuestas de B2 llevan `Cache-Control: private, no-store`. El contenido se sirve desde una ruta autenticada de la aplicación; B2 no entrega URLs firmadas de Active Storage ni URLs del bucket a visores externos.

## Instalación

Docker y CI incluyen los paquetes del conversor. En desarrollo sin Docker, instalar LibreOffice Writer, Calc e Impress y fuentes compatibles. En Ubuntu/Debian:

```sh
sudo apt-get update
sudo apt-get install --no-install-recommends libreoffice-writer libreoffice-calc libreoffice-impress fonts-liberation
```

Por defecto se ejecuta `libreoffice`, disponible en PATH. Se puede configurar `LIBREOFFICE_PATH` con la ruta al ejecutable. PDF y texto funcionan sin LibreOffice; los documentos de oficina requieren el conversor. Sin él, se muestra un error controlado.

La conversión se realiza al solicitar la vista previa, sin Redis ni trabajadores adicionales. Cada apertura de un documento de oficina vuelve a convertirlo. No se ha probado carga simultánea de múltiples conversiones; la caché o una cola de conversiones pueden abordarse si el volumen lo requiere.

## Relación con B1 y otras tarjetas

La rama `feature/b2-ver-material` nace de `origin/Develop` en `fc1cf00`, sin incorporar commits de B1 ni de otras features pendientes.

`CourseMaterialsController` atiende las consultas de B2; `MaterialsController` queda disponible para el trabajo de B1. No se cambian el modelo Material, sus validaciones, el almacenamiento de originales, Gemfile.lock ni el esquema de la base.

Al integrar B1 y B2, mantener las rutas de subida dirigidas a `MaterialsController` y las de lectura a `CourseMaterialsController`. Mantener también el botón de subida de B1 junto al nuevo listado compartido de B2 en la sección. Las ramas tocan esa zona de la vista y el bloque de rutas, por lo que podrían necesitar resolución de conflictos al integrarlas.

B3, B4 y B5 conservan su alcance. El visor del navegador puede ofrecer guardar o imprimir el PDF mostrado; B2 no implementa la descarga dedicada del original. B5 debe completar y verificar sus propias reglas, incluidas las rutas estándar de Active Storage existentes en el proyecto.

## Verificación

```sh
bin/rails test test/integration/course_materials_test.rb test/integration/office_material_previews_test.rb test/services/material_preview_service_test.rb test/services/office_preview_service_test.rb
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

Las pruebas cubren permisos y revocación de acceso, consultas cruzadas entre cursos y universidades, director y selector, PDF inline, texto escapado y truncado, archivos ausentes o falsificados, fallo y timeout del conversor y conversiones reales de `.docx`, `.xlsx`, `.pptx` y `.odp`.

Para ejecutar las pruebas de conversión se necesita LibreOffice. Se instala explícitamente en el job de pruebas de CI; esas pruebas fallan si falta el conversor.

Comprobaciones locales realizadas:

- B2: 37 pruebas y 352 aserciones, sin fallos, errores ni omisiones.
- Suite completa: 427 pruebas y 2.516 aserciones, sin fallos, errores ni omisiones.
- RuboCop: 214 archivos, sin infracciones.
- Brakeman: 0 errores y 0 advertencias de seguridad.
- Conversiones reales con LibreOffice 24.2.7.2, usando documentos Word, Excel, PowerPoint y OpenDocument.
- PostgreSQL 18 temporal y las versiones exactas de Gemfile.lock; sin acceso a buckets reales ni a bases existentes.

El entorno disponible usa Ruby 4.0.0; se añadió `benchmark` únicamente a la ruta de carga del proceso de pruebas. CI debe verificar la versión 3.4.5 declarada en el proyecto. No se ha construido la imagen Docker completa en este entorno.

Referencia del conversor: [parámetros oficiales de LibreOffice](https://help.libreoffice.org/latest/en-GB/text/shared/guide/start_parameters.html).

## Revisión y entrega

Abrir el PR hacia `Develop`, usar el template Feature y enlazar la tarjeta B2. La descripción preparada está en `docs/pull_requests/B2-ver-material.md`. Mantener En revisión hasta cumplir las aprobaciones y el release integrado en main, según la DoD del equipo.
