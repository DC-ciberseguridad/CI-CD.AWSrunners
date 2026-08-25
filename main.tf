# --- DATA SOURCES (Detecta VPC y Subredes por defecto en us-east-1) ---
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --- LOCALES Y SSM PLACEHOLDERS ---
locals {
  github_app_id_param_name             = "/github-action-runners/${var.env_prefix}/app/github_app_id"
  github_app_key_base64_param_name     = "/github-action-runners/${var.env_prefix}/app/github_app_key_base64"
  github_app_webhook_secret_param_name = "/github-action-runners/${var.env_prefix}/app/github_app_webhook_secret"

  lambda_s3_bucket = module.gha_runner_bucket.s3_bucket_id
  lambda_s3_key    = "github-runner/${var.github_runner_module_version}"
}

# 1. Creación inicial de recursos SSM
resource "aws_ssm_parameter" "github_app_id" {
  name  = local.github_app_id_param_name
  type  = "String"
  value = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "github_app_key_base64" {
  name  = local.github_app_key_base64_param_name
  type  = "SecureString"
  value = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "github_app_webhook_secret" {
  name  = local.github_app_webhook_secret_param_name
  type  = "SecureString"
  value = random_password.github_webhook_secret.result
}

# 2. LECTURA DE VALORES REALES (Añadido para corregir el error)
# Esto obliga a Terraform a consultar a AWS y traer el valor real actualizado
data "aws_ssm_parameter" "github_app_id" {
  name       = local.github_app_id_param_name
  depends_on = [aws_ssm_parameter.github_app_id]
}

data "aws_ssm_parameter" "github_app_key_base64" {
  name       = local.github_app_key_base64_param_name
  depends_on = [aws_ssm_parameter.github_app_key_base64]
}

# --- RECURSOS BASE ---
resource "random_password" "github_webhook_secret" {
  length  = 40
  special = false
}

module "gha_runner_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.10.0"

  bucket_prefix = "${var.env_prefix}-gha-runner-binaries-"
  force_destroy = true

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  versioning = {
    enabled = true
  }

  attach_deny_insecure_transport_policy = true
}

# --- MÓDULO GITHUB RUNNER ---
module "github_runner" {
  source  = "github-aws-runners/github-runner/aws"
  version = "7.10.1"

  aws_region = "us-east-1"
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  runner_architecture = "x64"

  # Cambiamos las referencias de 'aws_ssm_parameter' a 'data.aws_ssm_parameter'
  github_app = {
    id             = data.aws_ssm_parameter.github_app_id.value
    key_base64     = data.aws_ssm_parameter.github_app_key_base64.value
    webhook_secret = aws_ssm_parameter.github_app_webhook_secret.value
  }

  lambda_s3_bucket      = local.lambda_s3_bucket
  webhook_lambda_s3_key = "webhook.zip"
  runners_lambda_s3_key = "runners.zip"
  syncer_lambda_s3_key  = "runner-binaries-syncer.zip"

  instance_types                = var.runner_instance_types
  instance_target_capacity_type = var.instance_target_capacity_type

  repository_white_list = ["DC-ciberseguridad/CI-CD.AWSrunners"] # Cambia por tu repositorio

  runner_extra_labels = ["self-hosted", "demo"]
  runner_group_name   = "demo"

  enable_ssm_on_runners   = true
  enable_ephemeral_runners = true

  idle_config = []
}