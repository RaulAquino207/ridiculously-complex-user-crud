variable "region" {
  type    = string
  default = "sa-east-1"
}

variable "aws_profile" {
  type    = string
  default = "raulaquino207"
}

variable "name" {
  type    = string
  default = "rc-user-crud"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "ssh_public_key_path" {
  type = string
}

variable "registry" {
  type = string
}

variable "image_name" {
  type = string
}

variable "use_ecr" {
  type    = bool
  default = false
}

variable "registry_username" {
  type    = string
  default = ""
}

variable "registry_password" {
  type    = string
  default = ""
}
