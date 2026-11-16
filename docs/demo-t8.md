# T8 · Datos de demostración para dos universidades

## Qué se prepara

Período 2026-2. UCV usa ICC1001 · Programación, sección 1; IUSA usa ANAT101 · Anatomía Humana, sección 1.

Cada sección tiene:
- Un profesor, un ayudante y tres alumnos inscritos.
- Ocho clases entre el 10 de agosto y el 28 de septiembre de 2026, con presentes y ausentes. Se omiten las fechas que aún sean futuras al ejecutar.
- Tres evaluaciones de 20 %: **Demo T8 · Control publicado**, **Demo T8 · Control pendiente** y **Demo T8 · Control rechazado**.
- Nueve notas: tres por evaluación. Las rechazadas tienen comentario; las publicadas tienen profesor revisor.
- Pauta en texto y retroalimentación de ejemplo; no se crean archivos adjuntos.

En una base nueva, el conjunto completo tiene 14 cuentas (incluido el director), 18 notas y 48 marcas de asistencia una vez transcurridas las ocho fechas. Queda 40 % libre en cada sección para crear otra evaluación en la demo.

## Cargar en Ubuntu

Desde el proyecto, con PostgreSQL disponible:

```bash
cd ~/WEBPROYECTOS/IDS-Entrega-4
bin/rails db:prepare
read -s -p "Contraseña para las cuentas demo nuevas: " SEED_PASSWORD
echo
export SEED_PASSWORD
bin/rails db:seed
unset SEED_PASSWORD
```

Usa una contraseña de al menos 8 caracteres. Las cuentas existentes conservan su contraseña: cambiar SEED_PASSWORD y repetir la carga no la restablece.

Los seeds añaden registros faltantes y conservan notas, contraseñas y asistencia editadas. No se deben ejecutar simultáneamente. Están destinados a un entorno de demostración autorizado; esta tarea no ejecuta cargas en producción.

Si las evaluaciones existentes no dejan espacio para los ejemplos de 20 %, se muestra un aviso y se omiten las notas demo de esa sección. No se cambian ponderaciones para forzar la carga. Se conserva también una inscripción desactivada; ese alumno no recibe nuevos ejemplos de notas o asistencia.

## Cuentas para el recorrido

| Rol | UCV | IUSA |
|---|---|---|
| Administrativo | admin@ucv.test | admin@iusa.test |
| Profesor | profesor@ucv.test | camila.torres@iusa.test |
| Ayudante | ayudante@ucv.test | ayudante@iusa.test |
| Alumno principal | alumno@ucv.test | alumno@iusa.test |
| Otros alumnos | sofia@ucv.test, tomas@ucv.test | lucas@iusa.test, isidora@iusa.test |

Director: director@sga.test. Puede alternar universidades desde el selector.

Camila tiene además camila.torres@ucv.test, con el mismo RUT y otra cuenta, para demostrar que universidad y cuenta delimitan el acceso.

## Recorrido de aceptación

1. **Administrativo:** abre Cuentas. Comprueba que los alumnos de la otra universidad no aparecen.
2. **Alumno:** abre Mis notas. Solo debe ver el control publicado, con su propia nota, pauta y retroalimentación. Consulta también su asistencia.
3. **Profesor:** abre las evaluaciones de su sección y revisa el control pendiente. Aprueba o rechaza con un comentario.
4. **Ayudante:** abre el control rechazado, consulta el motivo, corrige y reenvía.
5. **Profesor:** aprueba las notas reenviadas.
6. **Alumno:** verifica que las nuevas notas aprobadas ya aparecen.
7. Repite con las cuentas de la otra universidad. Prueba que una URL de nota ajena no permite verla.
8. **Director:** cambia de universidad y comprueba cursos y estadísticas de sección. El dashboard general es otra tarjeta.

La carga inicial crea los estados de notas directamente: no envía notificaciones de ejemplo. Para probar notificaciones reales, realiza las transiciones desde la interfaz y comprueba que Redis y Sidekiq estén funcionando.

## Validación

```bash
bin/rails test test/integration/demo_seeds_test.rb
bin/rubocop db/seeds.rb test/integration/demo_seeds_test.rb
```

Las pruebas crean sus propios datos, sin cargar fixtures. Comprueban ambas universidades, repetición sin cambios, conservación de contraseñas, acceso del alumno y respeto de ponderaciones existentes.
