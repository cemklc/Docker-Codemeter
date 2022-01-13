#!/bin/bash
set -e

case "$1" in
   
   '--server')
        exec CodeMeterLin -v
    ;;

   '--webadmin')
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
