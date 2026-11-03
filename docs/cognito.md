# Cognito del laboratorio

Configuracion publica recuperada de `biblioteca-web/src/main.ts` del laboratorio anterior y de los valores
`COGNITO_*` de los contenedores anteriores de biblioteca. No contiene contrasenas ni access tokens.

| Dato | Valor |
|---|---|
| Region | `us-east-1` |
| User pool | `us-east-1_POIrUWRcA` |
| App client | `3e0h98ouo502bljiohhqk1bctb` |
| Issuer | `https://cognito-idp.us-east-1.amazonaws.com/us-east-1_POIrUWRcA` |
| Dominio de login, sin https | `us-east-1poiruwrca.auth.us-east-1.amazoncognito.com` |
| Callback | `http://localhost:4200/callback` |
| Logout | `http://localhost:4200` |

El 2 de noviembre de 2026 se verificaron dos claves en el JWKS publico y respuesta HTTP 200 de la pagina
de autorizacion del app client. Eso demuestra disponibilidad de la configuracion; el inicio de sesion de un
usuario y la pertenencia al grupo `bibliotecarios` se comprueban por separado con su cuenta.

En gateway, bff y admin se usan `COGNITO_ISSUER` y `COGNITO_CLIENT_ID`; prestamos solo utiliza el issuer.
El frontend configura los tres identificadores y el dominio en `src/main.ts` antes del bootstrap de Angular.

No guardar access tokens, claves de AWS ni contrasenas de usuarios en este archivo o en Git.
