#!/bin/bash
DEBIAN_10_PKGS_INSTALL_CMD="apt-get -qq install"

PKGS_DNSUTILS_INSTALL="dnsutils"
PKGS_CERTBOT_INSTALL="certbot"
PKGS_PYTHON_CERTBOT_NGINX_INSTALL="python3-certbot-nginx"
PKGS_NGINX_INSTALL="nginx"

pkgs_install() {
	local cmd="apt-get -qq install"
	if [ $NGINXSETUP_REMOTE_SET ]; then
		${NGINXSETUP_REMOTE_CMD} "$cmd $@"
	else
		$cmd $@
	fi
}