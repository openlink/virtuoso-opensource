#!/bin/sh

action=$1
case z$action
    in
    zvirtuoso)
    isql $PORT dba dba < Q.sql > temp.res 
    gawk -f test.awk -v mode=virt temp.res
    ;;

    zmysql)
    isql-iodbc mysql demo demo < Q_mysql.sql > temp.res
    gawk -f test.awk -v mode=virt temp.res
    ;;

    zinno)
    isql-iodbc inno demo demo < Q_mysql.sql > temp.res
    gawk -f test.awk -v mode=virt temp.res
    ;;

    zpostgesql)
    psql demo < Q_psql.sql > temp.res
    gawk -f test.awk -v mode="postgesql" temp.res
    ;;

    zoracle)
    isql-iodbc oralite demo demo < Q_ora.sql > temp.res
    gawk -f test.awk -v mode=oracle temp.res
    ;;

    z*)
    echo "usage (virtuoso | mysql | inno | postgesql | oracle )"
    exit 1
    ;;
esac
    



