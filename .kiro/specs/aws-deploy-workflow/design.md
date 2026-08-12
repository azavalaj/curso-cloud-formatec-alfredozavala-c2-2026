# Design Document: aws-deploy-workflow

## Overview

El workflow `m3-c5-infra-cd.yml` es un archivo de GitHub Actions que gestiona el ciclo de vida completo de la infraestructura AWS del lab M3-C5 (Banco Patacon) mediante Terraform. Expone un único trigger manual (`workflow_dispatch`) con un input `operation` (plan/apply/destroy) para que el operador elija explícitamente qué acción ejecutar.

El diseño se organiza en tres jobs encadenados:

1. **`ci-terraform`** — Validación estática: format check + init sin backend + validate.
2. **`cd-terraform`** — Ejecución real contra AWS: init con backend S3 + plan/apply/destroy según `operation`.
3. **`output-ec2`** — Solo tras un `apply` exitoso: lee el estado remoto y muestra las cinco URLs/IDs de las EC2 desplegadas.

El workflow no crea ni modifica ningún archivo `.tf`; tampoco almacena credenciales en texto plano. Toda la configuración sensible se lee del Environment `lab` de GitHub.

---

## Architecture

```mermaid
flowchart TD
    A([workflow_dispatch\noperation: plan|apply|destroy]) --> B

    subgraph WF ["m3-c5-infra-cd.yml"]
        B["ci-terraform\n• fmt -check\n• init -backend=false\n• validate"]
        C["cd-terraform\n• configure-aws-credentials\n• init con backend S3\n• plan / apply / destroy\nsegun operation"]
        D["output-ec2\n• configure-aws-credentials\n• init con backend S3\n• terraform output\n• print labels + values"]

        B -->|success| C
        C -->|success + operation==apply| D
    end

    C -.->|failure| SKIP([cd-terraform saltado\noutput-ec2 no ejecuta])

    style A fill:#4a90d9,color:#fff
    style B fill:#5ba85a,color:#fff
    style C fill:#d9954a,color:#fff
    style D fill:#9b59b6,color:#fff
```

### Principios de diseño

- **Fail-fast**: cada job detiene la cadena en cuanto un paso falla. Sin `continue-on-error` en pasos críticos.
- **Separación CI/CD**: el job CI no toca AWS — valida únicamente la sintaxis Terraform. El job CD usa las credenciales reales.
- **Idempotencia del output**: `output-ec2` solo lee estado remoto, nunca lo modifica. Se puede re-ejecutar de forma segura.
- **Sin secrets en YAML**: todas las credenciales y variables llegan exclusivamente mediante el Expression syntax `${{ secrets.* }}` y `${{ vars.* }}` del Environment `lab`.

---

## Components and Interfaces

### Trigger y entradas

| Campo | Valor |
|---|---|
| `on` | `workflow_dispatch` únicamente |
| `inputs.operation` | `type: choice`, opciones: `plan`, `apply`, `destroy`, default: `plan` |

GitHub Actions valida el valor de `choice` en tiempo de activación — si el valor no es una de las opciones declaradas, el trigger es rechazado por la plataforma antes de que cualquier job comience.

### Bloque de nivel workflow

```yaml
name: Infra CD - Banco Patacon M3-C5

on:
  workflow_dispatch:
    inputs:
      operation:
        description: "Operación Terraform"
        required: true
        type: choice
        default: plan
        options:
          - plan
          - apply
          - destroy

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false

env:
  TF_VERSION: "1.15.8"
  TF_IN_AUTOMATION: "true"
  TF_INPUT: "false"
  TF_WORKING_DIR: labs/m3-c5-lab/terraform/infra
```

**Decisión de diseño — `TF_VERSION` en `env`**: Se define a nivel workflow para ser reutilizada por todos los jobs con `${{ env.TF_VERSION }}`, evitando duplicación y simplificando actualizaciones futuras.

**Decisión de diseño — `TF_WORKING_DIR` en `env`**: El directorio de trabajo se centraliza como variable de entorno para eliminar repetición y facilitar futuras reestructuraciones de carpetas.

### Job `ci-terraform`

Responsabilidades: verificar que el código Terraform esté bien formateado y sea sintácticamente válido, sin contactar AWS ni el backend S3.

| Pasos | Acción / Comando |
|---|---|
| Checkout | `actions/checkout@v4` |
| Setup Terraform | `hashicorp/setup-terraform@v3` con `terraform_version: ${{ env.TF_VERSION }}` y `terraform_wrapper: false` |
| fmt | `terraform fmt -check -recursive` en `TF_WORKING_DIR` |
| init sin backend | `terraform init -backend=false` en `TF_WORKING_DIR` |
| validate | `terraform validate` en `TF_WORKING_DIR` |

**`terraform_wrapper: false`**: Se desactiva el wrapper para que los exit codes de Terraform sean los nativos del proceso, permitiendo que GitHub Actions falle correctamente en pasos subsiguientes.

**Sin `environment: lab`**: Este job no accede a secretos ni variables del Environment, por lo que no requiere declararlo. Esto reduce la exposición del entorno a los jobs que realmente necesitan credenciales.

### Job `cd-terraform`

Responsabilidades: ejecutar la operación Terraform seleccionada contra AWS usando el backend S3.

```
needs: [ci-terraform]
environment: lab
timeout-minutes: 25
```

Variables de entorno del job:

```yaml
env:
  AWS_REGION: ${{ vars.AWS_REGION }}
  TF_VAR_student_identity: ${{ vars.STUDENT_IDENTITY }}
```

| Pasos | Acción / Comando | Condición |
|---|---|---|
| Checkout | `actions/checkout@v4` | siempre |
| Setup Terraform | `hashicorp/setup-terraform@v3` | siempre |
| Configure AWS | `aws-actions/configure-aws-credentials@v4` | siempre |
| Verificar identidad | `aws sts get-caller-identity` | siempre |
| Terraform init (S3) | `terraform init -backend-config=...` | siempre |
| Terraform plan | `terraform plan` | `inputs.operation == 'plan'` |
| Terraform plan (apply) | `terraform plan -out=tfplan` | `inputs.operation == 'apply'` |
| Terraform apply | `terraform apply -auto-approve tfplan` | `inputs.operation == 'apply'` |
| Terraform plan (destroy) | `terraform plan -destroy -out=tfplan` | `inputs.operation == 'destroy'` |
| Terraform destroy | `terraform apply -auto-approve tfplan` | `inputs.operation == 'destroy'` |

**Decisión de diseño — pasos separados para plan y apply/destroy**: Dividir el plan del apply en pasos distintos (en lugar de `terraform apply -auto-approve`) garantiza que el plan se logueé por completo antes de ejecutar la acción, y que un fallo en el plan detenga el job antes de tocar infraestructura.

El `terraform init` usa `-backend-config` para inyectar los parámetros del backend sin hardcodearlos en el archivo `backend.tf`:

```bash
terraform init \
  -backend-config="bucket=${{ vars.TF_STATE_BUCKET }}" \
  -backend-config="key=${{ vars.TF_STATE_KEY }}" \
  -backend-config="region=${{ vars.AWS_REGION }}"
```

### Job `output-ec2`

Responsabilidades: leer los cinco outputs del estado Terraform remoto y mostrarlos en el log del workflow para que el operador pueda acceder de inmediato a los servicios desplegados.

```
needs: [cd-terraform]
if: success() && inputs.operation == 'apply'
environment: lab
timeout-minutes: 5
```

| Pasos | Acción / Comando |
|---|---|
| Checkout | `actions/checkout@v4` |
| Setup Terraform | `hashicorp/setup-terraform@v3` |
| Configure AWS | `aws-actions/configure-aws-credentials@v4` |
| Terraform init (S3) | `terraform init -backend-config=...` (mismos parámetros que `cd-terraform`) |
| Print outputs | Script bash que lee cada output y lo valida antes de imprimirlo |

Script de validación e impresión:

```bash
for OUTPUT in frontend_url backend_url backend_health_url frontend_instance_id backend_instance_id; do
  VALUE=$(terraform -chdir=${{ env.TF_WORKING_DIR }} output -raw "$OUTPUT" 2>/dev/null || true)
  if [ -z "$VALUE" ]; then
    echo "::error::Output Terraform '${OUTPUT}' está vacío o ausente" >&2
    exit 1
  fi
  echo "${OUTPUT}: ${VALUE}"
done
```

---

## Data Models

Este workflow opera sobre tres categorías de datos de configuración:

### 1. Variables y secretos del Environment `lab`

| Nombre | Tipo | Descripción |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Secret | Clave de acceso AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret | Clave secreta AWS |
| `AWS_REGION` | Variable | Región AWS (ej: `us-east-1`) |
| `STUDENT_IDENTITY` | Variable | Identificador del alumno, prefijo para recursos |
| `TF_STATE_BUCKET` | Variable | Nombre del bucket S3 para estado Terraform |
| `TF_STATE_KEY` | Variable | Key en S3 para el archivo de estado |

### 2. Variables de entorno del workflow

| Nombre | Valor | Alcance |
|---|---|---|
| `TF_VERSION` | `"1.15.8"` | Workflow (todos los jobs) |
| `TF_IN_AUTOMATION` | `"true"` | Workflow (todos los jobs) |
| `TF_INPUT` | `"false"` | Workflow (todos los jobs) |
| `TF_WORKING_DIR` | `labs/m3-c5-lab/terraform/infra` | Workflow (todos los jobs) |
| `AWS_REGION` | `${{ vars.AWS_REGION }}` | Jobs `cd-terraform`, `output-ec2` |
| `TF_VAR_student_identity` | `${{ vars.STUDENT_IDENTITY }}` | Jobs `cd-terraform`, `output-ec2` |

### 3. Outputs de Terraform leídos por `output-ec2`

| Output Terraform | Descripción | Formato esperado |
|---|---|---|
| `frontend_url` | URL HTTP pública del frontend nginx | `http://<public_ip>` |
| `frontend_instance_id` | Instance ID de la EC2 frontend | `i-XXXXXXXXXXXXXXXXX` |
| `backend_url` | URL HTTP pública del backend Flask | `http://<public_ip>:8080` |
| `backend_health_url` | Endpoint de health check del backend | `http://<public_ip>:8080/health` |
| `backend_instance_id` | Instance ID de la EC2 backend | `i-XXXXXXXXXXXXXXXXX` |

---

## Correctness Properties

Esta feature es un workflow de GitHub Actions — un archivo YAML declarativo que orquesta herramientas externas (Terraform, aws-actions). No contiene funciones puras ni lógica de transformación de datos propia.

El análisis de prework determinó que todos los criterios de aceptación caen en categorías SMOKE, EXAMPLE o INTEGRATION:

- **SMOKE**: Verificaciones estructurales del YAML (presencia de bloques, valores de campos, orden de pasos) — se comprueban con `actionlint` en una sola ejecución, sin variación de inputs.
- **EXAMPLE**: Comportamiento condicional de pasos según el valor de `operation` — se comprueban con 2–3 ejecuciones de ejemplo, no con 100 iteraciones aleatorias.
- **INTEGRATION**: Comportamiento de acciones externas (`aws-actions/configure-aws-credentials`, estado S3 de Terraform) — se comprueban con integration tests end-to-end.

**Property-based testing no aplica a esta feature** porque no existen funciones puras propias sobre las que formular "para todo input X, la propiedad P(X) se cumple". La lógica del workflow es declarativa y determinista: cada paso ejecuta una herramienta externa con parámetros fijos derivados del Environment `lab`. Ver la sección Testing Strategy para el enfoque completo.

---

## Error Handling

### Fallos en `ci-terraform`

| Condición | Comportamiento |
|---|---|
| `terraform fmt` detecta archivos mal formateados | El paso falla con exit code ≠ 0; los pasos `init` y `validate` se saltan; `cd-terraform` y `output-ec2` no se ejecutan |
| `terraform init -backend=false` falla | El paso falla; `terraform validate` se salta; los jobs dependientes no se ejecutan |
| `terraform validate` detecta errores de sintaxis | El paso falla; `cd-terraform` y `output-ec2` no se ejecutan |

### Fallos en `cd-terraform`

| Condición | Comportamiento |
|---|---|
| `configure-aws-credentials` falla (credenciales inválidas o ausentes) | La acción falla con error descriptivo; ningún paso Terraform se ejecuta |
| `terraform init` falla (variables de bucket/key/region ausentes o bucket inaccesible) | El paso falla; ningún plan ni apply se ejecuta |
| `terraform plan -out=tfplan` falla (operación `apply` o `destroy`) | El paso falla; el paso `terraform apply` correspondiente no se ejecuta |
| `terraform apply` falla | El paso falla; el job termina en error; `output-ec2` no se ejecuta |
| `STUDENT_IDENTITY` vacío | `TF_VAR_student_identity` será cadena vacía; Terraform puede aceptarla o fallar según validaciones en `variables.tf` |

### Fallos en `output-ec2`

| Condición | Comportamiento |
|---|---|
| `configure-aws-credentials` falla | La acción falla; ningún comando Terraform se ejecuta |
| `terraform init` falla (estado S3 inaccesible) | El paso falla; no se leen outputs |
| Un output de Terraform está vacío o ausente | El script de bash emite `::error::` con el nombre del output faltante y termina con `exit 1` |

### Comportamiento de concurrencia

Cuando se activa una segunda ejecución mientras hay una activa en el mismo workflow y rama:
- La nueva ejecución queda en estado `queued` (cola de espera)
- La ejecución activa **no** se cancela (`cancel-in-progress: false`)
- Esto protege el estado de Terraform de modificaciones concurrentes que podrían corromperlo

---

## Testing Strategy

Dado que esta feature es un workflow de GitHub Actions (IaC/configuración declarativa), **property-based testing no aplica**. El enfoque de pruebas se divide en tres niveles:

### Nivel 1: Smoke Tests — Validación estática del YAML

Herramienta: [`actionlint`](https://github.com/rhysd/actionlint)

Ejecutar `actionlint` sobre el archivo del workflow para verificar:

- El bloque `on:` contiene únicamente `workflow_dispatch` (Req. 1.1)
- El input `operation` es de `type: choice` con las tres opciones y default `plan` (Req. 1.2)
- Los jobs `cd-terraform` y `output-ec2` declaran `environment: lab` (Req. 2.7)
- No hay credenciales hardcodeadas — todas las referencias a secrets usan `${{ secrets.* }}` (Req. 2.1)
- El bloque `permissions:` contiene únicamente `contents: read` (Req. 6.1)
- `concurrency.cancel-in-progress: false` está presente (Req. 6.3)
- El bloque `env:` de nivel workflow define `TF_IN_AUTOMATION` y `TF_INPUT` (Req. 6.4)
- `output-ec2` declara `needs: [cd-terraform]` con condición `if: success() && inputs.operation == 'apply'` (Req. 5.1)
- `setup-terraform` usa `terraform_version: ${{ env.TF_VERSION }}` (Req. 3.6)

```bash
# Ejecutar desde la raíz del repositorio
actionlint .github/workflows/m3-c5-infra-cd.yml
```

### Nivel 2: Example-Based Tests — Comportamiento de pasos condicionales

Pruebas de integración manuales o con [`act`](https://github.com/nektos/act) (runner local de GitHub Actions):

| Escenario | Pasos esperados que se ejecutan | Req. |
|---|---|---|
| `operation=plan` | ci: fmt+init+validate; cd: init+plan (sin tfplan file); output-ec2: NO ejecuta | 4.2 |
| `operation=apply` | ci: fmt+init+validate; cd: init+plan-out+apply; output-ec2: ejecuta | 4.3, 4.4, 5.1 |
| `operation=destroy` | ci: fmt+init+validate; cd: init+plan-destroy+apply; output-ec2: NO ejecuta | 4.5, 4.6 |
| ci-terraform falla (fmt mal) | cd-terraform y output-ec2 NO ejecutan | 3.2, 4.1 |
| Output vacío en output-ec2 | El job falla con mensaje que identifica el output ausente | 5.9 |

### Nivel 3: Integration Tests — Ejecución real contra AWS

Pruebas end-to-end ejecutadas desde GitHub Actions con credenciales reales del Environment `lab`:

| Test | Descripción | Req. validados |
|---|---|---|
| Deploy completo | Dispatch con `apply`, verificar que todos los recursos se crean y output-ec2 muestra las 5 etiquetas | 4.4, 5.3–5.7 |
| Destroy completo | Dispatch con `destroy`, verificar que los recursos se eliminan | 4.6 |
| Credenciales inválidas | Configurar credenciales vacías en el Environment, verificar fallo en configure-aws-credentials | 2.5, 4.8 |
| Backend S3 inaccesible | Configurar TF_STATE_BUCKET incorrecto, verificar fallo en terraform init | 4.7 |

### Herramientas recomendadas

| Herramienta | Propósito |
|---|---|
| `actionlint` | Linting estático de YAML de GitHub Actions |
| `act` | Ejecución local de workflows para smoke/example tests sin push |
| `terraform validate` | Validación de sintaxis de código Terraform (ya incluida en ci-terraform) |
| GitHub Actions UI | Ejecución de integration tests con Environment `lab` real |
