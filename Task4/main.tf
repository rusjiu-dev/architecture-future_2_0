# main.tf
# Terraform конфигурация для Yandex Cloud (тестовый запуск)

# ============================================
# 1. Terraform и Provider
# ============================================
terraform {
  required_version = ">= 1.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.100"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}

# ============================================
# 2. Data Sources (образы)
# ============================================
data "yandex_compute_image" "ubuntu_bastion" {
  family = var.bastion_vm_image
}

data "yandex_compute_image" "ubuntu_app" {
  family = var.app_vm_image
}

# ============================================
# 3. VPC и подсети
# ============================================
resource "yandex_vpc_network" "main" {
  name        = var.vpc_name
  description = "VPC для тестовой инфраструктуры Future 2.0"
  labels      = var.project_tags
}

resource "yandex_vpc_subnet" "public" {
  name           = "${var.vpc_name}-public"
  description    = "Публичная подсеть для bastion"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.subnet_cidr_public]
  labels         = var.project_tags
}

resource "yandex_vpc_subnet" "private" {
  name           = "${var.vpc_name}-private"
  description    = "Приватная подсеть для app ВМ"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.subnet_cidr_private]
  labels         = var.project_tags
}

# ============================================
# 4. NAT Gateway
# ============================================
resource "yandex_vpc_gateway" "nat" {
  name        = "${var.vpc_name}-nat"
  description = "NAT шлюз для приватной подсети"
  shared_egress_gateway {}
  labels = var.project_tags
}

# ============================================
# 5. Security Groups
# ============================================
resource "yandex_vpc_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Security group для bastion ВМ"
  network_id  = yandex_vpc_network.main.id
  labels      = var.project_tags

  ingress {
    description    = "SSH из интернета"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description    = "Разрешить весь исходящий трафик"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "app_sg" {
  name        = "app-sg"
  description = "Security group для app ВМ"
  network_id  = yandex_vpc_network.main.id
  labels      = var.project_tags

  ingress {
    description    = "SSH только из публичной подсети"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.subnet_cidr_public]
  }

  ingress {
    description    = "HTTP из VPC"
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description    = "HTTPS из VPC"
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description    = "Разрешить весь исходящий трафик"
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ============================================
# 6. Data Disk
# ============================================
resource "yandex_compute_disk" "data_disk" {
  name        = "app-data-disk"
  description = "Data disk для app VM"
  type        = "network-ssd"
  zone        = var.yc_zone
  size        = var.app_vm_resources.data_disk_size
  labels      = var.project_tags
}

# ============================================
# 7. Bastion VM
# ============================================
resource "yandex_compute_instance" "bastion" {
  name        = "bastion-vm"
  description = "Bastion хост с публичным IP"
  zone        = var.yc_zone
  labels      = var.project_tags

  resources {
    cores         = var.bastion_vm_resources.cores
    memory        = var.bastion_vm_resources.memory
    core_fraction = var.bastion_vm_resources.core_fraction
  }

  boot_disk {
    auto_delete = true
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_bastion.id
      size     = var.bastion_vm_resources.boot_disk_size
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public.id
    security_group_ids = [yandex_vpc_security_group.bastion_sg.id]
    nat                = true
  }

  metadata = {
    ssh-keys          = "ubuntu:${var.ssh_public_key}"
    serial-port-enable = "1"
  }

  scheduling_policy {
    preemptible = var.bastion_vm_resources.preemptible
  }
}

# ============================================
# 8. Application VM
# ============================================
resource "yandex_compute_instance" "app" {
  name        = "app-vm"
  description = "Application VM для сервисов"
  zone        = var.yc_zone
  labels      = var.project_tags

  resources {
    cores         = var.app_vm_resources.cores
    memory        = var.app_vm_resources.memory
    core_fraction = var.app_vm_resources.core_fraction
  }

  boot_disk {
    auto_delete = true
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_app.id
      size     = var.app_vm_resources.boot_disk_size
      type     = "network-ssd"
    }
  }

  secondary_disk {
    disk_id     = yandex_compute_disk.data_disk.id
    auto_delete = false
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private.id
    security_group_ids = [yandex_vpc_security_group.app_sg.id]
    nat                = false
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  scheduling_policy {
    preemptible = var.app_vm_resources.preemptible
  }
}

# ============================================
# 9. Snapshot Schedule (бэкап)
# ============================================
resource "yandex_compute_snapshot_schedule" "app_backup" {
  name        = "app-vm-backup-schedule"
  description = "Ежедневный снапшот data диска app ВМ"
  labels      = var.project_tags

  schedule_policy {
    expression = "0 0 * * *"
  }

  snapshot_spec {
    description = "Автоматический бэкап app ВМ data диска"
    labels = {
      environment = var.project_tags["environment"]
    }
  }

  disk_ids = [yandex_compute_disk.data_disk.id]
}