#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Uso: %s <account-number> <student-id>\n' "$0" >&2
  printf 'Ejemplo: %s 123456789012 perez-ana\n' "$0" >&2
}

if [ "$#" -ne 2 ]; then
  usage
  exit 1
fi

account_number="$1"
student_id="$2"
region="${AWS_REGION:-us-east-1}"

if [[ ! "$account_number" =~ ^[0-9]{12}$ ]]; then
  printf 'Error: account-number debe tener exactamente 12 dígitos.\n' >&2
  exit 1
fi

if [[ ! "$student_id" =~ ^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$ ]]; then
  printf 'Error: student-id debe usar 3-32 caracteres minúsculos, números o guiones.\n' >&2
  exit 1
fi

bucket_suffix="${account_number}-${student_id}"
bucket_a="m4-c1-a-${bucket_suffix}"
bucket_b="m4-c1-b-${bucket_suffix}"

printf 'Región:  %s\n' "$region"
printf 'Bucket A: %s\n' "$bucket_a"
printf 'Bucket B: %s\n' "$bucket_b"

printf '\nVerificando identidad AWS activa...\n'
aws sts get-caller-identity --region "$region" --query '{Account:Account,Arn:Arn}' --output table

for bucket in "$bucket_a" "$bucket_b"; do
  if ! aws s3api head-bucket --bucket "$bucket" --region "$region"; then
    printf 'Error: no se puede acceder al bucket %s. Ejecutá Terraform apply y revisá tu identidad AWS.\n' "$bucket" >&2
    exit 1
  fi
done

work_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$work_dir/folder-a" "$work_dir/folder-b" "$work_dir/shared"
printf 'archivo creado para validar permisos desde folder-a\n' >"$work_dir/folder-a/a.txt"
printf 'archivo creado para validar permisos desde folder-b\n' >"$work_dir/folder-b/b.txt"
printf 'archivo compartido para validar acceso por prefijo\n' >"$work_dir/shared/shared.txt"

printf '\nObjetos locales preparados:\n'
find "$work_dir" -type f -printf '%P\n' | sort

printf '\nSincronizando datos con bucket A...\n'
aws s3 sync "$work_dir/" "s3://${bucket_a}/" --region "$region" --no-progress

printf 'Sincronizando datos con bucket B...\n'
aws s3 sync "$work_dir/" "s3://${bucket_b}/" --region "$region" --no-progress

printf '\nObjetos verificados en bucket A:\n'
aws s3 ls "s3://${bucket_a}/" --recursive --region "$region"
printf '\nObjetos verificados en bucket B:\n'
aws s3 ls "s3://${bucket_b}/" --recursive --region "$region"

printf '\nCarga inicial completada.\n'
printf 'Los objetos quedaron disponibles para las pruebas de IAM de LAB02.\n'
