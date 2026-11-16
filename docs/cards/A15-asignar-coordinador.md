# A15 · Asignar coordinador

Épica 1: Administrar la institución.

## Historia de usuario

Como administrativo de una universidad o director del sistema, quiero asignar un profesor como coordinador de una asignatura y período para registrar su responsabilidad y habilitar su acceso a la coordinación del curso.

## Reglas confirmadas

- El administrativo asigna dentro de su propia universidad.
- El director puede asignar en ambas universidades, utilizando el selector de universidad activa existente.
- El coordinador es un profesor de la universidad de la asignatura.
- El período pertenece a la misma universidad.
- La universidad y la persona que realiza la asignación se determinan en el servidor.

## Decisión pendiente: cantidad de coordinadores

El grupo aún no ha confirmado si una asignatura admite uno o varios coordinadores por período. A15 no declara ni añade una regla de coordinador único.

Sin embargo, Develop ya contiene la validación de unicidad de `CourseCoordinator` y el índice único `(course_id, term_id)` introducidos por T7. Este cambio conserva esas restricciones para no decidir ni migrar datos sin el acuerdo del grupo. Por eso, con la base actual, una segunda asignación para el mismo curso y período es rechazada y se informa sin reemplazar los datos existentes.

La vista agrupa y muestra las asignaciones por asignatura y mantiene disponible el formulario para otros profesores. Cuando el grupo confirme la cardinalidad, debe revisar la validación y el índice heredados junto con sus pruebas y las vistas del catálogo que hoy muestran un coordinador. Esa decisión sigue pendiente antes de considerar A15 terminada según la DoR/DoD del equipo.

## Criterios implementados

1. Director y administrativo acceden desde «Asignar coordinadores» en el menú.
2. La pantalla muestra asignaturas, profesores y períodos de la universidad activa; para el administrativo siempre es su propia universidad.
3. Al seleccionar un profesor y confirmar, la asignación se guarda con universidad, asignatura, período y autor, y aparece al volver a consultar la pantalla.
4. El director cambia de universidad con el selector existente y puede realizar una asignación allí sin cruzar instituciones.
5. Se rechazan asignaturas, profesores y períodos de otra universidad, incluso enviando IDs directamente.
6. No se pueden seleccionar cuentas que no sean profesores. Profesor, ayudante, alumno y visitantes sin sesión no pueden realizar esta operación.
7. Las asignaciones se consultan por período y conservan su historial.
8. El profesor encuentra el curso que coordina en «Mis cursos», utilizando los permisos ya implementados en Develop.
9. No se habilitan edición ni eliminación a través del scaffold anterior. Una asignación fallida no reemplaza registros existentes.

## Implementación y base

Rama: `feature/asignar-coordinador`, creada desde Develop. No incorpora cambios pendientes de otras ramas.

- Se reemplaza la pantalla scaffold de `/course_coordinators` por una pantalla de consulta y asignación por período.
- Las únicas acciones habilitadas son `index` y `create`, con su política de CanCanCan.
- Se reutilizan el modelo, los contratos de aislamiento de A3, los períodos y la infraestructura de T7. No se agrega ninguna migración.
- Se valida que el autor sea el director o un administrativo de la universidad correspondiente.
- Se agregan pruebas de modelo e integración y se actualiza el test que antes cerraba el scaffold para todos los roles.

## Validación

Con PostgreSQL configurado y las dependencias instaladas:

```sh
bin/rails test test/models/coordinator_assignment_test.rb test/integration/coordinator_assignments_test.rb
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

Antes de completar la tarjeta, confirmar la cardinalidad pendiente, revisar sus criterios de aceptación, obtener las aprobaciones de la DoD y llevar el release a main. El PR debe señalar expresamente esa decisión pendiente.

## Comprobaciones realizadas al preparar la rama

- Pruebas específicas de A15: 23 pruebas y 142 aserciones, sin fallos ni errores.
- Suite completa: 297 pruebas y 1.503 aserciones, sin fallos ni errores.
- RuboCop: 191 archivos inspeccionados, sin infracciones.
- Brakeman: sin advertencias de seguridad.
- Se utilizaron las dependencias exactas de Gemfile.lock y PostgreSQL 18 temporal.
- El entorno disponible usa Ruby 4.0.0; para la suite general se añadió la biblioteca instalada `benchmark` a la ruta de carga del proceso de pruebas, sin cambiar Gemfile ni otras tarjetas. La validación con Ruby 3.4.5, declarado por el proyecto, queda para CI o un entorno con esa versión.
