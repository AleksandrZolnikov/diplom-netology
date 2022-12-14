terraform {
  required_providers {
    yandex = {
      source = "terraform-registry.storage.yandexcloud.net/yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

locals {
  folder_id = "b1gv95....s6kbr5jn"
  cloud_id  = "b1gu.....ohajpph0q"
}


provider "yandex" {
  cloud_id  = "local.cloud_id"
  folder_id = local.folder_id
  zone      = "ru-central1-a"
}

##---------------------------------------------------------
# VPC # https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_network

resource "yandex_vpc_network" "network" {
  name = "netology"

}

#---------------------------------------------------------
# subnet public-subnet # https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_subnet

resource "yandex_vpc_subnet" "subnet-a" {
  name = "public subnet-a"
	v4_cidr_blocks = ["192.168.10.0/24"]
	zone = "ru-central1-a"
	network_id = yandex_vpc_network.network.id
}

resource "yandex_vpc_subnet" "subnet-b" {
  name = "public subnet-b"
	v4_cidr_blocks = ["192.168.20.0/24"]
	zone = "ru-central1-b"
	network_id = yandex_vpc_network.network.id
  depends_on = [yandex_vpc_subnet.subnet-a]
}

resource "yandex_vpc_subnet" "subnet-c" {
  name = "public subnet-c"
	v4_cidr_blocks = ["192.168.30.0/24"]
	zone = "ru-central1-c"
	network_id = yandex_vpc_network.network.id
  depends_on = [yandex_vpc_subnet.subnet-b]
}

# --------------------------------------------------------
# create NAT public

resource "yandex_compute_instance" "nat-instance" {
  name        = "nat-instance"
  platform_id = "standard-v1"
  zone        = "ru-central1-a"

  resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd80mrhj8fl2oe87o4e1"
    }
  }

  network_interface {
    subnet_id  = yandex_vpc_subnet.public-subnet.id
    nat        = true
    ip_address = "192.168.10.254"
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}


#---------------------------------------------------------
# Bucket object storage # https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/storage_bucket

// ???????????????? ???????????? ???????????????? # Create SA
resource "yandex_iam_service_account" "sa" {
  folder_id = local.folder_id
  name      = "netology-account"
}

#-----------------------------------------------
#  S3 bucket  https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/storage_bucket

// ???????????????????? ???????? ## Grant permissions
resource "yandex_resourcemanager_folder_iam_member" "sa-admin" {
  folder_id = local.folder_id
  role      = "admin"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
}

//  ???????????????? ???????????????????????? ?????????? ?????????????? ## Create Static Access Keys
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "static access key for object storage"
}

// ???????????????? Bucket ## Use keys to create bucket
resource "yandex_storage_bucket" "my-bucket" {
  access_key = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  bucket     = "diplom-devops"
  acl        = "private" # default value, just in case we specify
}

backend "s3" {
  endpoint   = "storage.yandexcloud.net"
  bucket     = "diplom-devops"
  region     = "ru-central1-a"
  key        = "terraform/terraform.tfstate"
  access_key = "here_you_need_access_key"
  secret_key = "here_you_need_secret_key"

  skip_region_validation      = true
  skip_credentials_validation = true
 }  

#-----------------------------------------------
#  master node 1

resource "yandex_compute_instance" "master-node-1" {
  name        = "master-node-1"
  platform_id = "standard-v1"
  zone        = yandex_vpc_subnet.subnet-a.zone

  resources {
    cores = 4
    #  core_fraction = 20 # Guaranteed share of vCPU
    memory = 4
  }

  # Interrupting machine ## ?????????????????????? ????????????
  scheduling_policy {
    preemptible = (terraform.workspace == "[prod]") ? true : false
  }

  boot_disk {
    initialize_params {
      image_id = "fd8anitv6eua45627i0e"
      size     = 50
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat       = true # no bastion
  }

  metadata = {
    user-data = file("./meta.txt")
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

#-----------------------------------------------
#  master node 2

resource "yandex_compute_instance" "master-node-2" {
  name        = "master-node-2"
  platform_id = "standard-v1"
  zone        = yandex_vpc_subnet.subnet-b.zone

  resources {
    cores = 4
    #  core_fraction = 20 # Guaranteed share of vCPU
    memory = 4
  }

  # Interrupting machine ## ?????????????????????? ????????????
  scheduling_policy {
    preemptible = (terraform.workspace == "[prod]") ? true : false
  }

  boot_disk {
    initialize_params {
      image_id = "fd8anitv6eua45627i0e"
      size     = 50
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-b.id
    nat       = true # no bastion
  }

  metadata = {
    user-data = file("./meta.txt")
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

#-----------------------------------------------
#  master node 3

resource "yandex_compute_instance" "master-node-3" {
  name        = "master-node-3"
  platform_id = "standard-v1"
  zone        = yandex_vpc_subnet.subnet-c.zone

  resources {
    cores = 4
    #  core_fraction = 20 # Guaranteed share of vCPU
    memory = 4
  }

  # Interrupting machine ## ?????????????????????? ????????????
  scheduling_policy {
    preemptible = (terraform.workspace == "[prod]") ? true : false
  }

  boot_disk {
    initialize_params {
      image_id = "fd8anitv6eua45627i0e"
      size     = 50
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-c.id
    nat       = true # no bastion
  }

  metadata = {
    user-data = file("./meta.txt")
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

#-----------------------------------------------
#  worker node 1

resource "yandex_compute_instance" "worker-node-1" {
  name        = "worker-node-1"
  platform_id = "standard-v1"
  zone        = yandex_vpc_subnet.subnet-a.zone

  resources {
    cores = 4
    #  core_fraction = 20 # Guaranteed share of vCPU
    memory = 4

  }

  # Interrupting machine ## ?????????????????????? ????????????
  scheduling_policy {
    preemptible = (terraform.workspace == "prod") ? true : false
  }

  boot_disk {
    initialize_params {
      image_id = "fd8anitv6eua45627i0e"
      size     = 50
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-a.id
    nat       = true # no bastion
    #  nat       = false ## bastion
  }

  metadata = {
    user-data = file("./meta.txt")
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

#-----------------------------------------------
#  worker node 2

resource "yandex_compute_instance" "worker-node-2" {
  name        = "worker-node-2"
  platform_id = "standard-v1"
  zone        = yandex_vpc_subnet.subnet-b.zone

  resources {
    cores = 4
    #    core_fraction = 20 # Guaranteed share of vCPU
    memory = 4
  }

  # Interrupting machine ## ?????????????????????? ????????????
  scheduling_policy {
    preemptible = (terraform.workspace == "prod") ? true : false
  }

  boot_disk {
    initialize_params {
      image_id = "fd8anitv6eua45627i0e"
      size     = 50
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-b.id
    nat       = true # no bastion
    #  nat       = false ## bastion
  }

  metadata = {
    user-data = file("./meta.txt")
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

