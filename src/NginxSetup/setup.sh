#!/bin/bash
TCLI_NGINXSETUP_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")" 
. $TCLI_NGINXSETUP_DIR/inc/shared.sh

[ -d ${TCLI_NGINXSETUP_PATH_TEMP}/etc/nginx/sites-available ] || mkdir -p ${TCLI_NGINXSETUP_PATH_TEMP}/etc/nginx/sites-available
[ -d ${TCLI_NGINXSETUP_PATH_TEMP}/$TCLI_NGINXSETUP_WWW_BASE_PATH ] || mkdir -p ${TCLI_NGINXSETUP_PATH_TEMP}/$TCLI_NGINXSETUP_WWW_BASE_PATH
. $TCLI_NGINXSETUP_DIR/vendor/Linux.Distribution/src/Distribution/distribution.sh

################################################################################
# Remote setup if using ssh
################################################################################
# $1 # remote server ip address
# $2 # remote server port number (optional) using port 22 if not given
# Requre password less connection for non-interactive
################################################################################
tcli_nginxsetup_remote() {
	if [ ${1:-} ] && [ ${2:-22} ]; then
		TCLI_NGINXSETUP_REMOTE_SET=1
		TCLI_NGINXSETUP_REMOTE_CMD="ssh -p $2 root@$1"
		TCLI_NGINXSETUP_REMOTE_IP=$1
		TCLI_NGINXSETUP_REMOTE_PORT=$2
	elif [ $remote -eq 1 ]; then 
		TCLI_NGINXSETUP_REMOTE_SET=0
		printf "setup.sh no remote" 1>&3
	fi
}

tcli_nginxsetup_remote_cmd() {
	ssh -p $TCLI_NGINXSETUP_REMOTE_PORT root@$TCLI_NGINXSETUP_REMOTE_IP $@
}

################################################################################
# Check and install needed packages
################################################################################
tcli_nginxsetup_prepare() {
	# Get requiered tools
	tcli_packageManager_install "certbot"
	tcli_packageManager_install "python3-certbot-nginx"
}

################################################################################
# Install nginx
################################################################################
# pararms
#   nocertbot will not create certificate
################################################################################
tcli_nginxsetup_install() {
	tcli_nginxsetup_prepare
	# for arg in "$@"; do
	# 	[ arg=="nocertbot" ] && local certbot=1
	# 	shift
	# done
	tcli_packageManager_install "nginx"
	# ssh -p 10233 root@161.97.108.95 systemctl enable nginx.service
	tcli_nginxsetup_remote_cmd systemctl enable nginx.service
	tcli_nginxsetup_remote_cmd systemctl start nginx.service
}

################################################################################
# Add domian name and create default site with ssl
################################################################################
# Params
#   <hostnames>
################################################################################
tcli_nginxsetup_add_domain() {
	declare domain=${1:-}
	declare webhostType=${2:-}
	for domain in $( echo "$1" | xargs -n1 ); do
		tcli_nginxsetup_lookup_domain $domain
		cp $TCLI_NGINXSETUP_PATH_CONF/nginx/sites-available/server.default $TCLI_NGINXSETUP_PATH_TEMP/etc/nginx/sites-available/$domain
		sed -i -e "s/<NGINX_DOMAIN_NAMES>/$domain/g" $TCLI_NGINXSETUP_PATH_TEMP/etc/nginx/sites-available/$domain
		sed -i "s|<NGINXSETUP_WWW_BASE_PATH>|$TCLI_NGINXSETUP_WWW_BASE_PATH|g" $TCLI_NGINXSETUP_PATH_TEMP/etc/nginx/sites-available/$domain
		if [ $TCLI_NGINXSETUP_REMOTE_SET ]; then
			# copy files to server and preserve newlines
			tar -C $TCLI_NGINXSETUP_PATH_TEMP/etc/nginx/sites-available/ -cf - $domain \
			| tcli_nginxsetup_remote_cmd tar --no-same-owner -C $TCLI_NGINXSETUP_PATH_SITES_AVAILABLE -xvf -
			tcli_nginxsetup_remote_cmd "cd $TCLI_NGINXSETUP_PATH_SITES_ENABLED && ln -s $TCLI_NGINXSETUP_PATH_SITES_AVAILABLE$domain"
		else
			cp $TCLI_NGINXSETUP_PATH_TEMP/etc/nginx/sites-available/$domain $TCLI_NGINXSETUP_PATH_SITES_AVAILABLE$domain
			cd $TCLI_NGINXSETUP_PATH_SITES_ENABLED && ln -s $TCLI_NGINXSETUP_PATH_SITES_AVAILABLE/$domain
		fi
		if [ ${DEFAULT_HTML:-} ]; then
			#TODO
			echo "\n\nDEFAULT_HTML $DEFAULT_HTML"
		else
			mkdir -p $TCLI_NGINXSETUP_PATH_TEMP$TCLI_NGINXSETUP_WWW_BASE_PATH$domain/html
			cp $TCLI_NGINXSETUP_DIR/conf/nginx/default.html $TCLI_NGINXSETUP_PATH_TEMP$TCLI_NGINXSETUP_PATH_WWW_BASE$domain/html/index.html
			sed -i -e "s/NGINX_DOMAIN_NAMES/$domain/g" $TCLI_NGINXSETUP_PATH_TEMP$TCLI_NGINXSETUP_PATH_WWW_BASE$domain/html/index.html
			tcli_nginxsetup_remote_cmd "mkdir -p $TCLI_NGINXSETUP_PATH_WWW_BASE$domain/html/"
			tar -C $TCLI_NGINXSETUP_PATH_TEMP$TCLI_NGINXSETUP_PATH_WWW_BASE$domain/html/ -cf - \
  		index.html | 
  		tcli_nginxsetup_remote_cmd tar --no-same-owner -C $TCLI_NGINXSETUP_PATH_WWW_BASE$domain/html/ -xvf -
		fi
		printf "\n$domain finished setup\n" 
		tcli_nginxsetup_remote_cmd "systemctl reload nginx"
	done
}

################################################################################
#  lookup domain
################################################################################
# Params
#   <hostname>
################################################################################
tcli_nginxsetup_lookup_domain() {
	declare domain=$1
	declare topdomain=$(echo $domain | cut -d / -f 3 | cut -d : -f 1 | rev | cut -d . -f 1,2 | rev)
	if [ -z $(dig +short $topdomain) ]; then
		printf "\nWARNING from tcli_nginxsetup_lookup_domain : $topdomain could not be lookup\n" 1>&2
	fi
}

( [[ -n ${ZSH_VERSION:-} && ${ZSH_EVAL_CONTEXT:-} =~ :file$ ]] || 
	[[ -n ${KSH_VERSION:-} && "$(cd -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")" != "$(cd -- "$(dirname -- "${.sh.file}")" && pwd -P)/$(basename -- "${.sh.file}")" ]] || 
	[[ -n ${BASH_VERSION:-} ]] && (return 0 2>/dev/null)
) || . $TCLI_NGINXSETUP_DIR/inc/run.sh
