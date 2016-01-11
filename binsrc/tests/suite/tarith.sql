--
--  tarrith.sql
--
--  $Id: tarith.sql,v 1.8.10.1 2013/01/02 16:14:58 source Exp $
--
--  Arithmetic tests
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

drop table artm;

create table artm (n1 real, n2 double precision, primary key (n1));

insert into artm values (1.2, atof ('11.11'));

select sprintf ('%.2f', n2) from artm;
ECHO BOTH $IF $EQU $LAST[1] 11.11 "PASSED" "***FAILED";
ECHO BOTH  ": atof stored as " $LAST[1] "\n";

--bug 4118
select count (*) from DB.DBA.SYS_KEYS where KEY_TABLE like case when 201 < 101 then '' else '%' end;
ECHO BOTH $IF $GT $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH  ": BUG4118: case in where returned " $LAST[1] " rows\n";

