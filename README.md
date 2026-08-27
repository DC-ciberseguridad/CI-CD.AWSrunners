
# 🏗️ Laboratorio # 9: Sistema de Ejecución de Pipelines 100% Bajo Demanda y Serverless en AWS (Free Tier)

Este repositorio contiene la infraestructura como código (IaC) para eliminar los servidores de CI/CD encendidos 24/7 y reemplazar la infraestructura fija por un sistema de ejecución de pipelines 100% bajo demanda, Serverless y adaptado a la Capa Gratuita de AWS.

Crédito y Atribución: 

•[Proyecto inspirado originalmente en la guía de daveopssh/youtube - gha-runners.](https://github.com/daveopssh/youtube/tree/master/src/terraform/gha-runners)

•[Proyecto original.](https://github-aws-runners.github.io/terraform-aws-github-runner/)

   
Modificado para operar íntegramente bajo la Capa Gratuita (Free Tier) de AWS en la región us-east-1 usando Terraform u OpenTofu.

## 🎯 Finalidad Principal

En un flujo tradicional de DevOps con GitHub Actions existen dos limitaciones comunes:

Runners gestionados por GitHub: Fáciles de usar, pero costosos a escala, con límites estrictos de hardware y sin acceso a tu VPC (Virtual Private Cloud) privada de AWS.

Servidores EC2 dedicados (Self-Hosted estáticos): Instancias encendidas 24/7 con el agente de GitHub instalado. Generan costos continuos en periodos de inactividad (noches/fines de semana) y presentan riesgos de contaminación de entorno entre compilaciones.

Solución: Construir una arquitectura Event-Driven (orientada a eventos). Cuando se genera un evento en GitHub Actions, AWS aprovisiona una instancia EC2 efímera, ejecuta el pipeline de CI/CD y la destruye automáticamente al finalizar el trabajo.

## 🔑 Beneficios Clave
Cero costo en reposo (Scale-to-Zero): Sin pipelines en ejecución, no hay instancias EC2 encendidas ni cobrando.

Seguridad por Aislamiento (Runners Efímeros): Cada trabajo se ejecuta en una instancia EC2 completamente limpia que se destruye al terminar, previniendo fuga de credenciales o conflictos de dependencias.

Acceso Privado a la VPC: Al residir en tu red privada de AWS, el runner puede interactuar con bases de datos internas, contenedores o servicios sin exponerlos a Internet.

Automatización con IaC: Todo el stack (API Gateway, Lambdas, SSM Parameters, Auto Scaling Groups y Roles IAM) se despliega mediante Terraform / OpenTofu.

## Requisitos
    • Cuenta de AWS con permisos para EC2, Lambda, API Gateway, SSM, S3 e IAM
    • AWS CLI configurada (en el demo se usa el profile personal)
    • Cuenta de GitHub con permisos para crear una GitHub App
    • OpenTofu o Terraform
    • Una VPC con subnets donde puedan salir las EC2 (en el demo usan IP pública)

## 🔄 Flujo de Trabajo

1. Disparo: Realizas un git push o ejecutas un workflow manual.

2. Evento (Webhook): GitHub notifica a API Gateway en AWS en tiempo real.

3. Procesamiento: Una Lambda evalúa el evento y calcula la capacidad necesaria.

4. Creación: AWS Auto Scaling enciende una EC2 efímera (t3.micro) que se registra en tu repositorio.

5. Ejecución y Limpieza: La EC2 procesa el job, reporta el resultado y se autodestruye.

## 🛠️ Lo que Aprenderás

Integración de GitHub Apps con AWS: Autenticación segura mediante pares de claves RSA (.pem) y almacenamiento en SSM Parameter Store.

Arquitecturas Serverless + Compute: Combinación de API Gateway, AWS Lambda y EC2 Auto Scaling para orquestación dinámica.

Aprovisionamiento Modular con Terraform/OpenTofu: Estrategia de bootstrap para cargar artefactos en S3 y secretos en SSM antes de aplicar el módulo principal de runners.

## 📁 Estructura del Proyecto
```
CI-CD.AWSrunners/
├── main.tf                 # Bucket S3, SSM Parameters y módulo github_runner
├── variables.tf            # Variables para la Capa Gratuita (t3.micro, on-demand, us-east-1)
├── outputs.tf              # Webhook URL y nombres de parámetros SSM
├── provider.tf             # Configuración del proveedor de AWS en us-east-1
└── scripts/
    ├── publish-github-runner-lambdas.sh # Sube artefactos .zip al bucket S3
    └── put-ssm-parameter.sh             # Carga el App ID y la Clave Privada (.pem) a SSM
```
## 📄 Desglose Detallado Archivo por Archivo

1. 📄 main.tf
Contiene la arquitectura base y la llamada al módulo de runners:

2. 📄 variables.tf
Parametriza el entorno con enfoque Free Tier:

3. 📄 outputs.tf
Muestra el endpoint de API Gateway, el bucket generado y los nombres de los parámetros SSM requeridos para conectar GitHub con AWS.

4. 📄 provider.tf
Fija la región de AWS en us-east-1 y define las versiones de los proveedores aws, tls y random.

5. 📄 scripts/publish-github-runner-lambdas.sh
Descarga los ejecutable .zip oficial del release v7.10.1 (webhook.zip, runners.zip y runner-binaries-syncer.zip) y los sube a S3.

6. 📄 scripts/put-ssm-parameter.sh
Lee la clave privada .pem descargada de GitHub, la codifica en Base64 y escribe el App ID y la clave en SSM Parameter Store sin exponerlos en código plano.

## 🚀 Plan de Ejecución Paso a Paso

### Paso 1 — Crear la GitHub App
Ve a GitHub: Settings > Developer settings > GitHub Apps > New GitHub App.

Configura los datos básicos:

GitHub App name: CI-CD-AWSrunners-Demo

Homepage URL: [https://github.com](https://github.com)

Webhook URL: [https://example.com](https://example.com) (se actualizará en el Paso 6)

Asigna Permisos de Repositorio (Repository permissions):

1. Actions: Read & write

2. Administration: Read & write

3. Checks: Read & write

4. Metadata: Read-only

5. Subscribe to events: Selecciona Workflow job.

6. Haz clic en Create GitHub App.

7. Guarda el App ID que aparece en pantalla.

8. En la sección Private keys, haz clic en "Generate a private key" y guarda el archivo .pem en tu máquina.

9. Ve a Install App en el menú izquierdo e instálala en tu organización o repositorio objetivo (ej. daveopssh/demo-tf-repo).

### Paso 2 — Bootstrap de Infraestructura Inicial
1. Inicializa Terraform e instala las dependencias:

```
Bash
terraform init
Aplica solo los recursos base (Bucket S3 y Parámetros SSM vacíos) para preparar el terreno sin fallos de dependencias:
```
2. Generar el plan de ejecución y verificar los recursos a crear

```
-Bash
terraform plan -target=aws_s3_bucket.action_runner_bucket -target=aws_ssm_parameter.github_app_id -target=aws_ssm_parameter.github_app_installation_id 
```
3. A continuación, desplegamos la base excluyendo el módulo de runners para evitar que falle por falta de archivos .zip en S3:

```
-Bash
terraform apply 
-target=module.gha_runner_bucket 
-target=aws_ssm_parameter.github_app_id 
-target=aws_ssm_parameter.github_app_key_base64 
-target=aws_ssm_parameter.github_app_webhook_secret
```

### Paso 3 — Publicar las Lambdas en S3
Concede permisos de ejecución al script Bash y súbelas al bucket:

```
Bash

# 1. Definir variables principales

-Bash
MODULE_VERSION="7.10.1"
BUCKET_NAME="demo-gha-runner-binaries-2ac7036add63616d3387b6d823"
AWS_REGION="us-east-1"
REPO_OWNER="DC-ciberseguridad"
REPO_NAME="CI-CD.AWSrunners"
BRANCH="main" # O la rama donde tengas los artefactos (ej. master, dev)

# 2. Crear carpeta temporal local

-Bash
rm -rf lambdas
mkdir -p lambdas
cd lambdas

# 3. Descargar los 3 archivos .zip desde el directorio /artifacts de tu repositorio

-Bash
curl -LO "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/artifacts/webhook.zip"

curl -LO "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/artifacts/runners.zip"

curl -LO "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/artifacts/runner-binaries-syncer.zip"

# 4. Subir los 3 archivos .zip a la ruta que espera Terraform en S3

-Bash

aws s3 cp webhook.zip "s3://${BUCKET_NAME}/github-runner/${MODULE_VERSION}/webhook.zip" --region ${AWS_REGION}

aws s3 cp runners.zip "s3://${BUCKET_NAME}/github-runner/${MODULE_VERSION}/runners.zip" --region $
{AWS_REGION}

aws s3 cp runner-binaries-syncer.zip "s3://${BUCKET_NAME}/github-runner/${MODULE_VERSION}/runner-binaries-syncer.zip" --region ${AWS_REGION}

# 5. Regresar al directorio principal y limpiar

-Bash
cd ..
rm -rf lambdas
```
### Paso 4 — Cargar Credenciales en SSM
Registra el App ID y la clave privada .pem en SSM usando el script helper:

```
Bash

-Bash
#1. Subir tu App ID real a SSM 
aws ssm put-parameter --name "/github-action-runners/demo/app/github_app_id" --value "TU_GITHUB_APP_ID_AQUI" --type "String" --overwrite --region us-east-1

#2. Convertir el contenido del archivo .pem a Base64 en una sola línea
KEY_BASE64=$(base64 -w 0 tu-clave-privada.pem)


#3. Subir el valor a AWS SSM Parameter Store como SecureString
aws ssm put-parameter --name "/github-action-runners/demo/app/github_app_key_base64" --value "$KEY_BASE64" --type "SecureString" --overwrite --region us-east-1
```

### Paso 5 — Desplegar el Módulo Completo
Aplica la totalidad de la infraestructura (API Gateway, Lambdas y Auto Scaling):

```
Bash
terraform apply
```

Al terminar, copia el valor del output webhook_endpoint.

### Paso 6 — Activar el Webhook en GitHub
Vuelve a tu GitHub App en GitHub.

Ve a General > Webhook.

En Webhook URL, pega la URL entregada por el output de Terraform (webhook_endpoint).

```
Bash

aws apigatewayv2 get-apis --region us-east-1 --query "Items[?contains(Name, 'github-actions')].ApiEndpoint" --output text
```

En Webhook Secret, pega el valor almacenado en SSM para la firma. Para consultarlo desde la terminal:

```
Bash

aws ssm get-parameter --name "/github-action-runners/demo/app/github_app_webhook_secret" --with-decryption --query 'Parameter.Value' --output text --region us-east-1
```
Activa la opción Active y Guarda los cambios.

### Paso 7 — Probar el Pipeline
En tu repositorio de GitHub autorizado, crea un archivo de workflow .github/workflows/demo.yml:

```
name: Demo AWS Ephemeral Runner

on:
  workflow_dispatch:

jobs:
  test-runner:
    runs-on: [self-hosted, demo]
    steps:
      - name: Checkout Código
        uses: actions/checkout@v4

      - name: Información del Runner y Sistema Operativo
        run: |
          echo "=========================================="
          echo "¡Hola desde la instancia EC2 efímera en AWS!"
          echo "=========================================="
          echo "Host: $(hostname)"
          echo "Usuario actual: $(whoami)"
          echo "Sistema Operativo:"
          uname -a
          cat /etc/os-release | grep PRETTY_NAME

      - name: Verificar Recursos de la Instancia EC2
        run: |
          echo "--- CPU & Memoria ---"
          lscpu | grep "Model name\|CPU(s):"
          free -h
          echo "--- Espacio en Disco ---"
          df -h /

      - name: Probar Conectividad y Salida a Internet
        run: |
          echo "--- Dirección IP Pública/Egress ---"
          curl -s https://ifconfig.me
          echo ""

      - name: Confirmación Final
        run: |
          echo "Job completado exitosamente en el runner efímero."
```

Dispara el pipeline manualmente desde la pestaña Actions de GitHub y observa en tu consola de AWS cómo se enciende una instancia EC2 t3.micro, procesa el trabajo y se autodestruye al terminar.


## 🧹 Limpieza de Recursos

Para destruir toda la infraestructura creada y evitar cargos innecesarios en AWS, ejecuta:

```
Bash
terraform destroy
```