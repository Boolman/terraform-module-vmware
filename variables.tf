variable "instances" {
  type        = map
  description = "hostname: { flavor: x, image: y }"
  default     = {}
}
variable "remote_connection" {
  type    = map
  default = {}
}
variable "extra_config" {
  type    = map(string)
  default = {}
}
