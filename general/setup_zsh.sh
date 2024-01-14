#!/bin/bash

# Download ZSH config
echo "Replacing ZSH config for user $USER..."
cp ~/.zshrc ~/.zshrc.bak
cp ./general/.zshrc ~/.zshrc

# Install Zsh and Oh-My-Zsh
echo "Installing Zsh and Oh-My-Zsh..."
sudo apt install git zsh rsync -y
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Set Zsh as the default shell
echo "Setting Zsh as the default shell..."
sudo chsh -s "$(which zsh)" "$USER"

echo "Done..."
