provider "google" {
  project = "appt-rescheduler-develop"
  region  = "us-central1"
  zone    = "us-central1-a"
}

resource "google_compute_instance" "default" {
  name         = "felipe-test"
  machine_type = "n1-standard-1"
  zone         = "us-central1-a"

  tags = ["felipe", "test", "created-by-teraform"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  // Local SSD disk
  scratch_disk {
    interface = "SCSI"
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }
}

resource "google_storage_bucket" "bucket" {
  name = "test-bucket-felipe-terraform"
  force_destroy = true
}

data "archive_file" "zip_function" {
  type        = "zip"
  output_path = "${path.module}/files/index.zip"
  source {
    content  = templatefile("${path.module}/files/index.tpl",
      {
        redis-ip = google_redis_instance.cache.host
      })
    filename = "index.js"
  }
  source {
    content  = "${file("${path.module}/files/package.json")}"
    filename = "package.json"
  }
}

resource "google_storage_bucket_object" "archive" {
  name   = "index.zip"
  bucket = google_storage_bucket.bucket.name
  content_type = "application/zip"
  source = "${path.module}/files/index.zip"
  depends_on = ["data.archive_file.zip_function"]
}

resource "google_cloudfunctions_function" "function" {
  name        = "function-test"
  description = "My function"
  runtime     = "nodejs12"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  entry_point           = "helloWorld"

  vpc_connector = "default-vpc-connector"

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = "${google_pubsub_topic.topic-example.name}"
    failure_policy {
      retry = true
    }
  }
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.function.project
  region         = google_cloudfunctions_function.function.region
  cloud_function = google_cloudfunctions_function.function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

resource "google_pubsub_topic" "topic-example" {
  name = "felipe-test-topic"
}

resource "google_redis_instance" "cache" {
  name           = "memory-cache"
  memory_size_gb = 1
}

