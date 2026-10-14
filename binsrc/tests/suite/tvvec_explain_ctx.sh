#!/bin/sh
#
#  tvvec_explain_ctx.sh
#
#  Driver for the shared report-context (trset_ctx_t) test.
#
#  Background.  Every BIF that reports through trset_printf () -- explain (),
#  status (), http_acl_stats (), xmlenc_test (), the query-log plan dump --
#  shares one context allocated by trset_start ().  __vvec_explain_str added a
#  member to that struct, tc_ses: when set, trset_printf appends to a string
#  session instead of pushing result rows.  __vvec_explain_str allocates its
#  context with dk_alloc_box_zero () and assigns tc_ses; trset_start () uses
#  dk_alloc_box (), which does not zero, and never assigned it.  So every
#  other reporter read an uninitialised pointer: NULL by luck, or a non-NULL
#  value that swallows the whole report, or a wild one that segfaults.  On a
#  fresh database the segfault landed during startup, so the server could not
#  be brought up at all.
#
#  Two halves, because only one of them is reproducible:
#
#    * structural -- assert from the source that trset_start () initialises
#      every member of trset_ctx_t (or allocates the context zeroed).  This is
#      the deterministic half, and it also catches the *next* member added to
#      the struct without an initialiser, which is how this one arrived.
#    * observable -- tvvec_explain_ctx.sql drives every trset reporter reachable
#      from SQL, interleaved with __vvec_explain_str, and asserts each still
#      produces its output.  A non-NULL tc_ses shows up there as a report with
#      zero rows, a wild one as a lost connection.
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

LOGFILE=`pwd`/tvvec_explain_ctx.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED report context (trset_ctx_t) test (tvvec_explain_ctx.sh)"

#
#  Part 1: structural.  Every member of trset_ctx_t must be initialised by
#  trset_start (), either explicitly or by allocating the context zeroed.
#
SQLBIF_H=$TOP/libsrc/Wi/sqlbif.h
SQLPRT_C=$TOP/libsrc/Wi/sqlprt.c

if test ! -f "$SQLBIF_H" -o ! -f "$SQLPRT_C"
then
    LOG "***FAILED: cannot read $SQLBIF_H / $SQLPRT_C (is \$TOP set?)"
else
    #  Member names of trset_ctx_t, one per line.  Comments (including the
    #  multi-line one on tc_ses) are stripped first, then the identifier
    #  immediately before each ';' is the member.
    MEMBERS=`awk '
      /typedef[ \t]+struct[ \t]+trset_ctx_s/ { inb = 1; next }
      inb && /^}/                            { exit }
      inb {
        line = $0
        while (incomment) {
          p = index (line, "*/")
          if (p == 0) { line = ""; break }
          line = substr (line, p + 2); incomment = 0
        }
        while ((p = index (line, "/*")) > 0) {
          rest = substr (line, p + 2)
          q = index (rest, "*/")
          if (q == 0) { line = substr (line, 1, p - 1); incomment = 1; break }
          line = substr (line, 1, p - 1) " " substr (rest, q + 2)
        }
        n = split (line, parts, ";")
        for (i = 1; i < n; i++) {
          decl = parts[i]
          gsub (/\[[^]]*\]/, "", decl)
          gsub (/[^A-Za-z0-9_ \t]/, " ", decl)
          m = split (decl, words, /[ \t]+/)
          if (m > 1 && words[m] != "") print words[m]
        }
      }' "$SQLBIF_H"`

    #  The body of trset_start (), from its definition to the closing brace in
    #  column 1.
    BODY=`awk '
      /^trset_start[ \t]*\(/ { inb = 1 }
      inb                    { print }
      inb && /^}/            { exit }' "$SQLPRT_C"`

    if test "x$MEMBERS" = "x"
    then
        LOG "***FAILED: could not parse the members of trset_ctx_t from $SQLBIF_H"
    elif test "x$BODY" = "x"
    then
        LOG "***FAILED: could not find trset_start () in $SQLPRT_C"
    else
        ZEROED=0
        echo "$BODY" | grep -E 'dk_alloc_box_zero[ \t]*\([ \t]*sizeof[ \t]*\([ \t]*trset_ctx_t' >/dev/null 2>&1 && ZEROED=1
        echo "$BODY" | grep -E 'memset[ \t]*\([ \t]*ctx[ \t]*,[ \t]*0' >/dev/null 2>&1 && ZEROED=1

        MISSING=
        for m in $MEMBERS
        do
            if test $ZEROED -eq 1
            then
                continue
            fi
            if echo "$BODY" | grep -E "ctx[ \t]*->[ \t]*$m[ \t]*=" >/dev/null 2>&1
            then
                :
            else
                MISSING="$MISSING $m"
            fi
        done

        if test "x$MISSING" = "x"
        then
            LOG "PASSED: trset_start () initialises every trset_ctx_t member (`echo $MEMBERS | tr '\n' ' '`)"
        else
            LOG "***FAILED: trset_start () leaves trset_ctx_t member(s) uninitialised:$MISSING"
        fi
    fi
fi

#
#  Part 2: observable.  Drive every trset reporter reachable from SQL.
#
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

LOG + run tvvec_explain_ctx.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_explain_ctx.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_explain_ctx.sql"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED report context (trset_ctx_t) test (tvvec_explain_ctx.sh)"
