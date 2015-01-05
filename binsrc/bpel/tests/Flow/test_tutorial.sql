--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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


create procedure test_flow (in ssn varchar)
{
  declare req any;
  req := xtree_doc (sprintf ('<loanApplication xmlns="http://www.autoloan.com/ns/autoloan"><SSN>%s</SSN><email>%s</email><customerName>%s</customerName><loanAmount>%s</loanAmount><carModel>%s</carModel><carYear>%s</carYear><creditRating></creditRating></loanApplication>', ssn, 'user@dot.domain', 'Joe Doe', '15000.00', 'BMW', '2004'));

      db.dba.soap_client (
      direction=>1,
      url=>sprintf ('http://localhost:%s/LoanFlow',
                      server_http_port()),
      soap_action=>'initiate',
      operation=>'initiate',
      style=>1,
      parameters =>  vector ('par1', req));
  commit work;
}
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create procedure test_flow " $STATE "\n";

select * from BPEL..resonresult;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rows in BPEL..resonresult: " $ROWCNT "\n";

test_flow ('75310');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": call test_flow " $STATE "\n";

delay (5);

select res[8] from BPEL..resonresult;
ECHO BOTH $IF $EQU $LAST[1] APR "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": test_flow result res[8] : " $LAST[1] "\n";
