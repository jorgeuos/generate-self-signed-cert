#!/bin/bash

if [ -z "$1" ]
  then
    echo "Which domain name do you want to use?"
    read -r DOMAIN
fi
if [[ "$DOMAIN" == ''  ]]
  then
    DOMAIN=$1
fi

PATH_TO_SSL_CERTS=./certs/${DOMAIN}

# Make dir if it does not exist
if [ ! -d "$PATH_TO_SSL_CERTS" ]; then
  echo "Create certs dir"
  mkdir -p "$PATH_TO_SSL_CERTS"
fi

# Create v3.ext file
cat <<EOT > "$PATH_TO_SSL_CERTS"/v3-template.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = %%DOMAIN%%
EOT

# Set vars
#DOMAIN=$1 SET THIS IN BEGINNING
DEVDOMAIN=${DOMAIN}
# I don't remember why I'm not using this :s
COMMON_NAME=${2:-*.$1}
SUBJECT="/C=SE/ST=Stockholm/L=Stockholm/O=Digitalist/CN=$DOMAIN"
NUM_OF_DAYS=365
ROOTNAME="rootCA"

# Create a new private key if one doesnt exist, or use the exsisting one if it does
if [ -f "$PATH_TO_SSL_CERTS/$DEVDOMAIN.key" ]; then
  KEY_OPT="-key"
else
  KEY_OPT="-keyout"
fi

# First fix root cert
openssl genrsa -out "${PATH_TO_SSL_CERTS}/rootCA.key" 2048
openssl req -x509 -new -nodes -key "${PATH_TO_SSL_CERTS}/rootCA.key" -sha256 -days 1024 -subj "$SUBJECT" -out "${PATH_TO_SSL_CERTS}/rootCA.pem"


# Then rest
openssl req -new -newkey rsa:2048 -sha256 -nodes $KEY_OPT "${PATH_TO_SSL_CERTS}/${DEVDOMAIN}.key" -subj "$SUBJECT" -out "${PATH_TO_SSL_CERTS}/device.csr"

# Fix v3 file to have domainname
while IFS= read -r i; do echo "${i}"; done < "${PATH_TO_SSL_CERTS}/v3-template.ext" | sed "s/%%DOMAIN%%/mtmo.com/g" > "${PATH_TO_SSL_CERTS}/v3.ext"
# Then domain cert with all stuff
openssl x509 -req -in "${PATH_TO_SSL_CERTS}/device.csr" -CA "${PATH_TO_SSL_CERTS}/${ROOTNAME}.pem" -CAkey "${PATH_TO_SSL_CERTS}/${ROOTNAME}.key" -CAcreateserial -out "${PATH_TO_SSL_CERTS}/${DEVDOMAIN}.crt" -days ${NUM_OF_DAYS} -sha256 -extfile "${PATH_TO_SSL_CERTS}/v3.ext"

# move output files to final filenames
mv "${PATH_TO_SSL_CERTS}/device.csr" "${PATH_TO_SSL_CERTS}/${DOMAIN}.csr"

# Display file to mounted nfs for easy copying
cat "${PATH_TO_SSL_CERTS}/${DEVDOMAIN}.crt"

echo
echo "###########################################################################"
echo Done!
echo "###########################################################################"
echo "Copy lines to Apache :443 area:"
echo
echo "    SSLEngine on"
echo "    SSLCertificateFile    ${PATH_TO_SSL_CERTS}/${DEVDOMAIN}.crt"
echo "    SSLCertificateKeyFile ${PATH_TO_SSL_CERTS}/${DEVDOMAIN}.key"
