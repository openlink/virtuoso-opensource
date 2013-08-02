--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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
BPEL.BPEL.upload_script('file://echovirt','echovirt.bpel','echovirt.wsdl','echovirt');

ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " echovirt script upload status:" $STATE "\n";

select  xpath_eval ('/echovirtResponse/result/text()',xml_tree_doc (DB.DBA.soap_client (direction=>1,style=>1,url=>sprintf ('http://localhost:%s/echovirt',server_http_port()), operation=>'process',soap_action=>'process', parameters=> vector ('par1', xtree_doc ('<echovirtRequest xmlns="http://openlinksw.com"><name>John</name><fname>Smith</fname></echovirtRequest>')))));

ECHO BOTH $IF $EQU $LAST[1] "Hello John Smith" "PASSED:" "***FAILED:";
ECHO BOTH " echovirt invocation result: " $LAST[1] "\n";

--url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file://echovirt/echovirt.bpel',server_http_port()),

create procedure BPEL.BPEL.temp_echovirt()
{
  declare scp_id, scp_id_new int;
  declare vdir varchar;

  whenever not found goto nf;

  select bs_id, bs_lpath into scp_id, vdir
    from BPEL.BPEL.script
   where bs_state = 0 and bs_name = 'file://echovirt/echovirt.bpel';

  scp_id_new := BPEL..copy_script(scp_id);
  BPEL..script_source_update(scp_id_new, 'file://echovirt/echovirtNew.bpel',null);
  BPEL..compile_script(scp_id_new,vdir);

  return 1;
  nf: return 0;
};

BPEL.BPEL.temp_echovirt();
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " echovirt script redifined status:" $STATE "\n";

select  xpath_eval ('/echovirtResponse/result/text()',xml_tree_doc (DB.DBA.soap_client (direction=>1,style=>1,url=>sprintf ('http://localhost:%s/echovirt',server_http_port()),operation=>'process',soap_action=>'process', parameters=> vector ('par1', xtree_doc ('<echovirtRequest xmlns="http://openlinksw.com"><name>John</name><fname>Smith</fname></echovirtRequest>')))));

ECHO BOTH $IF $EQU $LAST[1] "Redefined: Hello John Smith" "PASSED:" "***FAILED:";
ECHO BOTH " echovirt invocation result: " $LAST[1] "\n";

drop procedure BPEL.BPEL.temp_echovirt;
