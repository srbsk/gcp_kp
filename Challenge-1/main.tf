provider "google" {
  project = "quiet-axon-378816"
}

provider "google-beta" {
  project = "quiet-axon-378816"
  region  = "us-central1"
}

resource "google_compute_network" "vpc_network" {
  name                    = "my-vpc-network"
  auto_create_subnetworks = false
}

# New subnet for the web tier
resource "google_compute_subnetwork" "web_subnet" {
  name          = "web-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.self_link
}

# New subnet for the app tier
resource "google_compute_subnetwork" "app_subnet" {
  name          = "app-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.self_link
}

# New subnet for the db
resource "google_compute_subnetwork" "db_subnet" {
  name          = "db-subnet"
  ip_cidr_range = "10.0.3.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.self_link
}

# New compute instance for the web tier
  resource "google_compute_instance" "web_instance" {
    name         = "my-web-instance"
    machine_type = "f1-micro"
    zone         = "us-central1-a"
    tags         = ["web-server"]

    boot_disk {
      initialize_params {
        image = "debian-cloud/debian-10"
      }
    }

    network_interface {
      network = "my-vpc-network"
      subnetwork = google_compute_subnetwork.web_subnet.self_link
      access_config {}
    }

    metadata_startup_script = "apt-get update; apt-get install -y apache2;" 

  }

# New compute instance for the app tier
resource "google_compute_instance" "app_instance" {
  name         = "my-app-instance"
  machine_type = "f1-micro"
  zone         = "us-central1-a"
  tags         = ["app-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.app_subnet.self_link
    access_config {}
  }

  metadata_startup_script = "apt-get update; apt-get install -y nginx; service nginx start;" 
}

#create SQL instance
resource "google_sql_database_instance" "mysql-from-tf" {
  name = "mysql-from-tf"
  deletion_protection = false
  region = "us-central1"
  database_version = "MYSQL_5_7"
  
  settings {
    tier = "db-f1-micro"
  }

}

# fetch the SQL user password from Secret Manager
data "google_secret_manager_secret_version" "db-credentials" {
  provider = google-beta
  secret   = "db-credentials"
  version  = "latest"
}

# Parse JSON string to extract username and password
locals {
  db_credentials = jsondecode(data.google_secret_manager_secret_version.db-credentials.secret_data)
  db_username    = local.db_credentials.username
  db_password    = local.db_credentials.password
}

# Create SQL user
resource "google_sql_user" "myuser" {
  name     = local.db_username
  password = local.db_password
  instance = google_sql_database_instance.mysql-from-tf.name
}

#create firewall rule
resource "google_compute_firewall" "web_firewall" {
  name    = "allow-http-traffic"
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  source_tags = ["web-server","app-server"]
}