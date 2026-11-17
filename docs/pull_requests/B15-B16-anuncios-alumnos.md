# feat(anuncios): notificar y mostrar anuncios a alumnos [B15][B16]

Feature → Develop

Rama: `feature/b15-b16-anuncios-alumnos` → `Develop`

## Necesidad

Los profesores ya publican anuncios, pero un alumno que solo está inscrito no puede consultarlos ni recibe una notificación. Se necesita completar la entrega al alumno respetando sección, asignatura y universidad, como establecen los casos de uso 4 y 13.

## Solución

- El alumno con matrícula activa accede a «Anuncios», consulta los anuncios generales de sus asignaturas y los dirigidos a su sección y abre su contenido completo. Los anuncios ajenos quedan fuera del listado y del acceso por ID.
- Al publicar, se encola una notificación interna con los destinatarios calculados por el servidor. El trabajo revalida matrículas y universidad antes de entregar y evita duplicados por reintentos o varias matrículas del mismo alumno.
- El aviso enlaza al anuncio. El buzón y el contador ocultan avisos de anuncios cuyo acceso fue revocado. Los permisos de lectura se comprueban nuevamente al abrir el enlace.
- Se conserva el acceso del equipo docente de B12 y las notificaciones de notas existentes. Los alumnos no obtienen permisos para publicar, editar ni eliminar.

Se añade una migración con `notifications.announcement_id` nullable, clave foránea e índice único por anuncio y destinatario, compatible con las notificaciones anteriores. Debe ejecutarse `bin/rails db:migrate`. La entrega utiliza Redis/Sidekiq y la cola `default` existentes; el anuncio es consultable antes de que el trabajo entregue su aviso.

## Verificación

- Suite completa: **649 pruebas y 4.241 aserciones**, sin fallos, errores ni omisiones.
- Exportación temporal con B13: **61 pruebas y 356 aserciones**, sin fallos, errores ni omisiones. No se incorporaron sus commits a esta rama.
- RuboCop: **260 archivos**, sin infracciones.
- Brakeman: **0 errores y 0 advertencias de seguridad**.
- Migración, rollback y reaplicación: conserva avisos existentes y restaura el esquema esperado.
- `git diff --check`: sin errores.

Se comprueban publicación → trabajo → buzón → enlace → anuncio, segmentación entre secciones, anuncios generales, ambas universidades, matrículas inactivas, revocación de acceso, IDs manipulados, reintentos, texto escapado y compatibilidad con B11/B12 y notificaciones de notas.

Comandos de pruebas:

```sh
RAILS_ENV=test bin/rails db:test:prepare
bin/rails test test/integration/student_announcements_test.rb test/integration/announcement_notifications_test.rb test/jobs/announcement_published_notification_job_test.rb test/models/announcement_notification_test.rb
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

Validación local con Ruby 4.0.0, Rails 8.1.4.1, dependencias de `Gemfile.lock` y PostgreSQL 18 temporal. Para Ruby 4 se añadió `benchmark` a la ruta de carga del proceso sin cambiar dependencias. CI debe verificar Ruby 3.4.5, declarado por el proyecto. No se modificaron datos de desarrollo o producción.

## Tarjeta relacionada

- B15 · Notificar anuncio nuevo: **agregar enlace a Trello**.
- B16 · Consultar anuncios como alumno: **agregar enlace a Trello**.

## Checklist

- [x] La rama nace de Develop, no de main.
- [x] Verifiqué el recorrido de publicación, notificación y lectura con pruebas de integración.
- [x] Verifiqué que no rompí otra cosa mediante la suite completa.
- [x] Se respetan los permisos por rol y el aislamiento por university_id.
- [x] Verifiqué la migración y su reversión con datos de prueba.
- [ ] Agregué los enlaces a Trello y confirmé todos los criterios de aceptación de ambas tarjetas.
- [ ] Los commits siguen Conventional Commits.
- [ ] El PR cuenta con las aprobaciones acordadas por el equipo.

## Después de mergear

- [ ] Marcar ambas tarjetas con la etiqueta «Merge a develop».
- [ ] Mantenerlas en En revisión hasta que su release llegue a main.
- [ ] Borrar la rama feature/b15-b16-anuncios-alumnos.
