--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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

db.dba.vhost_remove (lpath=>'/processXSLT');
db.dba.vhost_define (lpath=>'/processXSLT', ppath=>'/processXSLT', vsp_user=>'dba'); 

create procedure XSLTSAMPLE_DEPLOY ()
{
  declare scp int;
  BPEL.BPEL.import_script (sprintf ('http://localhost:%s/processXSLT/bpel.xml', server_http_port ()),
	        'XSLTSample', scp);
  BPEL..compile_script (scp);
}
;
		  
commit work
;
		  
XSLTSAMPLE_DEPLOY ()
;

		  
select count (*) from BPEL.BPEL.script where bs_uri like '%XSLTSample.bpel';
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED:" "***FAILED:";
ECHO BOTH " XSLTSample.bpel script upload status:" $LAST[1] "\n";

select xpath_eval ('/creditResult/footer/text()', xml_tree_doc (db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=XSLTSample',server_http_port()), style=>1, soap_action=>'initiate', operation=>'initiate', parameters =>  vector ('par1', xtree_doc ('<n0:request xmlns:n0="http://samples.openlinksw.com/bpel" type="http://samples.openlinksw.com/bpel:requestT">
<n0:ssn type="string">1234567</n0:ssn>
<n0:fname type="string">John</n0:fname>
<n0:lname type="string">Smith</n0:lname>
</n0:request>')))));
ECHO BOTH $IF $EQU $LAST[1] "Rate is 100" "PASSED:" "***FAILED:";
ECHO BOTH " XSLTSample invoke: " $LAST[1] "\n";



