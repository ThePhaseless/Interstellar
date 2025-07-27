gpg --decrypt --cipher-algo AES256 --passphrase "$1" --batch --output "$2" "$2.gpg"
