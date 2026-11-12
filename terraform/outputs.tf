# ==============================================================================
# Cloud Run Service Endpoints
# ==============================================================================
output "supervisor_url" {
  description = "HTTPS endpoint URL of the Supervisor Agent Cloud Run service."
  value       = google_cloud_run_v2_service.supervisor_agent.uri
}

output "tool_runner_url" {
  description = "Internal HTTPS endpoint URL of the Tool Execution Cloud Run service."
  value       = google_cloud_run_v2_service.tool_runner.uri
}

# ==============================================================================
# Storage, Cache & Analytics Identifiers
# ==============================================================================
output "docs_bucket_name" {
  description = "GCS bucket name for uploading raw unstructured RAG documents."
  value       = google_storage_bucket.raw_docs_bucket.name
}

output "docs_bucket_url" {
  description = "GCS URI (gs://) for the raw RAG documents bucket."
  value       = google_storage_bucket.raw_docs_bucket.url
}

output "redis_host" {
  description = "Private IP address of the Memorystore Redis instance."
  value       = google_redis_instance.semantic_cache.host
}

output "redis_port" {
  description = "Port number of the Memorystore Redis instance."
  value       = google_redis_instance.semantic_cache.port
}

output "bigquery_dataset_id" {
  description = "BigQuery dataset ID storing inference traces and evaluation logs."
  value       = google_bigquery_dataset.rag_analytics.dataset_id
}

output "bigquery_eval_table_id" {
  description = "Fully qualified BigQuery table ID for RAG evaluation telemetry."
  value       = "${var.project_id}.${google_bigquery_dataset.rag_analytics.dataset_id}.${google_bigquery_table.eval_logs.table_id}"
}

# ==============================================================================
# Vertex AI Vector Search & IAM Outputs
# ==============================================================================
output "vector_index_id" {
  description = "Resource name of the Vertex AI Vector Search ScaNN index."
  value       = google_vertex_ai_index.rag_vector_index.name
}

output "vector_index_endpoint_id" {
  description = "Resource name of the private Vertex AI Vector Search endpoint."
  value       = google_vertex_ai_index_endpoint.rag_vector_endpoint.name
}

output "agent_service_account_email" {
  description = "Least-privilege IAM service account email attached to the agent runtime."
  value       = google_service_account.agent_runtime_sa.email
}

# ==============================================================================
# Local Development .env Helper Output
# ==============================================================================
output "local_dev_env_block" {
  description = "Ready-to-paste environment variables for local agent testing."
  value       = <<-EOT
    GCP_PROJECT_ID=${var.project_id}
    GCP_REGION=${var.region}
    ENVIRONMENT=${var.environment}
    GCS_DOCS_BUCKET=${google_storage_bucket.raw_docs_bucket.name}
    REDIS_HOST=${google_redis_instance.semantic_cache.host}
    REDIS_PORT=${google_redis_instance.semantic_cache.port}
    VECTOR_INDEX_ENDPOINT=${google_vertex_ai_index_endpoint.rag_vector_endpoint.name}
    BQ_DATASET=${google_bigquery_dataset.rag_analytics.dataset_id}
    TOOL_RUNNER_URL=${google_cloud_run_v2_service.tool_runner.uri}
  EOT
}