#!/usr/bin/env bash
set -e

VERSION="v7.10.1"
MODULE_VERSION="7.10.1"
AWS_REGION="us-east-1"

# Obtiene automáticamente el nombre del bucket generado por Terraform
BUCKET_NAME=${1:-$(terraform output -raw lambda_artifacts_bucket_name 2>/dev/null)}

if [ -z "$BUCKET_NAME" ]; then
  echo "Error: No se pudo obtener el nombre del bucket. Asegúrate de haber ejecutado el Paso 2 primero."
  echo "Uso: ./scripts/publish-github-runner-lambdas.sh <NOMBRE_DEL_BUCKET>"
  exit 1
fi

echo "==> Usando el bucket S3: $BUCKET_NAME en región $AWS_REGION"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "==> Descargando artefactos Lambda versión $VERSION..."
curl -sL "https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/${VERSION}/webhook.zip" -o "$TMP_DIR/webhook.zip"
curl -sL "https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/${VERSION}/runners.zip" -o "$TMP_DIR/runners.zip"
curl -sL "https://github.com/github-aws-runners/terraform-aws-github-runner/releases/download/${VERSION}/runner-binaries-syncer.zip" -o "$TMP_DIR/runner-binaries-syncer.zip"

echo "==> Subiendo artefactos a S3 (s3://$BUCKET_NAME/github-runner/$MODULE_VERSION/)..."
aws s3 cp "$TMP_DIR/webhook.zip" "s3://$BUCKET_NAME/github-runner/$MODULE_VERSION/webhook.zip" --region "$AWS_REGION"
aws s3 cp "$TMP_DIR/runners.zip" "s3://$BUCKET_NAME/github-runner/$MODULE_VERSION/runners.zip" --region "$AWS_REGION"
aws s3 cp "$TMP_DIR/runner-binaries-syncer.zip" "s3://$BUCKET_NAME/github-runner/$MODULE_VERSION/runner-binaries-syncer.zip" --region "$AWS_REGION"

echo "==> ¡Artefactos publicados exitosamente en S3!"