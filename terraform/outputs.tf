output "service_account_email" {
  description = "Email of the deployment service account."
  value       = google_service_account.agent_deployer.email
}

output "workload_identity_provider" {
  description = "Full resource name of the Workload Identity pool provider (paste into GitHub Actions workflow)."
  value       = google_iam_workload_identity_pool_provider.github_oidc.name
}
