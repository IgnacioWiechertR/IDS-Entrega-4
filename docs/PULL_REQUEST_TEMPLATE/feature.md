Feature → Develop

Rama: feature/<descripción> → Develop

Necesidad
<!-- Qué necesita el usuario y por qué -->

Solución
<!-- Qué funcionalidad se implementó y cómo responde a la necesidad -->

Verificación
<!-- Qué se probó y cuáles fueron los resultados -->

Tarjeta relacionada
<!-- Enlace a la tarjeta de Trello -->

Checklist
- [ ] La rama nace de Develop, no de main
- [ ] Se cumplen los criterios de aceptación de la tarjeta
- [ ] Verifiqué que la funcionalidad opera correctamente
- [ ] Verifiqué que no rompí otra cosa
- [ ] Se respetan los permisos por rol y el aislamiento por university_id
- [ ] Los commits siguen Conventional Commits
- [ ] El PR cuenta con las aprobaciones acordadas por el equipo

Después de mergear
- [ ] Marcar la tarjeta con la etiqueta “Merge a develop”
- [ ] Mantener la tarjeta en En revisión hasta que su release llegue a main
- [ ] Borrar la rama feature/<descripción>
