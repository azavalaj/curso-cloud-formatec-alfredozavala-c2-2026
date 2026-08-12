# Implementation Plan: aws-deploy-workflow

## Overview

Crear el archivo `.github/workflows/m3-c5-infra-cd.yml` que implementa el workflow de CD para la infraestructura AWS del lab M3-C5 (Banco Patacon). El workflow expone un único trigger manual (`workflow_dispatch`) con tres operaciones (plan/apply/destroy) y encadena tres jobs: `ci-terraform` (validación estática), `cd-terraform` (ejecución real contra AWS) y `output-ec2` (lectura de outputs tras apply). Toda la configuración sensible se lee del Environment `lab` de GitHub; no se hardcodean credenciales.

El diseño es un archivo YAML declarativo (IaC/GitHub Actions) sin lógica de transformación de datos propia — property-based testing no aplica. Las pruebas se cubren con smoke tests via `actionlint` y example-based tests.

---

## Tasks

- [x] 1. Crear la estructura base del workflow con trigger y configuración de nivel workflow
  - Crear el archivo `.github/workflows/m3-c5-infra-cd.yml`
  - Declarar `name: Infra CD - Banco Patacon M3-C5`
  - Definir el bloque `on: workflow_dispatch` con el input `operation` de `type: choice`, opciones `plan`/`apply`/`destroy` y default `plan`
  - Declarar `permissions: contents: read` como único scope
  - Configurar el bloque `concurrency` con grupo `${{ github.workflow }}-${{ github.ref }}` y `cancel-in-progress: false`
  - Definir el bloque `env` de nivel workflow: `TF_VERSION`, `TF_IN_AUTOMATION: "true"`, `TF_INPUT: "false"`, `TF_WORKING_DIR`
  - _Requirements: 1.1, 1.2, 6.1, 6.2, 6.3, 6.4_

- [x] 2. Implementar el job `ci-terraform`
  - [x] 2.1 Escribir el job `ci-terraform` con sus cinco pasos en orden
    - `runs-on: ubuntu-latest`, `timeout-minutes: 10`
    - Paso checkout con `actions/checkout@v4`
    - Paso setup-terraform con `hashicorp/setup-terraform@v3`, `terraform_version: ${{ env.TF_VERSION }}` y `terraform_wrapper: false`
    - Paso `terraform fmt -check -recursive` con `working-directory: ${{ env.TF_WORKING_DIR }}`
    - Paso `terraform init -backend=false` con `working-directory: ${{ env.TF_WORKING_DIR }}`
    - Paso `terraform validate` con `working-directory: ${{ env.TF_WORKING_DIR }}`
    - Sin declarar `environment: lab` (este job no accede a secretos ni variables del Environment)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [ ]* 2.2 Escribir smoke test con `actionlint` para el job `ci-terraform`
    - Verificar que el job no declara `environment: lab`
    - Verificar que `setup-terraform` usa `terraform_version: ${{ env.TF_VERSION }}`
    - Verificar que `terraform_wrapper: false` está presente
    - _Requirements: 3.6_

- [x] 3. Checkpoint — Verificar que el YAML es válido hasta aquí
  - Ejecutar `actionlint .github/workflows/m3-c5-infra-cd.yml` y confirmar que no reporta errores.

- [x] 4. Implementar el job `cd-terraform`
  - [x] 4.1 Escribir la cabecera y configuración del job `cd-terraform`
    - `needs: [ci-terraform]`
    - `environment: lab`
    - `runs-on: ubuntu-latest`, `timeout-minutes: 25`
    - Bloque `env` del job: `AWS_REGION: ${{ vars.AWS_REGION }}` y `TF_VAR_student_identity: ${{ vars.STUDENT_IDENTITY }}`
    - _Requirements: 2.2, 2.3, 2.7, 4.1, 4.10_

  - [x] 4.2 Escribir los pasos de inicialización de `cd-terraform` (checkout, setup, AWS credentials, identity check, terraform init)
    - Paso checkout con `actions/checkout@v4`
    - Paso setup-terraform con `hashicorp/setup-terraform@v3`, `terraform_version: ${{ env.TF_VERSION }}`, `terraform_wrapper: false`
    - Paso `aws-actions/configure-aws-credentials@v4` con `aws-access-key-id`, `aws-secret-access-key` y `aws-region` desde Environment `lab`
    - Paso `aws sts get-caller-identity` para verificar identidad
    - Paso `terraform init` con `-backend-config` para bucket, key y region usando variables del Environment
    - `working-directory: ${{ env.TF_WORKING_DIR }}` en los pasos Terraform
    - _Requirements: 2.1, 2.4, 2.5, 2.6, 4.7, 4.8_

  - [x] 4.3 Escribir los pasos condicionales de plan/apply/destroy en `cd-terraform`
    - Paso `terraform plan` con condición `if: inputs.operation == 'plan'` (sin plan file)
    - Paso `terraform plan -out=tfplan` con condición `if: inputs.operation == 'apply'`
    - Paso `terraform apply -auto-approve tfplan` con condición `if: inputs.operation == 'apply'`
    - Paso `terraform plan -destroy -out=tfplan` con condición `if: inputs.operation == 'destroy'`
    - Paso `terraform apply -auto-approve tfplan` (destroy) con condición `if: inputs.operation == 'destroy'`
    - `working-directory: ${{ env.TF_WORKING_DIR }}` en todos los pasos Terraform
    - _Requirements: 4.2, 4.3, 4.4, 4.5, 4.6, 4.9_

  - [ ]* 4.4 Escribir smoke tests con `actionlint` para el job `cd-terraform`
    - Verificar que declara `environment: lab`
    - Verificar que `needs: [ci-terraform]` está presente
    - Verificar que no hay credenciales hardcodeadas (todos los secrets usan `${{ secrets.* }}`)
    - Verificar que `TF_VAR_student_identity` se mapea desde `vars.STUDENT_IDENTITY`
    - _Requirements: 2.1, 2.7, 4.1_

- [x] 5. Implementar el job `output-ec2`
  - [x] 5.1 Escribir la cabecera y configuración del job `output-ec2`
    - `needs: [cd-terraform]`
    - `if: success() && inputs.operation == 'apply'`
    - `environment: lab`
    - `runs-on: ubuntu-latest`, `timeout-minutes: 5`
    - Bloque `env` del job: `AWS_REGION: ${{ vars.AWS_REGION }}` y `TF_VAR_student_identity: ${{ vars.STUDENT_IDENTITY }}`
    - _Requirements: 5.1, 2.7_

  - [x] 5.2 Escribir los pasos de inicialización de `output-ec2` (checkout, setup, AWS credentials, terraform init)
    - Paso checkout con `actions/checkout@v4`
    - Paso setup-terraform con `hashicorp/setup-terraform@v3`, `terraform_version: ${{ env.TF_VERSION }}`, `terraform_wrapper: false`
    - Paso `aws-actions/configure-aws-credentials@v4` con los mismos parámetros que en `cd-terraform`
    - Paso `terraform init` con los mismos `-backend-config` que en `cd-terraform`
    - _Requirements: 5.2, 5.8_

  - [x] 5.3 Escribir el paso de impresión de outputs de EC2
    - Script bash que itera sobre los cinco outputs: `frontend_url`, `backend_url`, `backend_health_url`, `frontend_instance_id`, `backend_instance_id`
    - Para cada output: capturar con `terraform -chdir=${{ env.TF_WORKING_DIR }} output -raw "$OUTPUT"`
    - Si el valor está vacío, emitir `::error::` con el nombre del output y terminar con `exit 1`
    - Si el valor es válido, imprimir `${OUTPUT}: ${VALUE}`
    - _Requirements: 5.3, 5.4, 5.5, 5.6, 5.7, 5.9_

  - [ ]* 5.4 Escribir smoke tests con `actionlint` para el job `output-ec2`
    - Verificar que declara `needs: [cd-terraform]`
    - Verificar que la condición `if` contiene `inputs.operation == 'apply'`
    - Verificar que `timeout-minutes` es 5
    - Verificar que declara `environment: lab`
    - _Requirements: 5.1, 2.7_

- [x] 6. Checkpoint final — Validar el workflow completo
  - Ejecutar `actionlint .github/workflows/m3-c5-infra-cd.yml` sobre el archivo completo y confirmar que no reporta errores.
  - Revisar que los tres jobs aparecen en orden y que las condiciones condicionales de los pasos son correctas según el escenario de cada `operation`.

---

## Notes

- Las tareas marcadas con `*` son opcionales y pueden omitirse para un MVP más rápido.
- No aplica property-based testing: el workflow es un archivo YAML declarativo (IaC) sin funciones puras propias — ver sección "Correctness Properties" del diseño.
- Los smoke tests se ejecutan con `actionlint`; los example-based tests se pueden ejecutar localmente con `act` o manualmente desde la UI de GitHub Actions.
- `actionlint` debe estar instalado en la máquina del desarrollador o en el entorno CI que valide el workflow.
- Cada tarea referencia los criterios de aceptación específicos para trazabilidad completa.
- El job `ci-terraform` no declara `environment: lab` intencionalmente — reduce la exposición del entorno de secretos a los jobs que realmente los necesitan.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["2.1"] },
    { "id": 1, "tasks": ["2.2", "4.1"] },
    { "id": 2, "tasks": ["4.2", "4.4"] },
    { "id": 3, "tasks": ["4.3"] },
    { "id": 4, "tasks": ["5.1"] },
    { "id": 5, "tasks": ["5.2"] },
    { "id": 6, "tasks": ["5.3", "5.4"] }
  ]
}
```
