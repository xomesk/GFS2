terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone      = "ru-central1-a"
}


resource "yandex_compute_image" "centos-7" {
  source_family = "centos-7"
}


resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" { 
  name = "subnet-1"
  zone = "ru-central1-a"
  network_id = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

 
#Create VM, iscsi initiator
resource "yandex_compute_instance" "node-clent-centos" { 
 name = "client-${count.index + 1}"
 count = 3
 resources {
   cores = 2
   memory = 2
 }

 boot_disk {
     initialize_params {
      image_id = yandex_compute_image.centos-7.id
    }
 }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }

   scheduling_policy {
    preemptible = true
  }

  metadata = {
    ssh-keys = "centos:${file("~/.ssh/id_rsa.pub")}"
 }
depends_on = [yandex_compute_instance.node-server-centos]
}


resource "yandex_compute_disk" "data-disk" {
  name       = "data"
  type       = "network-hdd"
  size       = 10
  #block_size = <размер_блока>
}

#Create VM, iscsi targer 
resource "yandex_compute_instance" "node-server-centos" {
 name = "fs-server"
 resources {
   cores = 2
   memory = 2
 }

 boot_disk {
     initialize_params {
      image_id = yandex_compute_image.centos-7.id
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    nat       = true
  }
   
  secondary_disk {
    disk_id = yandex_compute_disk.data-disk.id
  }
   
   scheduling_policy {
    preemptible = true
  }

  metadata = {
    ssh-keys = "centos:${file("~/.ssh/id_rsa.pub")}"
#    user-data = "${file("user-data.yml")}" 
 }

    connection {
    type        = "ssh"
    user        = "centos"
    private_key = file("~/.ssh/id_rsa")
    host        = yandex_compute_instance.node-server-centos.network_interface.0.nat_ip_address
  }

  provisioner "remote-exec" {
    inline = ["echo 'Im ready!'"]

  }

  provisioner "local-exec" {
    command = "ansible-playbook -u centos -i '${self.network_interface.0.nat_ip_address},' --private-key ~/.ssh/id_rsa iscsi-server.yml"
  }

}


#output "internal_ip_address_ndeo__centos" {
#  value = yandex_compute_instance.node-clent-centos.network_interface.0.ip_address
#}

#output "external_ip_address_ndeo_2_centos" {
#  value = yandex_compute_instance.node-clent-centos.network_interface.0.nat_ip_address
#}

#output "subnet-1" {
#  value = yandex_vpc_subnet.subnet-1.id
#}

