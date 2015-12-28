#!/bin/bash
RED='\033[0;31m'
NC='\033[0m'
printf "${RED} CHECK AND SETUP NEW USER"
printf "${NC}\n"
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

CURRENT_USER=$(id -u -n)
CURRENT_GROUP=$(id -g -n)
CURRENT_USER_HOME=$(eval echo ~${SUDO_USER})
if [ -n "${SUDO_USER}" ]; then
	CURRENT_USER=$(sudo -u ${SUDO_USER} id -u -n)
	CURRENT_GROUP=$(sudo -u ${SUDO_USER} id -g -n)
fi


if [ "${CURRENT_USER}" == "root" ]; then
	echo "Type a new username:"
	read CURRENT_USER
	CURRENT_GROUP=$CURRENT_USER
	adduser --disabled-login --gecos "${CURRENT_USER}" ${CURRENT_USER}
	CURRENT_USER_HOME="/home/${CURRENT_USER}"
fi


sudo -u ${CURRENT_USER} mkdir -p ${CURRENT_USER_HOME}/htdocs/default

sudo -u ${CURRENT_USER} cat >> ${CURRENT_USER_HOME}/htdocs/default/index.php <<EOF
<?php
phpinfo();
EOF


sudo -u ${CURRENT_USER} cat >> ${CURRENT_USER_HOME}/htdocs/default/index.html <<EOF
<h1>heading</h1>
EOF

printf "${RED} SYSTEM UPDATE"
printf "${NC}\n"

apt-get update -y;
apt-get upgrade -y;
apt-get clean -y;
apt-get autoclean -y;
apt-get autoremove -y;

printf "${RED} INSTALL PACKAGE 1"
printf "${NC}\n"

apt-get install unzip vim git-core curl wget build-essential python-software-properties ps-watcher -y 

printf "${RED} INSTALL PACAGE FOR PHP"
printf "${NC}\n"

apt-get install libpng++-dev libpng12-dev libmcrypt-dev spawn-fcgi build-essential gcc g++ libxml2-dev libcurl4-openssl-dev pkg-config  libbz2-dev libpcre3-dev libdb-dev  libjpeg-dev libpng12-dev  libxpm-dev libfreetype6-dev libt1-dev  libgd2-xpm-dev libgmp-dev libmysqlclient-dev libsasl2-dev libmhash-dev unixodbc-dev freetds-dev libpspell-dev libmcrypt-dev libxslt1-dev libtidy-dev libsnmp-dev librecode-dev librecode0 php5-recode recode -y

ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h 

printf "${RED} DOWNLOAD PHP"
printf "${NC}\n"

wget http://php.net/get/php-7.0.1.tar.gz/from/this/mirror -O php-7.0.1.tar.gz

tar xf php-7.0.1.tar.gz

printf "${RED} COMPAILE PHP"
printf "${NC}\n"

cd php-7.0.1 && ./configure \
--prefix=/usr/local/php7  \
--with-config-file-path=/etc/php7 \
--enable-mbstring \
--enable-zip \
--enable-bcmath \
--enable-pcntl \
--enable-ftp \
--enable-exif \
--enable-calendar \
--enable-sysvmsg \
--enable-sysvsem \
--enable-sysvshm \
--enable-wddx \
--with-curl \
--with-mcrypt \
--with-iconv \
--with-gmp \
--with-pspell \
--with-gd \
--with-jpeg-dir=/usr \
--with-png-dir=/usr \
--with-zlib-dir=/usr \
--with-xpm-dir=/usr \
--with-freetype-dir=/usr \
--enable-gd-native-ttf \
--enable-gd-jis-conv \
--with-openssl \
--with-pdo-mysql \
--with-gettext=/usr \
--with-zlib=/usr \
--with-bz2=/usr \
--with-mysqli \
--with-pcre-regex \
--enable-mysqlnd  \
--enable-shmop \
--enable-sockets \
--with-libxml-dir=/usr \
--enable-inline-optimization \
--disable-rpath \
--enable-mbregex \
--with-jpeg-dir=/usr \
--with-png-dir=/usr \
--enable-gd-native-ttf \
--with-fpm-user=${CURRENT_USER} \
--with-fpm-group=${CURRENT_USER} \
--with-kerberos \
--with-xmlrpc \
--with-xsl \
--enable-opcache \
--enable-fpm \
--with-recode=/usr 

# --with-libdir=/usr/include/x86_64-linux-gnu
# --with-imap \
# --with-imap-ssl \
# --with-pgsql \
# --with-pdo-pgsql \
# --with-soap \
# --with-dba \
# --enable-mhash \

make -j 2
# make test
make install
make clean

printf "${RED} SETUP PHP-FPM"
printf "${NC}\n"

cat > /usr/local/php7/etc/php-fpm.conf <<EOF
[global]
pid = /run/php7-fpm.pid
error_log = /var/log/php7-fpm.log

[www]
user = $CURRENT_USER
group = $CURRENT_GROUP

listen = 127.0.0.1:9000

pm = dynamic
pm.max_children = 10
pm.start_servers = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 6
EOF


wget -O /etc/init.d/php7-fpm "https://gist.github.com/bjornjohansen/bd1f0a39fd41c7dfeb3a/raw/f0312ec54d1be4a8f6f3e708e46ee34d44ef4657/etc%20inid.d%20php7-fpm"

chmod a+x /etc/init.d/php7-fpm

wget -O /etc/init/php7-fpm.conf "https://gist.github.com/bjornjohansen/9555c056a7e8d1b1947d/raw/15920fa2f447358fdd1c79eecd75a53aaaec76f9/etc%20init%20php7-fpm"


cat > /usr/local/lib/php7-fpm-checkconf <<EOF
#!/bin/sh
set -e
errors=$(/usr/local/php7/sbin/php-fpm --fpm-config /usr/local/php7/etc/php-fpm.conf -t 2>&1 | grep "\[ERROR\]" || true);
if [ -n "$errors" ]; then
    echo "Please fix your configuration file…"
    echo $errors
    exit 1
fi
exit 0
EOF

chmod a+x /usr/local/lib/php7-fpm-checkconf

update-rc.d php7-fpm defaults

printf "${RED} INSTALL NGINX"
printf "${NC}\n"

cat >> /etc/apt/sources.list <<EOF
deb http://nginx.org/packages/ubuntu/ trusty nginx
deb-src http://nginx.org/packages/ubuntu/ trusty nginx
EOF

wget http://nginx.org/keys/nginx_signing.key
apt-key add nginx_signing.key

apt-get update -y
apt-get install nginx -y

rm nginx_signing.key

sed -i -- "s/www-data/$CURRENT_USER/g" /etc/nginx/nginx.conf


cat >> /usr/local/php7/etc/php-fpm.d <<EOF
user = $CURRENT_USER
group = $CURRENT_GROUP
listen.owner = $CURRENT_USER
listen.group = $CURRENT_GROUP
listen.mode = 0660
listen = 127.0.0.1:9000
listen.allowed_clients = 127.0.0.1
EOF

service php7-fpm start

printf "${RED} SETUP NGINX"
printf "${NC}\n"

cat > /etc/nginx/sites-available/default <<EOF
# You may add here your
# server {
#	...
# }
# statements for each of your virtual hosts to this file
##
# You should look at the following URL's in order to grasp a solid understanding
# of Nginx configuration files in order to fully unleash the power of Nginx.
# http://wiki.nginx.org/Pitfalls
# http://wiki.nginx.org/QuickStart
# http://wiki.nginx.org/Configuration
#
# Generally, you will want to move this file somewhere, and start with a clean
# file but keep this around for reference. Or just disable in sites-enabled.
#
# Please see /usr/share/doc/nginx-doc/examples/ for more detailed examples.
##
server {
	listen 80 default_server;
	listen [::]:80 default_server ipv6only=on;
	root /home/$CURRENT_USER/htdocs/default;
	index index.php index.html index.htm;
	# Make site accessible from http://localhost/
	server_name localhost;
	location / {
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		try_files \$uri \$uri/ =404;
		# Uncomment to enable naxsi on this location
		# include /etc/nginx/naxsi.rules
	}
	location ~ \.(php)$ {
    	proxy_intercept_errors on;
		try_files \$uri =404;
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            include fastcgi_params;
	}

}

EOF

cat > /usr/bin/nginx_modsite <<EOF
#!/bin/bash
##
#  File:
#    nginx_modsite
#  Description:
#    Provides a basic script to automate enabling and disabling websites found
#    in the default configuration directories:
#      /etc/nginx/sites-available and /etc/nginx/sites-enabled
#    For easy access to this script, copy it into the directory:
#      /usr/local/sbin
#    Run this script without any arguments or with -h or --help to see a basic
#    help dialog displaying all options.
##
# Copyright (C) 2010 Michael Lustfield <mtecknology@ubuntu.com>
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
##
# Default Settings
##
NGINX_CONF_FILE="\$(awk -F= -v RS=' ' '/conf-path/ {print \$2}' <<< \$(nginx -V 2>&1))"
NGINX_CONF_DIR="\${NGINX_CONF_FILE%/*}"
NGINX_SITES_AVAILABLE="\$NGINX_CONF_DIR/sites-available"
NGINX_SITES_ENABLED="\$NGINX_CONF_DIR/sites-enabled"
SELECTED_SITE="\$2"
##
# Script Functions
##
ngx_enable_site() {
    [[ ! "\$SELECTED_SITE" ]] &&
        ngx_select_site "not_enabled"
    [[ ! -e "\$NGINX_SITES_AVAILABLE/\$SELECTED_SITE" ]] && 
        ngx_error "Site does not appear to exist."
    [[ -e "\$NGINX_SITES_ENABLED/\$SELECTED_SITE" ]] &&
        ngx_error "Site appears to already be enabled"
    ln -sf "\$NGINX_SITES_AVAILABLE/\$SELECTED_SITE" -T "\$NGINX_SITES_ENABLED/\$SELECTED_SITE"
    ngx_reload
}
ngx_disable_site() {
    [[ ! "\$SELECTED_SITE" ]] &&
        ngx_select_site "is_enabled"
    [[ ! -e "\$NGINX_SITES_AVAILABLE/\$SELECTED_SITE" ]] &&
        ngx_error "Site does not appear to be \'available\'. - Not Removing"
    [[ ! -e "\$NGINX_SITES_ENABLED/\$SELECTED_SITE" ]] &&
        ngx_error "Site does not appear to be enabled."
    rm -f "\$NGINX_SITES_ENABLED/\$SELECTED_SITE"
    ngx_reload
}
ngx_list_site() {
    echo "Available sites:"
    ngx_sites "available"
    echo "Enabled Sites"
    ngx_sites "enabled"
}
##
# Helper Functions
##
ngx_select_site() {
    sites_avail=(\$NGINX_SITES_AVAILABLE/*)
    sa="\${sites_avail[@]##*/}"
    sites_en=(\$NGINX_SITES_ENABLED/*)
    se="\${sites_en[@]##*/}"
    case "\$1" in
        not_enabled) sites=\$(comm -13 <(printf "%s\n" \$se) <(printf "%s\n" \$sa));;
        is_enabled) sites=\$(comm -12 <(printf "%s\n" \$se) <(printf "%s\n" \$sa));;
    esac
    ngx_prompt "\$sites"
}
ngx_prompt() {
    sites=(\$1)
    i=0
    echo "SELECT A WEBSITE:"
    for site in \${sites[@]}; do
        echo -e "\$i:\t\${sites[\$i]}"
        ((i++))
    done
    read -p "Enter number for website: " i
    SELECTED_SITE="\${sites[\$i]}"
}
ngx_sites() {
    case "\$1" in
        available) dir="\$NGINX_SITES_AVAILABLE";;
        enabled) dir="\$NGINX_SITES_ENABLED";;
    esac
    for file in \$dir/*; do
        echo -e "\t\${file#*\$dir/}"
    done
}
ngx_reload() {
    read -p "Would you like to reload the Nginx configuration now? (Y/n) " reload
    [[ "\$reload" != "n" && "\$reload" != "N" ]] && invoke-rc.d nginx reload
}
ngx_error() {
    echo -e "\${0##*/}: ERROR: \$1"
    [[ "\$2" ]] && ngx_help
    exit 1
}
ngx_help() {
    echo "Usage: \${0##*/} [options]"
    echo "Options:"
    echo -e "\t<-e|--enable> <site>\tEnable site"
    echo -e "\t<-d|--disable> <site>\tDisable site"
    echo -e "\t<-l|--list>\t\tList sites"
    echo -e "\t<-h|--help>\t\tDisplay help"
    echo -e "\n\tIf <site> is left out a selection of options will be presented."
    echo -e "\tIt is assumed you are using the default sites-enabled and"
    echo -e "\tsites-disabled located at \$NGINX_CONF_DIR."
}
##
# Core Piece
##
case "\$1" in
    -e|--enable)    ngx_enable_site;;
    -d|--disable)   ngx_disable_site;;
    -l|--list)  ngx_list_site;;
    -h|--help)  ngx_help;;
    *)      ngx_error "No Options Selected" 1; ngx_help;;
esac
EOF

chmod +x /usr/bin/nginx_modsite

printf "${RED} RESTART "
printf "${NC}\n"

service nginx restart
service php7-fpm restart

printf "${RED} SYSTEM CLEAN"
printf "${NC}\n"

apt-get clean -y;
apt-get autoclean -y;
apt-get autoremove -y;


# ref
# http://www.pilishen.com/442.html