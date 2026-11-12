# ==============================================================================
# Core Project & Environment Variables
# ==============================================================================
variable "project_id" {
  description = "GCP Project ID where resources will be provisioned."
  type        = string

  validation {
    condition     = length(trimspace(var.project_id)) > 0
    error_message = "project_id must be a non-empty string."
  }
}

variable "region" {
  description = "Primary GCP region (e.g., asia-south1 for Mumbai or us-central1)."
  type        = string
  default     = "asia-south1"
}

variable "environment" {
  description = "Target deployment environment (dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

# ==============================================================================
# Networking Variables
# ==============================================================================
variable "subnet_cidr" {
  description = "CIDR block for the Cloud Run VPC connector subnet."
  type        = string
  default     = "10.10.0.0/20"
}

# ==============================================================================
# Container Images & Cloud Run Scaling
# ==============================================================================
variable "supervisor_image" {
  description = "Container image URI for the Supervisor Agent Cloud Run service."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "tool_runner_image" {
  description = "Container image URI for the Tool Execution Cloud Run service."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "supervisor_scaling" {
  description = "Min and max instance counts per environment for the Supervisor Agent."
  type = map(object({
    min_instances = number
    max_instances = number
  }))
  default = {
    dev     = { min_instances = 0, max_instances = 3 }
    staging = { min_instances = 1, max_instances = 10 }
    prod    = { min_instances = 2, max_instances = 30 }
  }
}

variable "tool_runner_scaling" {
  description = "Min and max instance counts per environment for the Tool Runner service."
  type = map(object({
    min_instances = number
    max_instances = number
  }))
  default = {
    dev     = { min_instances = 0, max_instances = 3 }
    staging = { min_instances = 1, max_instances = 8 }
    prod    = { min_instances = 2, max_instances = 20 }
  }
}

# ==============================================================================
# Memorystore (Redis) & Vertex AI Vector Search Sizing
# ==============================================================================
variable "redis_config" {
  description = "Memorystore Redis tier and capacity (GB) per environment."
  type = map(object({
    tier           = string
    memory_size_gb = number
  }))
  default = {
    dev     = { tier = "BASIC", memory_size_gb = 1 }
    staging = { tier = "BASIC", memory_size_gb = 2 }
    prod    = { tier = "STANDARD_HA", memory_size_gb = 5 }
  }
}

variable "vector_embedding_dimensions" {
  description = "Vector embedding dimensions (768 for text-embedding-005)."
  type        = number
  default     = 768
}

variable "vector_shard_size" {
  description = "Vertex AI Vector Search shard size per environment."
  type        = map(string)
  default = {
    dev     = "SHARD_SIZE_SMALL"
    staging = "SHARD_SIZE_SMALL"
    prod    = "SHARD_SIZE_MEDIUM"
  }
}