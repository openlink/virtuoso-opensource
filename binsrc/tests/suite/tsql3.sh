#!/bin/sh
#  tsql3.sh
#
#  $Id: tsql3.sh,v 1.14.4.5.4.10 2013/01/02 16:15:28 source Exp $
#
#  SQL conformance tests
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2026 OpenLink Software
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

LOGFILE=tsql3.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh
cp -r $VIRTUOSO_TEST/docsrc .

BANNER "STARTED SERIES OF SQL TESTS (tsql3.sh)"

rm -f $DBLOGFILE
rm -f $DBFILE
rm -f noise.txt
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

SHUTDOWN_SERVER
START_SERVER $PORT 1000

LOG + running sql script tnull
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tnull.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tnull.sql"
    exit 1
fi

LOG + running sql script tgeo
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tgeo.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tgeo.sql"
    exit 1
fi

LOG + running sql script tarray
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tarray.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tarray.sql"
    exit 1
fi

LOG + running sql script tarith
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tarith.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tarith.sql"
    exit 1
fi

LOG + running sql script tnumt
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tnumt.sql
LOG + running sql script tnum
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tnum.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: tnum.sql"
    exit 1
fi

RUN date

LOG + running sql script testgz
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/testgz.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: Compression test -- testgz.sql"
    exit 1
fi

LOG + "running sql script testtext.sql (full text search index)"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'table=TTEST1' 'idtype=integer' 'haspk=yes' < $VIRTUOSO_TEST/testtext.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: freetext test integer primary key -- testtext.sql"
    exit 1
fi

if [ "$CURRENT_VIRTUOSO_CAPACITY" = "single" ] # explicit with key option is required for partitioned table
then
    LOG + "running sql script testtext.sql (fti, table TTEST2)"
    RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'table=TTEST2' 'idtype=integer' 'haspk=no' < $VIRTUOSO_TEST/testtext.sql
    if test $STATUS -ne 0
    then
	LOG "***ABORTED: freetext test integer -- testtext.sql"
	exit 1
    fi
    LOG + "running sql script testtext.sql (fti, table TTEST3)"
    RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u 'table=TTEST3' 'idtype=varchar' 'haspk=yes' < $VIRTUOSO_TEST/testtext.sql
    if test $STATUS -ne 0
    then
	LOG "***ABORTED: freetext test varchar primary key -- testtext.sql"
	exit 1
    fi
fi

LOG + running sql script tftt
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tftt.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: freetext triggers test -- tftt.sql"
    exit 1
fi


LOG + running sql script tescape
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tescape.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: C escaping tests -- tescape.sql"
    exit 1
fi

#LOG + running sql script texecute
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/texecute.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: EXEC & company tests -- texecute.sql"
    exit 1
fi

LOG + running sql script tidxksize
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tidxksize.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: Index key sizes test -- tidxksize.sql"
    exit 1
fi

LOG + running sql script tfk
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tfk.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: FK tests -- tfk.sql"
    exit 1
fi

LOG + running sql script tunq
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tunq.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: UNIQUE constraint tests -- tunq.sql"
    exit 1
fi

LOG + running sql script tsparql_values_conflict
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tsparql_values_conflict.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: SPARQL VALUES contradicted by FILTER -- tsparql_values_conflict.sql"
    exit 1
fi

LOG + running sql script tcheck
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tcheck.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: CHECK constraint tests -- tcheck.sql"
    exit 1
fi

LOG + running sql script tdt_no_from_where
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tdt_no_from_where.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: WHERE over a derived table without FROM -- tdt_no_from_where.sql"
    exit 1
fi

LOG + running sql script tft_offband
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tft_offband.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: freetext offband data tests -- tft_offband.sql"
    exit 1
fi

LOG + running sql script tftnear
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tftnear.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: free-text phrase inside NEAR -- tftnear.sql"
    exit 1
fi

LOG + running sql script test_fuzzy
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/test_fuzzy.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: fuzzy search tests -- test_fuzzy.sql"
    exit 1
fi

LOG + running sql script ttext_outer
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/ttext_outer.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: free-text check before an outer join -- ttext_outer.sql"
    exit 1
fi

LOG + running sql script tplmodule
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tplmodule.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: PL modules tests -- tplmodule.sql"
    exit 1
fi

# disabled until internal server is installed
#LOG + running sql script tldap
#RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tldap.sql
#if test $STATUS -ne 0
#then
#    LOG "***ABORTED: LDAP tests -- tldap.sql"
#    exit 1
#fi


LOG + running sql script tchars
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tchars.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: Varchar restrictions test -- tchars.sql"
    exit 1
fi


LOG + running sql script tstrses
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tstrses.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: Limited string session test -- tstrses.sql"
    exit 1
fi

LOG + running sql script trdfnumwrite
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/trdfnumwrite.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: numeric literals in RDF serializations -- trdfnumwrite.sql"
    exit 1
fi

LOG + running sql script trdfinf
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/trdfinf.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: rdf inference -- trdfinf.sql"
    exit 1
fi


LOG + running sql script trdfinfifp
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/trdfinfifp.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: rdf inference -- trdfinfifp.sql"
    exit 1
fi

LOG + running sql script trdfinf_filter
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/trdfinf_filter.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: FILTER on an inferred class or property -- trdfinf_filter.sql"
    exit 1
fi

LOG + running sql script ttrans2
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/ttrans2.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED: rdf inference -- ttrans2.sql"
    exit 1
fi

LOG + running sql script ttrans_target
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/ttrans_target.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: transitive derived table with both ends bound -- ttrans_target.sql"
    exit 1
fi


LOG + running sql script tclforvec
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tclforvec.sql 
if test $STATUS -ne 0
then
    LOG "***ABORTED:  -- tclforvec.sql"
    exit 1
fi

LOG + running sql script tsparql_html
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tsparql_html.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: SPARQL result pages -- tsparql_html.sql"
    exit 1
fi



RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/trdfapi.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED:rdfapi "
    exit 1
fi

LOG + running sql script tquietcast_datetime
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tquietcast_datetime.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: QUIETCAST of datetime -- tquietcast_datetime.sql"
    exit 1
fi

LOG + running sql script tvalues_union
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tvalues_union.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: VALUES in UNION -- tvalues_union.sql"
    exit 1
fi

LOG + running sql script trdforder
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/trdforder.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: SPARQL ORDER BY rank -- trdforder.sql"
    exit 1
fi

LOG + running sql script tsparql_dt_long
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tsparql_dt_long.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: long literals sorted and grouped in SQL -- tsparql_dt_long.sql"
    exit 1
fi

LOG + running sql script tsparql_value_in_o
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tsparql_value_in_o.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: a computed value looked up in the O column -- tsparql_value_in_o.sql"
    exit 1
fi

LOG + running sql script tsparql_strlang_eq
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tsparql_strlang_eq.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: STRLANG () / STRDT () literal and the stored literal -- tsparql_strlang_eq.sql"
    exit 1
fi

LOG + running sql script trdfview_nomatch
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/trdfview_nomatch.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: patterns no quad map can produce -- trdfview_nomatch.sql"
    exit 1
fi


# suite for bug #1092 - commented out for now
if [ "x$SQLOPTIMIZE" = "x" ]
then
    cat $CFGFILE >> $LOGFILE
    LOG + running sql script tviewqual
    RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u follow_std=1 < $VIRTUOSO_TEST/tviewqual.sql
    if test $STATUS -ne 0
    then
	LOG "***ABORTED: view qualifier expansion (off part)"
	exit 1
    fi
    SHUTDOWN_SERVER

    rm -f BACK_$CFGFILE
    mv $CFGFILE BACK_$CFGFILE
    cat BACK_$CFGFILE | sed -e "s/ADD_VIEWS/1/g" > $CFGFILE
    cat $CFGFILE >> $LOGFILE
    START_SERVER $PORT 1000

    LOG + running sql script tviewqual
    RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u follow_std=0 < $VIRTUOSO_TEST/tviewqual.sql
    if test $STATUS -ne 0
    then
	LOG "***ABORTED: view qualifier expansion (on part)"
	exit 1
    fi
fi

    LOG + running sql script tveccli
    RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u follow_std=0 < $VIRTUOSO_TEST/tveccli.sql
    if test $STATUS -ne 0
    then
	LOG "***ABORTED:tveccli "
	exit 1
    fi

cp -R $VIRTUOSO_TEST/tsparup/* .
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u follow_std=0 < $VIRTUOSO_TEST/tsparup/tsparup_run.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED:tsparup "
    exit 1
fi

LOG + running sql script texec_cache
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/texec_cache.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: exec () statement cache after DDL -- texec_cache.sql"
    exit 1
fi

LOG + running sql script txqf_null_datatype
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/txqf_null_datatype.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: __xqf_str_parse_to_rdf_box with a NULL datatype -- txqf_null_datatype.sql"
    exit 1
fi

LOG + running sql script tqn_stack
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT < $VIRTUOSO_TEST/tqn_stack.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: a long chain of query nodes and the thread stack -- tqn_stack.sql"
    exit 1
fi

SHUTDOWN_SERVER

if [ "x$SQLOPTIMIZE" = "x" ]
then
    rm -f $CFGFILE
    mv BACK_$CFGFILE $CFGFILE
fi

rm -f test_file

CHECK_LOG
BANNER "COMPLETED SERIES OF SQL TESTS (tsql3.sh)"
