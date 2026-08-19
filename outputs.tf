output "webhook_endpoint" {
  value       = module.github_runner.webhook.endpoint
  description = "URL del Webhook de API Gateway para configurar en la GitHub App."
}

output "lambda_artifacts_bucket_name" {
  value       = module.gha_runner_bucket.s3_bucket_id
  description = "Nombre del bucket S3 creado por Terraform."
}

output "github_app_ssm_parameter_names" {
  value = {
    id             = local.github_app_id_param_name
    key_base64     = local.github_app_key_base64_param_name
    webhook_secret = local.github_app_webhook_secret_param_name
  }
}