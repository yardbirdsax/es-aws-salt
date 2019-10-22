variable "cidrBlock" {
  type = "string"
}

variable "sshPubKeyFilePath" {
  type = "string"
}

variable "esNodeCount" {
  type = number
  default = 1
}