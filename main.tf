terraform {
  required_providers {
    vcd = {
      source = "vmware/vcd"
    }
  }
  required_version = ">= 0.13"
}

provider "vcd" {
    auth_type = "integrated" #Тип авторизации
    max_retry_timeout = 10 #Максимальное число попыток соединения
    user = var.connect["user"] #Имя пользователя
    password = var.connect["password"] #Пароль пользователя
    org = var.connect["organization"] #Название организации
    url = var.connect["url_connect"] #Адрес, на который будут посылаться API-запросы
}

#=====Создание маршрутизируемой сети========
resource "vcd_network_routed" "net" {
  org = var.connect["organization"] #Название организации
  vdc = var.connect["data_center"] #Название ЦОДа

  name         = var.routed_web["name"] #Название сети
  edge_gateway = var.routed_web["edge"] #Название виртуального роутера
  gateway      = var.routed_web["gateway"] #Шлюз сети

  netmask      = var.routed_web["netmask"] #Маска сети
  dns1         = var.routed_web["dns_1"] #1 DNS-сервер
  dns2         = var.routed_web["dns_2"] #2 DNS-сервер

  dhcp_pool { #Пул dhcp-адресов
    start_address = var.routed_web["dhcp_start"] #первый адрес пула
    end_address   = var.routed_web["dhcp_end"] #последний адрес пула
  }

  static_ip_pool { #Пул статик IP-адресов
    start_address = var.routed_web["static_start"] #первый адрес пула
    end_address   = var.routed_web["static_end"] #последний адрес пула
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
  org = var.connect["organization"] #Имя организации
  vdc = var.connect["data_center"] #Имя ЦОДа

  name = var.Nginx["name"] #Название VM
  computer_name = var.Nginx["name"] #Имя хоста
  power_on = true #Машина будет включена после создания

  cpus = var.vm_main_template["cpus"] #Количество процессорных ядер
  memory = var.vm_main_template["memory"] #Количество оперативной памяти

  catalog_name  = var.vm_main_template["catalog_name"] #Каталог, с шаблоном VM
  template_name = var.vm_main_template["template_name"] #Шаблон VM

  network { #Настройки сети, к которой подключается VM
    name               = var.routed_web["name"] #Имя сети
    type               = var.routed_web["type"] #Тип сети
    ip_allocation_mode = var.vm_main_template["ip_mode"] #Тип выдачи IP -- ручной из Static pool
    ip = var.Nginx["ip"] #IP VM
  }

  customization { #Кастомизация ОС
    force                      = true #Применить параметры кастомизации
    allow_local_admin_password = true #Наличие локального пароля админа
    auto_generate_password     = false #Отмена автогенерации пароля
    admin_password             = var.guest_properties["admin_passwd"] #Пароль администратора
  }

  depends_on = [vcd_nsxv_snat.web] # Ожидания выполнения блока с кодом
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