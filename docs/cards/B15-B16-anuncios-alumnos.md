# B15 y B16 · Notificar y consultar anuncios como alumno

Épica 2: Gestionar la actividad académica de un curso.

Rama: `feature/b15-b16-anuncios-alumnos`, creada desde `origin/Develop` en `ebd2a47`.

## Historias y requisitos

- B15: como alumno inscrito, quiero recibir un aviso interno cuando mi profesor publique un anuncio dirigido a mi sección o a toda la asignatura, para enterarme y abrirlo desde mi buzón.
- B16: como alumno inscrito, quiero consultar los anuncios generales de mis asignaturas y los de mis secciones, para recibir información sin acceder a mensajes destinados a otros alumnos.

Corresponde a los casos de uso 4 y 13 de los informes: notificar a los inscritos, distribuir mensajes por sección y ofrecer novedades según el perfil. Se utilizan las notificaciones internas y la cola Redis/Sidekiq ya existentes.

## Reglas y criterios de aceptación

1. El alumno con matrícula activa encuentra «Anuncios» en el menú. El listado muestra asunto, asignatura, destinatarios, autor y fecha, del más reciente al más antiguo. Desde el asunto abre el contenido completo.
2. Un anuncio de sección se muestra únicamente a sus alumnos activos. Un anuncio de toda la asignatura se muestra a alumnos activos de cualquiera de sus secciones. Los permisos existentes del equipo docente y coordinadores de B12 se conservan.
3. Una cuenta con rol ayudante también puede recibir anuncios como estudiante de otra asignatura; ser ayudante en otro curso no amplía su acceso en el curso donde estudia.
4. Los anuncios de otra sección, asignatura o universidad no aparecen en el listado del alumno y no se pueden abrir manipulando IDs. Las matrículas inactivas no conceden acceso.
5. Después de guardar una publicación válida, el servidor encola un trabajo con universidad, anuncio e IDs de los destinatarios inscritos en ese momento. El formulario no puede elegir destinatarios arbitrarios ni sustituir autor o universidad.
6. El anuncio ya es consultable mientras se procesa la cola. No se espera a la entrega del aviso para mostrarlo.
7. El trabajo vuelve a comprobar matrículas y universidad antes de crear las notificaciones. No avisa a quienes se retiraron antes de su ejecución ni añade alumnos inscritos después de publicar.
8. Cada alumno recibe como máximo un aviso por anuncio, aunque tenga más de una matrícula del curso o el trabajo se reintente. Un reintento no cambia el estado leído de un aviso existente.
9. El buzón muestra un enlace interno al anuncio y el contador refleja los avisos visibles sin leer. Si se revoca el acceso, se ocultan el aviso y su contador y el enlace guardado deja de abrir el anuncio. Al abrir el buzón, se marcan como leídos sus avisos visibles, como en C12.
10. El alumno conserva permisos de lectura: no puede publicar, editar ni eliminar anuncios. El contenido se escapa en anuncios y notificaciones; las respuestas llevan `Cache-Control: private, no-store`.
11. Una publicación inválida o no autorizada no crea anuncios ni encola avisos. Si el anuncio se elimina, se eliminan sus notificaciones; un trabajo retrasado no las recrea.

## Implementación

- `Announcement.readable_by` filtra anuncios en SQL para el listado, el detalle, el permiso de lectura del estudiante y la visibilidad del aviso.
- `Announcement#student_recipients` selecciona cuentas de alumno o ayudante con matrícula activa en la sección o asignatura correspondiente, dentro de la misma universidad.
- `AnnouncementPublishedNotificationJob` se ejecuta en la cola `default`. Recibe IDs y establece el tenant antes de buscar el anuncio, por lo que puede ejecutarse sin universidad activa y descarta de forma segura registros ya eliminados.
- `Notification.visible_to` limita los resultados al destinatario y a anuncios que todavía puede consultar. El buzón y el contador comparten esta consulta. Las notificaciones de notas existentes siguen funcionando sin referencia a un anuncio.

La migración `20261117090000_add_announcement_to_notifications.rb` añade `announcement_id` nullable, su clave foránea y un índice único por anuncio y destinatario. El vínculo permite generar enlaces internos y evitar duplicados también en la base de datos. Las notificaciones anteriores conservan sus datos.

## Ejecución y revisión

Antes de probar localmente:

```sh
bin/rails db:migrate
```

Para recibir los avisos, Redis y el worker de Sidekiq deben estar funcionando y consumir `default`; en Render se reutiliza Sidekiq embebido. Se trata de notificaciones dentro del portal, consultables al cargar la página, sin añadir correo ni otro servicio externo.

La rama es independiente de la corrección de asistencia y de B13. Se comprobó B13 junto a B15/B16 en una exportación temporal: sus cambios se combinaron sin conflictos de texto y pasaron las pruebas de edición, lectura y notificación. Esa verificación no incorpora B13 a esta rama ni reemplaza CI y la revisión del merge real.

## Validación

- Suite completa: **649 pruebas y 4.241 aserciones**, sin fallos, errores ni omisiones.
- Compatibilidad temporal con B13: **61 pruebas y 356 aserciones**, sin fallos, errores ni omisiones.
- RuboCop: **260 archivos**, sin infracciones.
- Brakeman: **0 errores y 0 advertencias de seguridad**.
- Migración, rollback y reaplicación comprobados en PostgreSQL temporal: se conservaron las notificaciones existentes y el esquema final coincidió con el verificado.
- `git diff --check`: sin errores.

Se utilizaron Ruby 4.0.0, Rails 8.1.4.1, las dependencias de `Gemfile.lock` y PostgreSQL 18 temporal. Para la suite en Ruby 4 se añadió la biblioteca `benchmark` instalada a la ruta de carga del proceso, sin cambiar dependencias. CI debe verificar Ruby 3.4.5, declarado por el proyecto. No se utilizaron bases de desarrollo, producción ni usuarios reales.

## Preparar el PR

Agregar los enlaces a las tarjetas B15 y B16 y revisar sus criterios con el equipo. La descripción preparada está en `docs/pull_requests/B15-B16-anuncios-alumnos.md`.

Para guardar y subir los archivos de esta funcionalidad:

```sh
git add app/controllers/announcements_controller.rb app/controllers/application_controller.rb app/controllers/notifications_controller.rb
git add app/models/announcement.rb app/models/notification.rb app/policies/announcement_policy.rb app/jobs/announcement_published_notification_job.rb
git add app/views/layouts/application.html.erb app/views/notifications/index.html.erb
git add db/migrate/20261117090000_add_announcement_to_notifications.rb db/schema.rb
git add test/integration/announcements_read_test.rb test/integration/student_announcements_test.rb test/integration/announcement_notifications_test.rb
git add test/jobs/announcement_published_notification_job_test.rb test/models/announcement_notification_test.rb test/support/announcement_delivery_data.rb
git add docs/cards/B15-B16-anuncios-alumnos.md docs/pull_requests/B15-B16-anuncios-alumnos.md
git commit -m "feat(anuncios): notificar y mostrar anuncios a alumnos [B15][B16]"
git push -u origin feature/b15-b16-anuncios-alumnos
```

Abrir el PR con base `Develop` y compare `feature/b15-b16-anuncios-alumnos`. Mantener las tarjetas en revisión hasta cumplir las aprobaciones y el release a main exigidos por la DoD.
