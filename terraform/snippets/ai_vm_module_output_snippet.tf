# Example snippet for your AI VM module.
# Merge this into the module that creates VM210 so the VM IP is exposed.
# Adjust the expression to match your module's real network variable or computed IP.

output "vm_ip" {
  description = "AI VM IPv4 address for inventory generation"
  value       = var.vm_ip
}
