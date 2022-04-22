terraform {
  required_providers {
    vcd = {
      source = "vmware/vcd"
    }
  }
  required_version = ">= 0.13"
}

provider "vcd" {
    auth_type = "integrated"
    max_retry_timeout = 10
    user = var.connect["user"]
    password = var.connect["password"]
    org = var.connect["organization"]
    url = var.connect["url_connect"]
}

#=====Создание маршрутизируемой сети========
resource "vcd_network_routed" "net" {
  org = var.connect["organization"]
  vdc = var.connect["data_center"]

  name         = var.routed_web["name"]
  edge_gateway = var.routed_web["edge"]
  gateway      = var.routed_web["gateway"]

  netmask      = var.routed_web["netmask"]
  dns1         = var.routed_web["dns_1"]
  dns2         = var.routed_web["dns_2"]

  dhcp_pool {
    start_address = var.routed_web["dhcp_start"]
    end_address   = var.routed_web["dhcp_end"]
  }

  static_ip_pool {
    start_address = var.routed_web["static_start"]
    end_address   = var.routed_web["static_end"]
  }
}

#=====Создание NAT-правил========
#SNAT-правила для исходящего трафика
resource "vcd_nsxv_snat" "web" {
  org = var.connect["organization"]
  vdc = var.connect["data_center"]

  edge_gateway = var.edge["name"]
  network_type = var.main_web["type"]
  network_name = var.main_web["name"]

  original_address   = var.routed_web["cidr"]
  translated_address = var.edge["ip"]

  depends_on = [vcd_network_routed.net] 
}

#DNAT-правила для входящего трафика
resource "vcd_nsxv_dnat" "Nginx" {
  org = var.connect["organization"]
  vdc = var.connect["data_center"]

  edge_gateway = var.edge["name"]
  network_type = var.main_web["type"]
  network_name = var.main_web["name"]

  original_address   = var.edge["ip"]
  original_port = var.Nginx["ssh_port"]
  translated_address = var.Nginx["ip"]
  translated_port = "22"
  protocol = "tcp"
}

resource "vcd_nsxv_dnat" "Django" {
  org = var.connect["organization"]
  vdc = var.connect["data_center"]

  edge_gateway = var.edge["name"]
  network_type = var.main_web["type"]
  network_name = var.main_web["name"]

  original_address   = var.edge["ip"]
  original_port = var.Django["ssh_port"]
  translated_address = var.Django["ip"]
  translated_port = "22"
  protocol = "tcp"
}

resource "vcd_nsxv_dnat" "PostgreSQL" {
  org = var.connect["organization"]
  vdc = var.connect["data_center"]

  edge_gateway = var.edge["name"]
  network_type = var.main_web["type"]
  network_name = var.main_web["name"]

  original_address   = var.edge["ip"]
  original_port = var.PostgreSQL["ssh_port"]
  translated_address = var.PostgreSQL["ip"]
  translated_port = "22"
  protocol = "tcp"
}

#=============Создание VM==================

#Nginx
resource "vcd_vm" "Nginx" {
  org = var.connect["organization"]
  vdc = var.connect["data_center"]

  name = var.Nginx["name"]
  computer_name = var.Nginx["name"]
  power_on = true

  cpus = var.vm_main_template["cpus"]
  memory = var.vm_main_template["memory"]

  catalog_name  = var.vm_main_template["catalog_name"]
  template_name = var.vm_main_template["template_name"]

  network {
    name               = var.routed_web["name"]
    type               = var.routed_web["type"]
    ip_allocation_mode = var.vm_main_template["ip_mode"]
    ip = var.Nginx["ip"]
  }

  customization {
    force                      = true
    allow_local_admin_password = true
    auto_generate_password     = false
    admin_password             = var.guest_properties["admin_passwd"]
  }

  depends_on = [vcd_nsxv_snat.web] 
}

#Django
resource "vcd_vm" "Django" {
  org = var.connect["organization"]
  vdc = var.connect["data_center"]

  name = var.Django["name"]
  computer_name = var.Django["name"]
  power_on = true

  cpus = var.vm_main_template["cpus"]
  memory = var.vm_main_template["memory"]

  catalog_name  = var.vm_main_template["catalog_name"]
  template_name = var.vm_main_template["template_name"]

  network {
    name               = var.routed_web["name"]
    type               = var.routed_web["type"]
    ip_allocation_mode = var.vm_main_template["ip_mode"]
    ip = var.Django["ip"]
  }

  customization {
    force                      = true
    allow_local_admin_password = true
    auto_generate_password     = false
    admin_password             = var.guest_properties["admin_passwd"]
  }

  depends_on = [vcd_nsxv_snat.web] 
}

#PostgreSQL
resource "vcd_vm" "PostgreSQL" {
  org = var.connect["organization"]
  vdc = var.connect["data_center"]

  name = var.PostgreSQL["name"]
  computer_name = var.PostgreSQL["name"]
  power_on = true

  cpus = var.vm_main_template["cpus"]
  memory = var.vm_main_template["memory"]

  catalog_name  = var.vm_main_template["catalog_name"]
  template_name = var.vm_main_template["template_name"]

  network {
    name               = var.routed_web["name"]
    type               = var.routed_web["type"]
    ip_allocation_mode = var.vm_main_template["ip_mode"]
    ip = var.PostgreSQL["ip"]
  }

  customization {
    force                      = true
    allow_local_admin_password = true
    auto_generate_password     = false
    admin_password             = var.guest_properties["admin_passwd"]
  }

  depends_on = [vcd_nsxv_snat.web] 
}