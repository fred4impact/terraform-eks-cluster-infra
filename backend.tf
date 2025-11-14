data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "terraform-state-stage"
    key    = "stagenetwork/terraform.tfstate"
    region = "us-east-1"
  }
}
