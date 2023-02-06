#ServiceAccount 
resource "google_service_account" "vm-sa" {
  account_id   = "default-vm-sa"
  display_name = "sa-private-vm"
}

resource "google_project_iam_member" "cluster-admin" {
  project = "liquid-sylph-375712"
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.vm-sa.email}"
}


#compute instance
resource "google_compute_instance" "private-management-vm" {
  name         = "private-management-vm"
  machine_type = "f1-micro"
  zone         = "europe-west3" #var.region
 
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }
  metadata = {
  enable-oslogin = "TRUE"
  }
  tags = ["management-vm"]
  network_interface {
    subnetwork = google_compute_subnetwork.management_subnet.id
    access_config {
      nat_ip = google_compute_address.nat_ip.address
    }
  }
  service_account {
    email = google_service_account.vm-sa.email
    scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  metadata_startup_script = <<-EOF
    sudo apt-get install  -y apt-transport-https ca-certificates gnupg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    sudo apt-get update && sudo apt-get install google-cloud -y
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    chmod +x kubectl
    mkdir -p ~/.local/bin
    mv ./kubectl ~/.local/bin/kubectl
    kubectl version --client
    sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin
    # sudo USE_GKE_GCLOUD_AUTH_PLUGIN: True
    # gcloud container clusters get-credentials private-cluster --zone asia-east2-a --project iti-makarios
  EOF
}