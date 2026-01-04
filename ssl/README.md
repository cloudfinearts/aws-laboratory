# SSL

https://amod-kadam.medium.com/create-private-ca-and-certificates-using-terraform-4b0be8d1e86d

Public key can be derived from private key, but not the other way around

Two available formats for keys and certs

OpenSSH format used by `ssh-keygen` to generate private and public keys

OpenSSL format used by `openssl` to generate private key and certificate. Public key is included in the certificate and is never exported
 
openssl x509 -in ca.crt -text
ssh-keygen -f ca.pem -y

Public key exported by openssl and ssh-keygen using the same private key do not match! Conversion is possible but they serve different purposes