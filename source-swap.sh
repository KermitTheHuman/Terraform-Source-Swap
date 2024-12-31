# Source-swap script to swap source in Terraform modules written by Kermit Smith 12/2024
# This script reads terragrunt.hcl and swaps the source in the main.tf file for the module 
# specified in terragrunt.hcl.
# This is useful when you want to swap the source of a module in dev or preprod environments.

#### Usage ####
# Enter a source-swap block as shown in examples below. 
# Be sure to comment out the block to avoid Terragrunt errors. 
# This is not a function of Terragrunt.

#  source-swap "my-module" {
#    old-source = "git::https://github.com/org/repository//module-call"
#    new-source = "git::https://github.com/org/repository//module-call?ref=test"
#  }
#  source-swap "my-module2" {
#    old-source = "git::https://github.com/org/repository//module-call"
#    new-source = "git::https://github.com/org/repository//module-call?ref=test"
#  }
#  Wild card * can be used to swap all occurrences of old-source with new-source in main.tf
#  source-swap "*" {
#    old-source = "git::https://github.com/org/repository//module-call"
#    new-source = "git::https://github.com/org/repository//module-call?ref=test"
#  }

#!/bin/bash

path_to_main=""
source_swap_found=false

# Check if current working directory contains "prd"
current_dir=$(pwd)
if [[ "$current_dir" == *"/prd"* ]]; then
  printf "Warning: Current working directory contains 'prd'. Source swapping should only be done in non-prod environments to avoid unintended changes in production.\n"
  printf "Remove the source-swap block from terragrunt.hcl and try again.\n"
fi

while IFS= read -r line || [ -n "$line" ]; do
  old_source=""
  new_source=""
  line=$(echo "$line" | tr -s ' ')
  if [[ $line == *"terraform {"* ]]; then
    read -r line || [ -n "$line" ]
    if [[ $line == *"source = "* ]]; then
      path_to_main=$(echo "$line" | grep -oP '(?<=source = ").*(?=")')
      path_to_main=$path_to_main"/main.tf"
      printf "Found terraform source: '$path_to_main'\n"
    fi
  fi
  if [[ $line == *"source-swap \""* ]]; then
    printf "\n"
    source_swap_found=true
    module_name=$(echo "$line" | grep -oP '(?<=source-swap ").*(?=")')
    printf "Attempting to swap source in module named '$module_name' provided in terragrunt.hcl\n"
    if [[ $module_name == "*" ]]; then
      swap_all=true
      printf "Swap wild card * provided. Swapping all occurrences of old-source with new-source in %s\n" "$path_to_main"...
    else
      swap_all=false
    fi
    read -r line || [ -n "$line" ]
    if [[ $line == *"old-source = "* ]]; then
      old_source=$(echo "$line" | grep -oP '(?<=old-source = ").*(?=")')
    fi
    read -r line || [ -n "$line" ]
    if [[ $line == *"new-source = "* ]]; then
      new_source=$(echo "$line" | grep -oP '(?<=new-source = ").*(?=")')
    fi
    if [[ -n "$old_source" && -n "$new_source" ]]; then
      printf "Both old-source and new-source were found in terragrunt.hcl.\n"
      printf "old-source = '$old_source'\n"
      printf "new-source = '$new_source'\n"
      
      # Check if path_to_main is blank
      if [[ -z "$path_to_main" ]]; then
        printf "Error: path_to_main is blank. Source-swap block must be after terraform block and source for module call\n"
        exit 1
      fi

      if [[ -f "$path_to_main" && ! -d "$path_to_main" ]]; then
        if [[ "$swap_all" = true  ]]; then
          sed -i "s|$old_source|$new_source|g" "$path_to_main"
          printf "Replaced all occurrences of old-source with new-source in %s\n" "$path_to_main"
        else
          if ! grep -q "\"$module_name\"" "$path_to_main"; then
            printf "Error: module_name '%s' not found in %s\n" "$module_name" "$path_to_main"
            continue
          fi

          # Temporary file to hold the modified content
          temp_file="./tmp_file"

          # Variables to track state
          found_first_string=false

          # Read file line by line
          while IFS= read -r line; do
              if [ "$found_first_string" = false ] && [[ "$line" == *"\"$module_name\""* ]]; then
                  found_first_string=true
              elif [ "$found_first_string" = true ] && [[ "$line" == *"$old_source"* ]]; then
                  # Replace old_source with new_source in the line
                  line="${line/"$old_source"/"$new_source"}"
                  found_first_string=false
              fi
              # Write the line to the temporary file
              echo "$line" >> "$temp_file"
          done < "$path_to_main"
          # Move the temporary file to the original file
          mv "$temp_file" "$path_to_main"

          echo "Replacement done."
        fi
      else
        printf "Error: Terraform file %s not found\n" "$path_to_main"
      fi
    else
      if [[ -z "$old_source" ]]; then
        printf "Error: old-source is empty\n"
      fi
      if [[ -z "$new_source" ]]; then
        printf "Error: new-source is empty\n"
      fi
    fi
  fi
done < "./terragrunt.hcl"

if [[ "$source_swap_found" = false ]]; then
  printf "Source-swap was not found in terragrunt.hcl\n"
  printf "You can add source-swap code block as follows: (Commented out on purpose to avoid Terragrunt errors - this is not a funtion of Terragrunt)\n"
  printf '# source-swap "module_name(Use * to swap all)" {\n#  old-source = "old-source-path"\n#  new-source = "new-source-path"\n#  }\n'
fi