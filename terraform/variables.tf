# --- Proxmox connection -------------------------------------------------------

variable "proxmox_endpoint" {
  description = "Proxmox API URL, e.g. https://192.168.1.10:8006/"
  type        = string
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (self-signed Proxmox certificate)."
  type        = bool
  default     = true
}

variable "proxmox_username" {
  description = "Proxmox user. Bind mounts can only be created by root@pam with a password (not an API token)."
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Password for proxmox_username."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_api_token" {
  description = "Optional API token (USER@REALM!ID=SECRET). Only works if you drop the bind mount (media_host_path = null)."
  type        = string
  default     = null
  sensitive   = true
}

variable "node_name" {
  description = "Proxmox node that hosts the container."
  type        = string
  default     = "pve"
}

# --- Container ----------------------------------------------------------------

variable "vm_id" {
  description = "Container ID. null = next free ID."
  type        = number
  default     = null
}

variable "hostname" {
  type    = string
  default = "fakeflix"
}

variable "unprivileged" {
  description = "Unprivileged LXC (safer). Host files must then be owned by 100000 + PUID (see README)."
  type        = bool
  default     = true
}

variable "cores" {
  type    = number
  default = 4
}

variable "memory_mb" {
  type    = number
  default = 4096
}

variable "swap_mb" {
  type    = number
  default = 1024
}

variable "rootfs_datastore" {
  description = "Storage for the container root disk."
  type        = string
  default     = "local-lvm"
}

variable "rootfs_size_gb" {
  description = "Root disk size. Holds the OS, Docker images and app configs (not media)."
  type        = number
  default     = 32
}

variable "template_datastore" {
  description = "Storage where the LXC template is downloaded to (must allow 'vztmpl' content)."
  type        = string
  default     = "local"
}

variable "template_url" {
  description = "Debian LXC template to download."
  type        = string
  default     = "http://download.proxmox.com/images/system/debian-12-standard_12.7-1_amd64.tar.zst"
}

# --- Network ------------------------------------------------------------------

variable "bridge" {
  type    = string
  default = "vmbr0"
}

variable "vlan_id" {
  type    = number
  default = null
}

variable "ipv4_address" {
  description = "Static IP in CIDR notation, e.g. 192.168.1.50/24 (needed to generate the Ansible inventory)."
  type        = string

  validation {
    condition     = can(cidrhost(var.ipv4_address, 0))
    error_message = "ipv4_address must be a static address in CIDR notation, e.g. 192.168.1.50/24."
  }
}

variable "ipv4_gateway" {
  type = string
}

variable "dns_servers" {
  type    = list(string)
  default = ["1.1.1.1", "9.9.9.9"]
}

variable "ssh_public_key_file" {
  description = "Public key installed for root; Ansible connects with the matching private key."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# --- Storage ------------------------------------------------------------------

variable "media_host_path" {
  description = "Directory on the Proxmox host holding Downloads/movies/series/music. null = no bind mount."
  type        = string
  default     = "/mnt/disk"
}

variable "media_mount_path" {
  description = "Where media_host_path appears inside the container."
  type        = string
  default     = "/mnt/disk"
}

variable "tags" {
  type    = list(string)
  default = ["fakeflix", "media"]
}
