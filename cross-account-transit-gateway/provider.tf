provider "aws" {
  assume_role {
    external_id = "terraform"
    session_name = "terraform"
    role_arn = "arn:aws:iam::${local.account_id}:role/terraform"
  }
  region = "eu-west-1"
}

provider "aws" {
  alias = "shared"
  assume_role {
    external_id = "terraform"
    session_name = "terraform"
    role_arn = "arn:aws:iam::${local.shared_account_id}:role/terraform"
  }
  region = "eu-west-1"
}

provider "aws" {
  alias = "dev"
  assume_role {
    external_id = "terraform"
    session_name = "terraform"
    role_arn = "arn:aws:iam::${local.dev_account_id}:role/terraform"
  }
  region = "eu-west-1"
}

provider "aws" {
  alias = "test"
  assume_role {
    external_id = "terraform"
    session_name = "terraform"
    role_arn = "arn:aws:iam::${local.test_account_id}:role/terraform"
  }
  region = "eu-west-1"
}

provider "aws" {
  alias = "prod"
  assume_role {
    external_id = "terraform"
    session_name = "terraform"
    role_arn = "arn:aws:iam::${local.prod_account_id}:role/terraform"
  }
  region = "eu-west-1"
}