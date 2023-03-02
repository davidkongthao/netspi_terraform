variable "aws_default_region" {
    type = string
    default = "us-west-2"
}

variable "access_key" {
    type = string
    default = ""
    sensitive = true
}

variable "secret_key" {
    type = string
    default = ""
    sensitive = true
}

variable "elastic_ip_id" {
    type = string
    default = ""
}

variable "allowed_cidr_blocks" {
    type = list
    default = []
}
