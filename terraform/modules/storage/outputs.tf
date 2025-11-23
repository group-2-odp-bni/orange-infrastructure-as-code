# =============================================================================
# Storage Module - Outputs
# =============================================================================

# Profile Bucket Outputs
output "profile_bucket_name" {
  description = "Name of the profile images bucket"
  value       = var.enable_profile_bucket ? google_storage_bucket.profile_bucket[0].name : null
}

output "profile_bucket_url" {
  description = "GCS URL of the profile images bucket"
  value       = var.enable_profile_bucket ? google_storage_bucket.profile_bucket[0].url : null
}

output "storage_sa_email" {
  description = "Email of the storage service account for signed URLs"
  value       = var.enable_profile_bucket ? google_service_account.storage_sa[0].email : null
}

# Backup Bucket Outputs
output "backup_bucket_name" {
  description = "Name of the backup bucket"
  value       = google_storage_bucket.backup_bucket.name
}

output "backup_bucket_url" {
  description = "GCS URL of the backup bucket"
  value       = google_storage_bucket.backup_bucket.url
}

output "backup_bucket_self_link" {
  description = "Self-link of the backup bucket"
  value       = google_storage_bucket.backup_bucket.self_link
}

output "log_archive_bucket_name" {
  description = "Name of the log archive bucket (if enabled)"
  value       = var.enable_log_archive ? google_storage_bucket.log_archive_bucket[0].name : null
}

output "log_archive_bucket_url" {
  description = "GCS URL of the log archive bucket (if enabled)"
  value       = var.enable_log_archive ? google_storage_bucket.log_archive_bucket[0].url : null
}
