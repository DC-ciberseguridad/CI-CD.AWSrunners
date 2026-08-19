
# Project Title

🏗️ Laboratorio # 9: Sistema de Ejecución de Pipelines 100% Bajo Demanda y Serverless en AWS (Free Tier)

Este repositorio contiene la infraestructura como código (IaC) para eliminar los servidores de CI/CD encendidos 24/7 y reemplazar la infraestructura fija por un sistema de ejecución de pipelines 100% bajo demanda, Serverless y adaptado a la Capa Gratuita de AWS.

Crédito y Atribución: Proyecto inspirado originalmente en la guía de daveopssh/youtube - gha-runners. Modificado para operar íntegramente bajo la Capa Gratuita (Free Tier) de AWS en la región us-east-1 usando Terraform u OpenTofu.

## 🎯 Finalidad Principal

En un flujo tradicional de DevOps con GitHub Actions existen dos limitaciones comunes:

Runners gestionados por GitHub: Fáciles de usar, pero costosos a escala, con límites estrictos de hardware y sin acceso a tu VPC (Virtual Private Cloud) privada de AWS.

Servidores EC2 dedicados (Self-Hosted estáticos): Instancias encendidas 24/7 con el agente de GitHub instalado. Generan costos continuos en periodos de inactividad (noches/fines de semana) y presentan riesgos de contaminación de entorno entre compilaciones.

Solución: Construir una arquitectura Event-Driven (orientada a eventos). Cuando se genera un evento en GitHub Actions, AWS aprovisiona una instancia EC2 efímera, ejecuta el pipeline de CI/CD y la destruye automáticamente al finalizar el trabajo.

🔑 Beneficios Clave
Cero costo en reposo (Scale-to-Zero): Sin pipelines en ejecución, no hay instancias EC2 encendidas ni cobrando.

Seguridad por Aislamiento (Runners Efímeros): Cada trabajo se ejecuta en una instancia EC2 completamente limpia que se destruye al terminar, previniendo fuga de credenciales o conflictos de dependencias.

Acceso Privado a la VPC: Al residir en tu red privada de AWS, el runner puede interactuar con bases de datos internas, contenedores o servicios sin exponerlos a Internet.

Automatización con IaC: Todo el stack (API Gateway, Lambdas, SSM Parameters, Auto Scaling Groups y Roles IAM) se despliega mediante Terraform / OpenTofu.

Nota sobre SSM Parameter Store: Los Parámetros SSM cumplen un rol similar a los Secrets/Variables de GitHub Actions: separar la configuración del código. La diferencia clave es que los valores de SSM residen dentro de AWS y son leídos en tiempo de ejecución por las funciones Lambda y los runners EC2.

## 🔄 Flujo de Trabajo

[ Git Push / Workflow ] 
         │ (Evento Event-Driven)
         ▼
[ API Gateway / Lambda Webhook ]
         │
         ▼
[ Lambda Scale-Up ] ──► (Lee credenciales de SSM)
         │
         ▼
[ EC2 Auto Scaling (t3.micro) ] ──► Arranca runner efímero en us-east-1
         │
 [ Ejecuta Job de CI/CD ]
         │
         ▼
[ Termina el Job ] ──► Destrucción automática de la instancia EC2

Disparo: Realizas un git push o ejecutas un workflow manual.

Evento (Webhook): GitHub notifica a API Gateway en AWS en tiempo real.

Procesamiento: Una Lambda evalúa el evento y calcula la capacidad necesaria.

Creación: AWS Auto Scaling enciende una EC2 efímera (t3.micro) que se registra en tu repositorio.

Ejecución y Limpieza: La EC2 procesa el job, reporta el resultado y se autodestruye.

## 🛠️ Lo que Aprenderás

Integración de GitHub Apps con AWS: Autenticación segura mediante pares de claves RSA (.pem) y almacenamiento en SSM Parameter Store.

Arquitecturas Serverless + Compute: Combinación de API Gateway, AWS Lambda y EC2 Auto Scaling para orquestación dinámica.

Aprovisionamiento Modular con Terraform/OpenTofu: Estrategia de bootstrap para cargar artefactos en S3 y secretos en SSM antes de aplicar el módulo principal de runners.

## 📁 Estructura del Proyecto

CI-CD.AWSrunners/
├── main.tf                 # Bucket S3, SSM Parameters y módulo github_runner
├── variables.tf            # Variables para la Capa Gratuita (t3.micro, on-demand, us-east-1)
├── outputs.tf              # Webhook URL y nombres de parámetros SSM
├── provider.tf             # Configuración del proveedor de AWS en us-east-1
└── scripts/
    ├── publish-github-runner-lambdas.sh # Sube artefactos .zip al bucket S3
    └── put-ssm-parameter.sh             # Carga el App ID y la Clave Privada (.pem) a SSM

## 📄 Desglose Detallado Archivo por Archivo

📄 main.tf
Contiene la arquitectura base y la llamada al módulo de runners:

Data Sources: Detecta automáticamente la VPC por defecto y sus subredes en us-east-1.

Locales y Parámetros SSM: Configura las rutas SSM (/github-action-runners/demo/...) e ignora cambios en sus valores reales mediante lifecycle { ignore_changes = [value] }.

Bucket S3 (module.gha_runner_bucket): Crea el bucket seguro con cifrado para guardar las Lambdas.

Módulo Runner (module.github_runner): Despliega API Gateway, funciones Lambda y el Auto Scaling Group para lanzar instancias t3.micro efímeras con acceso SSM habilitado.

📄 variables.tf
Parametriza el entorno con enfoque Free Tier:

env_prefix (Default: "demo").

instance_target_capacity_type (Default: "on-demand" para la capa gratuita).

runner_instance_types (Default: ["t3.micro"]).

github_runner_module_version (Default: "7.10.1").

📄 outputs.tf
Muestra el endpoint de API Gateway (webhook_endpoint), el bucket generado y los nombres de los parámetros SSM requeridos para conectar GitHub con AWS.

📄 provider.tf
Fija la región de AWS en us-east-1 y define las versiones de los proveedores aws, tls y random.

📄 scripts/publish-github-runner-lambdas.sh
Descarga los ejecutable .zip oficial del release v7.10.1 (webhook.zip, runners.zip y runner-binaries-syncer.zip) y los sube a S3.

📄 scripts/put-ssm-parameter.sh
Lee la clave privada .pem descargada de GitHub, la codifica en Base64 y escribe el App ID y la clave en SSM Parameter Store sin exponerlos en código plano.

## 🚀 Plan de Ejecución Paso a Paso

Paso 1 — Crear la GitHub App
Ve a GitHub: Settings > Developer settings > GitHub Apps > New GitHub App.

Configura los datos básicos:

GitHub App name: CI-CD-AWSrunners-Demo

Homepage URL: [https://github.com](https://github.com)

Webhook URL: [https://example.com](https://example.com) (se actualizará en el Paso 6)

Asigna Permisos de Repositorio (Repository permissions):

Actions: Read & write

Administration: Read & write

Checks: Read & write

Metadata: Read-only

Suscríbete a eventos (Subscribe to events): Selecciona Workflow job.

Haz clic en Create GitHub App.

Guarda el App ID que aparece en pantalla.

En la sección Private keys, haz clic en Generate a private key y guarda el archivo .pem en tu máquina.

Ve a Install App en el menú izquierdo e instálala en tu organización o repositorio objetivo (ej. daveopssh/demo-tf-repo).

Paso 2 — Bootstrap de Infraestructura Inicial
Inicializa Terraform e instala las dependencias:

Bash
terraform init
Aplica solo los recursos base (Bucket S3 y Parámetros SSM vacíos) para preparar el terreno sin fallos de dependencias:

Bash
terraform apply \
  -target=module.gha_runner_bucket \
  -target=aws_ssm_parameter.github_app_id \
  -target=aws_ssm_parameter.github_app_key_base64 \
  -target=aws_ssm_parameter.github_app_webhook_secret
Paso 3 — Publicar las Lambdas en S3
Concede permisos de ejecución al script Bash y súbelas al bucket:

Bash
chmod +x scripts/publish-github-runner-lambdas.sh
./scripts/publish-github-runner-lambdas.sh
Paso 4 — Cargar Credenciales en SSM
Registra el App ID y la clave privada .pem en SSM usando el script helper:

Bash
chmod +x scripts/put-ssm-parameter.sh
./scripts/put-ssm-parameter.sh <NÚMERO_DE_APP_ID> /ruta/a/tu-clave-privada.pem
Paso 5 — Desplegar el Módulo Completo
Aplica la totalidad de la infraestructura (API Gateway, Lambdas y Auto Scaling):

Bash
terraform apply
Al terminar, copia el valor del output webhook_endpoint.

Paso 6 — Activar el Webhook en GitHub
Vuelve a tu GitHub App en GitHub.

Ve a General > Webhook.

Activa la opción Active.

En Webhook URL, pega la URL entregada por el output de Terraform (webhook_endpoint).

En Webhook Secret, pega el valor almacenado en SSM para la firma. Para consultarlo desde la terminal:

Bash
aws ssm get-parameter \
  --name "/github-action-runners/demo/app/github_app_github_app_webhook_secret" \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text \
  --region us-east-1
Guarda los cambios.

Paso 7 — Probar el Pipeline
En tu repositorio de GitHub autorizado, crea un archivo de workflow .github/workflows/demo.yml:

YAML
name: Demo AWS Ephemeral Runner
on:
  workflow_dispatch:

jobs:
  test-runner:
    runs-on: [self-hosted, demo]
    steps:
      - name: Checkout Código
        uses: actions/checkout@v4

      - name: Probar Runner
        run: |
          echo "¡Hola desde la instancia EC2 efímera t3.micro en us-east-1!"
          uname -a
Dispara el pipeline manualmente desde la pestaña Actions de GitHub y observa en tu consola de AWS cómo se enciende una instancia EC2 t3.micro, procesa el trabajo y se autodestruye al terminar.

## 🧹 Limpieza de Recursos

Para destruir toda la infraestructura creada y evitar cargos innecesarios en AWS, ejecuta:

Bash
terraform destroy