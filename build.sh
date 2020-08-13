#!/bin/bash

# NGINX COMPILER
# This script pulls the nginx source code, other required libraries and builds nginx.
#
# REQUIREMENTS
# bash, curl, tar and a compiler like gcc or clang

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root."
   exit
fi

bold=$(tput bold)
normal=$(tput sgr0)
set -o pipefail

function checkSuccessfullExecution {
    if [ "$1" == "0" ]
    then
        echo " ✅"
    else
        echo " ❌"
        echo $2
        exit
    fi
}

function fetchAndExtractSources {
    /bin/echo -n "Fetching ${bold}$1 $nginxVersion${normal}"
    curl -s $2 > $3
    checkSuccessfullExecution $? "Fetching $1 failed."

    /bin/echo -n "Extracting ${bold}$1${normal}"
    tar xzf $3 > /dev/null 2>&1
    checkSuccessfullExecution $? "Extracting $1 failed."
}

read -p "${bold}nginx${normal} version to download [1.19.2]: " -e nginxVersion
read -p "${bold}openSSL${normal} version to download [1.1.1g]: " -e opensslVersion
read -p "${bold}zlib${normal} version to download [1.2.11]: " -e zlibVersion
read -p "${bold}pcre${normal} version to download [8.44]: " -e pcreVersion

if test -z $nginxVersion
    then
        nginxVersion="1.19.2"
fi

if test -z $opensslVersion
    then
        opensslVersion="1.1.1g"
fi

if test -z $zlibVersion
    then
        zlibVersion="1.2.11"
fi

if test -z $pcreVersion
    then
        pcreVersion="8.44"
fi

fetchAndExtractSources "nginx" "https://nginx.org/download/nginx-$nginxVersion.tar.gz" "nginx-$nginxVersion.tar.gz"
fetchAndExtractSources "openSSL" "https://www.openssl.org/source/openssl-$opensslVersion.tar.gz" "openssl-$opensslVersion.tar.gz"
fetchAndExtractSources "zlib" "https://www.zlib.net/zlib-$zlibVersion.tar.gz" "zlib-$zlibVersion.tar.gz"
fetchAndExtractSources "pcre" "https://ftp.pcre.org/pub/pcre/pcre-$pcreVersion.tar.gz" "pcre-$pcreVersion.tar.gz"


/bin/echo -n  "Configuring ${bold}nginx${normal} build"
cd nginx-$nginxVersion

# Adjust the configuration to your needs.
# An overview over all parameters is available [here](https://nginx.org/en/docs/configure.html)
./configure --prefix=/etc/nginx \
            --sbin-path=/usr/sbin/nginx \
            --modules-path=/usr/lib64/nginx/modules \
            --conf-path=/etc/nginx/nginx.conf \
            --error-log-path=/var/log/nginx/error.log \
            --pid-path=/var/run/nginx.pid \
            --lock-path=/var/run/nginx.lock \
            --user=nginx \
            --group=nginx \
            --builddir=nginx-$nginxVersion \
            --with-threads \
            --with-file-aio \
            --with-http_ssl_module \
            --with-http_v2_module \
            --with-http_image_filter_module=dynamic \
            --with-http_sub_module \
            --with-http_mp4_module \
            --with-http_gunzip_module \
            --with-http_gzip_static_module \
            --with-http_auth_request_module \
            --with-http_secure_link_module \
            --with-http_degradation_module \
            --with-http_slice_module \
            --with-http_stub_status_module \
            --http-log-path=/var/log/nginx/access.log \
            --http-client-body-temp-path=/var/cache/nginx/client_temp \
            --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
            --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
            --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
            --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
            --with-stream=dynamic \
            --with-stream_ssl_module \
            --with-stream_ssl_preread_module \
            --with-compat \
            --with-pcre=../pcre-$pcreVersion \
            --with-pcre-jit \
            --with-zlib=../zlib-$zlibVersion \
            --with-openssl=../openssl-$opensslVersion \
            --with-openssl-opt=no-nextprotoneg \
            --with-debug > /dev/null 2>&1
checkSuccessfullExecution $? "Configuring ${bold}nginx${normal} build failed."

echo -n "Building ${bold}nginx${normal}"
make > /dev/null 2>&1
checkSuccessfullExecution $? "Building ${bold}nginx${normal} failed."

read -p "Proceed with installing ${bold}nginx${normal}? [Y/n] " -e installNginx


if test -z $installNginx
    then
        installNginx="Y"
fi

if [ $installNginx == "Y" ]
    then
        echo -n "Installing ${bold}nginx${normal}"
        make install > /dev/null 2>&1
        checkSuccessfullExecution $? "Installing ${bold}nginx${normal} failed."

        echo "Cleaning up 🧹"
        cd ..
        rm -rf openssl-"$opensslVersion".tar.gz openssl-"$opensslVersion"/ \
                zlib-"$zlibVersion".tar.gz zlib-"$zlibVersion"/ \
                pcre-"$pcreVersion".tar.gz pcre-"$pcreVersion"/ \
                nginx-"$nginxVersion".tar.gz nginx-"$nginxVersion"/
fi