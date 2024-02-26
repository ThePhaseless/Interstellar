#
# Post-Installation Script Installer
# ----------------------------------

# Allow execution of all .sh files
echo "Making .sh files executable..."
find . -type f -iname "**/*.sh" -exec sudo chmod +x {} \;

# Ask if this is a host or a proxy
echo "Is this a host or a proxy?"
echo "1. DMZ"
echo "2. VPS"
read -r -p "Enter your choice: " choice
case $choice in
[1]*)
	cd DMZ || exit
	./install.sh
	;;
[2]*)
	cd VPS || exit
	./install.sh
	;;
*)
	echo "Invalid choice"
	;;
esac
