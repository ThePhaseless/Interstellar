#!/bin/sh
set -e

# Check if file path is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <file-path>"
    exit 1
fi

FILE_PATH="$1"

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File $FILE_PATH not found"
    exit 1
fi

echo "Replacing ENV_ variables in $FILE_PATH"

# Create a temporary file
TEMP_FILE=$(mktemp)

# Process the file line by line
while IFS= read -r line || [ -n "$line" ]; do
    # Look for ENV_ patterns and replace them with actual environment variable values
    processed_line="$line"

    # Extract all ENV_ variables from the line
    env_vars=$(echo "$line" | grep -o 'ENV_[A-Z0-9_]*' | sort -u)

    # Replace each ENV_ variable with its value
    for env_var in $env_vars; do
        # Remove the ENV_ prefix to get the actual environment variable name
        actual_var=${env_var#ENV_}

        # Use eval to get the value of the variable, which is compatible with sh
        value=$(eval echo "\$${actual_var}")

        # Check if the environment variable is set
        if [ -n "$value" ]; then
            # Replace all occurrences of the ENV_ variable with its value
            processed_line=$(echo "$processed_line" | sed "s|$env_var|$value|g")
        else
            echo "Warning: Environment variable $actual_var is not set"
        fi
    done

    # Write the processed line to the temporary file
    echo "$processed_line" >> "$TEMP_FILE"
done < "$FILE_PATH"

# Replace the original file with the processed one
mv "$TEMP_FILE" "$FILE_PATH"

echo "Finished replacing ENV_ variables in $FILE_PATH"

