#!/bin/sh
#
#  summary.sh
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2015 OpenLink Software
#  
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#  
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#  
#  

#egrep "^(\*\*\*.*FAILED|\*\*\*.*ABORTED)" *.test/*.output
detailed=0
if [ "$1" = -d ]
then
    detailed=1
fi
TEST_DIR_SUFFIXES="ro co clro clco"

tlist=`ls -d *.ro *.co *.clro *.clco 2>/dev/null | cut -d "." -f 1,2 --output-delimiter="-" | sort`
rtlist=`ps -A -F | grep "\.\/test_run.sh" | awk 'BEGIN{FS="test_run.sh ";}{ print $NF }' | awk '{ print $2 "-" $1 }' | sort`
ftlist=`echo $rtlist $rtlist $tlist | tr -s '[:blank:]' '\n' | sort | uniq -u`

if [ -n "$rtlist" ]
then
    echo "RUNNING tests:"
    echo "-------------------"
    echo $rtlist
    echo "-------------------"
fi

if [ -n "$ftlist" ]
then
    logs=`find . -type f -name "*.output" | grep -v testall`
    echo "FINISHED tests:"
    echo "-------------------"
    echo $ftlist
    echo "-------------------"

    passed=`find . -type f -name "*.output" -print0 | xargs -0 grep -E "^PASSED" | wc -l`
    failed=`find . -type f -name "*.output" -print0 | xargs -0 grep -E "^\*\*\* ?FAILED" | wc -l`
    aborted=`find . -type f -name "*.output" -print0 | xargs -0 grep -E "^\*\*\* ?ABORTED" | wc -l`

    if [ $failed -gt 0 ]
    then
	echo "    some of failed:"
	echo "-------------------"
	egrep "^(\*\*\*.*FAILED)" $logs | head -n 5
	echo "-------------------"
    fi
    if [ $aborted -gt 0 ]
    then
	echo "    some of aborted:"
	echo "-------------------"
	egrep "^(\*\*\*.*ABORTED)" $logs | head -n 5
	echo "-------------------"
    fi
fi

if [ -n "$tlist" -a -z "$rtlist" ]
then 
    echo "Total PASSED  : $passed"
    echo "Total FAILED  : $failed"
    echo "Total ABORTED : $aborted"

    if [ "$detailed" = 1 ]
    then
	if (expr $failed + $aborted \> 0 > /dev/null)
	then
    	    echo "-------------------"
	    echo "Aborted tests:"
    	    find . -mindepth 1 -type f -name "core*" -print0 | xargs -0 -I "{}" echo "Got a core: {}"
    	    find . -mindepth 1 -type f -name "*.output" -print0 | xargs -0 grep -EnH "^\*\*\* ?ABORTED"
	    echo "-------------------"
    	    echo "Failed tests:"
	    echo "-------------------"
    	    find . -mindepth 1 -type f -name "*.output" -print0 | xargs -0 grep -EnH "^\*\*\* ?FAILED"
	fi
    else
	echo all FAILED and ABORTED tests:
	echo "-------------------"
	for f in `egrep -ls "^(\*\*\*.*FAILED|\*\*\*.*ABORTED)" *.test/*.output *.ro/*.output *.co/*.output *.clro/*.output *.clco/*.output` 
	do 
	    #basename $f .output 
	    echo $f
	done
    fi
fi

if [ -z "$tlist" ]
then
    echo "No test results, run some tests..."
fi
