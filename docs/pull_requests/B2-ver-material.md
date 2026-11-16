Feature → Develop

Rama: feature/b2-ver-material → Develop

## Necesidad

Permitir consultar el material académico y obtener una vista previa de su contenido desde el curso o sección, respetando el acceso por rol y universidad.

## Solución

- Listado del material del curso, del más reciente al más antiguo.
- Detalle con título, archivo, tamaño y fecha de publicación.
- Visor de PDF y texto; conversión local de documentos de oficina a PDF mediante LibreOffice.
- Cada solicitud de contenido verifica sesión, acceso al curso y universidad activa.
- Mensajes para material ausente, documentos dañados o formatos no compatibles.
- Dependencias del conversor incluidas en Docker y CI.

La rama nace de Develop y no incluye los commits pendientes de B1. B2 usa un controlador de consulta independiente. Al integrar ambas tarjetas deben conservarse las rutas y el botón de subida de B1 junto a las vistas de B2.

La conversión puede presentar diferencias de formato y se realiza en cada apertura. Los documentos protegidos con contraseña o no compatibles muestran un mensaje. B3, B4 y la descarga dedicada del original de B5 conservan su alcance.

## Verificación

- B2: 37 pruebas y 352 aserciones, sin fallos, incluidas conversiones reales de Word, Excel, PowerPoint y OpenDocument.
- Suite completa: 427 pruebas y 2.516 aserciones, sin fallos.
- RuboCop: 214 archivos, sin infracciones. Brakeman: 0 advertencias de seguridad.
- Entorno local: Ruby 4.0.0, PostgreSQL 18 y LibreOffice 24.2.7.2. CI debe verificar Ruby 3.4.5, declarado en el proyecto. No se ha construido la imagen Docker completa.
- Detalles y requisitos de ejecución: `docs/cards/B2-ver-material.md`.

## Tarjeta relacionada

B2 · Ver material del curso

**Reemplazar esta línea por el enlace a la tarjeta de Trello antes de abrir el PR.**

## Checklist

- [x] La rama nace de Develop, no de main
- [x] Se cumplen los criterios de aceptación confirmados para B2
- [x] Verifiqué que la funcionalidad opera correctamente
- [x] Verifiqué que no rompí otra cosa mediante la suite completa
- [x] Se respetan los permisos por rol y el aislamiento por university_id
- [x] Los commits siguen Conventional Commits
- [ ] El PR cuenta con las aprobaciones acordadas por el equipo

## Después de mergear

- [ ] Marcar la tarjeta con la etiqueta “Merge a develop”
- [ ] Mantener la tarjeta en En revisión hasta que su release llegue a main
- [ ] Borrar la rama feature/b2-ver-material
