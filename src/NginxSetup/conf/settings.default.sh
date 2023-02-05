#!/bin/bash

################################################################################
# Nginx Setup
# see more
# src/NginxSetup/conf/settings.default.sh 
################################################################################

# NGINXSETUP
# Used from other script that sources NginxSetup script
# 1 => install nginx and setup, 0=> don't install or setup
NGINXSETUP=1
NGINXSETUP_TEMP="$(realpath "${NGINXSETUP_CONF/../temp}")"
NGINXSETUP_WWW_BASE_PATH="/srv/www/"
NGINXSETUP_SITES_AVAILABLE_PATH="/etc/nginx/sites-available/"
NGINXSETUP_SITES_ENABLED_PATH="/etc/nginx/sites-enabled/"

# Domain names seperated woth a space
NGINX_DOMAIN_NAMES="example.com new.examle.com"
NGINX_DOMAIN_NAME_AND_ALIAS="example.com www.example.com"