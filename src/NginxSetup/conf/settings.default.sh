#!/bin/bash

################################################################################
# Nginx Setup
# see more
# src/NginxSetup/conf/settings.default.sh 
################################################################################

# NGINXSETUP
# Used from other script that sources NginxSetup script
# 1 => install nginx and setup, 0=> don't install or setup
TCLI_NGINXSETUP=1
TCLI_NGINXSETUP_PATH_TEMP="$(realpath "${TCLI_NGINXSETUP_CONF/../temp}")"
TCLI_NGINXSETUP_PATH_WWW_BASE="/srv/www/"
TCLI_NGINXSETUP_PATH_SITES_AVAILABLE="/etc/nginx/sites-available/"
TCLI_NGINXSETUP_PATH_SITES_ENABLED="/etc/nginx/sites-enabled/"

# Domain names seperated woth a space
TCLI_NGINX_DOMAIN_NAMES="example.com new.examle.com"
TCLI_NGINX_DOMAIN_NAME_AND_ALIAS="example.com www.example.com"