if [ -f "$2" ]; then
    gpg --symmetric --cipher-algo AES256 --batch --yes --passphrase "$1" --output "$2.pem.gpg" "$2.pem"
fi
