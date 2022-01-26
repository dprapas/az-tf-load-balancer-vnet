terraform {

  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "dp-tf-rg"
    storage_account_name = "dptfstacc"
    container_name       = "tfstatedevops"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "dp_vnet1_rg" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_virtual_network" "dp_vnet1" {
  name                = "dp-vnet1"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.dp_vnet1_rg.location
  resource_group_name = azurerm_resource_group.dp_vnet1_rg.name
}

resource "azurerm_subnet" "dp_vnet1_subnet1" {
  name                 = "dp-vnet1-subnet1"
  resource_group_name  = azurerm_resource_group.dp_vnet1_rg.name
  virtual_network_name = azurerm_virtual_network.dp_vnet1.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_subnet" "dp_vnet1_subnet2" {
  name                 = "dp-vnet1-subnet2"
  resource_group_name  = azurerm_resource_group.dp_vnet1_rg.name
  virtual_network_name = azurerm_virtual_network.dp_vnet1.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "dp_azure_bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.dp_vnet1_rg.name
  virtual_network_name = azurerm_virtual_network.dp_vnet1.name
  address_prefixes     = ["10.1.2.0/24"]
}

resource "azurerm_public_ip" "dp_vnet1_bastion_ip" {
  name                = "dp-vnet1-bastion-ip"
  location            = azurerm_resource_group.dp_vnet1_rg.location
  resource_group_name = azurerm_resource_group.dp_vnet1_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "dp_nat_gateway_ip" {
  name                = "dp-nat-gateway-ip"
  location            = azurerm_resource_group.dp_vnet1_rg.location
  resource_group_name = azurerm_resource_group.dp_vnet1_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "dp_vnet1_public_ip" {
  name                = "dp-vnet1-public-ip"
  location            = azurerm_resource_group.dp_vnet1_rg.location
  resource_group_name = azurerm_resource_group.dp_vnet1_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "dp_vnet1_bastion" {
  name                = "dp-vnet1-bastion"
  location            = azurerm_resource_group.dp_vnet1_rg.location
  resource_group_name = azurerm_resource_group.dp_vnet1_rg.name

  ip_configuration {
    name                 = "ipconfig1"
    subnet_id            = azurerm_subnet.dp_azure_bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.dp_vnet1_bastion_ip.id
  }
}

## Virtual Machines ##
resource "azurerm_network_interface" "dp_vnet1_vm_nic" {
  for_each            = toset(var.vm_names)
  name                = "dp-vnet1-${each.value}-nic"
  location            = azurerm_resource_group.dp_vnet1_rg.location
  resource_group_name = azurerm_resource_group.dp_vnet1_rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.dp_vnet1_subnet1.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_security_group" "dp_vnet1_vm1_nic_nsg" {
  for_each            = toset(var.vm_names)
  name                = "dp-vnet1-${each.value}-nic-nsg"
  location            = azurerm_resource_group.dp_vnet1_rg.location
  resource_group_name = azurerm_resource_group.dp_vnet1_rg.name
  security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "AllowAllHTTP"
    priority                   = 100
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 80
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nic_to_nsg" {
  for_each                  = toset(var.vm_names)
  network_interface_id      = azurerm_network_interface.dp_vnet1_vm_nic[each.key].id
  network_security_group_id = azurerm_network_security_group.dp_vnet1_vm1_nic_nsg[each.key].id
}

resource "azurerm_virtual_machine" "dp_vnet1_vm" {
  for_each              = toset(var.vm_names)
  name                  = "dp-vnet1-${each.value}"
  location              = azurerm_resource_group.dp_vnet1_rg.location
  resource_group_name   = azurerm_resource_group.dp_vnet1_rg.name
  network_interface_ids = [azurerm_network_interface.dp_vnet1_vm_nic[each.key].id]
  vm_size               = "Standard_DS1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  storage_os_disk {
    name              = "dp-vnet1-${each.value}_os_disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "dp-vnet1-${each.value}"
    admin_username = "dp-${each.value}-user"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}

## Load Balancer ##
resource "azurerm_lb" "dp_vnet1_lb" {
  name                = "dp-vnet1-lb"
  location            = azurerm_resource_group.dp_vnet1_rg.location
  resource_group_name = azurerm_resource_group.dp_vnet1_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "dp-frontend-ip"
    public_ip_address_id = azurerm_public_ip.dp_vnet1_public_ip.id
  }
}

resource "azurerm_lb_backend_address_pool" "dp_vnet1_lb_backend_pool" {
  name            = "dp-vnet1-lb-backend-pool"
  loadbalancer_id = azurerm_lb.dp_vnet1_lb.id
}

resource "azurerm_lb_rule" "dp_load_balance_http_rule" {
  resource_group_name            = azurerm_resource_group.dp_vnet1_rg.name
  loadbalancer_id                = azurerm_lb.dp_vnet1_lb.id
  name                           = "dp-load-balance-http-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "dp-frontend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.dp_vnet1_lb_backend_pool.id]
  enable_tcp_reset               = true
}

resource "azurerm_lb_probe" "dp_load_balance_http_health" {
  resource_group_name = azurerm_resource_group.dp_vnet1_rg.name
  loadbalancer_id     = azurerm_lb.dp_vnet1_lb.id
  name                = "dp-load-balance-http-health"
  port                = 80
  protocol            = "Http"
  request_path        = "/"
}

## Associate VM's nics with backend pool ##
resource "azurerm_network_interface_backend_address_pool_association" "nic1_to_backend_pool" {
  for_each                = toset(var.vm_names)
  network_interface_id    = azurerm_network_interface.dp_vnet1_vm_nic[each.key].id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.dp_vnet1_lb_backend_pool.id
}

