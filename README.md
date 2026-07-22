# CloudCuyo Migration Lab — Formatec Cloud 2026

Repositorio del curso **Arquitectura e Ingeniería Cloud | C2**.

**Profesor:** Nicolás Pannucio

## Cómo está organizado el repositorio

Cada clase práctica vive en su propia branch. Antes de empezar, elegí la branch indicada por el docente o por la guía del laboratorio.

| Branch | Contenido |
|---|---|
| `main` | Documentación general y entorno base para trabajar desde GitHub Codespaces |
| `m2-c1-lab` | Módulo 2 - Clase 1: migración inicial a AWS |
| `m2-c2-lab` | Módulo 2 - Clase 2: alta disponibilidad, ALB y Auto Scaling |
| `m2-c3-lab` | Módulo 2 - Clase 3: modernización y descomposición de servicios |
| `m2-c4-lab` | Módulo 2 - Clase 4: contenedores, Docker Swarm y serverless |
| `m3-c1-lab` | Módulo 3 - Clase 1: Infrastructure as Code con Terraform |
| `m3-c2-lab` | Módulo 3 - Clase 2: gestión de configuración con Ansible |
| `codespace-test` | Branch de prueba del entorno Terraform + AWS CLI en Codespaces |

## Elegir el entorno de trabajo

Los laboratorios pueden requerir uno de estos caminos:

### Opción A — Entorno local

Usá Windows con PowerShell o WSL y el IDE indicado en la guía. Las herramientas se instalan en tu computadora.

### Opción B — Entorno web con GitHub Codespaces

Usá un IDE y una terminal Linux desde el navegador. GitHub ejecuta el entorno en una máquina remota y prepara las herramientas declaradas por la branch.

Codespaces reemplaza la computadora desde la que ejecutás los comandos. No reemplaza:

- la cuenta AWS del laboratorio;
- los permisos necesarios para crear recursos;
- las instrucciones de la guía;
- la limpieza de recursos;
- la entrega en tu repositorio personal.

```text
Navegador
   |
   v
GitHub Codespaces: VS Code Web + terminal Linux
   |
   +-- Git
   +-- Terraform / Ansible / herramientas del lab
   +-- AWS CLI
   |
   v
Cuenta AWS autorizada para el laboratorio
```

## Requisitos para trabajar desde el navegador

Necesitás:

- una cuenta personal de GitHub;
- acceso estable a Internet;
- la branch correcta del laboratorio;
- credenciales AWS autorizadas cuando la práctica interactúe con AWS;
- permisos para los recursos indicados en la guía.

No necesitás instalar localmente VS Code, WSL, Terraform ni AWS CLI cuando la branch ya contiene la configuración de Codespaces correspondiente.

## Abrir una branch en GitHub Codespaces

1. Abrí el repositorio:

   <https://github.com/nicopannu/curso-cloud-formatec-c2-2026>

2. En el selector de branches, elegí la branch indicada para la clase.
3. Presioná **Code**.
4. Abrí la pestaña **Codespaces**.
5. Presioná **Create codespace on `<branch>`**.
6. Esperá a que finalice la construcción del contenedor.

Para probar el entorno base de Terraform y AWS CLI, usá `codespace-test`:

<https://codespaces.new/nicopannu/curso-cloud-formatec-c2-2026?ref=codespace-test>

Un Codespace queda asociado a la branch seleccionada al momento de crearlo. Verificá la branch antes de empezar:

```bash
git branch --show-current
```

## Verificar las herramientas

Cuando termine la creación, abrí una terminal y ejecutá:

```bash
git --version
aws --version
terraform version
```

La salida debe mostrar una versión para cada herramienta. En los labs Terraform del curso se requiere Terraform `>= 1.6.0`.

Si la branch utiliza otras herramientas, la guía indicará las verificaciones adicionales.

### Si Terraform o AWS CLI no aparecen

1. Abrí la paleta con `Ctrl+Shift+P`.
2. Ejecutá **Codespaces: Rebuild Container**.
3. Esperá a que termine la reconstrucción.
4. Volvé a ejecutar los comandos de versión.

No instales herramientas manualmente antes de intentar la reconstrucción. La configuración versionada de la branch debe poder reproducir el entorno.

## Configurar acceso a AWS

Antes de ejecutar Terraform o comandos AWS, comprobá qué identidad estás usando:

```bash
aws sts get-caller-identity
```

Este comando consulta la identidad y no crea recursos.

### Camino recomendado: acceso temporal con AWS IAM Identity Center

Cuando el docente entregue acceso por SSO:

```bash
aws configure sso --profile curso
aws sso login --profile curso --use-device-code
```

AWS mostrará una URL y un código. Abrí la URL en el navegador, ingresá el código y completá la autorización.

Activá el perfil en la terminal:

```bash
export AWS_PROFILE=curso
aws sts get-caller-identity
```

El acceso SSO usa credenciales temporales y evita guardar access keys permanentes en GitHub.

### Alternativa: credenciales temporales mediante Codespaces secrets

Si el laboratorio entrega `Access Key`, `Secret Key` y `Session Token`, guardalos como secretos de Codespaces.

1. Abrí <https://github.com/settings/codespaces>.
2. En **Codespaces secrets**, presioná **New secret**.
3. Creá los secretos que correspondan:

| Nombre | Uso |
|---|---|
| `AWS_ACCESS_KEY_ID` | Identificador de acceso AWS |
| `AWS_SECRET_ACCESS_KEY` | Clave secreta AWS |
| `AWS_SESSION_TOKEN` | Token requerido por credenciales temporales |
| `AWS_DEFAULT_REGION` | Región del lab, normalmente `us-east-1` |

4. En **Repository access**, autorizá solamente el repositorio necesario.
5. Guardá los secretos.
6. Detené y reiniciá el Codespace para cargar los valores nuevos.

Si las credenciales tienen `Session Token`, los tres componentes son obligatorios. Cuando expiren, actualizá los secretos y reiniciá el Codespace.

Verificá la configuración sin mostrar los valores:

```bash
aws configure list
aws sts get-caller-identity
```

No uses `echo`, `env` ni `printenv` para mostrar credenciales.

### Nunca guardar credenciales en el repositorio

No escribas credenciales en:

- `.devcontainer/devcontainer.json`;
- archivos `.tf`;
- `terraform.tfvars`;
- `.env`;
- scripts;
- README;
- capturas de pantalla;
- commits o historial Git.

Los secretos de Codespaces se autorizan por repositorio, no por branch. Creá Codespaces solamente desde branches confiables y revisá los cambios de `.devcontainer/`, Dockerfiles y scripts de inicio antes de reconstruir el entorno.

## Flujo Terraform desde Codespaces

Entrá en la carpeta indicada por la guía y seguí el flujo normal:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
```

Interpretación:

- `terraform init` descarga los providers requeridos por el proyecto;
- `terraform fmt` normaliza el formato de los archivos;
- `terraform validate` revisa la configuración local;
- `terraform plan` consulta el estado necesario y muestra los cambios propuestos;
- `terraform apply` crea o modifica recursos reales;
- `terraform destroy` elimina recursos administrados por el proyecto.

No ejecutes `terraform apply` ni `terraform destroy` hasta que la guía o el docente lo autoricen.

Antes de aplicar, comprobá siempre:

```bash
aws sts get-caller-identity
terraform plan
```

Revisá la cuenta AWS, la región, los nombres de recursos y las acciones propuestas.

## Guardar el trabajo

El disco del Codespace no reemplaza Git. Guardá los avances con commits y publicalos antes de detener o borrar el entorno:

```bash
git status
git add RUTA_DEL_LAB
git commit -m "Agregar avance del laboratorio"
git push
```

La guía de cada clase define el repositorio personal, la branch, las carpetas y los entregables esperados. Codespaces no cambia esas reglas.

Si abriste el Codespace desde el repositorio del curso y no tenés permisos de escritura, no podrás usarlo como repositorio de entrega. Conservá tus entregables en el repositorio personal indicado por la guía antes de borrar el Codespace.

Nunca publiques:

- credenciales AWS;
- archivos `.env`;
- `.terraform/`;
- `terraform.tfstate` o backups de state;
- `terraform.tfvars` con datos personales o del entorno;
- claves `.pem`;
- paquetes generados que la guía indique excluir.

## Detener y eliminar el Codespace

GitHub contabiliza cómputo mientras el Codespace está activo y almacenamiento mientras el Codespace existe.

- **Stop:** detiene el cómputo y conserva el entorno.
- **Delete:** elimina el entorno y su almacenamiento.

Al terminar una sesión:

1. Revisá `git status`.
2. Hacé commit y push del trabajo que debas conservar.
3. Detené el Codespace.
4. Cuando ya no lo necesites, eliminá el Codespace.

Usá la máquina mínima indicada por el curso y evitá crear varios Codespaces para la misma práctica. Consultá el consumo en la configuración de facturación de GitHub, porque las cuotas pueden cambiar.

## Troubleshooting rápido

### `Unable to locate credentials`

Las credenciales no están cargadas. Configurá SSO o Codespaces secrets y reiniciá el entorno.

### `The security token included in the request is expired`

Las credenciales temporales expiraron. Renoválas, actualizá los secretos y reiniciá el Codespace.

### `terraform: command not found`

Ejecutá **Codespaces: Rebuild Container**. Si continúa, verificá que la branch seleccionada incluya `.devcontainer/devcontainer.json`.

### Terraform no encuentra providers

Ejecutá dentro del proyecto:

```bash
terraform init
```

La instalación de Terraform no incluye automáticamente los providers de cada lab.

### Estoy en la branch incorrecta

Verificá:

```bash
git branch --show-current
git status
```

No cambies de branch con archivos sin guardar. Hacé commit o guardá los cambios de acuerdo con la guía.

### El Codespace se detuvo

Volvé a iniciarlo desde la pestaña **Codespaces** del repositorio. Detenerlo no borra el trabajo, pero eliminarlo sí puede borrar cambios que no hayas publicado.

## Alcance de soporte por branch

La configuración del entorno debe acompañar a la branch del laboratorio. Las futuras branches pueden agregar o quitar herramientas según el contenido de la clase, por ejemplo Terraform, AWS CLI, Ansible, Python, Docker CLI o extensiones del IDE.

Antes de comenzar, revisá siempre:

1. branch correcta;
2. herramientas disponibles;
3. identidad AWS;
4. instrucciones específicas de la guía;
5. reglas de entrega y limpieza.

---

Proyecto educativo — Formatec Cloud Course 2026
