define "bundle" "metadata" {
  class       = "demo"
  version     = "1.0.0"
  name        = "demo"
  description = "Minimal reproduction for Catalyst v0.17 map(object) type regression"
}

define "bundle" {
  alias = "demo"

  # Pattern 1: map(object) with optional() attribute and nested map(object).
  # Declared correctly. Valid in v0.16.0-beta12. Breaks in v0.17.0-beta13 with:
  #   Error: failed to evaluate schema namespaces: failed to parse typestr
  #   map(object({...})): syntax error at position <input>:1:12
  # The new type parser does not understand inline object({...}) syntax.
  input "account_map" {
    description = "Map of AWS accounts"
    type = map(object({
      account_id     = string
      name           = string
      region         = optional(string)
      clusters = map(object({
        oidc_provider = string
        region        = string
      }))
    }))
    default = {
      dev = {
        account_id = "123456789012"
        name       = "development"
        region     = "us-east-1"
        clusters = {
          my-cluster = {
            oidc_provider = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
            region        = "us-east-1"
          }
        }
      }
    }
  }

  # Pattern 2: map(string) type with a complex object default.
  # The type declaration was incorrect (should have been map(object) or map(any)).
  # v0.16.0-beta12 accepted this silently. v0.17.0-beta13 validates the default
  # against the type and fails with:
  #   "failed to validate input type: map value error: %!w(MISSING): expected string, got object"
  input "providers" {
    description = "Terraform provider configurations"
    type        = map(string)
    default = {
      aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
      }
    }
  }

  input "name" {
    type   = string
    prompt = "Name:"
  }

  scaffolding {
    path = "/infra/demo"
    name = "demo"
  }
}
