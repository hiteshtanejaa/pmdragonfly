variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for Vertex AI resources."
  type        = string
  default     = "us-central1"
}

variable "github_repository" {
  description = "GitHub repository in 'owner/repo' format – used to scope Workload Identity Federation."
  type        = string
  # Example: "my-org/my-repo"
}
