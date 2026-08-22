# outputs.tf
output "bastion_public_ip" {
  description = "Публичный IP bastion хоста"
  value       = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
}

output "app_private_ip" {
  description = "Приватный IP app ВМ"
  value       = yandex_compute_instance.app.network_interface[0].ip_address
}

output "app_data_disk_id" {
  description = "ID data диска app ВМ"
  value       = yandex_compute_disk.data_disk.id
}

output "vpc_id" {
  description = "ID VPC"
  value       = yandex_vpc_network.main.id
}

output "ssh_bastion_command" {
  description = "Команда для подключения к bastion"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${yandex_compute_instance.bastion.network_interface[0].nat_ip_address}"
}

output "ssh_app_via_bastion_command" {
  description = "Команда для подключения к app ВМ через bastion"
  value       = "ssh -J ubuntu@${yandex_compute_instance.bastion.network_interface[0].nat_ip_address} ubuntu@${yandex_compute_instance.app.network_interface[0].ip_address}"
}

output "estimated_monthly_cost" {
  description = "Ориентировочная стоимость (руб/мес) - только для справки"
  value = <<EOF
BASTION: ${var.bastion_vm_resources.cores} vCPU, ${var.bastion_vm_resources.memory} GB RAM (preemptible)
APP: ${var.app_vm_resources.cores} vCPU, ${var.app_vm_resources.memory} GB RAM, ${var.app_vm_resources.data_disk_size} GB SSD (preemptible)
Ориентировочная стоимость: ~500-800 руб/мес (зависит от региона и нагрузки)
EOF
}