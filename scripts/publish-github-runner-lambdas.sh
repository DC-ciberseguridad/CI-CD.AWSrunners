#!/usr/bin/env bash
set -e

# --- CONFIGURACIÓN ---
MODULE_VERSION="7.10.1"
BUCKET_NAME="demo-gha-runner-binaries-2ac7036add63616d3387b6d823"
AWS_REGION="us-east-1"
REPO_OWNER="DC-ciberseguridad"
REPO_NAME="CI-CD.AWSrunners"
BRANCH="main" # Cambia por tu rama principal si es 'master' o 'dev'

# Token opcional por si el repositorio es privado
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

echo "==> Preparando entorno temporal..."
rm -rf lambdas_tmp
mkdir -p lambdas_tmp
cd lambdas_tmp

# Construir header de autenticación si existe GITHUB_TOKEN
CURL_AUTH_HEADER=()
if [ -n "$GITHUB_TOKEN" ]; then
  CURL_AUTH_HEADER=(-H "Authorization: token $GITHUB_TOKEN")
fi

echo "==> Descargando artefactos .zip desde ${REPO_OWNER}/${REPO_NAME} (${BRANCH}/artifacts)..."
curl -sSL "${CURL_AUTH_HEADER[@]}" -O "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/artifacts/webhook.zip"
curl -sSL "${CURL_AUTH_HEADER[@]}" -O "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/artifacts/runners.zip"
curl -sSL "${CURL_AUTH_HEADER[@]}" -O "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/artifacts/runner-binaries-syncer.zip"

echo "==> Subiendo artefactos a S3 en s3://${BUCKET_NAME}/github-runner/${MODULE_VERSION}/..."
aws s3 cp webhook.zip "s3://${BUCKET_NAME}/github-runner/${MODULE_VERSION}/webhook.zip" --region "${AWS_REGION}"
aws s3 cp runners.zip "s3://${BUCKET_NAME}/github-runner/${MODULE_VERSION}/runners.zip" --region "${AWS_REGION}"
aws s3 cp runner-binaries-syncer.zip "s3://${BUCKET_NAME}/github-runner/${MODULE_VERSION}/runner-binaries-syncer.zip" --region "${AWS_REGION}"

echo "==> Limpiando archivos temporales..."
cd ..
rm -rf lambdas_tmp

echo "==> ¡Artefactos publicados exitosamente en S3!"