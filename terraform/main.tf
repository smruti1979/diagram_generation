terraform {
  required_version = ">= 1.6.0"
  backend "gcs" {}
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  prefix = "rag-platform-${var.environment}"
  labels = {
    environment  = var.environment
    architecture = "vertex-multi-agent-rag"
    managed_by   = "terraform"
  }
}

# ==============================================================================
# 1. Enable Required Google Cloud APIs
# ==============================================================================
resource "google_project_service" "required_apis" {
  for_each = toset([
    "://googleapis.com",
    "://googleapis.com",
    "://googleapis.com",
    "://googleapis.com",
    "://googleapis.com",
    "://googleapis.com",
    "://googleapis.com",
    "://googleapis.com",
    "://googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ==============================================================================
# 2. Networking (VPC & Private Service Access)
# ==============================================================================
resource "google_compute_network" "rag_vpc" {
  name                    = "${local.prefix}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required_apis]
}

resource "google_compute_subnetwork" "rag_subnet" {
  name          = "${local.prefix}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.rag_vpc.id
}

resource "google_compute_global_address" "private_ip_range" {
  name          = "${local.prefix}-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.rag_vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.rag_vpc.id
  service                 = "://googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# ==============================================================================
# 3. Least-Privilege Service Account & IAM Roles
# ==============================================================================
resource "google_service_account" "agent_runtime_sa" {
  account_id   = "${local.prefix}-agent-sa"
  display_name = "Vertex AI Multi-Agent Runtime Service Account (${var.environment})"
}

resource "google_project_iam_member" "agent_roles" {
  for_each = toset([
    "roles/aiplatform.user",
    "roles/storage.objectViewer",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/cloudtrace.agent",
    "roles/logging.logWriter",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.agent_runtime_sa.email}"
}

# ==============================================================================
# 4. Cloud Storage (Raw Document Ingestion & Index Staging)
# ==============================================================================
resource "google_storage_bucket" "raw_docs_bucket" {
  name                        = "${var.project_id}-${local.prefix}-docs"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = var.environment == "dev" ? true : false
  labels                      = local.labels

  versioning {
    enabled = true
  }

  depends_on = [google_project_service.required_apis]
}

# ==============================================================================
# 5. Memorystore for Redis (Session State & Semantic Cache)
# ==============================================================================
resource "google_redis_instance" "semantic_cache" {
  name               = "${local.prefix}-redis"
  tier               = var.redis_config[var.environment].tier
  memory_size_gb     = var.redis_config[var.environment].memory_size_gb
  region             = var.region
  authorized_network = google_compute_network.rag_vpc.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"
  redis_version      = "REDIS_7_0"
  display_name       = "Agent Session & Semantic Cache (${var.environment})"
  labels             = local.labels

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# ==============================================================================
# 6. BigQuery (Enterprise Analytics & RAG Evaluation Telemetry)
# ==============================================================================
resource "google_bigquery_dataset" "rag_analytics" {
  dataset_id                 = replace("${local.prefix}_analytics", "-", "_")
  friendly_name              = "Multi-Agent RAG Analytics (${var.environment})"
  description                = "Stores inference traces, token usage, and Vertex AI Evaluation scores"
  location                   = var.region
  delete_contents_on_destroy = var.environment == "dev" ? true : false
  labels                     = local.labels

  depends_on = [google_project_service.required_apis]
}

resource "google_bigquery_table" "eval_logs" {
  dataset_id          = google_bigquery_dataset.rag_analytics.dataset_id
  table_id            = "inference_eval_logs"
  deletion_protection = var.environment == "prod" ? true : false

  schema = jsonencode([
    { name = "trace_id", type = "STRING", mode = "REQUIRED" },
    { name = "timestamp", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "user_query", type = "STRING", mode = "NULLABLE" },
    { name = "retrieved_chunks", type = "JSON", mode = "NULLABLE" },
    { name = "final_response", type = "STRING", mode = "NULLABLE" },
    { name = "groundedness_score", type = "FLOAT64", mode = "NULLABLE" },
    { name = "latency_ms", type = "INT64", mode = "NULLABLE" }
  ])
}

# ==============================================================================
# 7. Vertex AI Vector Search (ScaNN Index & Private Endpoint)
# ==============================================================================
resource "google_vertex_ai_index" "rag_vector_index" {
  display_name        = "${local.prefix}-scann-index"
  description         = "Hybrid dense+sparse ScaNN index (${var.environment})"
  region              = var.region
  index_update_method = "STREAM_UPDATE"
  labels              = local.labels

  metadata {
    contents_delta_uri = "gs://${google_storage_bucket.raw_docs_bucket.name}/index-init"

    config {
      dimensions                  = var.vector_embedding_dimensions
      approximate_neighbors_count = 150
      shard_size                  = var.vector_shard_size[var.environment]
      distance_measure_type       = "DOT_PRODUCT_DISTANCE"

      algorithm_config {
        tree_ah_config {
          leaf_node_embedding_count    = 1000
          leaf_nodes_to_search_percent = 7
        }
      }
    }
  }

  depends_on = [google_storage_bucket.raw_docs_bucket]
}

resource "google_vertex_ai_index_endpoint" "rag_vector_endpoint" {
  display_name = "${local.prefix}-vector-endpoint"
  description  = "Private VPC endpoint for Vertex AI Vector Search (${var.environment})"
  region       = var.region
  network      = "projects/${var.project_id}/global/networks/${google_compute_network.rag_vpc.name}"
  labels       = local.labels

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# ==============================================================================
# 8. Cloud Run Services (Supervisor Agent & Tool Execution Runner)
# ==============================================================================
resource "google_cloud_run_v2_service" "tool_runner" {
  name     = "${local.prefix}-tool-runner"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  labels   = local.labels

  template {
    service_account = google_service_account.agent_runtime_sa.email

    scaling {
      min_instance_count = var.tool_runner_scaling[var.environment].min_instances
      max_instance_count = var.tool_runner_scaling[var.environment].max_instances
    }

    vpc_access {
      network_interfaces {
        network    = google_compute_network.rag_vpc.id
        subnetwork = google_compute_subnetwork.rag_subnet.id
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = var.tool_runner_image
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "BQ_DATASET"
        value = google_bigquery_dataset.rag_analytics.dataset_id
      }
    }
  }

  depends_on = [google_project_service.required_apis]
}

resource "google_cloud_run_v2_service" "supervisor_agent" {
  name     = "${local.prefix}-supervisor"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  labels   = local.labels

  template {
    service_account = google_service_account.agent_runtime_sa.email

    scaling {
      min_instance_count = var.supervisor_scaling[var.environment].min_instances
      max_instance_count = var.supervisor_scaling[var.environment].max_instances
    }

    vpc_access {
      network_interfaces {
        network    = google_compute_network.rag_vpc.id
        subnetwork = google_compute_subnetwork.rag_subnet.id
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = var.supervisor_image

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "GCP_REGION"
        value = var.region
      }
      env {
        name  = "REDIS_HOST"
        value = google_redis_instance.semantic_cache.host
      }
      env {
        name  = "REDIS_PORT"
        value = tostring(google_redis_instance.semantic_cache.port)
      }
      env {
        name  = "VECTOR_INDEX_ENDPOINT"
        value = google_vertex_ai_index_endpoint.rag_vector_endpoint.name
      }
      env {
      name  = "TOOL_RUNNER_URL"
      value = google_cloud_run_v2_service.tool_runner.uri
      }
      }
      }
      depends_on = [google_project_service.required_apis]
      }
    resource "google_cloud_run_v2_service_iam_member" "supervisor_invokes_tools" {
      project  = var.project_id
      location = var.region
      name     = google_cloud_run_v2_service.tool_runner.name
      role     = "roles/run.invoker"
      member   = "serviceAccount:${google_service_account.agent_runtime_sa.email}"
      }