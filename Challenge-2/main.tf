provider "google" {
  project = "quiet-axon-378816"
  region  = "us-central1"
}

data "google_compute_instance" "instance" {
  name         = "my-app-instance"
  zone         = "us-central1-a"
}

output "metadata_json" {
  value = jsonencode(data.google_compute_instance.instance.metadata)
}

output "metadata_value" {
  value = data.google_compute_instance.instance.metadata["startup-script"]
}
