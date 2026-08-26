# LAB01 — GitHub Actions con OIDC desde AWS Console

**Curso:** Arquitectura e Ingeniería Cloud | C2 — FormaTEC 2026  
**Duración estimada:** 90 minutos  
**Modalidad:** individual o en parejas  
**Región de referencia:** `us-east-1`  
**Tema:** GitHub Actions, IAM OIDC y credenciales temporales

---

## 1. Contexto

Tu repositorio GitHub y tu cuenta AWS de laboratorio ya existen.

En los próximos laboratorios, GitHub Actions ejecutará Terraform para desplegar recursos AWS. Un error frecuente es guardar credenciales permanentes en GitHub:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

Ese patrón deja un secreto que puede filtrarse, copiarse, reutilizarse o permanecer activo más tiempo del necesario.

En este laboratorio configurarás OpenID Connect (OIDC) desde la consola de AWS. GitHub Actions pedirá un token temporal; AWS verificará que ese token viene de tu repositorio y de la rama autorizada; recién entonces AWS entregará una sesión temporal de un role IAM.

```text
GitHub Actions
   │
   │ token OIDC temporal
   ▼
OIDC Provider de GitHub en IAM
   │
   │ AssumeRoleWithWebIdentity
   ▼
Role IAM de tu repositorio
   │
   ▼
Credenciales temporales para el workflow
```

Este LAB01 no crea infraestructura. No se despliegan VPC, EC2, S3, RDS ni Security Groups. El único objetivo es dejar GitHub Actions listo para autenticarse en AWS de forma segura.

---

## 2. Definir `student_identity` para todos los laboratorios

`student_identity` es el identificador estable que usarás en nombres, tags y variables durante las próximas clases.

El curso ya utiliza esta convención en otros laboratorios. No uses `student_id` para este repositorio.

### 2.1 Elegir o reutilizar un valor válido

Usá entre 3 y 32 caracteres:

- minúsculas;
- números;
- guiones simples;
- debe comenzar y terminar con una letra o número.

Ejemplos válidos:

```text
perez-ana
lopez-juan
grupo-04
```

Ejemplos no válidos:

```text
Ana Pérez
ana_perez
-ana
ana-
```

### 2.2 Verificar `STUDENT_IDENTITY` en GitHub

1. Abrí tu repositorio en GitHub.
2. Elegí **Settings**.
3. En el menú lateral, abrí **Secrets and variables → Actions**.
4. Elegí la pestaña **Variables**.
5. Buscá la variable:

```text
STUDENT_IDENTITY
```

- Si existe, conservá su valor. Debe respetar el formato de la sección anterior. No la dupliques ni la reemplaces por `student_id`.
- Si no existe, elegí **New repository variable** y completá:

| Campo | Valor |
|---|---|
| Name | `STUDENT_IDENTITY` |
| Value | tu `student_identity` |

6. Elegí **Add variable** solo si tuviste que crearla.

`STUDENT_IDENTITY` no es un secreto. Es una variable de identificación que los futuros workflows podrán convertir en:

```text
TF_VAR_student_identity
```

y que Terraform podrá usar para nombres como:

```text
security-lab-<student_identity>-vpc
security-lab-<student_identity>-backend-a-01
security-lab-<student_identity>-bucket-a
```

### Resultado esperado

En **Settings → Secrets and variables → Actions → Variables** existe una única variable:

```text
STUDENT_IDENTITY = <tu-identidad>
```

---

## 3. Reunir los datos de tu repositorio

La trust policy debe coincidir literalmente con tu repositorio GitHub.

1. Abrí la página principal del repositorio.
2. Anotá el owner y el nombre del repositorio desde la URL:

```text
https://github.com/<OWNER>/<REPO>
```

3. Confirmá que la rama de despliegue es `main`:

```bash
git branch --show-current
```

Usarás estos valores:

```text
OWNER  = <owner-exacto>
REPO   = <repositorio-exacto>
BRANCH = main
```

No cambies mayúsculas, guiones ni caracteres del owner o repositorio al escribir la trust policy.

---

## 4. Crear el OIDC Provider de GitHub en AWS Console

El OIDC Provider conecta tu cuenta AWS con el emisor de identidad de GitHub Actions.

Cada alumno tiene su propia cuenta AWS. Por eso cada cuenta debe tener su propio OIDC Provider de GitHub.

### 4.1 Verificar si ya existe

1. Abrí **AWS Console → IAM → Identity providers**.
2. Buscá:

```text
token.actions.githubusercontent.com
```

3. Si aparece, abrilo y verificá que la audiencia configurada sea:

```text
sts.amazonaws.com
```

4. Si ya existe y la audiencia es correcta, continuá con la sección 5.

### 4.2 Crear el provider si no existe

1. Elegí **Add provider**.
2. En **Provider type**, seleccioná **OpenID Connect**.
3. En **Provider URL**, escribí:

```text
https://token.actions.githubusercontent.com
```

4. En **Audience**, escribí:

```text
sts.amazonaws.com
```

5. Elegí **Add provider**.

AWS mostrará el provider creado. No necesitás generar un token ni copiar certificados manualmente.

### Resultado esperado

En IAM aparece un identity provider con:

```text
Provider URL: https://token.actions.githubusercontent.com
Audience:     sts.amazonaws.com
```

---

## 5. Crear el role OIDC desde AWS Console

Este role será asumido solo por GitHub Actions cuando el workflow se ejecute desde tu repositorio y desde `main`.

### 5.1 Crear el role con trust policy personalizada

1. Abrí **AWS Console → IAM → Roles**.
2. Elegí **Create role**.
3. Seleccioná **Custom trust policy**.
4. Reemplazá `<ACCOUNT_ID>`, `<OWNER>` y `<REPO>` en esta policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:<OWNER>/<REPO>:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

5. Pegá la policy modificada en la consola.
6. Elegí **Next**.

Para obtener el account ID:

1. Abrí el menú de tu cuenta en la esquina superior derecha de AWS Console.
2. Copiá el número de 12 dígitos mostrado como **Account ID**.

### 5.2 Nombrar el role

Usá exactamente:

```text
github-oidc-security-lab-<student_identity>
```

Ejemplo:

```text
github-oidc-security-lab-perez-ana
```

7. Elegí **Create role**.

### 5.3 Leer la trust policy

Abrí el role creado y entrá a **Trust relationships**.

La policy contiene dos controles:

| Condición | Significado |
|---|---|
| `aud = sts.amazonaws.com` | el token fue emitido para AWS STS |
| `sub = repo:OWNER/REPO:ref:refs/heads/main` | solo ese repositorio y esa rama pueden asumir el role |

No reemplaces el `sub` por valores amplios como:

```text
repo:<OWNER>/*
repo:*/*:ref:refs/heads/*
```

### Resultado esperado

El role existe con el nombre que contiene tu `student_identity` y su trust policy referencia exactamente tu owner, repositorio y rama `main`.

---

## 6. Agregar una policy mínima al role

En este LAB01, el workflow solo necesita comprobar qué identidad temporal recibió. No necesita crear infraestructura.

### 6.1 Crear una inline policy

1. Dentro del role, abrí la pestaña **Permissions**.
2. Elegí **Add permissions → Create inline policy**.
3. Elegí la pestaña **JSON**.
4. Pegá:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "VerifyTemporaryIdentity",
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    }
  ]
}
```

5. Elegí **Next**.
6. En **Policy name**, escribí:

```text
verify-temporary-identity
```

7. Elegí **Create policy**.

### Por qué aparece `Resource: "*"`

`sts:GetCallerIdentity` no admite un ARN de recurso específico. Este permiso solo permite conocer la identidad de la sesión actual; no permite crear, cambiar ni borrar recursos AWS.

En los próximos laboratorios, cualquier permiso nuevo deberá indicar una acción necesaria y un recurso concreto identificado con tu `student_identity`.

### Resultado esperado

En **Permissions policies** aparece la inline policy:

```text
verify-temporary-identity
```

No aparecen policies administradas como `AdministratorAccess`, `PowerUserAccess` o `AmazonS3FullAccess`.

---

## 7. Continuar con el environment `lab`

El environment `lab` ya existe en el repositorio. Usalo como continuidad de la configuración existente; no crees otro environment con el mismo propósito y no elimines variables o secrets que pertenecen a laboratorios previos.

### 7.1 Abrir y revisar el environment

1. Abrí tu repositorio en GitHub.
2. Elegí **Settings → Environments**.
3. Abrí el environment existente:

```text
lab
```

4. Revisá las secciones **Environment secrets** y **Environment variables**.
5. Conservá todos los nombres y valores existentes que no pertenezcan a este LAB01.

### 7.2 Agregar o actualizar solo las variables OIDC

En **Environment variables**, buscá primero estas variables:

| Nombre | Valor esperado |
|---|---|
| `AWS_ROLE_ARN` | ARN del role OIDC creado en la sección 5 |
| `AWS_REGION` | `us-east-1` |

- Si una variable ya existe con el valor correcto, no la modifiques.
- Si `AWS_ROLE_ARN` existe pero apunta a un role anterior, editá únicamente esa variable y reemplazá el ARN por el role OIDC de este laboratorio.
- Si falta alguna de las dos, creala como **Environment variable**.

Para obtener el ARN:

1. Volvé a **AWS Console → IAM → Roles**.
2. Abrí `github-oidc-security-lab-<student_identity>`.
3. Copiá **ARN** desde la sección de resumen.

No agregues ni reemplaces secrets con estos valores:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
```

El ARN del role no es un secreto. La trust policy es la que define qué repositorio y rama pueden usarlo.

### Resultado esperado

El environment existente `lab` conserva su configuración previa y contiene:

```text
AWS_ROLE_ARN = arn:aws:iam::<ACCOUNT_ID>:role/github-oidc-security-lab-<student_identity>
AWS_REGION   = us-east-1
```

No se agregaron AK/SAK como secrets o variables.

---

## 8. Usar el workflow de verificación disponible

El repositorio ya incluye el workflow:

```text
.github/workflows/oidc-verify.yml
```

No necesitás crearlo, editarlo, hacer commit ni push para este laboratorio.

Abrí el archivo para reconocer estas partes:

| Elemento | Función |
|---|---|
| `workflow_dispatch` | ejecuta el workflow manualmente |
| `id-token: write` | permite que GitHub solicite un token OIDC |
| `configure-aws-credentials` | intercambia el token OIDC por credenciales temporales AWS |
| `AWS_ROLE_ARN` | indica qué role debe asumir el workflow |
| `aws sts get-caller-identity` | muestra qué sesión temporal se obtuvo |
| `STUDENT_IDENTITY` | confirma la variable que se reutilizará en laboratorios futuros |

---

## 9. Ejecutar el workflow de verificación

1. Abrí **GitHub → Actions**.
2. Elegí **Verify AWS OIDC**.
3. Elegí **Run workflow**.
4. Confirmá la rama `main`.
5. Elegí **Run workflow**.
6. Abrí el run iniciado.
7. Revisá el paso **3 · Show the temporary AWS identity**.

### Resultado esperado

El run termina correctamente y la salida contiene una sesión asumida similar a:

```text
arn:aws:sts::<ACCOUNT_ID>:assumed-role/github-oidc-security-lab-<student_identity>/<session-name>
```

La salida no debe mostrar un usuario IAM ni una access key.

En el paso 4 aparece:

```text
STUDENT_IDENTITY=<tu-identidad>
```

---

## 10. Verificación final

El laboratorio está listo cuando se cumplen estas condiciones:

| Condición | Resultado esperado |
|---|---|
| `STUDENT_IDENTITY` | existe como repository variable y tiene el valor elegido |
| OIDC Provider | existe en IAM con URL de GitHub y audiencia `sts.amazonaws.com` |
| Role OIDC | incluye tu `student_identity` en el nombre |
| Trust policy | limita `sub` a tu owner, repo y rama `main` |
| Permission policy | contiene solo `sts:GetCallerIdentity` |
| Environment `lab` | incluye ARN del role y región, sin AK/SAK |
| Workflow | termina con una sesión `assumed-role` |

---

## 11. Troubleshooting

| Problema | Causa probable | Qué revisar |
|---|---|---|
| No aparece el provider en IAM | Todavía no fue creado en tu cuenta AWS | Crear el provider con URL y audiencia exactas |
| GitHub no puede asumir el role | `sub`, `aud`, owner, repo o rama no coincide | Comparar literalmente trust policy, URL del repo y `main` |
| El workflow no obtiene token OIDC | Falta `id-token: write` | Revisar bloque `permissions` |
| No aparece Run workflow | El workflow disponible no está visible en la rama `main` | Confirmar que estás viendo `main`; si sigue sin aparecer, informar al docente sin crear un workflow alternativo |
| El ARN no contiene `assumed-role` | OIDC no se configuró o se usó otra autenticación | Revisar el paso configure credentials y el role ARN |
| El workflow busca AK/SAK | Se reutilizó un YAML anterior | Eliminar referencias a access keys y usar OIDC |
| `STUDENT_IDENTITY` aparece vacío | La variable no existe a nivel repositorio | Revisar Settings → Secrets and variables → Actions → Variables |

---

## 12. Continuidad para los próximos laboratorios

Conservá:

- el OIDC Provider;
- el role `github-oidc-security-lab-<student_identity>`;
- el environment `lab`;
- la variable `STUDENT_IDENTITY`;
- el workflow de verificación.

En LAB02 se agregarán permisos de infraestructura solo cuando exista un recurso concreto que administrar. Los nombres y tags usarán:

```text
security-lab-${student_identity}-<recurso>
```

Antes de agregar cualquier permiso, respondé:

> ¿Qué acción necesita el pipeline, sobre qué recurso identificado con mi `student_identity`, y qué acción debe seguir denegada?
