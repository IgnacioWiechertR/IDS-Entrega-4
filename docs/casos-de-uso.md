# Casos de uso: estado de los requisitos

El detalle completo de casos de uso y requisitos está en el informe de la Entrega 5 (anexo "Requisitos Funcionales (RF) y No Funcionales (RNF) por Caso de Uso"). Este archivo registra los cambios de estado posteriores a esa entrega, junto al código que los implementa.

## Caso de Uso 1: Gestión de Usuarios, Autenticación y Multi-Tenancy

| Requisito | Descripción | Estado | Implementación |
|---|---|---|---|
| RF-Caso de Uso 1-1 | Inicio de sesión diferenciado por rol (Director, Administrativo, Profesor, Ayudante y Alumno). | Implementado | A1 |
| RF-Caso de Uso 1-2 | Mecanismo de recuperación de contraseña para los usuarios registrados. | **Implementado** (antes pendiente) | A2: enlace por correo, válido por 2 horas y de un solo uso. Ver abajo. |
| RF-Caso de Uso 1-3 | El RUT es único dentro de cada universidad. | Implementado | A8 |
| RNF-Caso de Uso 1-1 | Separación estricta de los datos por universidad (`university_id`). | Implementado | A3 |

### RF-Caso de Uso 1-2: recuperación de contraseña (A2)

- En el login, **¿Olvidaste tu contraseña?** lleva a un formulario donde se escribe el correo de la cuenta.
- La respuesta es siempre la misma, exista o no la cuenta (`config.paranoid`), para no revelar qué correos están registrados. Las cuentas desactivadas no reciben el correo.
- El correo (en español) trae un enlace que vence en 2 horas y sirve una sola vez. Con él se crea una contraseña nueva que cumple las mismas reglas que al crear la cuenta (mínimo 8 caracteres) y se inicia sesión.
- Si la cuenta estaba bloqueada por intentos fallidos, cambiar la contraseña la desbloquea.
- Los correos se envían en segundo plano (Sidekiq) por la API de Brevo; ver [decisiones.md](decisiones.md).
- Tests: `test/integration/password_recovery_test.rb`, `test/mailers/devise_mailer_test.rb` y `test/lib/brevo_delivery_test.rb`.
