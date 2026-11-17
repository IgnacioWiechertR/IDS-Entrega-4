# D6 · Verificar completitud de datos

El administrativo accede a **Completitud** desde la navegación. El reporte es de solo lectura y muestra todas las secciones de su universidad que requieren correcciones, con un enlace a cada sección.

Criterios:
- Sin profesor: no hay una asignación de profesor; un ayudante no la reemplaza.
- Sin alumnos: no hay inscripciones activas.
- Sin asistencia: no existe ninguna marca registrada, aunque haya sesiones creadas.
- Evaluaciones incompletas: no tienen notas publicadas o falta la nota publicada de algún alumno activo. Las pendientes y rechazadas no son oficiales.
- Se revisan todos los períodos. No tener evaluaciones no añade una alerta de notas.
- Las secciones sin alertas se omiten. Si no hay resultados se muestra un mensaje explícito.

Prueba: `bin/rails test test/integration/data_completeness_test.rb`.
