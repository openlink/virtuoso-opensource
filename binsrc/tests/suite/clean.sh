#!/bin/sh
#  clean.sh
#
#  $Id:
#
#  Change above line and this line
#  
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#  
#  Copyright (C) 1998-2006 OpenLink Software
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

# 
#  Clean up the mess
#

. ./test_fn.sh

rm -f *.log
rm -f *.out
rm -f *.output
rm -f comp.ok comp.tmp
rm -f ident.txt audit.txt dump backup.stat
rm -f core core.* debug.txt ftp_test_file test_file new.ini
rm -f $DELETEMASK
rm -rf remote1 remote2 t1 t2 t3 nw1 nw2 nw3 nw4 nw5 
rm -f virtuoso.ini virtuoso.lck virtuoso.trx virtuoso.db virtuoso.log
rm -rf http tproxy rep1 rep2 rep3 xslt wcopy oremote1 oremote2 vspx soap12  
rm -f txslt.diff vvv?.bp
rm -f tpc-d/tpcd.output tpc-d/tsqlo.output  
rm -f virt.odbc t1.xml t2.xml t3.xml t4.xml bpel4ws.vad bpel_temp.sql 
rm -rf plugins msdtc1 msdtc2 msdtc3 tutorial_test fault1_req fault1 "echo" Flow bpel_audit vad 
rm -f *.svr
rm -f wierr.rep1 wierr.rep2 wierr.rep3
rm -f noise.txt
rm -f $SRVMSGLOGFILE
