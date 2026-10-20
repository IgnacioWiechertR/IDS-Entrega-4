Develop

Rama: Release/<version> o hotfix/<descripción> → Develop

Origen
<!-- Indicar el release o hotfix y su PR hacia main -->
Release vX.Y.Z (PR #)
Hotfix (PR #)

Propósito
Sincronizar Develop con los cambios que ya entraron a main, para que no se pierdan en el siguiente release.

Verificación
<!-- Qué se probó y cuáles fueron los resultados -->

Checklist
- [ ] El release o hotfix ya fue integrado en main
- [ ] Los conflictos están resueltos, conservando los cambios de Develop
- [ ] Verifiqué que la versión resultante funciona localmente
- [ ] No agregué funcionalidades ni correcciones ajenas a la sincronización
- [ ] El PR cuenta con las aprobaciones acordadas por el equipo

Después de mergear
- [ ] Comprobar que Develop contiene los ajustes del release o hotfix
- [ ] Borrar la rama de origen cuando esté integrada en todos sus destinos
