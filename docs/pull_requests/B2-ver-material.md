Feature → Develop

Rama: feature/b2-ver-material → Develop

## Necesidad

Permitir consultar el material académico y obtener una vista previa de su contenido desde el curso o sección, respetando el acceso por rol y universidad.

## Solución

- Listado del material del curso, del más reciente al más antiguo.
- Detalle con título, archivo, tamaño y fecha de publicación.
- Visor de PDF y texto.
- Los documentos de oficina muestran su detalle y un aviso de vista previa no disponible, sin descargar su contenido desde S3 ni ejecutar conversiones.
- Cada solicitud de contenido verifica sesión, acceso al curso y universidad activa.
- Mensajes para material ausente, documentos dañados o formatos no compatibles.
- Docker y CI sin LibreOffice; se retira el conversor síncrono para evitar el agotamiento de memoria observado durante la revisión del equipo.

La rama nace de Develop y no incluye los commits pendientes de B1. Las rutas de consulta usan un controlador y un bloque independientes. La combinación de `routes.rb` y `sections/show.html.erb` con B1 se comprobó sin conflictos. Al integrar B1 también se deben conservar los botones «Subir material» y «Publicar anuncio» del curso, cada uno con su permiso; ese conflicto con Develop ya existe en la cabecera de `courses/show.html.erb`.

La vista previa de documentos de oficina queda pendiente para una tarjeta posterior con procesamiento en segundo plano, concurrencia limitada y PDF persistido. El equipo debe validar el alcance PDF/texto para esta entrega. B3, B4 y la descarga dedicada del original de B5 conservan su alcance.

## Verificación

- B2: 33 pruebas y 410 aserciones, sin fallos y sin LibreOffice, incluida la comprobación de que los documentos de oficina no descargan contenido desde el almacenamiento.
- Suite completa: 423 pruebas y 2.574 aserciones, sin fallos, errores ni omisiones.
- RuboCop: 212 archivos, sin infracciones. Brakeman: 0 errores y 0 advertencias de seguridad.
- Rutas combinadas con B1 comprobadas en memoria: lectura en `CourseMaterialsController`, formulario y subida en `MaterialsController`.
- Entorno local: Ruby 4.0.0 y PostgreSQL 18. CI debe verificar Ruby 3.4.5, declarado en el proyecto.
- No se pudo construir la imagen actualizada: Docker Desktop no tiene integración con esta distribución WSL. Las pruebas de Docker compartidas por el revisor corresponden a la versión anterior.
- Detalles y requisitos de ejecución: `docs/cards/B2-ver-material.md`.

## Tarjeta relacionada

B2 · Ver material del curso

**Reemplazar esta línea por el enlace a la tarjeta de Trello antes de abrir el PR.**

## Checklist

- [x] La rama nace de Develop, no de main
- [ ] El equipo valida el alcance de esta entrega: vista previa PDF/texto; documentos de oficina con listado y detalle
- [x] Verifiqué que la funcionalidad opera correctamente
- [x] Verifiqué que no rompí otra cosa mediante la suite completa
- [x] Se respetan los permisos por rol y el aislamiento por university_id
- [x] Los commits siguen Conventional Commits
- [ ] El PR cuenta con las aprobaciones acordadas por el equipo

## Después de mergear

- [ ] Marcar la tarjeta con la etiqueta “Merge a develop”
- [ ] Mantener la tarjeta en En revisión hasta que su release llegue a main
- [ ] Borrar la rama feature/b2-ver-material
