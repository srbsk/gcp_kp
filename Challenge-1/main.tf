# Set the project ID
provider "google" {
  project = "quiet-axon-378816"
}

provider "google-beta" {
  project = "quiet-axon-378816"
}

resource "google_compute_network" "vpc_network" {
  name                    = "my-vpc-network"
  auto_create_subnetworks = false
}

resource "google_service_networking_connection" "private_connection" {
  provider                 = google-beta
  network                  = google_compute_network.vpc_network.self_link
  reserved_peering_ranges = ["192.168.0.0/16"]
  service                  = "servicenetworking.googleapis.com"
}


resource "google_compute_subnetwork" "private_subnet" {
  name          = "my-private-subnet"
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.vpc_network.self_link

  private_ip_google_access = true
  private_ip_google_access_configs {
    name = "private-google-access"
    private_service_connection = google_service_networking_connection.private_connection.name
  }
}


# Create a new subnet for the web tier
resource "google_compute_subnetwork" "web_subnet" {
  name          = "web-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.self_link
}

# Create a new subnet for the app tier
resource "google_compute_subnetwork" "app_subnet" {
  name          = "app-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.self_link
}

# Create a new subnet for the db
resource "google_compute_subnetwork" "db_subnet" {
  name          = "db-subnet"
  ip_cidr_range = "10.0.3.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.self_link
}

# Create a new compute instance for the web tier
resource "google_compute_instance" "web_instance" {
  name         = "my-web-instance"
  machine_type = "f1-micro"
  zone         = "us-central1-a"

  # Use a pre-built web server image
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  # Add a startup script to install Apache web server
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y apache2
    EOF

  # Configure the instance to use the web subnet
  network_interface {
    subnetwork = google_compute_subnetwork.web_subnet.self_link
    access_config {}
  }
}

# Create a new compute instance for the app tier
resource "google_compute_instance" "app_instance" {
  name         = "my-app-instance"
  machine_type = "f1-micro"
  zone         = "us-central1-a"

  # Use a pre-built app server image
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  # Add a startup script to install the app server software
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    EOF

  # Configure the instance to use the app subnet
  network_interface {
    subnetwork = google_compute_subnetwork.app_subnet.self_link
    access_config {}
  }
}

# Create a PostgreSQL instance
resource "google_sql_database_instance" "my_db_instance" {
  name             = "my-db-instance"
  database_version = "MYSQL_8_0"
  region           = "us-central1"

  settings {
    tier = "db-f1-micro"

    ip_configuration {
      ipv4_enabled        = true
      private_network     = google_compute_network.vpc_network.self_link
      subnetwork          = google_compute_subnetwork.private_subnet.self_link
    }
  }
}


# Create a PostgreSQL user
resource "google_sql_user" "my_db_user" {
  instance = google_sql_database_instance.my_db_instance.name
  name     = "my-db-user"
}

# resource "google_sql_user_instance_grant" "my_db_user_grant" {
#   user      = google_sql_user.my_db_user.name
#   instance  = google_sql_database_instance.my_db_instance.name
#   role      = "roles/cloudsql.editor"
# }

# Create the PostgreSQL database using local-exec provisioner
resource "null_resource" "create_db" {
  provisioner "local-exec" {
    command = "gcloud sql databases create my-db --instance=${google_sql_database_instance.my_db_instance.connection_name} && gcloud sql users create my-user --instance=${google_sql_database_instance.my_db_instance.connection_name} --password=my-password && gcloud sql users set-password my-user --instance=${google_sql_database_instance.my_db_instance.connection_name} --password=my-password"
  }
}

# resource "google_sql_database_instance" "db_instance" {
#   name             = "my-db-instance"
#   region           = "us-central1"
#   database_version = "MYSQL_5_7"

#   settings {
#     tier = "db-f1-micro"

#     ip_configuration {
#       ipv4_enabled    = true
#       private_network = google_compute_network.vpc_network.self_link
#       #subnet          = google_compute_subnetwork.db_subnet.self_link
#     }
#   }
# }

# resource "google_sql_database" "db" {
#   name     = "my-database"
#   instance = google_sql_database_instance.db_instance.name
# }

# resource "google_sql_user" "db_user" {
#   name     = "my-db-user"
#   password = "pass123"
#   instance = google_sql_database_instance.db_instance.name

#   depends_on = [google_sql_database_instance.db_instance]
# }
