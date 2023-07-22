# Random String Generator for bucket name
resource "random_string" "random_string_for_bucket" {
  length = 16
  special = false
  upper = false
}