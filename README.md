# SGA · Sistema de Gestión Académica (Grupo 3)

Plataforma web para un directorio que administra dos universidades con datos aislados: la **Universidad Central del Valle (UCV)** y el **Instituto Universitario de Salud Austral (IUSA)**. Cada universidad ve solo sus cuentas, asignaturas, secciones, notas y asistencia. Roles: director, administrativo, profesor, ayudante y alumno.

Proyecto del curso Introducción a la Ingeniería de Software, Universidad de los Andes. El detalle de casos de uso, requisitos y su estado está en el informe de la Entrega 5.

## Probar la aplicación

**Aplicación en producción:** <URL_DE_RENDER>

La aplicación corre en el plan gratuito de Render, que la suspende cuando no se usa: la primera carga puede tardar alrededor de un minuto.

### Cuentas de demostración

Todas usan la misma contraseña, que se entrega junto con el informe (no se guarda en el repositorio).

| Rol | Correo | Universidad |
|---|---|---|
| Director | `director@sga.test` | Ambas (elige la universidad con el selector de la barra superior) |
| Administrativo | `admin@ucv.test` | UCV |
| Administrativo | `admin@iusa.test` | IUSA |
| Profesor | `profesor@ucv.test` | UCV (coordina ICC4204 y dicta ICC4204-1 e ICC1001-1) |
| Ayudante | `ayudante@ucv.test` | UCV (ayudante de ICC1001-1) |
| Alumno | `alumno@ucv.test` | UCV (inscrito en ICC1001-1) |
| Ayudante | `ayudante@iusa.test` | IUSA (ayudante de ANAT101-1) |
| Alumnos adicionales | `sofia@ucv.test`, `tomas@ucv.test` | UCV (ICC1001-1) |
| Alumnos | `alumno@iusa.test`, `lucas@iusa.test`, `isidora@iusa.test` | IUSA (ANAT101-1) |
| Profesora en ambas sedes | `camila.torres@ucv.test` y `camila.torres@iusa.test` | Una cuenta por universidad, con el mismo RUT |

### Recorrido sugerido: el flujo de notas

La sección **ICC1001 · Programación, sección 1** (período 2026-2) tiene profesor, ayudante, tres alumnos inscritos y asistencia registrada. ANAT101 · Anatomía Humana en IUSA tiene el mismo recorrido con cuentas separadas.

T8 añade tres evaluaciones de ejemplo por sección: publicada, pendiente y rechazada, de 20 % cada una. Consulta la [guía de datos y demostración T8](docs/demo-t8.md) para cargar los datos y probar ambos roles.

1. **Ayudante** (`ayudante@ucv.test`): Mis cursos → Programación → **Evaluaciones** → **Nueva evaluación** (por ejemplo, "Control 1", 20 %). Luego **Ingresar notas**, escribe una nota entre 1.0 y 7.0 y un comentario, y presiona **Subir a revisión**.
2. **Profesor** (`profesor@ucv.test`): recibe el aviso en las notificaciones. En la sección → Evaluaciones → **Revisar notas**. Puede **Aceptar notas** (se publican) o **Rechazar notas** con un comentario obligatorio. Si las rechaza, el ayudante ve el comentario, corrige y vuelve a subirlas.
3. **Alumno** (`alumno@ucv.test`): en **Mis notas** ve solo sus notas publicadas, con ponderación, comentario y pauta. Las notas pendientes o rechazadas no se le muestran.

### Qué probar con cada rol

- **Administrativo** (`admin@ucv.test`):
  - **Cuentas**: listar, buscar por nombre o RUT y filtrar por rol; **Crear cuenta** de alumno, ayudante o profesor. El RUT se valida con su dígito verificador, y el sistema muestra una contraseña temporal una sola vez.
  - **Cursos**: crear, editar y eliminar asignaturas y secciones.
  - En una sección: **Gestionar alumnos** (inscribir) y **Gestionar ayudantes** (asignar).
  - **Asignar profesores** a secciones.
- **Profesor** (`profesor@ucv.test`): en su sección, **Marcar asistencia de hoy** y ver la tabla de asistencia; revisar y aprobar notas; ver todas las notas de la sección.
- **Ayudante** (`ayudante@ucv.test`): crear evaluaciones e ingresar notas; ver la asistencia de su sección (no la marca).
- **Alumno** (`alumno@ucv.test`): **Mis notas** y **Asistencia** (porcentaje y detalle por clase).
- **Director** (`director@sga.test`): alterna entre UCV e IUSA con el selector y ve cursos y secciones en solo lectura, con el promedio y la asistencia de cada sección.
- **Aislamiento entre universidades**: con `admin@iusa.test` no aparece nada de la UCV, y un enlace a un recurso de la otra universidad responde "no encontrado".

## Ejecutar en local

Requisitos: Ruby 3.4.5, PostgreSQL y Docker (para Redis, que usa Sidekiq).

```bash
bundle install
docker compose up -d                          # Redis (Valkey) para los trabajos en segundo plano
bin/rails db:prepare
SEED_PASSWORD=una-clave bin/rails db:seed     # crea las universidades, cursos y cuentas demo con esa contraseña
bin/dev                                       # servidor, Tailwind y Sidekiq
```

La aplicación queda en http://localhost:3000. Los datos de demostración se pueden volver a cargar sin duplicarse. Las cuentas existentes conservan su contraseña y se respetan las notas y marcas de asistencia editadas. La contraseña indicada solo se asigna a cuentas nuevas.

## Tests

```bash
bin/rails test           # tests de modelos, servicios e integración
bin/rubocop              # estilo
bin/brakeman --no-pager  # seguridad
```

La integración continua (GitHub Actions) corre los tres en cada pull request.

## Stack

Rails 8.1 · Ruby 3.4.5 · PostgreSQL · Devise (inicio de sesión) · CanCanCan (permisos por rol) · acts_as_tenant (aislamiento por universidad) · Tailwind CSS · Turbo · Active Job con Sidekiq y Redis · Docker · Render.
