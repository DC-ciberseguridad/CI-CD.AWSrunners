#!/usr/bin/env bash
set -e

# --- CONFIGURACIÓN DE NOMBRES DE PARÁMETROS ---
ENV_PREFIX="demo" # Debe coincidir con var.env_prefix de tu Terraform
AWS_REGION="us-east-1"

PARAM_APP_ID="/github-action-runners/${ENV_PREFIX}/app/github_app_id"
PARAM_APP_KEY="/github-action-runners/${ENV_PREFIX}/app/github_app_key_base64"

# --- SOLICITUD DE DATOS AL USUARIO ---
echo "=================================================="
echo " Configuración de Credenciales GitHub App en SSM "
echo "=================================================="

read -p "Ingresa el GitHub App ID: " GITHUB_APP_ID
read -p "Ingresa la ruta a tu archivo .pem (ej: ./github-app.private-key.pem): " PEM_FILE_PATH

if [ ! -f "$PEM_FILE_PATH" ]; then
    echo "Error: El archivo PEM '$PEM_FILE_PATH' no existe."
    exit 1
fi

echo "==> Codificando llave privada a Base64..."
# En Linux se usa 'base64 -w 0', en macOS 'base64'
if [[ "$OSTYPE" == "darwin"* ]]; then
    APP_KEY_BASE64=$(base64 -i "$PEM_FILE_PATH")
else
    APP_KEY_BASE64=$(base64 -w 0 "$PEM_FILE_PATH")
fi

echo "==> Actualizando parámetro $PARAM_APP_ID en SSM..."
aws ssm put-parameter \
    --name "$PARAM_APP_ID" \
    --value "$GITHUB_APP_ID" \
    --type "String" \
    --overwrite \
    --region "$AWS_REGION"

echo "==> Actualizando parámetro $PARAM_APP_KEY en SSM..."
aws ssm put-parameter \
    --name "$PARAM_APP_KEY" \
    --value "$APP_KEY_BASE64" \
    --type "SecureString" \
    --overwrite \
    --region "$AWS_REGION"

echo "=================================================="
echo "¡Parámetros SSM actualizados correctamente en AWS!"
echo "=================================================="