# fix(reportes): corregir el cálculo de asistencia de alumnos activos

Feature → Develop

Rama: `feature/corregir-calculo-asistencia` → `Develop`

Base: `origin/Develop` en `ebd2a47`.

## Necesidad

El reporte consolidado cuenta marcas de asistencia de alumnos retirados o cuya matrícula fue eliminada, mientras calcula el total esperado solo con alumnos activos. Por ejemplo, una clase con dos alumnos activos y un retirado presentes muestra 150 % en el reporte, aunque la sección y el dashboard muestran 100 %. El mismo error aparece en la exportación CSV.

## Solución

El conteo considera únicamente marcas `presente` de alumnos con matrícula activa en la misma sección de la clase. La consulta relaciona sección y alumno para que una matrícula activa en otra sección no haga contar las marcas anteriores después de un traslado.

Se mantiene el criterio de asistencia de B8: clases registradas por alumnos activos como total esperado; una marca faltante cuenta como ausencia. Sin clases o alumnos activos, la asistencia queda sin datos. El reporte conserva su redondeo a un decimal.

El resultado corregido se utiliza tanto en la pantalla como en el CSV. Las marcas históricas se conservan; no se necesitan migraciones ni cambios de configuración. Los permisos y filtros existentes por universidad, período y asignatura siguen aplicándose.

## Verificación

- Antes de la corrección, las pruebas de regresión reprodujeron seis fallos, incluidos porcentajes de 150 %, 200 % y 116,7 %.
- Pruebas de reportes: **16 pruebas y 141 aserciones**, sin fallos, errores ni omisiones.
- Suite completa: **625 pruebas y 4.165 aserciones**, sin fallos, errores ni omisiones.
- RuboCop: **253 archivos**, sin infracciones.
- Brakeman: **0 errores y 0 advertencias de seguridad**.
- `git diff --check`: sin errores.

Las pruebas comprueban matrículas inactivas y eliminadas, traslados entre secciones, marcas faltantes, varias clases, ausencia de clases o alumnos activos, datos de IUSA y UCV, conservación del historial y concordancia con estadísticas de sección y dashboard. La prueba de integración verifica la pantalla y el CSV.

Comandos para reproducir con PostgreSQL de pruebas y las dependencias del proyecto:

```sh
RAILS_ENV=test bin/rails db:test:prepare
bin/rails test test/services/consolidated_report_service_test.rb test/integration/consolidated_test.rb
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

La validación local utilizó Ruby 4.0.0, Rails 8.1.4.1, las versiones de `Gemfile.lock` y PostgreSQL 18 temporal. Para ejecutar la suite en Ruby 4 se agregó la biblioteca `benchmark` instalada a la ruta de carga del proceso, sin cambiar dependencias. CI debe verificar Ruby 3.4.5, declarado por el proyecto. Las pruebas se ejecutaron en una base temporal, sin utilizar datos de desarrollo o producción.

## Tarjeta relacionada

Corrección del cálculo de asistencia del reporte consolidado y su CSV, relacionada con D4/D5 y el criterio de asistencia de B8.

**Pendiente antes de solicitar revisión:** agregar el enlace a la tarjeta de corrección en Trello.

## Checklist

- [x] La rama nace de Develop, no de main.
- [x] El cálculo utiliza la misma población activa en numerador y denominador y conserva los registros históricos.
- [x] Verifiqué que la funcionalidad opera correctamente mediante pruebas de servicio e integración.
- [x] Verifiqué que no rompí otra cosa mediante la suite completa.
- [x] Se respetan los permisos por rol y el aislamiento por university_id.
- [ ] Agregué el enlace a Trello y verifiqué los criterios de aceptación acordados en la tarjeta.
- [ ] Los commits siguen Conventional Commits. Mensaje propuesto: `fix(reportes): corregir asistencia de alumnos activos`.
- [ ] El PR cuenta con las aprobaciones acordadas por el equipo.

## Después de mergear

- [ ] Marcar la tarjeta con la etiqueta «Merge a develop».
- [ ] Mantener la tarjeta en En revisión hasta que su release llegue a main.
- [ ] Borrar la rama feature/corregir-calculo-asistencia.
