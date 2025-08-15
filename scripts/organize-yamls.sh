#!/bin/bash

YAML_DIR=$1
# Check if a directory argument is provided
if [ -z "$YAML_DIR" ]; then
    YAML_DIR="$(pwd)"
fi

echo "Organizing YAML files in directory: $YAML_DIR"

# Get files in the current directory
files=$(ls ${YAML_DIR}/*.yaml 2>/dev/null)
if [ -z "$files" ]; then
    echo "No YAML files found in the current directory."
    exit 0
fi

# Create directories for each file
for file in $files; do
    # Split by dash and take the first part as directory name
    dir_name=$(echo "$file" | cut -d'-' -f1)
    # Create the directory if it doesn't exist
    mkdir -p "$dir_name"
    # Get path without the directory name
    file_path=$(echo "$file" | sed "s|^$dir_name-||")
    # Move the file into the corresponding directory
    mv "$file" "$dir_name/$file_path"
    echo "Moved $file to $dir_name/$file_path"
done
