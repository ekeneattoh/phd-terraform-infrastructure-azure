variable "env_name" {
  type = string
}

variable "project_name" {
  type = string
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "resourcegroup_name" {
  type    = string
  default = "cocuisson-dev-rg"
}

variable "mongo_url" {
  type = string
}

variable "api_base_url" {
  type = string
}

variable "db_name" {
  type = string
}
