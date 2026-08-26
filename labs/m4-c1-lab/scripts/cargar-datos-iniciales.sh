#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  printf 'Uso: %s <bucket-a> <bucket-b>\n' "$0" >&2
  exit 1
fi

bucket_a="$1"
bucket_b="$2"

aws s3 sync /s3/ "s3://${bucket_a}/"
aws s3 sync /s3/ "s3://${bucket_b}/"
