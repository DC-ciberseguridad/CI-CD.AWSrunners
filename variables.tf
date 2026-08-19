variable "env_prefix" {
  type        = string
  default     = "demo"
  description = "Prefix for all resources created."
}

variable "instance_target_capacity_type" {
  type        = string
  default     = "on-demand" # Cambiado a on-demand para Free Tier
  description = "Target capacity type for the runner instances."

  validation {
    condition     = contains(["spot", "on-demand"], var.instance_target_capacity_type)
    error_message = "The instance_target_capacity_type must be 'spot' or 'on-demand'."
  }
}

variable "runner_instance_types" {
  type        = list(string)
  default     = ["t3.micro"] # Instancia elegible para la capa gratuita
  description = "List of instance types for the runner."
}

variable "github_runner_module_version" {
  type        = string
  default     = "7.10.1"
  description = "Version of the github-runner module."
}