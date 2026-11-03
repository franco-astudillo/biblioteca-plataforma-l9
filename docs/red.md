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
| `gw-aws` | publica | 10.0.1.20, Elastic IP pendiente E2 | t3.small | Caddy HTTPS y `biblioteca-gateway` | Gateway midio 43,58 MiB. 2 GiB propuestos, con margen para Caddy, SO y picos; falta probar carga. |
| `nat` | publica | 10.0.1.10 | t3.nano | NAT instance | 0,5 GiB propuestos por su rol de reenvio, sin contenedores; verificar trafico. Requiere desactivar source/dest check. |
| `servicios` | aplicacion | 10.0.11.10 | t3.medium | `biblioteca-libros`, `biblioteca-prestamos`, `biblioteca-eventos` | Libros midio 19,74 MiB. 4 GiB propuestos; falta medir prestamos y eventos juntos y reservar margen para el SO. |
| `gestion` | aplicacion | 10.0.11.20 | t3.medium | `biblioteca-admin`, Kafka UI, simulador, runner `aws`; Prometheus/Grafana opcionales | Kafka UI midio 372,4 MiB; faltan admin, simulador, runner y margen de compilacion. 4 GiB propuestos. |
| `mq-1` | datos-a | 10.0.21.11 | t3.small | controller 1, broker 4 y `rabbit1` | Controller 228,5 + broker 520,3 = 748,8 MiB; sumar RabbitMQ y SO antes de confirmar los 2 GiB. |
| `mq-2` | datos-b | 10.0.22.12 | t3.small | controller 2, broker 5 y `rabbit2` | Controller 171,6 + broker 485,3 = 656,9 MiB; falta RabbitMQ y SO. 2 GiB propuestos. |
| `mq-3` | datos-a | 10.0.21.13 | t3.small | controller 3 y broker 6 | 174,1 + 486,2 = 660,3 MiB medidos; 2 GiB dejan margen para SO y picos. |
| `datos` | datos-a | 10.0.21.30 | t3.small | Postgres 18 | 2 GiB propuestos; medir Postgres con los prestamos y la auditoria antes de confirmarlo. |

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
| `gw-azure` | publica | 10.1.1.4; IP publica estatica y etiqueta pendientes E2 | B2ats_v2 | Caddy, web, gateway y NAT de la privada | Web 12,19 + gateway 43,58 = 55,77 MiB; sumar Caddy, SO y picos. Disponibilidad, RAM y cuota del SKU pendientes de verificar. |
| `bff` | privada | 10.1.2.4, sin IP publica | B2als_v2 | BFF y runner `azure` | BFF midio 47,48 MiB. Reservar el pico de compilacion del runner y SO; SKU y cuota pendientes de verificar. |

| NSG | Puerto | Origen | Para que |
|---|---|---|---|
| `gw-azure` | 443 y 80 | Internet | Web y desafio de Let's Encrypt |
| `gw-azure` | 22 | IP de cada integrante/32, pendiente E2 | SSH restringido |
| `gw-azure` | todos | 10.1.2.0/24 | NAT de BFF |
| `bff` | todos | 10.1.0.0/16 | Acceso solo desde la VNet |

## Evidencias y pendientes

Medicion parcial tomada con `docker stats --no-stream`: controller-1 228,5 MiB; controller-2 171,6 MiB;
controller-3 174,1 MiB; broker-1 520,3 MiB; broker-2 485,3 MiB; broker-3 486,2 MiB; Kafka UI 372,4 MiB.
No son una prueba de capacidad de las maquinas cloud ni incluyen todavia todo el sistema.

`deploy/aws/permisos.txt` registra ExpiredToken en STS: renovar la sesion Learner Lab y repetir el script.
`deploy/azure/region.txt` registra la verificacion pendiente; no contiene resultados de cuota o presupuesto
inventados. Debe haber al menos 4 vCPU regionales disponibles y ambos SKU sin restricciones. El titular
debe definir y crear el presupuesto con alerta; aun no hay un monto ni destinatario confirmados.
