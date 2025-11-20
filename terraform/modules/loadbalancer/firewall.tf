# =============================================================================
# Firewall Rule for Load Balancer and Health Checks
# =============================================================================
#
# This rule allows traffic from the GCP Load Balancer and Health Checkers
# to reach the Ingress Controller's NodePorts on the worker nodes.
#
# GCP health checkers and LBs use specific, documented IP ranges.
# Source Ranges:
# - 130.211.0.0/22 (Legacy Health Checks, Load Balancers)
# - 35.191.0.0/16 (Legacy Health Checks, Load Balancers)
# - 209.85.152.0/22 (General Health Checks)
# - 209.85.204.0/22 (General Health Checks)
#
# =============================================================================

resource "google_compute_firewall" "allow_lb_to_nodeports" {
  name    = "${var.environment}-allow-lb-to-nodeports"
  project = var.project_id
  network = var.network_name

  # Apply this rule only to tagged worker nodes
  target_tags = [var.worker_nodes_tag]

  # Allow traffic from all potential GCP health checker and load balancer source IPs
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "209.85.152.0/22", "209.85.204.0/22"]

  allow {
    protocol = "tcp"
    ports    = ["30080", "30443", "30254"] # HTTP, HTTPS NodePorts and health check port
  }

  direction = "INGRESS"
  priority  = 1000
}
