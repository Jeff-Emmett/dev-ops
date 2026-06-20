# Portable rSpace node — structural seed. TASK-415.10.
terraform {
  required_providers {
    rspace = { source = "registry.opentofu.org/jeffemmett/rspace" }
  }
  encryption {
    key_provider "pbkdf2" "infisical" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "default" {
      keys = key_provider.pbkdf2.infisical
    }
    state { method = method.aes_gcm.default }
    plan { method = method.aes_gcm.default }
  }
}

provider "rspace" {
  endpoint     = var.rspace_endpoint
  internal_key = var.rspace_internal_key
}

variable "rspace_endpoint" { type = string }
variable "rspace_internal_key" {
  type      = string
  sensitive = true
}
variable "state_passphrase" {
  type      = string
  sensitive = true
}
variable "machine_did" { type = string }

# A minimal home space so a fresh node is immediately usable.
resource "rspace_space" "home" {
  slug       = "home"
  name       = "Home"
  owner_did  = var.machine_did
  visibility = "private"
}

resource "rspace_space_modules" "home" {
  space           = rspace_space.home.slug
  enabled_modules = ["rtasks", "rdocs", "rcal"]
}

output "home_url" {
  value = "${var.rspace_endpoint} (space: ${rspace_space.home.slug})"
}
