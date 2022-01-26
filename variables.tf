variable "resource_group_name" {
  description = "The main resource group name"
  type        = string
}

variable "resource_group_location" {
  description = "The main resource group location"
  type        = string
}

variable "vm_names" {
  description = "The names of the VMs to be created"
  type = list(string)
  default = ["vm1", "vm2", "vm3"]
}

