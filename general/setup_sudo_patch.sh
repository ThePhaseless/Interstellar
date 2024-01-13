#!/bin/bash

printf "Applying sudo patch... \n"

# Check if patch is already applied by searching for the comment
if grep -Fxq "# INSTALLATION SCRIPT DO NOT MODIFY" /etc/sudoers.d/"$USER"; then
    echo "Patch already applied"
    exit
fi

# Allow for sudo without password
echo "# INSTALLATION SCRIPT DO NOT MODIFY" | sudo tee -a /etc/sudoers.d/"$USER"
echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/"$USER"
echo "# END OF INSTALLATION SCRIPT" | sudo tee -a /etc/sudoers.d/"$USER"
echo "Done..."
