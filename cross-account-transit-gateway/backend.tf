terraform {
  required_version = "<=1.3.9"
  /* backend "s3" {
    bucket = "<IAMACCOUNT>-terraform-cross-account-transit-gateway"
    key = "terraform.tfstate"
    region = "eu-west-1"
    external_id = "terraform"
    session_name = "terraform"
    role_arn = "arn:aws:iam::<IAMACCOUNT>:role/terraform" 
  } */
}