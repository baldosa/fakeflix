resource "proxmox_virtual_environment_download_file" "template" {
  node_name    = var.node_name
  datastore_id = var.template_datastore
  content_type = "vztmpl"
  url          = var.template_url
  overwrite    = false
}

resource "random_password" "root" {
  length  = 24
  special = false
}

resource "proxmox_virtual_environment_container" "fakeflix" {
  node_name     = var.node_name
  vm_id         = var.vm_id
  description   = "Media stack managed by Terraform + Ansible (fakeflix)"
  tags          = var.tags
  unprivileged  = var.unprivileged
  start_on_boot = true
  started       = true

  # Docker inside LXC needs nesting (and keyctl when unprivileged).
  features {
    nesting = true
    keyctl  = var.unprivileged
  }

  operating_system {
    template_file_id = proxmox_virtual_environment_download_file.template.id
    type             = "debian"
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.swap_mb
  }

  disk {
    datastore_id = var.rootfs_datastore
    size         = var.rootfs_size_gb
  }

  network_interface {
    name    = "eth0"
    bridge  = var.bridge
    vlan_id = var.vlan_id
  }

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }

    dns {
      servers = var.dns_servers
    }

    user_account {
      keys     = [trimspace(file(pathexpand(var.ssh_public_key_file)))]
      password = random_password.root.result
    }
  }

  dynamic "mount_point" {
    for_each = var.media_mounts
    content {
      volume = mount_point.key
      path   = mount_point.value
    }
  }
}

# Hand the new host over to Ansible.
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory/hosts.yml"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/inventory.yml.tftpl", {
    hostname = var.hostname
    ip       = split("/", var.ipv4_address)[0]
  })
}
