# Source-swap script to swap source in Terraform modules written by Kermit Smith 12/2024
# This script reads terragrunt.hcl and swaps the source in the "$path_to_module"/*.tf file for the module 
# specified in terragrunt.hcl.
# This is useful when you want to swap the source of a module in dev or preprod environments.

#### Usage ####
# Enter a source-swap block as shown in examples below. 
# Be sure to comment out the block to avoid Terragrunt errors. 
# This is not a function of Terragrunt.

# source-swap "my-module" {
#   old-source = "git::https://github.com/ibmalpine/azure-infrastructure-child-modules//CreateHubConnection"
#   new-source = "git::https://github.com/ibmalpine/azure-infrastructure-child-modules//CreateHubConnection?ref=test"
# }
# source-swap "my-module2" {
#   old-source = "git::https://github.com/ibmalpine/azure-infrastructure-child-modules//CreateHubConnection"
#   new-source = "git::https://github.com/ibmalpine/azure-infrastructure-child-modules//CreateHubConnection?ref=test"
# }
# Wild card * can be used to swap all occurrences of old-source with new-source in main.tf
# source-swap "*" {
#   old-source = "git::https://github.com/ibmalpine/azure-infrastructure-child-modules//CreateHubConnection"
#   new-source = "git::https://github.com/ibmalpine/azure-infrastructure-child-modules//CreateHubConnection?ref=test"
# }
# source-swap "my-module" {
#   repo-name = "azure-infrastructure-child-modules"
#   repo-version = "v0.0.2"
# }   

#!/bin/bash

path_to_module=""
source_swap_found=false

while IFS= read -r line || [ -n "$line" ]; do
  old_source=""
  new_source=""
  repo_name=""
  repo_version=""
  swap_type=""
  line=$(echo "$line" | tr -s ' ')
  if [[ $line == *"terraform {"* ]]; then
    read -r line || [ -n "$line" ]
    if [[ $line == *"source = "* ]]; then
      path_to_module=$(echo "$line" | grep -oP '(?<=source = ").*(?=")')
      printf "Found terraform source: '$path_to_module'\n"
    fi
  fi
  if [[ $line == *"source-swap \""* && $line != \#* ]]; then
    printf "\n"
    source_swap_found=true
    module_name=$(echo "$line" | grep -oP '(?<=source-swap ").*(?=")')
    printf "Attempting to swap source in module named '$module_name' provided in terragrunt.hcl\n"
    if [[ $module_name == "*" ]]; then
      swap_all=true
      printf "Swap wild card * provided. Swapping all occurrences in %s\n" "$path_to_module"...
    else
      swap_all=false
    fi
    read -r line || [ -n "$line" ]
    if [[ $line == *"repo-name = "* ]]; then
      repo_name=$(echo "$line" | grep -oP '(?<=repo-name = ").*(?=")')
    fi
    if [[ $line == *"old-source = "* ]]; then
      old_source=$(echo "$line" | grep -oP '(?<=old-source = ").*(?=")')
    fi
    read -r line || [ -n "$line" ]
    if [[ $line == *"repo-version = "* ]]; then
      repo_version=$(echo "$line" | grep -oP '(?<=repo-version = ").*(?=")')
    fi
    if [[ $line == *"new-source = "* ]]; then
      new_source=$(echo "$line" | grep -oP '(?<=new-source = ").*(?=")')
    fi
    
    if [[ -n "$repo_name" && -n "$repo_version" ]]; then
      printf "Both repo_name and repo_version were found in terragrunt.hcl.\n"
      printf "repo_name = '$repo_name'\n"
      printf "repo_version = '$repo_version'\n"
      swap_type="repo-version"
    fi
    if [[ -n "$old_source" && -n "$new_source" ]]; then
      printf "Both old-source and new-source were found in terragrunt.hcl.\n"
      printf "old-source = '$old_source'\n"
      printf "new-source = '$new_source'\n"
      swap_type="source-swap"
    fi

    if [[ "$swap_type" == "repo-version" || "$swap_type" == "source-swap" ]]; then
      # Check if path_to_module is blank
      if [[ -z "$path_to_module" ]]; then
        printf "Error: path_to_module is blank. Block must be after terraform block and source for module call\n"
        exit 1
      fi
      
      if ! ls "$path_to_module"/*.tf 1> /dev/null 2>&1; then
        printf "Error: No .tf files found in %s\n" "$path_to_module"
      else
        if [[ "$swap_all" == true  ]]; then
          if [[ "$swap_type" == "repo-version" ]]; then
            for file in "$path_to_module"/*.tf; do
              sed -i "s|\($repo_name.*\)?ref=.*\"|\1\"|g" "$file"
              sed -i "s|\($repo_name.*\)\"|\1?ref=$repo_version\"|g" "$file"
              printf "Appended ?ref=%s to all occurrences of %s in %s\n" "$repo_version" "$repo_name" "$file"
              printf "Result:\n"
              cat $file
            done
          else
            for file in "$path_to_module"/*.tf; do
              sed -i "s|$old_source|$new_source|g" "$file"
              printf "Replaced all occurrences of old-source with new-source in %s\n" "$file"
              printf "Result:\n"
              cat $file
            done
          fi
        else
          for file in "$path_to_module"/*.tf; do
            if ! grep -q "\"$module_name\"" "$file"; then
              printf "Error: module_name '%s' not found in %s\n" "$module_name" "$file"
              continue
            fi

            # Temporary file to hold the modified content
            temp_file="./tmp_file"

            # Variables to track state
            found_first_string=false

            # Read file line by line
            while IFS= read -r line; do
              if [[ $found_first_string == false && "$line" == *"module \"$module_name\""* ]]; then
                printf "Found module %s in %s\n" "$module_name" "$file"
                found_first_string=true
              elif [[ $found_first_string == true && "$line" == *"$old_source"* && "$swap_type" == "source-swap" ]]; then
                # printf "Remove ?ref=*\" at the end of the line\n"
                # line=$(echo "$line" | sed 's|\?ref=.*\"|\"|g')
                printf "Replace old_source with new_source in the line\n"
                line="${line/"$old_source"/"$new_source"}"
                found_first_string=false
              elif [[ $found_first_string == true && "$line" == *"$repo_name"* && "$swap_type" == "repo-version" ]]; then
                printf "Remove ?ref=*\" at the end of the line\n"
                line=$(echo "$line" | sed 's|\?ref=.*\"|\"|g')
                printf "Replace last \" in line with ?ref=$repo_version\n"
                line=$(echo "$line" | sed "s|\"$|?ref=$repo_version\"|")
                found_first_string=false
              fi
              # Write the line to the temporary file
              echo "$line" >> "$temp_file"
            done < "$file"
            # Move the temporary file to the original file
            mv "$temp_file" "$file"

            echo "Replacement done in $file. Result:\n"
            cat $file
          done
        fi
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

# Remove source-swap code block from terragrunt.hcl
temp_file="./terragrunt_temp.hcl"
inside_source_swap_block=false

while IFS= read -r line || [ -n "$line" ]; do
  if [[ $line == *"source-swap \""* ]]; then
    inside_source_swap_block=true
  fi

  if [[ $inside_source_swap_block == false ]]; then
    echo "$line" >> "$temp_file"
  fi

  if [[ $inside_source_swap_block == true && $line == *"}"* ]]; then
    inside_source_swap_block=false
  fi
done < "./terragrunt.hcl"

mv "$temp_file" "./terragrunt.hcl"

if [[ "$source_swap_found" == false ]]; then
  printf "Source-swap was not found in terragrunt.hcl\n"
  printf "You can add source-swap code block as follows: (This is not a funtion of Terragrunt. It is removed at runtime to avoid Terragrunt errors.)\n"
  printf ' source-swap "module_name(Use * to swap all)" {\n  old-source = "old-source-path"\n  new-source = "new-source-path"\n  }\n'
fi
