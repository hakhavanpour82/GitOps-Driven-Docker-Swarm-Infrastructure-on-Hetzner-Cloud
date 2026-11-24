variable "hcloud_token" {
  type      = string
  sensitive = true
}
variable "location" {
  type    = string
  default = "fsn1"
}
variable "image" {
  type    = string
  default = "ubuntu-24.04"
}
variable "size_small" {
  type    = string
  default = "cx23"
}
variable "size_medium" {
  type    = string
  default = "cx33"
}
variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/applyops_ed25519.pub"
}
variable "admin_cidrs" {
  type        = list(string)
  description = "Your public IP [\"176.0.6.14/32\"]"
}
