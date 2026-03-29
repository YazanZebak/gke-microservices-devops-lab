terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Firewall rule — allows access to Locust web UI from the internet
resource "google_compute_firewall" "locust_ui" {
  name    = "allow-locust-ui"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["8089"]
  }

  # Allow SSH access for Ansible
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["load-generator"]
}

# GCE VM — the load generator machine
resource "google_compute_instance" "load_generator" {
  name         = "load-generator"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["load-generator"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
    }
  }

  network_interface {
    network = "default"

    # Assigns a public IP so Ansible can SSH in and
    # so you can access the Locust UI from your browser
    access_config {}
  }

  metadata = {
    # Allows SSH key-based access for Ansible
    enable-oslogin = "false"
  }

  # Minimal scope — VM only needs internet access to pull Docker images
  service_account {
    scopes = ["cloud-platform"]
  }
}

# Write the VM's IP to ansible/inventory.ini automatically
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    vm_ip         = google_compute_instance.load_generator.network_interface[0].access_config[0].nat_ip
    frontend_addr = var.frontend_addr
    users         = var.locust_users
    spawn_rate    = var.locust_spawn_rate
  })
  filename = "${path.module}/../ansible/loadgenerator/inventory.ini"
}
