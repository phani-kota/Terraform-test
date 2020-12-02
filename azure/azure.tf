provider "azurerm" {
    features{}
}
resource "azurerm_resource_group" "main" {
    name     = "azure-rg"
    location = "Canada Central"
}

resource "azurerm_virtual_network" "main" {
    name                = "azureVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "Canada Central"
    resource_group_name = azurerm_resource_group.main.name

    tags = {
        environment = "Azure terraform"
    }
}

resource "azurerm_subnet" "main" {
    name                 = "azure-subnet"
    resource_group_name  = azurerm_resource_group.main.name
    virtual_network_name = azurerm_virtual_network.main.name
    address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "main" {
    name                         = "azurePublicIP"
    location                     = "Canada Central"
    resource_group_name          = azurerm_resource_group.main.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Azure terraform"
    }
}

resource "azurerm_network_security_group" "main" {
    name                = "azureNetworkSecurityGroup"
    location            = "Canada Central"
    resource_group_name = azurerm_resource_group.main.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Azure Terraform"
    }
}

resource "azurerm_network_interface" "main" {
    name                      = "azureNIC"
    location                  = "Canada Central"
    resource_group_name       = azurerm_resource_group.main.name

    ip_configuration {
        name                          = "azureNicConfiguration"
        subnet_id                     = azurerm_subnet.main.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.main.id
    }

    tags = {
        environment = "Azure terraform"
    }
}

resource "azurerm_network_interface_security_group_association" "nicassociation" {
    network_interface_id      = azurerm_network_interface.main.id
    network_security_group_id = azurerm_network_security_group.main.id
}

resource "random_id" "randomId" {
    keepers = {
        resource_group = azurerm_resource_group.main.name
    }

    byte_length = 8
}

resource "azurerm_storage_account" "main" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.main.name
    location                    = "Canada Central"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Azure terraform"
    }
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = tls_private_key.ssh.private_key_pem }

resource "azurerm_linux_virtual_machine" "vm" {
    name                  = "azureVM"
    location              = "Canada Central"
    resource_group_name   = azurerm_resource_group.main.name
    network_interface_ids = [azurerm_network_interface.main.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "azureOSDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "azurevm"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.main.primary_blob_endpoint
    }

    tags = {
        environment = "Azure terraform"
    }
}

resource "azurerm_kubernetes_cluster" "kubernetes" {
  name                = "azure-k8s"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "azure-k8s"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  addon_profile {
    aci_connector_linux {
      enabled = false
    }

    azure_policy {
      enabled = false
    }

    http_application_routing {
      enabled = false
    }

    kube_dashboard {
      enabled = true
    }

    oms_agent {
      enabled = false
    }
  }
}

resource "azurerm_sql_server" "db" {
  name                         = "azure-sqlsvr"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "phani"
  administrator_login_password = "5-v3xy-sv56-pa355fwmd"
}

resource "azurerm_sql_database" "sqldb" {
  name                             = "sql-db"
  resource_group_name              = azurerm_resource_group.main.name
  location                         = azurerm_resource_group.main.location
  server_name                      = azurerm_sql_server.db.name
  edition                          = "Basic"
  collation                        = "SQL_Latin1_General_CP1_CI_AS"
  create_mode                      = "Default"
  requested_service_objective_name = "Basic"
}

resource "azurerm_sql_firewall_rule" "main" {
  name                = "allow-azure-services"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_sql_server.db.name
  start_ip_address    = "10.0.1.1"
  end_ip_address      = "10.0.1.254"
}
