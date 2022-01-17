#!/bin/bash
set -e

case "$1" in
   
    '--install')
        for license in $LICENSE_PATH/*; do
            f="$(basename -- $license)"
            printf "\nLicense file: ${f}\n"
            cmu -i -f "${license}" || true
            printf "===========================\n"
        done
        # update license time after installation.
        exec cmu -u
    ;;
  
    '--remove')
        if [ ! -z "$2" ] ; then
            cmu --delete-cmcloud-credentials -s$2 || cmu --del --serial $2
        else
            printf "\nERROR: a license serial was not set!\n"
        fi
    ;;

    '--update')
        exec cmu -u
    ;;

    '--cmdust')
        exec cmu --cmdust
    ;;
    
    '--list')
        exec cmu -l
    ;;

    '--show')
        exec cmu -x
    ;;

    '--showall')
        exec cmu -n --all-servers
    ;;

    *)
        exec "$@"
    ;;
esac