# M3-C5 — Monitoreo proactivo

## Contexto

Banco Patacon tiene un frontend web y un backend de transferencias. La infraestructura está declarada con Terraform. En LAB01 se construye, a partir de un spec y con ayuda de un agente, un workflow manual de GitHub Actions para ejecutar Terraform.

El sistema que vamos a monitorear sigue este recorrido:

```text
spec → Plan Mode → workflow → Terraform apply
→ frontend + backend → tráfico → logs
→ métricas → dashboard → alarmas
```

## Arquitectura objetivo

```mermaid
flowchart LR
  SPEC["Spec del workflow"] --> AGENT["Kiro Spec Mode"]
  AGENT --> WF["GitHub Actions"]
  WF --> TF["Terraform"]
  TF --> FE["EC2 Frontend nginx"]
  TF --> BE["EC2 Backend Flask"]
  FE --> FLOG["/aws/frontend/access"]
  BE --> BLOG["/aws/backend/app"]
  FLOG --> CW["CloudWatch Logs"]
  BLOG --> CW
  CW --> MF["Metric filters"]
  CW --> DASH["Dashboard"]
  CW --> ALARM["Alarmas"]
```

### Qué monitoreamos

| Componente | Señales |
|---|---|
| Frontend nginx | Requests, status HTTP y errores 5xx |
| Backend Flask | Transferencias exitosas/erróneas y duración |
| EC2 | CPU, red y estado de instancia |
| CloudWatch Logs | Evidencia detallada de requests y eventos |
| Metric filters | Métricas agregadas derivadas de logs |
| Dashboard | Volumen, errores y saturación |
| Alarmas | Condiciones que requieren atención |

## Labs

| Lab | Guía | Formato |
|---|---|---|
| LAB01 | Clase en vivo | Spec en Kiro, workflow, deploy y monitoreo por consola |
| LAB02 | [`guias/guia-monitoreo-lab02-terraform.md`](guias/guia-monitoreo-lab02-terraform.md) | Tarea: monitoreo como código con Terraform |

## Specs

La guía de specs y el guion de construcción del workflow quedan en el material docente. Este repositorio conserva el material operativo del alumno y la infraestructura de referencia.

## Estructura

```text
labs/m3-c5-lab/
├── guias/guia-monitoreo-lab02-terraform.md
├── terraform/infra/
└── scripts/generar-trafico.sh
```

## State y Actions

- El bucket de Terraform state lo entrega el docente por cuenta.
- Se configura como variable del Environment `lab`: `TF_STATE_BUCKET`.
- Las credenciales se configuran como secrets del mismo Environment:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
- Cada identidad usa una key aislada: `m3-c5/<student_identity>/infra.tfstate`.
- El bucket de state nunca se elimina con `destroy`.
- LAB01 crea el workflow desde el spec; LAB02 convierte el monitoreo de consola en Terraform.
