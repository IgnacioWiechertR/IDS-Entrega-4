# Decisiones técnicas

Registro de decisiones de arquitectura e infraestructura del SGA: qué se decidió, por qué y qué consecuencias tiene.

## Correo transaccional con la API HTTP de Brevo (A2, noviembre 2026)

**Contexto.** La recuperación de contraseña (A2, RF-Caso de Uso 1-2) es el primer flujo que envía correos a los usuarios. La aplicación corre en el plan gratuito de Render y no tenemos dominio propio.

**Decisión.** En producción los correos se envían con la API HTTP de [Brevo](https://www.brevo.com/) (`POST https://api.brevo.com/v3/smtp/email`) mediante un *delivery method* propio de ActionMailer, `lib/brevo_delivery.rb`, registrado como `:brevo`. Usa `Net::HTTP` de la biblioteca estándar, sin gemas de terceros. El remitente es un correo personal verificado como *sender* en Brevo.

**Por qué.**

- **Render bloquea SMTP en el plan gratuito.** Los puertos de salida 25, 465 y 587 están cerrados, así que ningún proveedor por SMTP (Gmail, Brevo SMTP, SendGrid SMTP) funciona desde el servicio. Una API por HTTPS (puerto 443) sí funciona.
- **Sin dominio propio.** La mayoría de los proveedores transaccionales (Resend, Postmark, Amazon SES) exigen verificar un dominio con registros DNS antes de enviar a terceros. Brevo permite enviar desde una sola dirección verificada por correo, que es lo que tenemos.
- **Plan gratuito suficiente.** Brevo permite 300 correos diarios gratis, de sobra para la recuperación de contraseña de dos universidades.
- **Sin dependencias nuevas.** El cliente es una clase de ~70 líneas. La gema oficial de Brevo agrega muchas dependencias para una sola llamada.

**Consecuencias.**

- Los correos se envían con `deliver_later`: viajan en un trabajo de Sidekiq (embebido en Puma). Si la API responde un error, `BrevoDelivery` levanta `BrevoDelivery::Error` y Sidekiq reintenta el trabajo con su espera exponencial.
- Sin dominio propio no hay SPF/DKIM alineados con el remitente, así que algunos correos pueden llegar a spam. Si el proyecto consigue un dominio, basta con verificarlo en Brevo y cambiar `MAILER_FROM`.
- Rack::Attack limita las solicitudes de recuperación (5 por minuto por IP y 3 cada 15 minutos por correo) para no agotar la cuota diaria ni usar el formulario para inundar un buzón.
- En desarrollo no se envía nada: los correos se ven en `/letter_opener` (gema `letter_opener_web`). En test se usa el adaptador `:test` de ActionMailer.
- Variables de entorno en Render: `BREVO_API_KEY`, `APP_HOST` y `MAILER_FROM` (ver el README, sección "Correo").
