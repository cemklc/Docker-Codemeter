#!/bin/bash
set -e

case "$1" in
   
   '--server')
	sed -i "s/255.255.255.255/$LICENSE_SERVER/" /etc/wibu/CodeMeter/Server.ini
        exec CodeMeterLin -v
    ;;

   '--webadmin')
	exec cmu --set-access-data --password sinecins
        exec CmWebAdmin
    ;;
   
   '--update')
        exec cmu -u
    ;;

   '--cmdust')
        exec cmu --cmdust
    ;;
    
    '--check')
        exec cmu -l
    ;;
   
   *)
        exec "$@"
    ;;
esac
