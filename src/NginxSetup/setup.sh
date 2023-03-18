#!/bin/bash

declare TCLI_NGINXSETUP_DIR="$(dirname "$(realpath "${BASH_SOURCE}")")"
declare TCLI_NGINXSETUP_PATH_INC=${TCLI_NGINXSETUP_DIR}/inc
. ${TCLI_NGINXSETUP_PATH_INC}/shared.sh
. $TCLI_NGINXSETUP_DIR/vendor/Linux.Distribution/src/Distribution/distribution.sh


tcli_nginxsetup_init() {
	[ -d ${TCLI_NGINXSETUP_PATH_TEMP}/etc/nginx/sites-available ] || mkdir -p ${TCLI_NGINXSETUP_PATH_TEMP}/etc/nginx/sites-available
	[ -d ${TCLI_NGINXSETUP_PATH_TEMP}/$TCLI_NGINXSETUP_PATH_WWW_BASE ] || mkdir -p ${TCLI_NGINXSETUP_PATH_TEMP}/$TCLI_NGINXSETUP_PATH_WWW_BASE
}

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
	tcli_packageManager_install certbot
	tcli_packageManager_install python3-certbot-nginx
}

################################################################################
# Install nginx
################################################################################
# pararms
#   nocertbot will not create certificate
################################################################################
tcli_nginxsetup_install() {
	tcli_nginxsetup_prepare
	tcli_packageManager_install nginx
	tcli_nginxsetup_remote_cmd systemctl enable nginx.service
	tcli_nginxsetup_remote_cmd systemctl start nginx.service
}

################################################################################
# Add domian name and create default site with ssl
################################################################################
# Params
#   <hostname>
#		<root>
# 	<siteType>
# 	<confFile> which nginx conf file. Default server.default
################################################################################
tcli_nginxsetup_add_domain() {
	local _domain=${1:-}
	local _wwwBaseRoot=${2:-}
	local _type=${3:-html}
	local _confFile=${4:-}
	case "$3" in
		"html" | "")
			[ -z "$_wwwBaseRoot" ] && _wwwBaseRoot=${TCLI_NGINXSETUP_PATH_WWW_BASE}/${_domain}/public/html
			[ -z "$_confFile" ] && _confFile="${TCLI_NGINXSETUP_PATH_CONF}/nginx/sites-available/server.default"
			mkdir -p ${TCLI_NGINXSETUP_PATH_TEMP}${_wwwBaseRoot}
			tcli_nginxsetup_remote_cmd "mkdir -p ${_wwwBaseRoot}"
			[ -f $_confFile ] || infoscreenFailedExit "custom website conf file '" "${_domain}" "' does not exist"
			printf "adding ${_domain} to nginx with document root at as ${_wwwBaseRoot} with file ${_confFile}"
			tcli_nginxsetup_lookup_domain $_domain
			cp "${_confFile}" "${TCLI_NGINXSETUP_PATH_TEMP}/etc/nginx/sites-available/${_domain}"
			sed -i -e "s/<NGINX_DOMAIN_NAMES>/${_domain}/g" ${TCLI_NGINXSETUP_PATH_TEMP}/etc/nginx/sites-available/${_domain}
			sed -i "s|<NGINXSETUP_WWW_BASE_PATH>|${_wwwBaseRoot}|g" ${TCLI_NGINXSETUP_PATH_TEMP}/etc/nginx/sites-available/${_domain}
			if [ $TCLI_NGINXSETUP_REMOTE_SET ]; then
				if [ ! -d ${TCLI_NGINXSETUP_PATH_TEMP}/etc/nginx/sites-available/$_domain ]; then
					if [ ! $(tcli_nginxsetup_remote_cmd "ls /etc/nginx/sites-available/$_domain > /dev/null") ]; then
						# copy files to server and preserve newlines
						tar -C $TCLI_NGINXSETUP_PATH_TEMP/etc/nginx/sites-available/ -cf - $_domain \
						| tcli_nginxsetup_remote_cmd tar --no-same-owner -C $TCLI_NGINXSETUP_PATH_SITES_AVAILABLE -xvf -
						tcli_nginxsetup_remote_cmd "cd $TCLI_NGINXSETUP_PATH_SITES_ENABLED && ln -s $TCLI_NGINXSETUP_PATH_SITES_AVAILABLE/$_domain"
					else
						printf "tcli_nginxsetup_add_domain: domain conf file exist allready at server. We will not owerwrite." "/etc/nginx/sites-available/$_domain"
						infoscreenwarn
					fi
				fi
			else
				cp ${TCLI_NGINXSETUP_PATH_TEMP}/etc/nginx/sites-available/${_domain} ${TCLI_NGINXSETUP_PATH_SITES_AVAILABLE}/${_domain}
				cd ${TCLI_NGINXSETUP_PATH_SITES_ENABLED} && ln -s ${TCLI_NGINXSETUP_PATH_SITES_AVAILABLE}/${_domain}
			fi
			## @todo create custom html file here
			mkdir -p ${TCLI_NGINXSETUP_PATH_TEMP}${_wwwBaseRoot}
			cp ${TCLI_NGINXSETUP_DIR}/conf/nginx/default.html ${TCLI_NGINXSETUP_PATH_TEMP}${_wwwBaseRoot}/index.html
			sed -i -e "s/NGINX_DOMAIN_NAMES/$_domain/g" ${TCLI_NGINXSETUP_PATH_TEMP}${_wwwBaseRoot}/index.html
			tar -C "${TCLI_NGINXSETUP_PATH_TEMP}${_wwwBaseRoot}/" -cf - index.html | 
			tcli_nginxsetup_remote_cmd tar --no-same-owner -C ${_wwwBaseRoot}/ -xvf -
			;;
		postfixAdmin)
			[ -z "$_wwwBaseRoot" ] && _wwwBaseRoot=${TCLI_NGINXSETUP_PATH_WWW_BASE}/${_domain}/public/html
		;;
		*)
			infoscreenwarn
			printf "tcli_nginxsetup_add_domain: unknown website type '${3}'"
			;;
	esac
	printf "\n$domain finished setup\n" 
	tcli_nginxsetup_remote_cmd "systemctl reload nginx"
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
