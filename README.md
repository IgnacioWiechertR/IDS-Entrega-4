# SGA · Sistema de Gestión Académica (Grupo 3)

Plataforma web para un directorio que administra dos universidades con datos aislados: la **Universidad Central del Valle (UCV)** y el **Instituto Universitario de Salud Austral (IUSA)**. Cada universidad ve solo sus cuentas, asignaturas, secciones, notas y asistencia. Roles: director, administrativo, profesor, ayudante y alumno.

Proyecto del curso Introducción a la Ingeniería de Software, Universidad de los Andes. El detalle de casos de uso, requisitos y su estado está en el informe de la Entrega 5; los cambios posteriores se registran en [docs/casos-de-uso.md](docs/casos-de-uso.md) y las decisiones técnicas en [docs/decisiones.md](docs/decisiones.md).

## Probar la aplicación

**Aplicación en producción:** https://sga-web-0yoo.onrender.com/

La aplicación corre en el plan gratuito de Render, que la suspende cuando no se usa: la primera carga puede tardar alrededor de un minuto.

### Cuenta de acceso

En producción la aplicación se entrega vacía: solo existen las dos universidades y la cuenta del **director** (`director@sga.test`). Su contraseña está en el *Manual de uso del SGA* (no se guarda en el repositorio). Desde esa cuenta se crean los administrativos, y ellos crean facultades, períodos, cursos, secciones y el resto de las cuentas; el manual describe la puesta en marcha paso a paso.

Los recorridos de abajo usan las cuentas y datos de demostración, que solo existen al correr la aplicación en local con `SEED_DEMO=1` (ver [Datos de demostración](#datos-de-demostración-solo-en-local)).

### Recorrido sugerido: el flujo de notas

La sección **ICC1001 · Programación, sección 1** (período 2026-2) tiene profesor, ayudante, tres alumnos inscritos y asistencia registrada. ANAT101 · Anatomía Humana en IUSA tiene el mismo recorrido con cuentas separadas.

T8 añade tres evaluaciones de ejemplo por sección: publicada, pendiente y rechazada, de 20 % cada una. Consulta la [guía de datos y demostración T8](docs/demo-t8.md) para cargar los datos y probar ambos roles.

1. **Ayudante** (`ayudante@ucv.test`): Mis cursos → Programación → **Evaluaciones** → **Nueva evaluación** (por ejemplo, "Control 1", 20 %). Luego **Ingresar notas**, escribe una nota entre 1.0 y 7.0 y un comentario, y presiona **Subir a revisión**.
2. **Profesor** (`profesor@ucv.test`): recibe el aviso en las notificaciones, y en la sección el botón **Evaluaciones** muestra una campana con la cantidad de notas pendientes de aprobación. En Evaluaciones → **Revisar notas** puede **Aceptar notas** (se publican) o **Rechazar notas** con un comentario obligatorio. Si las rechaza, el ayudante ve el comentario, corrige y vuelve a subirlas.
3. **Alumno** (`alumno@ucv.test`): en la pestaña **Notas** del curso, o en **Mis notas**, ve solo sus notas publicadas, con ponderación, comentario y pauta. Las notas pendientes o rechazadas no se le muestran.

### Qué probar con cada rol

- **Administrativo** (`admin@ucv.test`):
  - **Cuentas**: listar, buscar por nombre o RUT y filtrar por rol; **Crear cuenta** de alumno, ayudante o profesor. El RUT se valida con su dígito verificador, y el sistema muestra una contraseña temporal una sola vez.
  - **Editar** una cuenta (nombre, apellido, RUT y correo) y **Eliminar** una cuenta de su universidad, con confirmación. Eliminar la desactiva: la persona ya no puede iniciar sesión, pero la cuenta y sus notas siguen en la base de datos. **Reactivar** deshace una eliminación por error.
  - **Facultades** y **Períodos**: crear, editar y eliminar. Son la base de todo: un curso necesita una facultad y una sección necesita un período. Solo hay un período vigente por universidad, y una facultad con cursos o un período con secciones no se elimina.
  - **Cursos**: crear, editar y eliminar asignaturas y secciones.
  - **Syllabus**: en un curso, **Subir syllabus** (PDF, uno por curso y período). Desde que comienza el período ya no se puede reemplazar; si el curso no tenía, se puede subir una vez. Los datos demo no traen syllabus.
  - En una sección: **Gestionar alumnos** (inscribir) y **Gestionar ayudantes** (asignar).
  - **Asignar profesores** a secciones y **Asignar coordinadores** a cada asignatura por período.
  - Reportes: **Completitud** (qué le falta a cada sección) y **Notas** (estado de notas por sección, con el reporte consolidado y su exportación a CSV).
- **Profesor** (`profesor@ucv.test`): en su sección, **Marcar asistencia de hoy** y ver la tabla de asistencia; revisar notas (la campana del botón **Evaluaciones** indica cuántas hay pendientes) y aceptarlas o rechazarlas con comentario; ver todas las notas de la sección; subir, editar y eliminar su material; publicar, editar y eliminar anuncios. Como coordinador de ICC4204 e ICC1001 además sube el syllabus, crea secciones, gestiona ayudantes y asigna profesores en esas asignaturas.
- **Ayudante** (`ayudante@ucv.test`): crear evaluaciones e ingresar notas; ver la asistencia de su sección (no la marca).
- **Alumno** (`alumno@ucv.test`): en **Mis cursos**, cada curso muestra el syllabus y cuatro pestañas: **Resumen** (su promedio, su asistencia y el material), **Notas** (sus notas publicadas), **Asistencia** (porcentaje y detalle por clase) y **Anuncios** (los de la asignatura y los de su sección). También tiene **Mis notas** con todas sus notas.
- **Director** (`director@sga.test`): alterna entre UCV e IUSA con el selector y **ve todo en solo lectura**: dashboard, cuentas, cursos, syllabus, secciones (promedio y asistencia), evaluaciones, anuncios, coordinadores, facultades, períodos y los reportes de completitud, estado de notas y consolidado. No edita, asigna ni elimina nada, y no tiene notificaciones. Lo único que crea son **cuentas de administrativo** en la universidad activa (**Cuentas → Crear cuenta**).
- **Recuperar la contraseña** (cualquier rol): en el login, **¿Olvidaste tu contraseña?** envía un enlace al correo de la cuenta, válido por 2 horas. En local el correo se ve en http://localhost:3000/letter_opener. Si la cuenta estaba bloqueada por intentos fallidos, cambiar la contraseña la desbloquea.
- **Aislamiento entre universidades**: con `admin@iusa.test` no aparece nada de la UCV, y un enlace a un recurso de la otra universidad responde "no encontrado".

## Ejecutar en local

Requisitos: Ruby 3.4.13, PostgreSQL y Docker (para Redis, que usa Sidekiq).

```bash
bundle install
docker compose up -d                          # Redis (Valkey) para los trabajos en segundo plano
bin/rails db:prepare
SEED_DEMO=1 SEED_PASSWORD=una-clave bin/rails db:seed   # universidades, director y todos los datos demo con esa contraseña
bin/dev                                       # servidor, Tailwind y Sidekiq
```

Sin `SEED_DEMO=1` los seeds crean solo las dos universidades y la cuenta del director (`director@sga.test`, o el correo de `DIRECTOR_EMAIL`), con la contraseña de `SEED_PASSWORD`. Es lo que recibe el cliente en producción: desde el director se crean los administrativos, y ellos crean facultades, períodos, cursos, secciones y cuentas.

La aplicación queda en http://localhost:3000. En desarrollo los correos no se envían: se leen en http://localhost:3000/letter_opener. Los datos de demostración se pueden volver a cargar sin duplicarse. Las cuentas existentes conservan su contraseña y se respetan las notas y marcas de asistencia editadas. La contraseña indicada solo se asigna a cuentas nuevas.

### Datos de demostración (solo en local)

Con `SEED_DEMO=1` los seeds crean estas cuentas, todas con la contraseña de `SEED_PASSWORD`:

| Rol | Correo | Universidad |
|---|---|---|
| Director | `director@sga.test` | Ambas (elige la universidad con el selector de la barra superior) |
| Administrativo | `admin@ucv.test` | UCV |
| Administrativo | `admin@iusa.test` | IUSA |
| Profesor | `profesor@ucv.test` | UCV (coordina ICC4204 e ICC1001; dicta ICC4204-1, ICC1001-1 e ICC2002-1) |
| Ayudante | `ayudante@ucv.test` | UCV (ayudante de ICC1001-1 e ICC2002-1; alumno de MAT1001) |
| Alumno | `alumno@ucv.test` | UCV (ICC1001-1, MAT1001-1, ICC2002-1 y ECO1001-1) |
| Ayudante | `ayudante@iusa.test` | IUSA (ayudante de ANAT101-1) |
| Alumnos adicionales | `sofia@ucv.test`, `tomas@ucv.test` | UCV (ICC1001-1) |
| Alumnos | `alumno@iusa.test`, `lucas@iusa.test`, `isidora@iusa.test` | IUSA (ANAT101-1) |
| Profesora en ambas sedes | `camila.torres@ucv.test` y `camila.torres@iusa.test` | Una cuenta por universidad, con el mismo RUT |
| Cuentas generadas | `admin01`–`admin02`, `profesor01`–`profesor12`, `ayudante01`–`ayudante10`, `alumno001`–`alumno150` `@ucv.test` | UCV |
| Cuentas generadas | `admin01`–`admin02`, `profesor01`–`profesor10`, `ayudante01`–`ayudante08`, `alumno001`–`alumno120` `@iusa.test` | IUSA |

También generan volumen en ambas universidades (`db/seeds/demo_volume.rb`): 8 asignaturas en 3 facultades por universidad, secciones en 2026-2 y una sección cerrada en 2026-1 en cuatro asignaturas, evaluaciones con notas publicadas, pendientes y rechazadas, asistencia semanal con correcciones, anuncios del curso y de sección, material (archivos `.txt` de un carácter) y notificaciones. Algunas secciones quedan incompletas a propósito para el reporte de completitud (por ejemplo, ICC4204-2 sin profesor y HUM1001-2 sin alumnos). Uno de cada quince alumnos generados tiene la cuenta eliminada (`alumno015`, `alumno030`, ...): no entra, pero conserva su historial de 2026-1. `SEED_ALUMNOS` cambia cuántos alumnos se generan por universidad. No existen entregas de tareas: las tareas son evaluaciones con nota.

## Correo

La aplicación envía correos para recuperar la contraseña. En producción salen por la **API HTTP de Brevo** (`lib/brevo_delivery.rb`), porque el plan gratuito de Render bloquea los puertos SMTP y no tenemos dominio propio (ver [docs/decisiones.md](docs/decisiones.md)). Se envían en segundo plano con Sidekiq, que los reintenta si Brevo falla.

| Variable | Ejemplo | Para qué |
|---|---|---|
| `BREVO_API_KEY` | `xkeysib-...` | Clave de la API de Brevo. Solo en producción. |
| `MAILER_FROM` | `SGA <sga.g3.noreply@gmail.com>` | Remitente de los correos. Debe ser un *sender* verificado en Brevo. |
| `APP_HOST` | `sga-web-0yoo.onrender.com` | Dominio de los enlaces de los correos, sin `https://`. Si falta, se usa el que Render asigna al servicio (`RENDER_EXTERNAL_HOSTNAME`). |

Las tres están en `render.yaml` con `sync: false`: se cargan a mano en Render (**sga-web → Environment**). En desarrollo y en test no hacen falta.

**Configurar Brevo** (una sola vez; los menús están en **Settings**, con la interfaz en español):

1. Crea una cuenta gratuita en https://www.brevo.com (300 correos diarios) y completa el perfil.
2. **Verifica el remitente**: en **Remitentes, dominio, IP**, agrega un remitente con el nombre `SGA` y el correo `sga.g3.noreply@gmail.com`. Brevo envía un código a ese correo; ingrésalo para verificarlo. Sin dominio propio, este es el único paso de verificación.
3. **Genera la clave de API**: en **SMTP y API**, pestaña de claves API, genera una clave nueva (por ejemplo `sga-render`). Cópiala al crearla, porque Brevo no la vuelve a mostrar. Es una clave de API (`xkeysib-...`), no la clave SMTP.
4. **Deja desactivado el bloqueo de IP**: en **Seguridad → IP autorizadas**, "Bloqueando direcciones IP no autorizadas" debe quedar **Desactivada** para **Claves API**. Render (plan gratuito) no tiene una IP de salida fija: con el bloqueo activo, Brevo rechaza los envíos con un error 401.
5. En Render, define `BREVO_API_KEY` con esa clave, `MAILER_FROM` con el remitente verificado (`SGA <sga.g3.noreply@gmail.com>`) y `APP_HOST` con el dominio del servicio. Guardar redespliega la aplicación.
6. Prueba con **¿Olvidaste tu contraseña?** en el login, con una cuenta cuyo correo exista de verdad. Los envíos y sus errores se ven en los registros de correos transaccionales de Brevo. Si Brevo rechaza un correo, el error (`BrevoDelivery::Error` con el código de respuesta) queda en los logs del servicio y Sidekiq lo reintenta: un 401 suele ser la clave o el bloqueo de IP, y un 400, un remitente sin verificar o distinto de `MAILER_FROM`.

Sin dominio propio algunos correos pueden llegar a spam: conviene revisar esa carpeta en la primera prueba.

## Tests y cobertura

Los tests usan Minitest (el framework de Rails) y la cobertura se mide con [SimpleCov](https://github.com/simplecov-ruby/simplecov). Requisitos: los mismos de "Ejecutar en local" (Ruby 3.4.13, `bundle install` y PostgreSQL corriendo). No hace falta Redis: los trabajos en segundo plano usan el adaptador de pruebas.

```bash
bin/rails db:test:prepare   # crea o actualiza la base de datos de pruebas (solo la primera vez o tras una migración)
bin/rails test              # corre todos los tests y genera el reporte de cobertura
bin/rubocop                 # estilo
bin/brakeman --no-pager     # seguridad
```

**Cómo obtener la cobertura.** `bin/rails test` mide la cobertura automáticamente. Al terminar imprime el resumen en la terminal y deja el reporte completo en `coverage/index.html`:

```
Line coverage: 1961 / 2109 (92.98%)
Branch coverage: 568 / 680 (83.52%)
```

- Abre `coverage/index.html` en el navegador para ver el porcentaje por archivo y las líneas sin cubrir (en rojo). Los archivos están agrupados en controladores, modelos, servicios, policies, jobs y helpers.
- Se mide la cobertura de **líneas** y de **ramas** (cada `if`/`else` por separado).
- El dato es de la suite completa: si corres un solo archivo (`bin/rails test test/models/grade_test.rb`), el reporte refleja solo ese archivo.
- La carpeta `coverage/` se genera en cada ejecución y no se sube al repositorio.

**Cobertura actual** (23-nov-2026, 849 tests): **92,99 % de líneas** y **83,87 % de ramas**.

La integración continua (GitHub Actions) corre los tests, RuboCop y Brakeman en cada pull request.

## Stack

Rails 8.1 · Ruby 3.4.13 · PostgreSQL · Devise (inicio de sesión y recuperación de contraseña) · Brevo (correo) · CanCanCan (permisos por rol) · acts_as_tenant (aislamiento por universidad) · Tailwind CSS · Turbo · Active Job con Sidekiq y Redis · Docker · Render.
