Hotfix → main

Rama: hotfix/<descripción> → main

Problema en producción
<!-- Qué falla, a quién afecta, cómo se reproduce -->
Causa
<!-- Por qué ocurría -->
Solución
<!-- Qué cambiaste. Debe ser el cambio mínimo. -->

Issue relacionado
Fixes #

Checklist
- [ ] La rama nace de main, no de develop
- [ ] El cambio es mínimo y acotado al bug
- [ ] Verifiqué que el bug ya no se reproduce
- [ ] Verifiqué que no rompí otra cosa
- [ ] Versión patch incrementada (x.x.+1)

Después de mergear
- [ ] Abrir PR de back-merge hotfix/<descripción> → develop (template backmerge.md)

- [ ] Si hay un release/* abierto, mergear también ahí
- [ ] Borrar la rama hotfix/<descripción>