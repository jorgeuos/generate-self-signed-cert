#!/bin/bash
# I've used this script for years and I couldn't remember the source.
# I've tweaked it a bunch of times, but I found some similar scripts online.
# https://gist.github.com/aimeemikaelac/6e6fe1cc8c6f1c91087dff256d9fa7ee
# https://stackoverflow.com/questions/7580508/getting-chrome-to-accept-self-signed-localhost-certificate/43666288#43666288
# https://stackoverflow.com/questions/43665243/invalid-self-signed-ssl-cert-subject-alternative-name-missing/43665244#43665244


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
FULL_PATH_TO_SSL_CERTS=${PWD}/certs/${DOMAIN}

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
# But I believe Common Name **IS** the FQDN without protocol
# note to self: RTFM
# CN could also be subdomains with wildcard
# Anywho, here's a link explaining more:
# https://support.dnsimple.com/articles/ssl-certificate-names/
# shellcheck disable=SC2034
COMMON_NAME=${2:-*.$1}

SUBJECT="/C=SE/ST=Stockholm/L=Stockholm/O=Jorgeuos/OU=DevTeam/CN=$DOMAIN"
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
# This is where COMMON_NAME was used before:
while IFS= read -r i; do echo "${i}"; done < "${PATH_TO_SSL_CERTS}/v3-template.ext" | sed "s/%%DOMAIN%%/${DOMAIN}/g" > "${PATH_TO_SSL_CERTS}/v3.ext"
# Then domain cert with all stuff
openssl x509 -req -in "${PATH_TO_SSL_CERTS}/device.csr" -CA "${PATH_TO_SSL_CERTS}/${ROOTNAME}.pem" -CAkey "${PATH_TO_SSL_CERTS}/${ROOTNAME}.key" -CAcreateserial -out "${PATH_TO_SSL_CERTS}/${DEVDOMAIN}.crt" -days ${NUM_OF_DAYS} -sha256 -extfile "${PATH_TO_SSL_CERTS}/v3.ext"

# move output files to final filenames
mv "${PATH_TO_SSL_CERTS}/device.csr" "${PATH_TO_SSL_CERTS}/${DOMAIN}.csr"

# Display file to mounted nfs for easy copying
cat "${PATH_TO_SSL_CERTS}/${DEVDOMAIN}.crt"

echo "Do you want to add this to your trusted certs? (Mac Only!)"
while true; do
read -p "Needs sudoing. (Y/N): " -r yn
case $yn in
    [Yy]* )
        echo "Adding to trusted hosts..."
        sudo security add-trusted-cert -r trustAsRoot -k /Library/Keychains/System.keychain "${FULL_PATH_TO_SSL_CERTS}/${DEVDOMAIN}.crt"
        break;;
    [Nn]* )
        break;;
    * ) echo "Please answer yes or no.";;
esac
done


# RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo
echo -e "${GREEN}###########################################################################${NC}"
echo Done!
echo -e "${GREEN}###########################################################################${NC}"
echo -e "${PURPLE}Copy lines to Apache :443 area:${NC}"
echo
echo "    SSLEngine on"
echo "    SSLCertificateFile    ${FULL_PATH_TO_SSL_CERTS}/${DEVDOMAIN}.crt"
echo "    SSLCertificateKeyFile ${FULL_PATH_TO_SSL_CERTS}/${DEVDOMAIN}.key"
echo -e "${GREEN}###########################################################################${NC}"
echo -e "${PURPLE}Or move the files to your httpd certs folder.${NC}"
echo "E.g something like this:"
echo "mv ${PATH_TO_SSL_CERTS} /usr/local/etc/httpd/certs/${DOMAIN}"
echo "mv ${PATH_TO_SSL_CERTS} /usr/local/etc/nginx/certs/${DOMAIN}"
echo "mv ${PATH_TO_SSL_CERTS} /usr/local/etc/node/certs/${DOMAIN}"
