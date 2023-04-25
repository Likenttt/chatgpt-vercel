#!/bin/bash

# Install dependencies
sudo yum update -y
sudo yum install -y epel-release
sudo yum install -y nginx git python3 nodejs npm zsh vim curl wget gcc-c++ make nodejs npm certbot util-linux-user httpd-tools
sudo yum groupinstall -y "Development Tools"
sudo dnf install -y python3-certbot-nginx
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
chsh -s /usr/bin/zsh

echo "Enter the domain name:"
read domain_name

echo "Enter the auth user:"
read auth_user

auth_password=""
auth_password_confirm=""

while [ "$auth_password" != "$auth_password_confirm" ]; do
    echo "Enter the auth password:"
    read auth_password

    echo "Confirm the auth password:"
    read auth_password_confirm

    if [ "$auth_password" != "$auth_password_confirm" ]; then
        echo "Passwords do not match. Please try again."
    fi
done

echo "Enter your email for SSL certificate:"
read email

# Generate SSL certificate
sudo certbot --nginx -d $domain_name --non-interactive --agree-tos --email $email

# Create htpasswd file
sudo htpasswd -c -b /etc/nginx/.htpasswd $auth_user $auth_password

# Create Nginx configuration
nginx_config="server {
    listen 80;
    server_name $domain_name;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain_name;

    ssl_certificate /etc/letsencrypt/live/$domain_name/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain_name/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/$domain_name/chain.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    auth_basic \"Restricted Content\";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}"

echo "$nginx_config" | sudo tee /etc/nginx/conf.d/$domain_name.conf

# Restart Nginx and reload firewall rules
sudo systemctl restart nginx

echo "SSL certificate installed, and Nginx configured with authentication for domain $domain_name."

