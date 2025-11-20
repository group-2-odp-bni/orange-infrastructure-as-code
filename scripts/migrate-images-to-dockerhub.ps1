# =============================================================================
# Script: Migrate Images from GCP Artifact Registry to Docker Hub
# =============================================================================
# Usage: .\migrate-images-to-dockerhub.ps1 -DockerHubUsername "your-username"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$DockerHubUsername
)

$ErrorActionPreference = "Stop"

# GCP Artifact Registry details
$GCP_REGISTRY = "asia-southeast2-docker.pkg.dev/orange-wallet/orange-wallet-registry"

# Services to migrate
$SERVICES = @(
    "api-gateway",
    "user-service",
    "wallet-service",
    "transaction-service",
    "authentication-service"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Migrating Images to Docker Hub" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GCP Registry: $GCP_REGISTRY" -ForegroundColor Yellow
Write-Host "Docker Hub User: $DockerHubUsername" -ForegroundColor Yellow
Write-Host ""

# Step 1: Login to GCP Artifact Registry
Write-Host "Step 1: Configuring GCP Artifact Registry authentication..." -ForegroundColor Green
gcloud auth configure-docker asia-southeast2-docker.pkg.dev --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to configure GCP auth" -ForegroundColor Red
    exit 1
}

# Step 2: Process each service
foreach ($SERVICE in $SERVICES) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Processing: $SERVICE" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $GCP_IMAGE = "$GCP_REGISTRY/${SERVICE}:latest"
    $DOCKERHUB_IMAGE = "${DockerHubUsername}/orange-wallet-${SERVICE}:latest"

    Write-Host "  From: $GCP_IMAGE" -ForegroundColor Yellow
    Write-Host "  To:   $DOCKERHUB_IMAGE" -ForegroundColor Yellow

    # Pull from GCP
    Write-Host ""
    Write-Host "  [1/3] Pulling from GCP Artifact Registry..." -ForegroundColor Green
    docker pull $GCP_IMAGE
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to pull $GCP_IMAGE" -ForegroundColor Red
        continue
    }

    # Tag for Docker Hub
    Write-Host "  [2/3] Tagging for Docker Hub..." -ForegroundColor Green
    docker tag $GCP_IMAGE $DOCKERHUB_IMAGE
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to tag $DOCKERHUB_IMAGE" -ForegroundColor Red
        continue
    }

    # Push to Docker Hub
    Write-Host "  [3/3] Pushing to Docker Hub..." -ForegroundColor Green
    docker push $DOCKERHUB_IMAGE
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to push $DOCKERHUB_IMAGE" -ForegroundColor Red
        continue
    }

    Write-Host "  SUCCESS: $SERVICE migrated!" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Migration Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Update GitOps manifests with Docker Hub image paths" -ForegroundColor White
Write-Host "2. Commit and push to GitHub" -ForegroundColor White
Write-Host "3. ArgoCD will auto-sync and deploy with new images" -ForegroundColor White
Write-Host ""

# Display summary
Write-Host "Docker Hub Images Created:" -ForegroundColor Cyan
foreach ($SERVICE in $SERVICES) {
    Write-Host "  - ${DockerHubUsername}/orange-wallet-${SERVICE}:latest" -ForegroundColor White
}
