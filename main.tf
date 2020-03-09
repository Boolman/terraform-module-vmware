terraform {
  backend "consul" {}
}
provider "vsphere" {
  allow_unverified_ssl = true
}


locals {
  flavor = {
    "m1.nano" = {
      memory = 2048
      cpu    = 1
    },
    "m1.small" = {
      memory = 4096,
      cpu    = 4
    },
    "m1.medium" = {
      memory = 8192,
      cpu    = 4
    }
  }
}

resource "vsphere_virtual_machine" "web" {
  for_each         = var.instances
  name             = split(".", each.key)[0]
  resource_pool_id = each.value.cluster.resource_pool_id
  datastore_id     = each.value.ds
  folder           = each.value.folder

  num_cpus = lookup(each.value, "cpu", local.flavor[try(each.value.flavor, "m1.small")].cpu)
  memory   = lookup(each.value, "memory", local.flavor[try(each.value.flavor, "m1.small")].memory)

  guest_id  = each.value.template.guest_id
  scsi_type = each.value.template.scsi_type

  wait_for_guest_net_timeout = lookup(each.value, "customize", true) ? 5 : 0

  dynamic "network_interface" {
    for_each = toset(each.value.network.interfaces)
    content {
      network_id   = network_interface.key.network.id
      adapter_type = each.value.template.network_interface_types[0]
    }
  }

  extra_config = lookup(each.value, "extra_config", var.extra_config)
  // OS Disk
  disk {
    label            = "disk0"
    size             = each.value.template.disks.0.size
    thin_provisioned = each.value.template.disks.0.thin_provisioned
  }
  // Additional disks
  dynamic "disk" {
    for_each = { for k, v in try(each.value.extra_disks, []) : k + 1 => v }
    content {
      label            = format("%s%s", "disk", disk.key)
      size             = disk.value
      thin_provisioned = true
      unit_number      = disk.key
    }
  }

  clone {
    template_uuid = each.value.template.id
    dynamic "customize" {
      for_each = lookup(each.value, "customize", true) ? ["Yes, run customize"] : []
      content {
        dynamic "linux_options" {
          for_each = length(regexall("(.*[Ll]inux.*|^ubuntu.*|^rhel.*)", each.value.template.guest_id)) > 0 ? [each.key] : []
          content {
            host_name = split(".", each.key)[0]
            domain    = join(".", [for x in split(".", each.key) : x if x != split(".", each.key)[0]])
          }
        }
        dynamic "windows_options" {
          for_each = length(regexall("^win.+", each.value.template.guest_id)) > 0 ? [each.key] : []
          content {
            computer_name  = split(".", each.key)[0]
            admin_password = sha1(each.key) // printf nodename | sha1sum
          }
        }
        dynamic "network_interface" {
          for_each = toset(each.value.network.interfaces)
          content {
            ipv4_address = split("/", network_interface.key.address)[0]
            ipv4_netmask = try(split("/", network_interface.key.address)[1], 24)
          }
        }
        ipv4_gateway    = try(lookup(each.value.network, "gateway"), cidrhost(each.value.network.interfaces[0].address, 1))
        dns_server_list = lookup(each.value.network, "dns", [])
      }
    }
  }
}

resource "null_resource" "remote-check" {
  for_each = length(var.remote_connection) > 0 ? var.instances : {}
  triggers = {
    host = each.key
  }
  provisioner "remote-exec" {
    connection {
      user                = length(var.remote_connection) > 0 ? lookup(var.remote_connection, "user", "ubuntu") : null
      host                = length(var.remote_connection) > 0 ? each.value.network.interfaces[0].address : null
      type                = length(var.remote_connection) > 0 ? lookup(var.remote_connection, "type", "ssh") : null
      port                = length(var.remote_connection) > 0 ? lookup(var.remote_connection, "port", "22") : null
      private_key         = length(var.remote_connection) > 0 ? lookup(var.remote_connection, "private_key", "") : null
      bastion_host        = length(var.remote_connection) > 0 ? lookup(var.remote_connection, "bastion_host", "") : null
      bastion_user        = length(var.remote_connection) > 0 ? lookup(var.remote_connection, "bastion_user", "ubuntu") : null
      bastion_private_key = length(var.remote_connection) > 0 ? lookup(var.remote_connection, "bastion_private_key", "") : null
    }
    inline = [
      "echo terraform executed",
      "uptime"
    ]
  }
}
