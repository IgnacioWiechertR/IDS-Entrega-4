# A22 · Asignar profesor a sección

Épica 1: Administrar la institución.

## Historia de usuario

Como administrativo de una universidad, quiero asignar un profesor de mi institución a una sección para registrar quién estará a cargo de su docencia.

Como profesor coordinador de una asignatura, quiero asignar un profesor a una sección de mi asignatura para que pueda dictarla y gestionar su material, asistencia, anuncios y notas.

## Reglas confirmadas

- Pueden asignar el administrativo de la misma universidad y el profesor coordinador de la asignatura (tarjeta A22 del Trello).
- El coordinador asigna solo en las secciones de su asignatura y del período que coordina, porque la coordinación es por asignatura y período.
- El coordinador puede asignarse a sí mismo a una sección de su asignatura. Sigue rigiendo un solo rol por asignatura y período.
- El director no asigna.
- Cada sección admite un único profesor. Asignar nuevamente no reemplaza al profesor existente.

## Criterios de aceptación

1. El administrativo accede desde «Asignar profesores» en el menú y ve las secciones y profesores de su universidad.
2. Selecciona un profesor para una sección disponible y confirma. La asignación persiste y aparece al volver a consultar la pantalla.
3. El servidor registra el rol `profesor` y a quien realiza la operación; esos valores no se aceptan desde el formulario.
4. Se rechaza una segunda asignación a la misma sección, incluso ante solicitudes simultáneas.
5. Se rechazan profesores y secciones de otras universidades, incluso enviando directamente sus IDs.
6. No se pueden asignar cuentas de otro rol. Director, profesor que no coordina, ayudante, alumno y visitantes sin sesión no pueden realizar esta operación.
7. La pantalla informa si no hay secciones o profesores disponibles y muestra los errores de validación.
8. Ambas universidades pueden realizar sus propias asignaciones de forma independiente.
9. El coordinador accede desde «Asignar profesores» y ve solo las secciones de su asignatura en el período que coordina, con los profesores de su universidad.
10. Al asignarlo, la sección aparece en «Mis cursos» del profesor.
11. El coordinador no puede asignar en otra asignatura ni en otro período, aunque envíe el ID (404). La cuenta que la misma persona tiene en la otra universidad no hereda la coordinación.
12. La pantalla muestra quién asignó a cada profesor y cuándo.

## Implementación

- `GET /teacher_assignments`: consulta y formulario por sección.
- `POST /teacher_assignments`: guarda la asignación.
- `TeacherAssignmentPolicy`: permiso de CanCanCan para el administrativo de la universidad y para el profesor que coordina alguna asignatura. La regla del coordinador solo existe si coordina algo, así que un profesor que no coordina no ve el menú.
- `Section.coordinated_by(user)` y `Section#coordinated_by?(user)`: las secciones cuya asignatura coordina el usuario en el mismo período. Filtran por universidad de forma explícita, porque `course_coordinators` todavía no usa `acts_as_tenant`.
- `ProfessorAssignment`: validaciones de `SectionStaff` para filas con `role: "profesor"`. `assigned_by` debe ser el administrativo de la universidad o el coordinador de la asignatura en ese período. Las asignaciones de ayudantes conservan su comportamiento.
- Índice único parcial de PostgreSQL sobre `section_id` cuando `role = 'profesor'`.

El cambio no incluye retirar o cambiar al profesor, crear secciones, asignar ayudantes, asignar coordinadores (A15) ni modificar roles de cuentas.

## Base y coordinación

La rama nace de `Develop`, que ya contiene modelos académicos y autenticación. No incorpora commits de otras features pendientes.

Se utiliza el contrato vigente de `User`: `first_name`, `last_name`, `university_id` y roles de Devise/CanCanCan.

La consulta de A22 filtra secciones, asignaturas, períodos y profesores por universidad. No implementa el selector de dominio global de A3.

Coordinar la integración con `feature/T7-completar-esqueleto-dominio`, que también extiende `SectionStaff` y las restricciones del dominio, y con `feature/crud-secciones`. La validación de A22 está en un concern propio para reducir conflictos.

## Comprobación y revisión

Después de instalar las dependencias y configurar PostgreSQL:

```sh
bin/rails db:migrate
bin/rails test test/models/teacher_assignment_test.rb test/integration/teacher_assignments_test.rb
```

La migración no elimina datos. Si ya hay varias filas de profesor para una sección, el índice rechazará la migración; corresponde revisar esas asignaciones con el equipo.

Para la demo: entrar como administrativo, asignar un profesor, recargar y verificar la persistencia. Repetir en la otra universidad y comprobar que no se pueden cruzar IDs ni asignar un segundo profesor.

Con los datos de demo, `profesor@ucv.test` coordina ICC4204: entra a «Asignar profesores», ve solo las secciones de ICC4204 del período vigente y puede asignar, por ejemplo, a Camila Torres en la sección 2. Después, `camila.torres@ucv.test` ve ICC4204 en «Mis cursos». Un profesor que no coordina, el ayudante y el alumno no ven el enlace.

El PR se dirige a `Develop`. La tarjeta permanece En revisión tras su integración; pasa a Hecho al cumplir la DoD, incluidas las aprobaciones acordadas y el release integrado en `main`.
