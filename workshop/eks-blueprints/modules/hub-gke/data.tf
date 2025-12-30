data "google_container_cluster" "this" {
  name       = module.gke.name
  location   = module.gke.zone
  depends_on = [module.gke]
}

data "google_project" "this" {
}

# fetches new access token on apply, expires in 1h
data "google_client_config" "this" {
}
