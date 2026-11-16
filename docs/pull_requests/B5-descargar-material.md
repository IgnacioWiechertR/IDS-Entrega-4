Feature → Develop

Rama: feature/b5-descargar-material → Develop

## Necesidad

Permitir descargar el material original de un curso sin exponer rutas públicas que permitan saltarse los permisos o el aislamiento entre universidades.

## Solución

- Accesos de descarga desde el curso y la sección, y descarga autenticada del original.
- Permisos vigentes de lectura del curso para profesor, coordinador, ayudante, alumno con matrícula activa y personal autorizado dentro de su universidad.
- Comprobación de universidad y curso en cada solicitud; retirar la participación revoca los enlaces guardados.
- Entrega como adjunto, conservando los bytes y saneando el nombre del archivo.
- Transmisión por bloques y caché privada deshabilitada, sin conversión ni carga completa del original en un String.
- Rutas públicas de Active Storage deshabilitadas, incluidos blobs, representaciones y disco. Direct uploads continúan denegados y B1 conserva su helper.
- Mensajes para adjuntos ausentes o archivos eliminados.

La rama nace de Develop sin incorporar commits pendientes de B1 o B2. Al integrar la sección, conservar el enlace al detalle de B2 y el botón de descarga de B5; la indicación concreta está en `docs/cards/B5-descargar-material.md`.

No se implementan edición, eliminación, conversión de oficina ni reanudación de descargas mediante Range. No se modifican el esquema, dependencias, Dockerfile ni CI.

## Verificación

- B5: 24 pruebas y 329 aserciones, sin fallos.
- Suite completa: 455 pruebas y 2.748 aserciones, sin fallos, errores ni omisiones.
- Ensamble temporal con B1/B2/B5: 70 pruebas y 614 aserciones, incluido el flujo de subir, previsualizar PDF, descargar y revocar acceso. No se hicieron merges en las ramas.
- Archivo de 12 MB transmitido en varios bloques, conservando su SHA-256.
- RuboCop: 214 archivos, sin infracciones. Brakeman: 0 advertencias de seguridad.
- Entorno local: Ruby 4.0.0 y PostgreSQL 18. CI debe verificar Ruby 3.4.5, declarado en el proyecto.
- Sin pruebas contra buckets reales ni pruebas de carga a 512 MB. No se pudo construir Docker por falta de integración de Docker Desktop con esta distribución WSL.

## Tarjeta relacionada

B5 · Descargar material

**Reemplazar esta línea por el enlace de la tarjeta de Trello antes de abrir el PR.**

## Checklist

- [x] La rama nace de Develop, no de main
- [x] Se cumplen las reglas de descarga descritas para B5
- [x] Verifiqué que la funcionalidad opera correctamente
- [x] Verifiqué que no rompí otra cosa mediante la suite completa
- [x] Se respetan los permisos por rol y el aislamiento por university_id
- [x] Los commits siguen Conventional Commits
- [ ] El PR cuenta con las aprobaciones acordadas por el equipo

## Después de mergear

- [ ] Marcar la tarjeta con la etiqueta “Merge a develop”
- [ ] Mantener la tarjeta en En revisión hasta que su release llegue a main
- [ ] Borrar la rama feature/b5-descargar-material
