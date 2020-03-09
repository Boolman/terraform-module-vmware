output "ips" {
  value = {
    for instance in vsphere_virtual_machine.web :
    instance.name => instance.default_ip_address
  }
}
