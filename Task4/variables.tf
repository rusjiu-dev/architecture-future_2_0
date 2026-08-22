# variables.tf
variable "yc_token" {
  description = "Yandex Cloud IAM token"
  type        = string
  sensitive   = true
}

variable "yc_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "yc_folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "yc_zone" {
  description = "Yandex Cloud availability zone"
  type        = string
  default     = "ru-central1-a"
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "future20-vpc-test"
}

variable "subnet_cidr_public" {
  description = "Public subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_cidr_private" {
  description = "Private subnet CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

variable "bastion_vm_image" {
  description = "Bastion VM image family"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "app_vm_image" {
  description = "App VM image family"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "bastion_vm_resources" {
  description = "Bastion VM resources"
  type = object({
    cores          = number
    memory         = number
    boot_disk_size = number
    core_fraction  = number
    preemptible    = bool
  })
  default = {
    cores          = 2
    memory         = 1
    boot_disk_size = 8
    core_fraction  = 20
    preemptible    = true
  }
}

variable "app_vm_resources" {
  description = "App VM resources"
  type = object({
    cores          = number
    memory         = number
    boot_disk_size = number
    data_disk_size = number
    core_fraction  = number
    preemptible    = bool
  })
  default = {
    cores          = 2
    memory         = 1
    boot_disk_size = 8
    data_disk_size = 8
    core_fraction  = 20
    preemptible    = true
  }
}

variable "ssh_public_key" {
  description = "Public SSH key for VM access"
  type        = string
  sensitive   = true
}

variable "project_tags" {
  description = "Tags for resources"
  type        = map(string)
  default = {
    environment = "test"
    managed_by  = "terraform"
    project     = "future20"
  }
}