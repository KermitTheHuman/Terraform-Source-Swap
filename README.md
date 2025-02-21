# Terraform Source-Swap with Terragrunt


## Source-Swap Script

### Author: Kermit Smith
### Date: December 2024

This script reads `terragrunt.hcl` and swaps the source in the Terraform `*.tf` files for the module specified in `terragrunt.hcl`.  
This is useful when you want to swap the source of a module in other environments while using same Terraform root module.

Feb. 2025 Update:
An additional option is to set the repo versioning. By using the wild card '*' you can set all calls in your script to 
other repos to a specific version. You can also change a specific module's source version by specifying the module name. 

### Usage
Enter a source-swap block as shown in the examples below. Commenting out the block is not longer needed. 
Code was changed to remove the source-swap block during runtime.  
**Note**: This is not a function of Terragrunt.

```hcl
source-swap "my-module" {
  old-source = "git::https://github.com/org/repository//module-call"
  new-source = "git::https://github.com/org/repository//module-call?ref=test"
}

source-swap "my-module2" {
  old-source = "git::https://github.com/org/repository//module-call"
  new-source = "git::https://github.com/org/repository//module-call?ref=test"
}

source-swap "my-module" {
  repo-name = "NameOfTheRepo"
  repo-version = "v0.0.2"
}

# Wild card * can be used to swap all occurrences of old-source with new-source in main.tf
source-swap "*" {
  old-source = "git::https://github.com/org/repository//module-call"
  new-source = "git::https://github.com/org/repository//module-call?ref=test"
}

source-swap "*" {
  repo-name = "NameOfTheRepo"
  repo-version = "v0.0.2"
}
```

Run this script in the same directory where you run Terragrunt.exe.  
I run it in the yaml pipeline as follows: (copy depends on where you place it of course. Here I have it my Terragrunt root)
```yaml
- name: Copy source-swap.sh to current folder
      run: |
        cp ../../../source-swap.sh .
        pwd
        ls -la

- name: Run source-swap.sh to replace module sources if requested in terragrunt.hcl
  run: |
    chmod +x ./source-swap.sh
    ./source-swap.sh
```
