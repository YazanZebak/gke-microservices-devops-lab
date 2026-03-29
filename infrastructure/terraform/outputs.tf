output "load_generator_ip" {
  description = "External IP of the load generator VM"
  value       = google_compute_instance.load_generator.network_interface[0].access_config[0].nat_ip
}

output "locust_ui_url" {
  description = "URL to access the Locust web UI"
  value       = "http://${google_compute_instance.load_generator.network_interface[0].access_config[0].nat_ip}:8089"
}

output "ansible_inventory_path" {
  description = "Path to the generated Ansible inventory file"
  value       = "${path.module}/../../ansible/loadgenerator/inventory.ini"
}
