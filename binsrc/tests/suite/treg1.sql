--
--  treg.sql
--
--  $Id$
--
--  Test DB Registry
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

create procedure treg (in n_ents integer, in dt varchar)
{
  declare i integer;
  i :=0;
  while (i < n_ents) {
    declare r_name varchar;
    r_name := convert (varchar, i);
    registry_set (r_name, dt);
    i := i + 1;
  }
};

create procedure treg2 (in n_ents integer, in dt varchar)
{
  declare i integer;
  i :=0;
  while (i < n_ents) {
    declare r_name varchar;
    r_name := concat ('a', convert (varchar, i));
    registry_set (r_name, dt);
    i := i + 1;
  }
};

create procedure tdelreg (in n_ents integer)
{
  declare i integer;
  i :=0;
  while (i < n_ents) {
    declare r_name varchar;
    r_name := concat ('a', convert (varchar, i));
    if (not isstring (registry_remove (r_name)))
      signal ('42000', sprintf ('No registry by name %s', r_name), 'TS001');
    i := i + 1;
  }
};

checkpoint;
treg2 (20000, repeat ('*', 1000));
checkpoint;
tdelreg (20000);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": dropping a large part of the registry\n";
checkpoint;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": checkpoint after dropping a large part of the registry\n";
treg (1000, '-------');
checkpoint;
treg (1000, '***************************');
checkpoint;
treg (1000, '++');
checkpoint;
treg2 (20000, repeat ('*', 1000));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": again adding a large part of the registry\n";
checkpoint;
