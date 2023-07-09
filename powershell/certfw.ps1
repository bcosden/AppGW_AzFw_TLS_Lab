# Create root CA
openssl req -x509 -new -nodes -newkey rsa:4096 -keyout rootCA.key -sha256 -days 3650 -out rootCA.crt -subj '/C=US/ST=US/O=Self Signed/CN=Self Signed Root CA' -config openssl.cnf -extensions rootCA_ext

# Create intermediate CA request
openssl req -new -nodes -newkey rsa:4096 -keyout interCA.key -sha256 -out interCA.csr -subj '/C=US/ST=US/O=Self Signed/CN=Self Signed Intermediate CA'

# Sign on the intermediate CA
openssl x509 -req -in interCA.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out interCA.crt -days 3650 -sha256 -extfile openssl.cnf -extensions interCA_ext

# Export the intermediate CA into PFX
openssl pkcs12 -export -out interCA.pfx -inkey interCA.key -in interCA.crt -password 'pass:'

Write-Host ""
Write-Host "================"
Write-Host "Successfully generated root and intermediate CA certificates"
Write-Host "   - rootCA.crt/rootCA.key - Root CA public certificate and private key"
Write-Host "   - interCA.crt/interCA.key - Intermediate CA public certificate and private key"
Write-Host "   - interCA.pfx - Intermediate CA pkcs12 package which could be uploaded to Key Vault"
Write-Host "================"

