# Creating the Resource Group first

resource "azurerm_resource_group" "rg_devops_pool" {
  name     = "rg-devops-pool"
  location = "uksouth"
}

# Create the Virtual Network for the VM

resource "azurerm_virtual_network" "vnet_devops_pool" {
  name                = "vnet-devops-pool"
  location            = azurerm_resource_group.rg_devops_pool.location
  resource_group_name = azurerm_resource_group.rg_devops_pool.name
  # Here I want a address spaces of 255 addresses so used a .254 mask
  address_space = ["10.0.0.0/23"]
}

# Create a Subnet within the Virtual Network

resource "azurerm_subnet" "subnet_devops_pool" {
  name                 = "subnet-devops-pool"
  resource_group_name  = azurerm_resource_group.rg_devops_pool.name
  virtual_network_name = azurerm_virtual_network.vnet_devops_pool.name
  # I am now splitting my address space into a .255 mask
  address_prefixes = ["10.0.0.0/24"]
}

# Create a Network Security Group

resource "azurerm_network_security_group" "nsg_devops_pool" {
  name                = "nsg-devops-pool"
  location            = azurerm_resource_group.rg_devops_pool.location
  resource_group_name = azurerm_resource_group.rg_devops_pool.name
}

# Subnet + NSG Association

resource "azurerm_subnet_network_security_group_association" "nsg_subnet_assoc_devops_pool" {
  subnet_id                 = azurerm_subnet.subnet_devops_pool.id
  network_security_group_id = azurerm_network_security_group.nsg_devops_pool.id
}

# Create the NIC

resource "azurerm_network_interface" "nic_devops_agent" {
  name                = "nic-devops-agent-vm"
  location            = azurerm_resource_group.rg_devops_pool.location
  resource_group_name = azurerm_resource_group.rg_devops_pool.name

  ip_configuration {
    name                          = "ip-devops-agent-vm"
    subnet_id                     = azurerm_subnet.subnet_devops_pool.id
    private_ip_address_allocation = "Dynamic"
  }
}

# NIC + NSG Association

resource "azurerm_network_interface_security_group_association" "nsg_nic_assoc_devops_agent" {
  network_interface_id      = azurerm_network_interface.nic_devops_agent.id
  network_security_group_id = azurerm_network_security_group.nsg_devops_pool.id
}

# Create Linux Virtual Machine

resource "azurerm_virtual_machine" "vm_devops_agent" {
  name                  = "vm-devops-agent-01"
  location              = azurerm_resource_group.rg_devops_pool.location
  resource_group_name   = azurerm_resource_group.rg_devops_pool.name
  network_interface_ids = [azurerm_network_interface.nic_devops_agent.id]
  vm_size               = "Standard_B1ms"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "dsk-devops-agent-01"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name = "vm-devops-agent-01"
    # Configure the user credential in a manner that is secure. This is an example so will be in clear text.
    admin_username = "USERNAME"
    admin_password = "PASSWORD"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  delete_os_disk_on_termination = true
}

# Here an extension will be created using Azure Virtual Machine Extension

resource "azurerm_virtual_machine_extension" "devops_agent" {
  name                 = "ext-azuredevops-agent"
  virtual_machine_id   = azurerm_virtual_machine.vm_devops_agent.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  # We are specifying the SAS URI. Replace SAS TOKEN with the SAS Token URI

  settings = <<SETTINGS
    {
        "fileUris": ["SAS TOKEN"],
        "commandToExecute": "sh extension.sh"
    }
SETTINGS

  # The depends on is so that the extension will deploy after the VM is built.

  depends_on = [
    azurerm_virtual_machine.vm_devops_agent
  ]
}
