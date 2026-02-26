# TFLint Configuration

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

# Disable unused declarations - variables/data may be used in future phases
rule "terraform_unused_declarations" {
  enabled = false
}
