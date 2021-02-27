terraform {
  backend "azurerm" {
    resource_group_name  = "RESOURCE_GROUP_NAME"
    storage_account_name = "STORAGE_ACCOUNT_NAME"
    container_name       = "CONTAINER NAME"
    key                  = "FOLDERNAME/terraform.tfstate"
  }
}
