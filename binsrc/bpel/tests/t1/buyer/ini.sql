--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
insert into partner_link_conf values ('Seller', sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file://seller/Seller.bpel', '$U{seller_http_port}'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " Seller script endpoint set status:" $STATE "\n";

upload_script ('file://buyer/','Buyer.bpel','Buyer.wsdl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " Buyer script upload status:" $STATE "\n";

BPEL.BPEL.wsdl_process_remote ('Seller', 
	sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file://seller/Seller.bpel&wsdl', '$U{seller_http_port}'),
	'file://buyer/Buyer.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " Seller WSDL upload status:" $STATE "\n";

create table resOnResult (
	res	varchar
)
;

create procedure BPEL.BPEL.onResult (in POR any)
{
	-- dbg_printf ('onResult is invoked:\n');
	-- dbg_obj_print (POR);
	http_request_status ('HTTP/1.1 202 Accepted');
	http_flush();
	insert into resOnResult values ('DONE');
}
;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " Buyer script: onResult interceptor creation status:" $STATE "\n";

select db.dba.soap_client (direction=>1, url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file://buyer/Buyer.bpel',server_http_port() ), soap_action=>'purchase', operation=>'purchase', parameters =>  vector ('par1', xtree_doc ('<CID> aaa </CID> <Order> order111 </Order>')));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " Buyer script: purchase operation status:" $STATE "\n";

sleep 90;

select * from resOnResult;
ECHO BOTH $IF $EQU $LAST[1] "DONE"  "PASSED" "***FAILED";
ECHO BOTH " The t1 test produced:" $LAST[1] "\n";

select count (bi_last_error) from BPEL.BPEL.instance where bi_last_error is not null;
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "***FAILED";
ECHO BOTH $LAST[1] " errors found" "\n";

