###############################################################################
# main.tf – Enable required GCP APIs and provision the deployment service
# account for the ADK hello-agent.
###############################################################################

terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Remote state is recommended for CI; configure the backend that fits your
  # organisation (GCS shown here – substitute as needed).
  backend "gcs" {
    # bucket and prefix are supplied via -backend-config in CI so that this
    # file stays environment-agnostic.
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ---------------------------------------------------------------------------
# APIs
# ---------------------------------------------------------------------------

resource "google_project_service" "aiplatform" {
  project                    = var.project_id
  service                    = "aiplatform.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

# Required for Workload Identity Federation token exchange.
resource "google_project_service" "iamcredentials" {
  project                    = var.project_id
  service                    = "iamcredentials.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "iam" {
  project                    = var.project_id
  service                    = "iam.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "serviceusage" {
  project                    = var.project_id
  service                    = "serviceusage.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_project_service" "cloudresourcemanager" {
  project                    = var.project_id
  service                    = "cloudresourcemanager.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

# Storage API is needed for the Agent Engine staging bucket.
resource "google_project_service" "storage" {
  project                    = var.project_id
  service                    = "storage.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

# ---------------------------------------------------------------------------
# Service account used by the deployment script
# ---------------------------------------------------------------------------

resource "google_service_account" "agent_deployer" {
  project      = var.project_id
  account_id   = "agent-deployer"
  display_name = "ADK Agent Deployer"
  description  = "Used by the GitHub Actions deployment script to register agents in Agent Engine."
}

resource "google_project_iam_member" "agent_deployer_aiplatform_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.agent_deployer.email}"
}

# The deployer also needs to write staging artefacts to GCS.
resource "google_project_iam_member" "agent_deployer_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.agent_deployer.email}"
}

resource "google_project_iam_member" "agent_deployer_serviceusage_admin" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = "serviceAccount:${google_service_account.agent_deployer.email}"
}

resource "google_project_iam_member" "agent_deployer_wif_pool_admin" {
  project = var.project_id
  role    = "roles/iam.workloadIdentityPoolAdmin"
  member  = "serviceAccount:${google_service_account.agent_deployer.email}"
}

resource "google_project_iam_member" "agent_deployer_project_iam_admin" {
  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.agent_deployer.email}"
}

resource "google_project_iam_member" "agent_deployer_sa_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.agent_deployer.email}"
}

# ---------------------------------------------------------------------------
# Workload Identity Federation (optional but preferred over key files in CI)
# ---------------------------------------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions pool"
}

resource "google_iam_workload_identity_pool_provider" "github_oidc" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC provider"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository == \"${var.github_repository}\""
}

resource "google_service_account_iam_member" "github_wif_binding" {
  service_account_id = google_service_account.agent_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}
