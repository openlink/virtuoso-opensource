#!/bin/bash

VALUE=000000

if test \! -f git_head.c 
then
    echo "char * git_head = \"$VALUE\";" > git_head.c
fi

VALUE=`git rev-parse --verify HEAD --short` || exit

echo "char * git_head = \"$VALUE\";" > git_head.c.new

cmp git_head.c git_head.c.new >/dev/null 2>/dev/null || mv git_head.c.new git_head.c

rm -f git_head.c.new

exit 0
