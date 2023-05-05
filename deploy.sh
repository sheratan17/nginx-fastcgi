#!/bin/sh

read -p "Masukkan nama domain: " domain
read -p "Masukkan password admin wordpress: " adminpass
read -p "Masukkan email admin wordpress: " adminemail

sed -i 's,//de\.,//id\.,g' /etc/apt/sources.list

# install aplikasi
apt-get update
apt-get upgrade -y
apt-get install nginx php-fpm php-mysqli mariadb-server php-gd php-zip php-redis libnginx-mod-http-cache-purge redis certbot ca-certificates python3-certbot-nginx debconf-utils sendmail bind9 -y

# edit nginx
mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
wget https://raw.githubusercontent.com/sheratan17/nginx-fastcgi/main/default -P /etc/nginx/sites-available
sed -i '20s/\#/\ /' /etc/nginx/nginx.conf
sed -i '46s/\#/\ /' /etc/nginx/nginx.conf
sed -i '47s/\#/\ /' /etc/nginx/nginx.conf
sed -i '48s/\#/\ /' /etc/nginx/nginx.conf
sed -i '49s/\#/\ /' /etc/nginx/nginx.conf
sed -i '50s/\#/\ /' /etc/nginx/nginx.conf
sed -i '51s/\#/\ /' /etc/nginx/nginx.conf
sed -i '52s/\#/\ /' /etc/nginx/nginx.conf
sed -i '53s/\#/\ /' /etc/nginx/nginx.conf
sed -i '7s/768/1024/' /etc/nginx/nginx.conf

# install expect dan jalankan mysql_secure_installation
[ ! -e /usr/bin/expect ] && { apt-get -y install expect; }
SECURE_MYSQL=$(expect -c "

set timeout 10
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none): \"
send \"n\r\"
expect \"Switch to unix_socket authentication \[Y/n\] \"
send \"n\r\"
expect \"Change the root password? \[Y/n\] \"
send \"y\r\"
expect \"New password: \"
send \"{{root_pass}}\r\"
expect \"Re-enter new password: \"
send \"{{root_pass}}\r\"
expect \"Remove anonymous users? \[Y/n\] \"
send \"y\r\"
expect \"Disallow root login remotely? \[Y/n\] \"
send \"y\r\"
expect \"Remove test database and access to it? \[Y/n\] \"
send \"y\r\"
expect \"Reload privilege tables now? \[Y/n\] \"
send \"y\r\"
expect eof
")

# Download dan pasang seed
wget https://raw.githubusercontent.com/sheratan17/nginx-fastcgi/main/phpmyadmin.seed -P /root
debconf-set-selections /root/phpmyadmin.seed

# Install phpmyAdmin
apt install phpmyadmin -y
ln -s /usr/share/phpmyadmin/ /var/www/html/phpmyadmin

# RNG
dbuser=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 9 | head -n 1)
dbpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 9 | head -n 1)

# Install WP-CLI
wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -P /root
chmod +x /root/wp-cli.phar
mv /root/wp-cli.phar /usr/local/bin/wp

# Buat database dan user
mysql -e "CREATE DATABASE db_wp;"
mysql -e "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$dbpassword';"
mysql -e "GRANT ALL PRIVILEGES ON db_wp.* TO '$dbuser'@'localhost';"

# download dan install wp via wp-cli
wp core download --allow-root --path=/var/www/html
wp core config --allow-root --dbhost=localhost --dbname=db_wp --dbuser=$dbuser --dbpass=$dbpassword --path=/var/www/html
wp core install --allow-root --url=$domain --title="Wordpress" --admin_name=admin --admin_password=$adminpass --admin_email=$adminemail --path=/var/www/html

# Lindungi wp-admin dengan htpasswd
PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 9 | head -n 1)
HTPASSWD_ENTRY="admin:$(openssl passwd -apr1 $PASSWORD)"
echo $HTPASSWD_ENTRY >> /var/www/.htpasswd
echo "htpasswd user: admin | htpasswd password: $PASSWORD" >> /root/htpasswd_login.txt

# Fix-fix
chown -R www-data:www-data /var/www/html
sed -i '861s/On/Off/' /etc/php/8.1/fpm/php.ini
sed -i "s/server_name _;/server_name ${output} www.${output};/" /etc/nginx/sites-available/default
rm -f /root/recipe_24.log
rm -f /root/recipe_-1.log
rm -f /root/exec_recipe.log
rm -f /root/phpmyadmin.seed
systemctl restart php8.1-fpm.service
systemctl restart nginx
systemctl stop redis
