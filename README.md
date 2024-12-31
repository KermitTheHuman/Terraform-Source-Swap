# Terraform-Source-Swap


## Source-swap Script

### Author: Kermit Smith
### Date: December 2024

This script reads `terragrunt.hcl` and swaps the source in the `main.tf` file for the module specified in `terragrunt.hcl`. This is useful when you want to swap the source of a module in dev or preprod environments.

### Usage
Enter a source-swap block as shown in the examples below. Be sure to comment out the block to avoid Terragrunt errors. **Note**: This is not a function of Terragrunt.

```hcl
source-swap "my-module" {
  old-source = "git::https://github.com/org/repository//module-call"
  new-source = "git::https://github.com/org/repository//module-call?ref=test"
}

source-swap "my-module2" {
  old-source = "git::https://github.com/org/repository//module-call"
  new-source = "git::https://github.com/org/repository//module-call?ref=test"
}

# Wild card * can be used to swap all occurrences of old-source with new-source in main.tf
source-swap "*" {
  old-source = "git::https://github.com/org/repository//module-call"
  new-source = "git::https://github.com/org/repository//module-call?ref=test"
}
```
