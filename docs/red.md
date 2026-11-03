# Red de la biblioteca - L9

Diseno para la siguiente entrega. No se han desplegado estas maquinas. Fecha de medicion local: 2 de
noviembre de 2026, America/Santiago. Los valores de nube pendientes se identifican expresamente.

## AWS - VPC 10.0.0.0/16 - us-east-1

| Subred | Rango | Zona | Ruta 0.0.0.0/0 |
|---|---|---|---|
| publica | 10.0.1.0/24 | us-east-1a | Internet Gateway |
| aplicacion | 10.0.11.0/24 | us-east-1a | interfaz de red de `nat` |
| datos-a | 10.0.21.0/24 | us-east-1a | interfaz de red de `nat` |
| datos-b | 10.0.22.0/24 | us-east-1b | interfaz de red de `nat` |

| Maquina | Subred | IP privada | Tamano | Lo que corre | Por que ese tamano |
|---|---|---|---|---|---|
| `gw-aws` | publica | 10.0.1.20, Elastic IP pendiente E2 | t3.small | Caddy HTTPS y `biblioteca-gateway` | Gateway midio 43,07 MiB. 2 GiB propuestos, con margen para Caddy, SO y picos; falta probar carga. |
| `nat` | publica | 10.0.1.10 | t3.nano | NAT instance | 0,5 GiB propuestos por su rol de reenvio, sin contenedores; verificar trafico. Requiere desactivar source/dest check. |
| `servicios` | aplicacion | 10.0.11.10 | t3.medium | `biblioteca-libros`, `biblioteca-prestamos`, `biblioteca-eventos` | Libros 20,60 + prestamos 93,29 + eventos 65,39 = 179,28 MiB medidos. 4 GiB dejan margen para SO, picos y crecimiento; falta prueba de carga. |
| `gestion` | aplicacion | 10.0.11.20 | t3.medium | `biblioteca-admin`, Kafka UI, simulador, runner `aws`; Prometheus/Grafana opcionales | Kafka UI 387,20 + admin 55,55 = 442,75 MiB; reservar margen para simulador, runner y compilacion. 4 GiB propuestos. |
| `mq-1` | datos-a | 10.0.21.11 | t3.small | controller 1, broker 4 y `rabbit1` | Controller 270,60 + broker 600,90 + RabbitMQ 145,60 = 1017,10 MiB. 2 GiB dejan aproximadamente 1 GiB para SO y picos; verificar bajo carga. |
| `mq-2` | datos-b | 10.0.22.12 | t3.small | controller 2, broker 5 y `rabbit2` | Controller 293,00 + broker 593,60 + RabbitMQ 151,80 = 1038,40 MiB. 2 GiB dejan margen para SO; verificar bajo carga. |
| `mq-3` | datos-a | 10.0.21.13 | t3.small | controller 3 y broker 6 | 238,20 + 592,10 = 830,30 MiB medidos; 2 GiB dejan margen para SO y picos. |
| `datos` | datos-a | 10.0.21.30 | t3.small | Postgres 18 | Postgres midio 52,33 MiB con los esquemas cargados. 2 GiB dejan margen para cache y conexiones; medir bajo carga. |

| Grupo de reglas | Puerto | Origen | Para que |
|---|---|---|---|
| `sg-gw` | 80 | `0.0.0.0/0` | Desafio de Let's Encrypt y redireccion a HTTPS |
| `sg-gw` | 443 | IP publica de `gw-azure`/32, pendiente E2 | API accesible desde la salida NAT del BFF |
| `sg-servicios` | 3001, 3002 y 3010 | `sg-gw` y `sg-gestion` | Gateway hacia libros/prestamos; gestion revisa eventos |
| `sg-mq` | 9092 | `sg-servicios`, `sg-gestion` y `sg-mq` | Clientes Kafka y replica entre brokers |
| `sg-mq` | 9093 | `sg-mq` | Quorum KRaft |
| `sg-mq` | 5672 | `sg-servicios` y `sg-gestion` | AMQP |
| `sg-mq` | 15672 | `sg-gestion` | Administracion RabbitMQ |
| `sg-mq` | 4369 y 25672 | `sg-mq` | Cluster RabbitMQ |
| `sg-datos` | 5432 | `sg-servicios` y `sg-gestion` | Postgres |
| `sg-nat` | todos | `sg-servicios`, `sg-gestion`, `sg-mq` y `sg-datos` | Salida de las subredes privadas |
| `sg-gestion` | ninguno entrante | no aplica | Acceso mediante Session Manager |

No se abre el 22 en AWS: se usa Systems Manager Session Manager, un perfil de instancia como
`LabInstanceProfile`, agente SSM y conectividad saliente hacia SSM (por NAT o VPC endpoints). Un tunel
SSM permite acceder a un puerto privado sin hacer publica la maquina. Las IP privadas de los brokers
son fijas porque son las que anuncian a los clientes; en la nube debe adaptarse el puerto anunciado a 9092.

Este esquema de la guia reparte tres nodos entre dos zonas. Tolera un nodo caido; perder datos-a elimina
dos nodos y puede dejar sin quorum y sin ISR suficiente. No equivale a tolerancia a cualquier falla de zona.

## Azure - VNet 10.1.0.0/16 - region pendiente de verificar

Region candidata: `northcentralus`. No se declara aprobada hasta crear y borrar una VNet en esta suscripcion.

| Subred | Rango | Salida a internet |
|---|---|---|
| publica | 10.1.1.0/24 | IP publica de `gw-azure` |
| privada | 10.1.2.0/24 | UDR 0.0.0.0/0 hacia 10.1.1.4; `--default-outbound false` |

| Maquina | Subred | IP privada | Tamano | Lo que corre | Por que ese tamano |
|---|---|---|---|---|---|
| `gw-azure` | publica | 10.1.1.4; IP publica estatica y etiqueta pendientes E2 | B2ats_v2 | Caddy, web, gateway y NAT de la privada | Web 11,91 + gateway 43,07 = 54,98 MiB; sumar Caddy, SO y picos. Disponibilidad, RAM y cuota del SKU pendientes de verificar. |
| `bff` | privada | 10.1.2.4, sin IP publica | B2als_v2 | BFF y runner `azure` | BFF midio 44,78 MiB. Reservar el pico de compilacion del runner y SO; SKU y cuota pendientes de verificar. |

| NSG | Puerto | Origen | Para que |
|---|---|---|---|
| `gw-azure` | 443 y 80 | Internet | Web y desafio de Let's Encrypt |
| `gw-azure` | 22 | IP de cada integrante/32, pendiente E2 | SSH restringido |
| `gw-azure` | todos | 10.1.2.0/24 | NAT de BFF |
| `bff` | todos | 10.1.0.0/16 | Acceso solo desde la VNet |

## Evidencias y pendientes

Medicion completa local tomada con `docker stats --no-stream` tras cargar el simulador y arrancar los 17
contenedores: web 11,91; gateway 43,07; bff 44,78; libros 20,60; prestamos 93,29; eventos 65,39;
admin 55,55; Postgres 52,33; rabbit1 145,60; rabbit2 151,80; Kafka UI 387,20; broker-1 600,90;
broker-2 593,60; broker-3 592,10; controller-1 270,60; controller-2 293,00; controller-3 238,20 MiB.
Total aproximado: 3659,92 MiB de contenedores. Se excluye la CLI Azure temporal. No incluye toda la
memoria del SO ni demuestra capacidad bajo carga.

`deploy/aws/permisos.txt`: sesion renovada y plugin SSM 1.2.896.0; resumen real **14 OK y 0 FALLA**.
Se verifico acceso SSM, tunel, DNS y ausencia de acceso por el puerto 22. El script termino y confirmo
instancia terminada, Elastic IP liberada y VPC temporal borrada. El intento inicial ExpiredToken se
conserva en las evidencias locales del informe, no como resultado final.

`deploy/azure/region.txt`: pendiente porque el estudiante indico no tener cuenta Azure actualmente.
La CLI oficial fue preparada en Docker, pero se cancelo el login sin una suscripcion. No se crearon
recursos ni presupuesto. Debe haber al menos 4 vCPU regionales disponibles y ambos SKU sin restricciones.
El titular debe definir y crear el presupuesto con alerta cuando disponga de la cuenta.
