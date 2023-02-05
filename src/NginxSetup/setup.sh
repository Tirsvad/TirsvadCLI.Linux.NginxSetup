#!/bin/bash
NGINXSETUP_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")" 
. $NGINXSETUP_DIR/inc/shared.sh

[ -d ${NGINXSETUP_TEMP}/etc/nginx/sites-available ] || mkdir -p ${NGINXSETUP_TEMP}/etc/nginx/sites-available
[ -d ${NGINXSETUP_TEMP}/$NGINXSETUP_WWW_BASE_PATH ] || mkdir -p ${NGINXSETUP_TEMP}/$NGINXSETUP_WWW_BASE_PATH
. $NGINXSETUP_DIR/vendor/Linux.Distribution/src/Distribution/distribution.sh

case $DISTRIBUTION_ID in
	"Debian GNU/Linux")
		. $NGINXSETUP_DIR/inc/packagesDebian10.sh
		;;
	"Ubuntu")
		. $NGINXSETUP_DIR/inc/packagesDebian10.sh
		;;
esac

################################################################################
# Remote setup if using ssh
################################################################################
# nginx_remote 0 # we do things directly on server
# nginx_remote 1 <function that can take commands as argument>
# Requre password less connection for non-interactive
################################################################################
nginxsetup_remote() {
	if [ ${1:-0} ] && [ $2 ]; then
		NGINXSETUP_REMOTE_SET=$1
		NGINXSETUP_REMOTE_CMD=$2
	elif [ $remote -eq 1 ]; then 
		NGINXSETUP_REMOTE_SET=0
		printf "setup.sh no remote" 1>&3
	fi
}

################################################################################
# Check and install needed packages
################################################################################
nginxsetup_prepare() {
	# Get requiered tools
	pkgs_install $PKGS_CERTBOT_INSTALL
	pkgs_install $PKGS_PYTHON_CERTBOT_NGINX_INSTALL
}

################################################################################
# Install nginx
################################################################################
# pararms
#   nocertbot will not create certificate
################################################################################
nginxsetup_install() {
	nginxsetup_prepare
	# for arg in "$@"; do
	# 	[ arg=="nocertbot" ] && local certbot=1
	# 	shift
	# done
	pkgs_install $PKGS_NGINX_INSTALL
	$NGINXSETUP_REMOTE_CMD "systemctl enable nginx.service"
	$NGINXSETUP_REMOTE_CMD "systemctl start nginx.service"
}

################################################################################
# Add domian name and create default site with ssl
################################################################################
# Params
#   <hostnames>
################################################################################
nginxsetup_add_domain() {
	local domains=$@
	for domain in $( echo "$@" | xargs -n1 ); do
		nginxsetup_lookup_domain $domain
		cp $NGINXSETUP_CONF/nginx/sites-available/server.default $NGINXSETUP_TEMP/etc/nginx/sites-available/$domain
		sed -i -e "s/<NGINX_DOMAIN_NAMES>/$domain/g" $NGINXSETUP_TEMP/etc/nginx/sites-available/$domain
		sed -i "s|<NGINXSETUP_WWW_BASE_PATH>|$NGINXSETUP_WWW_BASE_PATH|g" $NGINXSETUP_TEMP/etc/nginx/sites-available/$domain
		if [ $NGINXSETUP_REMOTE_SET ]; then
			# copy files to server and preserve newlines
			tar -C $NGINXSETUP_TEMP/etc/nginx/sites-available/ -cf - \
  		$domain | 
  		$NGINXSETUP_REMOTE_CMD tar --no-same-owner -C $NGINXSETUP_SITES_AVAILABLE_PATH -xvf -
			#$NGINXSETUP_REMOTE_CMD "printf "$myvar" > $NGINXSETUP_SITES_AVAILABLE_PATH$domain"
			$NGINXSETUP_REMOTE_CMD "cd $NGINXSETUP_SITES_ENABLED_PATH && ln -s $NGINXSETUP_SITES_AVAILABLE_PATH$domain"
		else
			cp $NGINXSETUP_TEMP/etc/nginx/sites-available/$domain $NGINXSETUP_SITES_AVAILABLE_PATH$domain
			cd $NGINXSETUP_SITES_ENABLED_PATH && ln -s $NGINXSETUP_SITES_AVAILABLE_PATH/$domain
		fi
		if [ ${DEFAULT_HTML:-} ]; then
			#TODO
			echo "\n\nDEFAULT_HTML $DEFAULT_HTML"
		else
			mkdir -p $NGINXSETUP_TEMP$NGINXSETUP_WWW_BASE_PATH$domain/html
			cp $NGINXSETUP_DIR/conf/nginx/default.html $NGINXSETUP_TEMP$NGINXSETUP_WWW_BASE_PATH$domain/html/index.html
			sed sed -i -e "s/NGINX_DOMAIN_NAMES/$domain/g" $NGINXSETUP_TEMP$NGINXSETUP_WWW_BASE_PATH$domain/html/index.html
			$NGINXSETUP_REMOTE_CMD "mkdir -p $NGINXSETUP_WWW_BASE_PATH$domain/html/"
			tar -C $NGINXSETUP_TEMP$NGINXSETUP_WWW_BASE_PATH$domain/html/ -cf - \
  		index.html | 
  		$NGINXSETUP_REMOTE_CMD tar --no-same-owner -C $NGINXSETUP_WWW_BASE_PATH$domain/html/ -xvf -
		fi
		printf "\n$domain finished setup\n" 
		$NGINXSETUP_REMOTE_CMD "systemctl reload nginx"
	done
}

################################################################################
#  lookup domain
################################################################################
# Params
#   <hostname>
################################################################################
nginxsetup_lookup_domain() {
	local DOMAIN=$1
	TOPDOMAIN=$(echo $DOMAIN | cut -d / -f 3 | cut -d : -f 1 | rev | cut -d . -f 1,2 | rev)
	if [ -z $(dig +short $DOMAIN) ]; then
		printf "\nWARNING from nginxsetup_lookup_domain : $DOMAIN could not be lookup\n" 1>&2
	fi
}

( [[ -n ${ZSH_VERSION:-} && ${ZSH_EVAL_CONTEXT:-} =~ :file$ ]] || 
	[[ -n ${KSH_VERSION:-} && "$(cd -- "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")" != "$(cd -- "$(dirname -- "${.sh.file}")" && pwd -P)/$(basename -- "${.sh.file}")" ]] || 
	[[ -n ${BASH_VERSION:-} ]] && (return 0 2>/dev/null)
) || . $NGINXSETUP_DIR/inc/run.sh
