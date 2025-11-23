# =============================================================================
# Storage Module - GCS Buckets & Service Accounts
# =============================================================================
#
# This module creates:
# - User profile images bucket (with CORS)
# - Database backup bucket with lifecycle policies
# - Storage service account for signed URL generation
# - IAM bindings for impersonation pattern
#
# =============================================================================

locals {
  # Construct backup SA email if not provided
  backup_sa_email = var.backup_sa_email != "" ? var.backup_sa_email : "k8s-backup-sa@${var.project_id}.iam.gserviceaccount.com"

  # Construct k3s node SA email
  k3s_node_sa_email = var.k3s_node_sa_email != "" ? var.k3s_node_sa_email : "k3s-node-sa@${var.project_id}.iam.gserviceaccount.com"
}

# -----------------------------------------------------------------------------
# Storage Service Account for Signed URLs
# -----------------------------------------------------------------------------

resource "google_service_account" "storage_sa" {
  count = var.enable_profile_bucket ? 1 : 0

  account_id   = "orange-wallet-storage"
  display_name = "Orange Wallet Storage Service Account"
  description  = "Service account for GCS signed URL generation and storage operations"
  project      = var.project_id
}

# Allow storage SA to create tokens for itself (needed for signed URLs)
resource "google_project_iam_member" "storage_sa_token_creator" {
  count = var.enable_profile_bucket ? 1 : 0

  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.storage_sa[0].email}"
}

# Allow k3s-node-sa to impersonate storage SA
resource "google_service_account_iam_member" "k3s_can_impersonate_storage" {
  count = var.enable_profile_bucket ? 1 : 0

  service_account_id = google_service_account.storage_sa[0].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${local.k3s_node_sa_email}"
}

# -----------------------------------------------------------------------------
# Profile Images Bucket
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "profile_bucket" {
  count = var.enable_profile_bucket ? 1 : 0

  name          = var.profile_bucket_name
  location      = var.region
  force_destroy = false
  project       = var.project_id

  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }

  # CORS for frontend access
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["Content-Type", "Content-Length", "Date"]
    max_age_seconds = 3600
  }

  labels = merge(
    var.labels,
    {
      purpose = "user-profiles"
      type    = "image-storage"
    }
  )
}

# Grant storage SA full access to profile bucket
resource "google_storage_bucket_iam_member" "profile_object_admin" {
  count = var.enable_profile_bucket ? 1 : 0

  bucket = google_storage_bucket.profile_bucket[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.storage_sa[0].email}"
}

# -----------------------------------------------------------------------------
# Backup Bucket for PostgreSQL
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "backup_bucket" {
  name          = var.backup_bucket_name
  location      = var.region
  force_destroy = false # Prevent accidental deletion
  project       = var.project_id

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = var.backup_retention_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age                = 7
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  labels = merge(
    var.labels,
    {
      purpose = "database-backups"
      type    = "backup-storage"
    }
  )

  # Enable encryption (Google-managed by default, customer-managed if KMS key provided)
  dynamic "encryption" {
    for_each = var.kms_key_name != null ? [1] : []
    content {
      default_kms_key_name = var.kms_key_name
    }
  }
}

# -----------------------------------------------------------------------------
# IAM Binding for Backup Service Account
# -----------------------------------------------------------------------------

resource "google_storage_bucket_iam_member" "backup_writer" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${local.backup_sa_email}"
}

resource "google_storage_bucket_iam_member" "backup_reader" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${local.backup_sa_email}"
}

# -----------------------------------------------------------------------------
# Optional: Log Archive Bucket
# -----------------------------------------------------------------------------

resource "google_storage_bucket" "log_archive_bucket" {
  count         = var.enable_log_archive ? 1 : 0
  name          = "${var.backup_bucket_name}-logs"
  location      = var.region
  force_destroy = false
  project       = var.project_id

  uniform_bucket_level_access = true

  versioning {
    enabled = false # Logs don't need versioning
  }

  lifecycle_rule {
    condition {
      age = 90 # Keep logs for 90 days
    }
    action {
      type = "Delete"
    }
  }

  # Lifecycle transition to cheaper storage class
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  labels = merge(
    var.labels,
    {
      purpose = "log-archive"
      type    = "log-storage"
    }
  )
}
