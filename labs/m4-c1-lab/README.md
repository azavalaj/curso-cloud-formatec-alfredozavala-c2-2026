# M4-C1: Seguridad de acceso a S3 desde EC2 privadas

Este laboratorio crea una base de red, EC2 privadas y dos buckets S3 para practicar permisos IAM por rol desde la consola de AWS.

La continuidad con AWS se hace con GitHub Actions OIDC. No uses secretos `AWS_ACCESS_KEY_ID` ni `AWS_SECRET_ACCESS_KEY`. El ambiente `lab` de GitHub Actions ya existe y entrega estas variables:

- `AWS_ROLE_ARN`
- `AWS_REGION`
- `STUDENT_IDENTITY`

Terraform usa `STUDENT_IDENTITY` como `var.student_identity` para nombrar y etiquetar recursos. Todos los recursos llevan las etiquetas `StudentIdentity`, `Lab=m4-c1` y `ManagedBy=terraform`.

## Que Crea Terraform

- Una VPC con DNS habilitado.
- Dos subnets publicas en dos Availability Zones.
- Dos subnets privadas `backend-a`, dos subnets privadas `backend-b` y dos subnets privadas `db`.
- Un Internet Gateway.
- Una instancia NAT `t3.micro` en subnet publica, con IP publica y `source_dest_check=false`.
- Tablas de ruta privadas de aplicaciones con salida por la interfaz de red de la NAT instance.
- Tablas de ruta privadas de base de datos sin ruta default a Internet ni NAT.
- Un VPC endpoint Gateway para S3 asociado solo a las route tables de aplicaciones.
- Dos buckets S3 privados, versionados, cifrados, con bloqueo de acceso publico y `force_destroy=true`.
- Cuatro EC2 Amazon Linux privadas: `backend-a-01`, `backend-a-02`, `backend-b-01`, `backend-b-02`.

Terraform no crea roles IAM, politicas IAM, instance profiles, RDS, ALB, endpoints publicos de aplicacion, CloudFront, HTTPS, SSH keys, ni objetos S3.

## Antes de Empezar

Las EC2 de foundation deben tener roles SSM preasociados manualmente desde la base de aula para que Session Manager funcione. Este laboratorio no crea ni asocia esos roles desde Terraform.

Durante la primera parte, esos roles mantienen temporalmente la politica amplia `s3-lab02-full-buckets`, ya preparada por la base de aula. No la crees en Terraform.

## Desplegar Foundation

1. En GitHub, abre `Actions`.
2. Ejecuta el workflow `M4-C1 Foundation`.
3. Selecciona `plan` para revisar la infraestructura.
4. Si el plan es correcto, ejecuta el mismo workflow con `apply`.
5. Revisa los outputs del workflow y anota `bucket_a_name` y `bucket_b_name`.

El workflow ejecuta `terraform fmt -check`, `terraform init -backend=false`, `terraform validate` y luego `plan`, `apply` o `destroy` segun la opcion manual.

## Preparar Datos Iniciales

Conectate por Session Manager a `backend-a-01`.

El patron local es trabajar en `/s3` y luego sincronizarlo a los buckets. Ya existen estas carpetas:

- `/s3/folder-a`
- `/s3/folder-b`
- `/s3/shared`

Ejemplo:

```bash
sudo touch /s3/folder-a/a.txt
sudo nano /s3/folder-a/a.txt

sudo touch /s3/folder-b/b.txt
sudo nano /s3/folder-b/b.txt

sudo touch /s3/shared/shared.txt
sudo nano /s3/shared/shared.txt

sudo /opt/security-lab/cargar-datos-iniciales.sh <bucket-a> <bucket-b>
```

El script ejecuta `aws s3 sync /s3/ s3://<bucket-a>/` y `aws s3 sync /s3/ s3://<bucket-b>/`. No usa `--delete`.

Tambien puedes practicar comandos puntuales:

```bash
aws s3 ls s3://<bucket-a>/
aws s3 cp /s3/folder-a/a.txt s3://<bucket-a>/folder-a/a.txt
aws s3 cp s3://<bucket-a>/folder-a/a.txt /tmp/a.txt
aws s3 rm s3://<bucket-a>/folder-a/a.txt
```

## Revisar Acceso Amplio Inicial

En la consola de AWS:

1. Abre IAM.
2. Entra a los roles preasociados a las EC2 del lab.
3. Verifica que todavia tengan `AmazonSSMManagedInstanceCore`.
4. Verifica que inicialmente tengan la politica amplia `s3-lab02-full-buckets`.

Conectate por Session Manager a `backend-a-02` y demuestra que el acceso amplio permite listar o leer ambos buckets:

```bash
aws s3 ls s3://<bucket-a>/
aws s3 ls s3://<bucket-b>/
aws s3 cp s3://<bucket-b>/shared/shared.txt /tmp/shared-from-b.txt
```

Este acceso amplio es intencional solo para observar el punto de partida.

## Retirar Politica Amplia

Desde IAM, entra rol por rol y quita `s3-lab02-full-buckets`.

Conserva `AmazonSSMManagedInstanceCore`; si la quitas, Session Manager puede dejar de funcionar.

## Crear Politicas Finales Manualmente

Crea manualmente cuatro politicas IAM y asocialas al rol correspondiente de cada EC2. Reemplaza `<bucket-a>` y `<bucket-b>` por los nombres reales.

### backend-a-01: Full S3-A

Permite control completo sobre el bucket A:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::<bucket-a>",
        "arn:aws:s3:::<bucket-a>/*"
      ]
    }
  ]
}
```

### backend-a-02: Lectura Completa S3-A

Permite listar y leer todo el bucket A:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::<bucket-a>"
    },
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::<bucket-a>/*"
    }
  ]
}
```

### backend-b-01: Shared de S3-A y Full S3-B

Permite listar solo el prefijo `shared/` de bucket A, leer objetos bajo `shared/` en bucket A y control completo sobre bucket B:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::<bucket-a>",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "shared",
            "shared/*"
          ]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::<bucket-a>/shared/*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::<bucket-b>",
        "arn:aws:s3:::<bucket-b>/*"
      ]
    }
  ]
}
```

### backend-b-02: Lectura S3-B y Escritura Solo folder-b

Permite listar y leer todo bucket B, pero crear y borrar solo en `folder-b/`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::<bucket-b>"
    },
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::<bucket-b>/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::<bucket-b>/folder-b/*"
    }
  ]
}
```

## Matriz Esperada

| Instancia | Bucket A | Bucket B |
| --- | --- | --- |
| `backend-a-01` | Listar, leer, subir y borrar todo | Denegado |
| `backend-a-02` | Listar y leer todo | Denegado |
| `backend-b-01` | Listar y leer solo `shared/` | Listar, leer, subir y borrar todo |
| `backend-b-02` | Denegado | Listar y leer todo; subir y borrar solo `folder-b/` |

Comandos utiles para comprobar:

```bash
aws s3 ls s3://<bucket-a>/
aws s3 ls s3://<bucket-a>/shared/
aws s3 cp s3://<bucket-a>/shared/shared.txt /tmp/shared.txt
aws s3 cp /tmp/test.txt s3://<bucket-b>/folder-b/test.txt
aws s3 rm s3://<bucket-b>/folder-b/test.txt
aws s3 cp /tmp/test.txt s3://<bucket-b>/folder-a/test.txt
```

Cuando una accion no corresponde a la politica final, espera `AccessDenied`.

## Limpieza Segura

1. Si creaste politicas IAM manuales para este lab, desasocialas y eliminalas desde IAM.
2. Mantener o quitar los roles SSM base depende de la indicacion de aula; recuerda que estan fuera de Terraform.
3. En GitHub Actions, ejecuta `M4-C1 Foundation` con `destroy` para eliminar la infraestructura Terraform.

Los roles y politicas IAM de consola son intencionalmente externos a Terraform en este laboratorio.
