# generate-self-signed-cert
Script to generate a self signed certificate for development purposes.

## Make sure you have mod_ssl inside your box

```
sudo yum install mod_ssl openssh # For CentOS
sudo a2enmod ssl # Ubuntu
```

## Fetch script, e.g. from a Vagrant box or Docker container

```
cd ~
curl -0 https://raw.githubusercontent.com/jorgeuos/generate-self-signed-cert/main/gen_certs.sh -o gen_certs.sh
chmod +x gen_certs.sh
./gen_certs.sh
```
### Restart apache

```
sudo service httpd restart
```
## Fix self signed certificate error for Chrome on mac

Open `Keychain Access`, easiest is to use keyboard shortcut `cmd+space` and type `Keychain Access`

Drag and drop certificate that you just created `/PATH/TO/CERT/DOMAIN.dev.crt` into `Keychain Access` and the category `Certificates`

![alt "Keychain Access"](https://raw.githubusercontent.com/jorgeuos/generate-self-signed-cert/main/assets/images/keychain_access.png)

Double click the certificate, open the `Trust` accordion by clicking the chevron.

Change the `When using this certificate:` to `Always Trust`

![alt "Always Trust"](https://raw.githubusercontent.com/jorgeuos/generate-self-signed-cert/main/assets/images/always_trust.png)

Close window and verify with your computer password

## Example of a vhost

Usually you find your conf in:
Apache:
* CentOS:   `/etc/httpd/conf.d/DOMAIN_NAME.conf`
* Ubuntu:   `/etc/apache/sites-enabled/DOMAIN_NAME.conf`
* Mac:      `/usr/local/etc/httpd/extra/DOMAIN_NAME.conf`

```conf
<VirtualHost *:443>
    ServerAdmin jorgeuos@github
    ServerName DOMAIN_NAME.dev
    ServerAlias DOMAIN_NAME.dev www.DOMAIN_NAME.dev
    DocumentRoot /srv/www/DOMAIN_NAME/web

    SSLEngine on
    SSLCertificateFile /home/vagrant/.ssh/DOMAIN_NAME.dev.crt
    SSLCertificateKeyFile /home/vagrant/.ssh/DOMAIN_NAME.dev.key

    CustomLog /var/log/httpd/DOMAIN_NAME.dev.access.log combined
    ErrorLog /var/log/httpd/DOMAIN_NAME.dev.error.log
    <Directory /srv/www/DOMAIN_NAME/web>
        # Allow from all as default.
        Require all granted
        AllowOverride All

        # Allow symlinks.
        Options FollowSymLinks

        # Set the default handler.
        DirectoryIndex index.php

        # Make APP handle any 404 errors.
        ErrorDocument 404 /index.php
    </Directory>
</VirtualHost>
```

Or Nginx:
```conf

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    gzip on;
    gzip_disable "msie6";
    server {
        listen [::]:80; # enable IPv6
        listen 80;
        server_name DOMAIN_NAME;
        # Redirect all HTTP requests to HTTPS with a 301 Moved Permanently response.
        location / {
            return 301 https://$host$request_uri;
        }
    }

    server {
        listen [::]:443 ssl http2; # enable IPv6
        listen 443 ssl http2;
        #listen 443 default_server ssl;
        ssl_certificate       /etc/nginx/certificates/DOMAIN_NAME.crt;
        ssl_certificate_key   /etc/nginx/certificates/DOMAIN_NAME.key;
        error_log /var/log/nginx/error.log;
        ssl_session_cache    shared:SSL:1m;
        ssl_session_timeout  5m;
        ssl_ciphers  HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers  on;

        server_name DOMAIN_NAME;
        root /var/www/html/;

        index index.php index.html index.htm;
        client_max_body_size 2m;
        location / {
            try_files $uri $uri/ =404;
        }
    }
}

```
