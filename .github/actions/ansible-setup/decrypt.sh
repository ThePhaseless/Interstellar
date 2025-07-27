gpg --decrypt --symmetric --cipher-algo AES256 --passphrase "$1" --batch --output "$2.gpg" "$2"
