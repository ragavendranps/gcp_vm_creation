# Configure the Google Cloud provider
provider "google" {
  project = ""
  region  = "us-west1"
  zone    = "us-west1-a"
}

# Create a VPC network
resource "google_compute_network" "vpc_network" {
  name                    = "my-vpc-network"
  auto_create_subnetworks = false
}

# Subnetwork configuration
resource "google_compute_subnetwork" "web_subnet" {
  name          = "web-subnet"
  network       = google_compute_network.vpc_network.self_link
  ip_cidr_range = "10.0.1.0/24"
}

resource "google_compute_subnetwork" "app_subnet" {
  name          = "app-subnet"
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
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Create a load balancer
resource "google_compute_backend_service" "web_app_backend_service" {
  name                  = "web-app-backend-service"
  protocol              = "HTTP"
  health_checks         = [google_compute_http_health_check.http_check.self_link]
  timeout_sec           = 10
  connection_draining_timeout_sec = 300

  backend {
    group = google_compute_instance_group.web_instance_group.self_link
  }
  backend {
    group = google_compute_instance_group.app_instance_group.self_link
  }
  load_balancing_scheme = "EXTERNAL"
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
  instances        = [google_compute_instance.web_instance.self_link, google_compute_instance.app_instance.self_link]
  health_checks    = [google_compute_http_health_check.http_check.self_link]
  session_affinity = "CLIENT_IP"
}

# Create a Windows web server
resource "google_compute_instance" "web_server" {
  name         = "web-server"
  machine_type = "n1-highmem-4"
  zone         = "us-west1-a"
  tags         = "web"
  boot_disk {
    initialize_params {
      image = "windows-server-2019-dc-v20230315 "
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.web_subnet.self_link
    access_config {
      nat_ip = google_compute_address.web_nat_ip.address
    }
  }
  metadata = {
    windows-startup-script-cmd = "net user /add BAASSAdmin Password_123 & net localgroup administrators BAASSAdmin /add"
    windows-startup-script-cmd = "net user /add BAASSUser Password_123 & net localgroup administrators BAASSUser /add"
    windows-startup-script-cmd = "net user /add Sagert Password_123 & net localgroup administrators Sagert /add"
  }
}

# Create a Windows app server
resource "google_compute_instance" "app_server" {
  name         = "app-server"
  machine_type = "n1-highmem-2"
  zone         = "us-west1-a"
  tags         = "app"
  boot_disk {
    initialize_params {
      image = "windows-server-2019-dc-v20230315 "
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.app_subnet.self_link
    access_config {
      nat_ip = google_compute_address.web_nat_ip.address
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
#   region           = "us-west1"
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
resource "google_compute_instance" "db" {
  name         = "db-server"
  machine_type = "db-highmem-4"
  zone         = "us-west1-c"
  boot_disk {
    initialize_params {
      image = "sql-2019-standard-windows-2019-dc-v20230315"
    }
  }
  network_interface {
    network = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.db_subnet.self_link
    access_config {
      nat_ip = google_compute_address.web_nat_ip.address
    }
  }
}
