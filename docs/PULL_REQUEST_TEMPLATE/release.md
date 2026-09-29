Release → main

Rama: Release/<version> → main

Propósito de la versión
<!-- Qué incorpora esta versión y para qué se publica -->

Cambios incluidos
<!-- Funcionalidades y correcciones que forman parte de la versión -->

Verificación
<!-- Qué se probó y cuáles fueron los resultados -->

Tarjetas relacionadas
<!-- Enlaces a las tarjetas de Trello incluidas -->

Checklist
- [ ] La rama nace de Develop, no de main
- [ ] Se cumplen los criterios de aceptación de las tarjetas incluidas
- [ ] Verifiqué que las funcionalidades funcionan en conjunto
- [ ] Verifiqué los permisos por rol y el aislamiento por university_id
- [ ] Los commits siguen Conventional Commits
- [ ] El PR cuenta con las aprobaciones acordadas por el equipo

Después de mergear
- [ ] Abrir PR de back-merge Release/<version> → Develop (template develop.md)
- [ ] Mover a Hecho las tarjetas que cumplen la Definition of Done
- [ ] Borrar la rama Release/<version> después de integrar sus cambios en main y Develop
