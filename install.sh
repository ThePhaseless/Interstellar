#
# Post-Installation Script Installer
# ----------------------------------

# Ask if this is a host or a proxy
find . -type f -iname "*.sh" -exec chmod +x {} \;
echo "Is this a host or a proxy?"
echo "1. Host"
echo "2. Proxy"
read -r -p "Enter your choice: " choice
case $choice in
[1]*)
	./host/install.sh
	;;
[2]*)
	./proxy/install.sh
	;;
*)
	echo "Invalid choice"
	;;
esac
