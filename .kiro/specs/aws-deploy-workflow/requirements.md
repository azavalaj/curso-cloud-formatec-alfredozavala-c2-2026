# Requirements Document

## Introduction

Este documento especifica los requisitos para el workflow de GitHub Actions del lab M3-C5 (Banco Patacon). El workflow gestiona el ciclo de vida completo de la infraestructura AWS mediante Terraform: permite ejecutar `plan`, `apply` y `destroy` con un único trigger manual. Tras un `apply` exitoso, un job dedicado consulta los outputs de Terraform y muestra las IPs públicas de las instancias EC2 creadas (frontend nginx y backend Flask). El workflow no crea ni modifica archivos `.tf`; tampoco almacena credenciales en texto plano — todas las credenciales y variables de entorno se leen del Environment `lab` de GitHub.

## Glossary

- **Workflow**: Archivo YAML ubicado en `.github/workflows/` que define la automatización de GitHub Actions.
- **Workflow_Dispatch**: Trigger manual de GitHub Actions que permite iniciar una ejecución desde la UI o vía API.
- **Environment_Lab**: Entorno `lab` configurado en GitHub con variables (`AWS_REGION`, `STUDENT_IDENTITY`, `TF_STATE_BUCKET`, `TF_STATE_KEY`) y secretos (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).
- **Terraform**: Herramienta de infraestructura como código cuyo código fuente reside en `labs/m3-c5-lab/terraform/infra/`.
- **Backend_S3**: Almacenamiento remoto del estado de Terraform en un bucket S3, con key `m3-c5/<student_identity>/infra.tfstate`.
- **Operation**: Input del dispatch manual que determina la acción Terraform a ejecutar (`plan`, `apply` o `destroy`).
- **Output_Job**: Job final del workflow responsable de leer los outputs de Terraform y mostrar las IPs de las EC2.
- **EC2_Frontend**: Instancia EC2 que ejecuta nginx, identificada por el output `frontend_instance_id`.
- **EC2_Backend**: Instancia EC2 que ejecuta Flask en el puerto 8080, identificada por el output `backend_instance_id`.

---

## Requirements

### Requisito 1: Trigger manual con selección de operación

**User Story:** Como operador del lab, quiero iniciar el workflow manualmente eligiendo entre `plan`, `apply` y `destroy`, para controlar explícitamente qué acción Terraform se ejecuta.

#### Criterios de Aceptación

1. THE Workflow SHALL declarar `workflow_dispatch` como único trigger en la sección `on` del archivo YAML, sin ningún otro trigger adicional (push, pull_request, schedule, etc.).
2. WHEN el operador activa el Workflow, THE Workflow SHALL presentar un input `operation` de tipo `choice` con las opciones `plan`, `apply` y `destroy`, y con el valor por defecto `plan`.
3. IF el valor del input `operation` en el momento de ejecución no es uno de `plan`, `apply` o `destroy`, THEN THE Workflow SHALL fallar el job con un mensaje de error indicando el valor inválido recibido.

---

### Requisito 2: Uso exclusivo de variables y secretos del Environment Lab

**User Story:** Como operador del lab, quiero que el workflow lea todas las credenciales y variables de configuración del Environment `lab` de GitHub, para que ninguna credencial quede expuesta en el código fuente.

#### Criterios de Aceptación

1. THE Workflow SHALL leer las credenciales AWS exclusivamente desde los secretos `AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY` del Environment_Lab.
2. THE Workflow SHALL leer la región AWS desde la variable `AWS_REGION` del Environment_Lab.
3. THE Workflow SHALL leer la identidad del alumno desde la variable `STUDENT_IDENTITY` del Environment_Lab.
4. THE Workflow SHALL leer el bucket y la key del estado Terraform desde las variables `TF_STATE_BUCKET` y `TF_STATE_KEY` del Environment_Lab.
5. IF el Workflow detecta que `AWS_ACCESS_KEY_ID` o `AWS_SECRET_ACCESS_KEY` están ausentes o vacíos, THEN THE Workflow SHALL fallar el job con un error indicando cuál credencial está ausente.
6. IF alguna de las variables `AWS_REGION`, `STUDENT_IDENTITY`, `TF_STATE_BUCKET` o `TF_STATE_KEY` está ausente o vacía al momento de ejecutar un job que las requiere, THEN THE Workflow SHALL fallar ese job con un mensaje de error que identifique la variable faltante.
7. THE Workflow SHALL declarar `environment: lab` en todos los jobs que referencien al menos una variable o secreto del Environment_Lab.

---

### Requisito 3: Validación estática de Terraform (CI)

**User Story:** Como operador del lab, quiero que el workflow valide el formato y la sintaxis de los archivos Terraform antes de ejecutar cualquier operación sobre AWS, para detectar errores de configuración de forma temprana.

#### Criterios de Aceptación

1. THE Workflow SHALL ejecutar un job `ci-terraform` que corra `terraform fmt -check -recursive` sobre `labs/m3-c5-lab/terraform/infra`.
2. WHEN `terraform fmt` detecta archivos mal formateados (exit code ≠ 0), THE Workflow SHALL fallar los pasos `terraform init` y `terraform validate` restantes del mismo job, así como todos los jobs dependientes.
3. WHEN `terraform fmt` finaliza con éxito, THE Workflow SHALL ejecutar `terraform init -backend=false` en el directorio `labs/m3-c5-lab/terraform/infra`.
4. IF `terraform init -backend=false` falla (exit code ≠ 0), THEN THE Workflow SHALL omitir el paso `terraform validate` y fallar el job `ci-terraform`.
5. WHEN `terraform init -backend=false` finaliza con éxito, THE Workflow SHALL ejecutar `terraform validate` en el directorio `labs/m3-c5-lab/terraform/infra`.
6. THE Workflow SHALL configurar Terraform mediante `hashicorp/setup-terraform@v3` especificando `terraform_version` con el valor de la variable de entorno `TF_VERSION`, cuyo formato SHALL seguir semver `x.y.z`.

---

### Requisito 4: Ejecución de Terraform en AWS (CD)

**User Story:** Como operador del lab, quiero que el workflow ejecute la operación Terraform seleccionada contra AWS usando el backend S3, para gestionar el ciclo de vida de la infraestructura del lab.

#### Criterios de Aceptación

1. IF el job `ci-terraform` finaliza con éxito, THEN THE Workflow SHALL ejecutar el job `cd-terraform`; IF `ci-terraform` falla, THE Workflow SHALL omitir `cd-terraform` y todos sus dependientes.
2. WHEN el input `operation` es `plan`, THE Workflow SHALL ejecutar `terraform plan` sin generar un plan file persistente.
3. WHEN el input `operation` es `apply`, THE Workflow SHALL ejecutar `terraform plan -out=tfplan`; IF ese plan falla (exit code ≠ 0), THEN THE Workflow SHALL fallar el job sin ejecutar `terraform apply`.
4. WHEN `terraform plan -out=tfplan` finaliza con éxito y `operation` es `apply`, THE Workflow SHALL ejecutar `terraform apply -auto-approve tfplan`.
5. WHEN el input `operation` es `destroy`, THE Workflow SHALL ejecutar `terraform plan -destroy -out=tfplan`; IF ese plan falla (exit code ≠ 0), THEN THE Workflow SHALL fallar el job sin ejecutar `terraform apply`.
6. WHEN `terraform plan -destroy -out=tfplan` finaliza con éxito y `operation` es `destroy`, THE Workflow SHALL ejecutar `terraform apply -auto-approve tfplan`.
7. IF alguna de las variables `TF_STATE_BUCKET`, `TF_STATE_KEY` o `AWS_REGION` está vacía o ausente, THEN THE Workflow SHALL fallar el paso `terraform init` con un mensaje que identifique la variable faltante, sin intentar contactar el backend S3.
8. IF la configuración de credenciales AWS mediante `aws-actions/configure-aws-credentials@v4` falla, THEN THE Workflow SHALL fallar el job `cd-terraform` inmediatamente sin ejecutar ningún paso Terraform.
9. IF la variable `STUDENT_IDENTITY` está vacía o ausente al momento de ejecutar `cd-terraform`, THEN THE Workflow SHALL fallar el job con un mensaje indicando que `TF_VAR_student_identity` no puede ser vacío.
10. THE Workflow SHALL pasar la identidad del alumno a Terraform mediante la variable de entorno `TF_VAR_student_identity` con el valor de `STUDENT_IDENTITY` del Environment_Lab.

---

### Requisito 5: Job de output con IPs de las EC2

**User Story:** Como operador del lab, quiero que el workflow muestre las IPs públicas de las EC2 creadas después de un `apply` exitoso, para poder acceder inmediatamente a los servicios desplegados.

#### Criterios de Aceptación

1. IF el job `cd-terraform` finalizó con éxito Y el input `operation` es `apply`, THEN THE Workflow SHALL ejecutar el job `output-ec2` con un timeout máximo de 5 minutos.
2. WHEN el job `output-ec2` se ejecuta, THE Workflow SHALL inicializar el backend S3 con los mismos parámetros (`TF_STATE_BUCKET`, `TF_STATE_KEY`, `AWS_REGION`) usados en `cd-terraform`.
3. WHEN el job `output-ec2` se ejecuta, THE Workflow SHALL imprimir en el log la etiqueta `frontend_url:` seguida del valor no vacío del output Terraform `frontend_url`.
4. WHEN el job `output-ec2` se ejecuta, THE Workflow SHALL imprimir en el log la etiqueta `backend_url:` seguida del valor no vacío del output Terraform `backend_url`.
5. WHEN el job `output-ec2` se ejecuta, THE Workflow SHALL imprimir en el log la etiqueta `backend_health_url:` seguida del valor no vacío del output Terraform `backend_health_url`.
6. WHEN el job `output-ec2` se ejecuta, THE Workflow SHALL imprimir en el log la etiqueta `frontend_instance_id:` seguida del valor no vacío del output Terraform `frontend_instance_id`.
7. WHEN el job `output-ec2` se ejecuta, THE Workflow SHALL imprimir en el log la etiqueta `backend_instance_id:` seguida del valor no vacío del output Terraform `backend_instance_id`.
8. THE Workflow SHALL configurar las credenciales AWS mediante `aws-actions/configure-aws-credentials@v4` en el job `output-ec2` antes de ejecutar cualquier comando Terraform que acceda al estado remoto.
9. IF alguno de los outputs de Terraform (`frontend_url`, `backend_url`, `backend_health_url`, `frontend_instance_id`, `backend_instance_id`) está vacío o ausente al leerlo, THEN THE Workflow SHALL fallar el job `output-ec2` con un mensaje que indique cuál output no pudo ser recuperado.

---

### Requisito 6: Seguridad y configuración del workflow

**User Story:** Como operador del lab, quiero que el workflow siga buenas prácticas de seguridad y control de concurrencia, para evitar ejecuciones paralelas que corrompan el estado de Terraform.

#### Criterios de Aceptación

1. THE Workflow SHALL declarar `permissions: contents: read` como único scope de permiso en el bloque de permisos del workflow, sin agregar scopes adicionales.
2. THE Workflow SHALL declarar un grupo de concurrencia con el patrón `{nombre-del-workflow}-{rama}` que sea único por combinación de workflow y rama, impidiendo ejecuciones simultáneas del mismo workflow en la misma rama.
3. THE Workflow SHALL configurar `cancel-in-progress: false` en el bloque de concurrencia, de modo que una nueva ejecución espere en cola mientras haya una activa en el mismo grupo.
4. THE Workflow SHALL definir en el bloque `env` de nivel de workflow las variables `TF_IN_AUTOMATION: "true"` y `TF_INPUT: "false"`, visibles para todos los jobs sin redefinición en cada job.
