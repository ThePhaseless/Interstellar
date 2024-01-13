# Preparing SAMBA
echo "Preparing SAMBA..."
sudo apt install samba wsdd -y

# Add HDD_SAMBA_SHARE to config file
HDD_SAMBA_SHARE="
[HDD]\n
comment = HDD\n
path = $JBOD_PATH\n
guest ok = yes\n
browsable = yes\n
writeable = yes\n
public = yes\n
"

# Add SSD_SAMBA_SHARE to config file
SSD_SAMBA_SHARE="
[SSD]\n
path = $SSD_PATH\n
acl support = yes\n
read only = no\n
guest ok = yes\n
browsable = yes\n
writeable = yes\n
public = yes\n
"

echo "Creating SAMBA shares..."
# Check if the HDD_SAMBA_SHARE is already in the config file and add it if not
if grep -Fxq "[HDD]" /etc/samba/smb.conf; then
    echo "HDD_SAMBA_SHARE is already in the config file"
else
    echo "Adding HDD_SAMBA_SHARE to the config file..."
    echo -e "$HDD_SAMBA_SHARE" >>/etc/samba/smb.conf
fi

# Check if the SSD_SAMBA_SHARE is already in the config file and add it if not
if grep -Fxq "[SSD]" /etc/samba/smb.conf; then
    echo "SSD_SAMBA_SHARE is already in the config file"
else
    echo "Adding SSD_SAMBA_SHARE to the config file..."
    echo -e "$SSD_SAMBA_SHARE" >>/etc/samba/smb.conf
fi

echo "Restarting SAMBA..."
sudo systemctl restart smbd
echo "Done..."
