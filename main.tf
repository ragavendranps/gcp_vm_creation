# Configure the Google Cloud provider
provider "google" {
  project = "molli-erp"
  region  = "northamerica-northeast2"
  zone    = "northamerica-northeast2-a"
}

# Create a VPC network
resource "google_compute_network" "vpc_network" {
  name                    = "molli-erp-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

# Subnetwork configuration
resource "google_compute_subnetwork" "web_app_subnet" {
  name          = "web-app-subnet"
  network       = google_compute_network.vpc_network.self_link
  ip_cidr_range = "10.0.1.0/24"
}

resource "google_compute_subnetwork" "sei_search_subnet" {
  name          = "sei-search-subnet"
  network       = google_compute_network.vpc_network.self_link
  ip_cidr_range = "10.0.2.0/24"
}

resource "google_compute_subnetwork" "db_subnet" {
  name          = "db-subnet"
  network       = google_compute_network.vpc_network.self_link
  ip_cidr_range = "10.0.3.0/24"
}

# Create a firewall rule to allow HTTP traffic
resource "google_compute_firewall" "http_firewall" {
  name    = "allow-http"
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["22", "3389", "1433", "1434", "443"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
}

# Create a load balancer
resource "google_compute_backend_service" "web_app_backend_service" {
  name                  = "web-app-backend-service"
  protocol              = "TCP"
  health_checks         = [google_compute_http_health_check.http_check.self_link]
  timeout_sec           = 10
  connection_draining_timeout_sec = 300

  backend {
    group = google_compute_instance_group.web_private_group.self_link
  }
  load_balancing_scheme = "EXTERNAL"
}

# creates a group of dissimilar virtual machine instances
resource "google_compute_instance_group" "web_private_group" {
  name        = "web-app-vm-group"
  description = "Web servers instance group"
  zone        = "northamerica-northeast2-a"
  
  instances   = [ 
    google_compute_instance.web_app_server.self_link
    ]

  named_port {
    name = "http"
    port = "80"
  }
}
# Create a health check
resource "google_compute_http_health_check" "http_check" {
  name               = "http-check"
  check_interval_sec = 5
  timeout_sec        = 5
  request_path       = "/"
}

# Create a target pool for the load balancer
resource "google_compute_target_pool" "web_app_target_pool" {
  name             = "web-app-target-pool"
  instances        = [google_compute_instance.web_app_server.self_link]
  health_checks    = [google_compute_http_health_check.http_check.self_link]
  session_affinity = "CLIENT_IP"
}

# Create a Windows web server
resource "google_compute_disk" "disk1" {
  name  = "web-app-server-disk"
  type  = "pd-standard"
  size  = 375
  zone  = "northamerica-northeast2-a"
  disk_encryption_key {
    kms_key_self_link = local.cmek_self_link
  }
}

resource "google_compute_attached_disk" "disk1-attachment" {
  instance = google_compute_instance.web_app_server.id
  disk     = google_compute_disk.disk1.id
}


resource "google_compute_instance" "web_app_server" {
  name         = "web-app-server"
  machine_type = "n1-highmem-4"
  zone         = "northamerica-northeast2-a"
  tags         = ["web"]
  boot_disk {
    initialize_params {
      image = "windows-2019"
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.web_app_subnet.self_link
    access_config {
    }
  }
  metadata = {
    windows-startup-script-cmd = "net user /add BAASSAdmin Password_123 & net localgroup administrators BAASSAdmin /add"
    windows-startup-script-cmd = "net user /add BAASSUser Password_123 & net localgroup administrators BAASSUser /add"
    windows-startup-script-cmd = "net user /add Sagert Password_123 & net localgroup administrators Sagert /add"
  }
}

# Create a Windows app server

resource "google_compute_disk" "disk2" {
  name  = "sei-search-server-disk"
  type  = "pd-standard"
  size  = 375
  zone  = "northamerica-northeast2-a"
  disk_encryption_key {
    kms_key_self_link = local.cmek_self_link
  }
}

resource "google_compute_attached_disk" "disk2-attachment" {
  instance = google_compute_instance.sei_search_server.id
  disk     = google_compute_disk.disk2.id
}

resource "google_compute_instance" "sei_search_server" {
  name         = "sei-search-server"
  machine_type = "n1-highmem-2"
  zone         = "northamerica-northeast2-a"
  tags         = ["app"]
  boot_disk {
    initialize_params {
      image = "windows-2019"
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.sei_search_subnet.self_link
    access_config {
    }
  }
  metadata = {
    windows-startup-script-cmd = "net user /add BAASSAdmin Password_123 & net localgroup administrators BAASSAdmin /add"
    windows-startup-script-cmd = "net user /add BAASSUser Password_123 & net localgroup administrators BAASSUser /add"
    windows-startup-script-cmd = "net user /add Sagert Password_123 & net localgroup administrators Sagert /add"
  }
}

# Create a MSSQL database
# resource "google_sql_database_instance" "sql_instance" {
#   name             = "my-sql-instance"
#   database_version = "SQL_SERVER_2019_STANDARD"
#   region           = "northamerica-northeast2"
#   tags             = "db"

#   settings {
#     tier = "db-highmem-4"
#   }

#   database {
#     name = "my-database"
#   }

#   user {
#     name     = "my-user"
#     password = "my-password"
#   }
# }

# Create a MSSQL compute

resource "google_compute_disk" "disk3" {
  name  = "db-server-disk"
  type  = "pd-standard"
  size  = 375
  zone  = "northamerica-northeast2-a"
}

resource "google_compute_attached_disk" "disk3-attachment" {
  instance = google_compute_instance.dbserver.id
  disk     = google_compute_disk.disk3.id
}

resource "google_compute_instance" "dbserver" {
  name         = "db-server"
  machine_type = "e2-highmem-4"
  zone         = "northamerica-northeast2-a"
  tags         = ["db"]
  boot_disk {
    initialize_params {
      image = "/marketplace/product/cognosys-public/secured-sql-server-2019-stand-win-ser-2019"
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.db_subnet.self_link
    access_config {
    }
  }
  metadata = {
    windows-startup-script-cmd = "net user /add BAASSAdmin Password_123 & net localgroup administrators BAASSAdmin /add"
    windows-startup-script-cmd = "net user /add BAASSUser Password_123 & net localgroup administrators BAASSUser /add"
    windows-startup-script-cmd = "net user /add Sagert Password_123 & net localgroup administrators Sagert /add"
  }
}
