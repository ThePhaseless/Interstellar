#!/bin/bash
set -e

# Check if oci is authenticated
if ! oci session validate &> /dev/null; then
    oci session authenticate --region "eu-frankfurt-1" --profile "DEFAULT"
fi

# Download Ansible configuration files and set permissions
oci os object bulk-download -bn "${{ vars.ANSIBLE_BUCKET_NAME }}" -ns "${{ secrets.TF_NAMESPACE }}" --dest-dir .private/
chmod 600 ./.private/deployment_key.pem
