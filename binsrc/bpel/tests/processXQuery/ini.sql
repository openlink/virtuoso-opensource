--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
--  
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--  
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--  
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--  
--  

db.dba.vhost_remove (lpath=>'/processXQuery');
db.dba.vhost_define (lpath=>'/processXQuery', ppath=>'/processXQuery', vsp_user=>'dba'); 

create procedure XQUERYSAMPLE_DEPLOY ()
{
  declare scp int;
  BPEL.BPEL.import_script (sprintf ('http://localhost:%s/processXQuery/bpel.xml', server_http_port ()),
	        'XQuerySample', scp);
  BPEL..compile_script (scp);
}
;
		  
commit work
;
		  
XQUERYSAMPLE_DEPLOY ()
;

		  
select count (*) from BPEL.BPEL.script where bs_uri like '%XQuerySample.bpel';
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED:" "***FAILED:";
ECHO BOTH " XQuery.bpel script upload status:" $LAST[1] "\n";

select xpath_eval ('count(/invoiceReport/item)', xml_tree_doc (db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=XQuerySample',server_http_port()), style=>1, soap_action=>'initiate', operation=>'initiate', parameters =>  vector ('par1', xtree_doc ('<n0:XQuerySampleRequest xmlns:n0="http://samples.openlinksw.com/bpel" type="http://samples.openlinksw.com/bpel:XQuerySampleRequestType">
<n0:id type="integer">2</n0:id>
<n0:seller type="integer">Kathreen Smith</n0:seller>
</n0:XQuerySampleRequest>')))));
ECHO BOTH $IF $EQU $LAST[1] "2" "PASSED:" "***FAILED:";
ECHO BOTH " XQuerySample returned " $LAST[1] " items\n";



