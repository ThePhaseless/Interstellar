#!/usr/bin/env python3
import os
import sys
import yaml
from pathlib import Path

# --- Configuration ---
# The root directory to start searching from.
# Defaults to the current directory if no argument is provided.
ROOT_DIRECTORY = Path(sys.argv[1] if len(sys.argv) > 1 else '.')
# File extensions to check for
YAML_EXTENSIONS = ['.yaml', '.yml']

def add_namespace_to_manifest(file_path: Path):
    """
    Reads a Kubernetes YAML file, adds the namespace based on its parent
    directory, and writes the changes back to the file.
    Handles both single and multi-document YAML files.
    """
    try:
        # The namespace is the name of the parent directory of the app's folder
        # e.g., for 'media/sonarr/deployment.yaml', the namespace is 'media'
        namespace = file_path.parent.parent.name

        print(f"Processing '{file_path}' for namespace '{namespace}'...")

        with file_path.open('r') as f:
            # Load all documents from the YAML file (handles multi-doc files)
            manifests = list(yaml.safe_load_all(f))

        modified = False
        processed_manifests = []

        for manifest in manifests:
            # Check if it's a valid Kubernetes object manifest
            if not isinstance(manifest, dict) or 'apiVersion' not in manifest or 'kind' not in manifest:
                print(f"  -> Skipping document in '{file_path}' as it's not a valid K8s object.")
                processed_manifests.append(manifest)
                continue

            # Ensure metadata key exists
            if 'metadata' not in manifest:
                manifest['metadata'] = {}

            # Check if namespace is already set and if it's correct
            current_namespace = manifest['metadata'].get('namespace')
            if current_namespace == namespace:
                print(f"  -> Namespace '{namespace}' already correctly set. Skipping modification.")
            else:
                if current_namespace:
                    print(f"  -> Updating namespace from '{current_namespace}' to '{namespace}'.")
                else:
                    print(f"  -> Setting namespace to '{namespace}'.")
                manifest['metadata']['namespace'] = namespace
                modified = True

            processed_manifests.append(manifest)

        # If any manifest in the file was changed, write the whole file back
        if modified:
            with file_path.open('w') as f:
                # Use Dumper to get a cleaner output, indent sequences correctly
                yaml.dump_all(processed_manifests, f, Dumper=yaml.Dumper, default_flow_style=False, sort_keys=False)
            print(f"  -> Successfully updated '{file_path}'.")

    except yaml.YAMLError as e:
        print(f"Error parsing YAML file '{file_path}': {e}")
    except Exception as e:
        print(f"An unexpected error occurred with file '{file_path}': {e}")

def main():
    """
    Main function to walk through the directory structure and process YAML files.
    """
    if not ROOT_DIRECTORY.is_dir():
        print(f"Error: Provided path '{ROOT_DIRECTORY}' is not a valid directory.")
        sys.exit(1)

    print(f"Starting scan in directory: '{ROOT_DIRECTORY.resolve()}'")

    file_count = 0
    for root, _, files in os.walk(ROOT_DIRECTORY):
        for file in files:
            file_path = Path(root) / file
            # Check if the file has a valid YAML extension
            if file_path.suffix.lower() in YAML_EXTENSIONS:
                # Ensure the file is at the correct depth (e.g., namespace/app/file.yaml)
                # The path relative to the root should have at least 2 parts
                try:
                    relative_path = file_path.relative_to(ROOT_DIRECTORY)
                    if len(relative_path.parts) > 2:
                        add_namespace_to_manifest(file_path)
                        file_count += 1
                except ValueError:
                    # This can happen if the file is not within the root dir, should not occur with os.walk
                    continue

    print(f"\nScan complete. Processed {file_count} YAML files.")

if __name__ == "__main__":
    # You need to install PyYAML: pip install pyyaml
    main()
