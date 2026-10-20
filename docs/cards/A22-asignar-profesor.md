# A22 · Asignar profesor a sección

Épica 1: Administrar la institución.

## Historia de usuario

Como administrativo de una universidad, quiero asignar un profesor de mi institución a una sección para registrar quién estará a cargo de su docencia.

## Reglas confirmadas

- Solo el administrativo de la misma universidad puede realizar la asignación.
- Cada sección admite un único profesor. Asignar nuevamente no reemplaza al profesor existente.

## Criterios de aceptación

1. El administrativo accede desde «Asignar profesores» en el menú y ve las secciones y profesores de su universidad.
2. Selecciona un profesor para una sección disponible y confirma. La asignación persiste y aparece al volver a consultar la pantalla.
3. El servidor registra el rol `profesor` y al administrativo que realiza la operación; esos valores no se aceptan desde el formulario.
4. Se rechaza una segunda asignación a la misma sección, incluso ante solicitudes simultáneas.
5. Se rechazan profesores y secciones de otras universidades, incluso enviando directamente sus IDs.
6. No se pueden asignar cuentas de otro rol. Director, profesor, ayudante, alumno y visitantes sin sesión no pueden realizar esta operación.
7. La pantalla informa si no hay secciones o profesores disponibles y muestra los errores de validación.
8. Ambas universidades pueden realizar sus propias asignaciones de forma independiente.

## Implementación

- `GET /teacher_assignments`: consulta y formulario por sección.
- `POST /teacher_assignments`: guarda la asignación.
- `TeacherAssignmentPolicy`: permiso de CanCanCan limitado al administrativo de la universidad.
- `ProfessorAssignment`: validaciones de `SectionStaff` para filas con `role: "profesor"`. Las asignaciones de ayudantes conservan su comportamiento.
- Índice único parcial de PostgreSQL sobre `section_id` cuando `role = 'profesor'`.

El cambio no incluye retirar o cambiar al profesor, crear secciones, asignar ayudantes ni modificar roles de cuentas.

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

El PR se dirige a `Develop`. La tarjeta permanece En revisión tras su integración; pasa a Hecho al cumplir la DoD, incluidas las aprobaciones acordadas y el release integrado en `main`.
