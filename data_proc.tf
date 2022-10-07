variable "project_id" {
  description = "project id"
}

variable "region" {
  description = "region"
}
resource "google_storage_bucket" "spark-nv" {
  project       = var.project_id
  name          = "rapids-sparknv"
  location      = var.region
  force_destroy = true

  lifecycle_rule {
    condition {
      age = 3
    }
    action {
      type = "Delete"
    }
  }
}
resource "google_dataproc_cluster" "accelerated_cluster" {
  project  = var.project_id
  provider = google-beta
  name     = "rapidsai-spark-nvgpu"
  region   = var.region
  cluster_config {
    endpoint_config {
      enable_http_port_access = "true"
    }
    gce_cluster_config {
      zone = "${var.region}-b"
      metadata = {
        rapids-runtime      = "SPARK"
        gpu-driver-provider = "NVIDIA"
      }
    }
    staging_bucket = google_storage_bucket.spark-nv.name
    master_config {
      num_instances = 1
      machine_type  = "n1-standard-16"
    }
    worker_config {
      accelerators {
        accelerator_type  = "nvidia-tesla-t4"
        accelerator_count = "1"
      }
      num_instances = 1
      machine_type  = "n1-standard-8"
      disk_config {
        num_local_ssds = 1
      }
    }
    initialization_action {
      script      = "gs://goog-dataproc-initialization-actions-${var.region}/gpu/install_gpu_driver.sh"
      timeout_sec = 3600
    }
    initialization_action {
      script      = "gs://goog-dataproc-initialization-actions-${var.region}/rapids/rapids.sh"
      timeout_sec = 3600
    }
    initialization_action {
      script      = "gs://goog-dataproc-initialization-actions-${var.region}/kafka/kafka.sh"
      timeout_sec = 3600
    }
    software_config {
      image_version       = "2.0-ubuntu18"
      optional_components = ["JUPYTER", "ZEPPELIN", "DOCKER", "PRESTO", "FLINK", "ZOOKEEPER"]
    }

  }

}
