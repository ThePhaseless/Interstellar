if [ -f "$2" ]; then
    gpg --symmetric --batch --passphrase "$1" --output "$2.gpg" "$2"
fi
