output "container_id" {
  value = proxmox_virtual_environment_container.fakeflix.vm_id
}

output "ip" {
  value = split("/", var.ipv4_address)[0]
}

output "root_password" {
  description = "Console password for root (SSH uses your key)."
  value       = random_password.root.result
  sensitive   = true
}
