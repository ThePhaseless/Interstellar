if [ -f "$2.gpg" ]; then
    gpg --decrypt --batch --yes --passphrase "$1" --output "$2" "$2.gpg"
    chmod 600 "$2"
fi
