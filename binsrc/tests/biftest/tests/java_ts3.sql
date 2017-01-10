--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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

drop type "WRITE_YES";
drop type "WRITE_NO";

create type "WRITE_YES" language JAVA external name 'Write_yes' UNRESTRICTED METHOD "WRITE_FILE_YES" () returns any external type 'V' external name 'write_file_yes';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create type WRITE_YES " $STATE"\n";

select new WRITE_YES().WRITE_FILE_YES();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select new WRITE_YES().WRITE_FILE_YES() " $STATE"\n";

drop type "WRITE_YES";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop type WRITE_YES " $STATE"\n";

create type "WRITE_NO" language JAVA external name 'Write_no' METHOD "WRITE_FILE_NO" () returns any external type 'V' external name 'write_file_no';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  create type WRITE_NO " $STATE"\n";

select new WRITE_NO().WRITE_FILE_NO();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select new WRITE_NO().WRITE_FILE_NO() " $MESSAGE"\n";

drop type "WRITE_NO";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop type WRITE_NO " $STATE"\n";

create type "WRITE_YES" language JAVA external name 'Write_yes' UNRESTRICTED METHOD "WRITE_FILE_YES" () returns any external type 'V' external name 'write_file_yes';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create type WRITE_YES " $STATE"\n";

select new WRITE_YES().WRITE_FILE_YES();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select new WRITE_YES().WRITE_FILE_YES() " $MESSAGE"\n";

drop type "WRITE_YES";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop type WRITE_YES " $STATE"\n";

create type "WRITE_NO" language JAVA external name 'Write_no' METHOD "WRITE_FILE_NO" () returns any external type 'V' external name 'write_file_no';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  create type WRITE_NO " $STATE"\n";

select new WRITE_NO().WRITE_FILE_NO();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select new WRITE_NO().WRITE_FILE_NO() " $MESSAGE"\n";

drop type "WRITE_NO";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop type WRITE_NO " $STATE"\n";

create type "WRITE_YES" language JAVA external name 'Write_yes' UNRESTRICTED METHOD "WRITE_FILE_YES" () returns any external type 'V' external name 'write_file_yes';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create type WRITE_YES " $STATE"\n";

select new WRITE_YES().WRITE_FILE_YES();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select new WRITE_YES().WRITE_FILE_YES() " $MESSAGE"\n";

drop type "WRITE_YES";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop type WRITE_YES " $STATE"\n";

create type "WRITE_NO" language JAVA external name 'Write_no' METHOD "WRITE_FILE_NO" () returns any external type 'V' external name 'write_file_no';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ":  create type WRITE_NO " $STATE"\n";

select new WRITE_NO().WRITE_FILE_NO();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select new WRITE_NO().WRITE_FILE_NO() " $MESSAGE"\n";

drop type "WRITE_NO";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop type WRITE_NO " $STATE"\n";

select new WRITE_YES().WRITE_FILE_YES();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": select new WRITE_YES().WRITE_FILE_YES() " $MESSAGE"\n";
