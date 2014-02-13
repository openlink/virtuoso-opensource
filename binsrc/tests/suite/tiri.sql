--
--  $Id: tiri.sql,v 1.5.2.1.4.2 2013/01/02 16:15:11 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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

-- IRI_ID type


drop table it;
drop table at;
drop table it2;
create table it (i IRI_ID_8 primary key);
create table at (i any primary key);


insert into it values (#i1);
insert into it values (#i2);
insert into it values (#i3);
insert into it values (iri_id_from_num (4000000003));
insert into it values (iri_id_from_num (4000003000));


insert into at values (#i1);
insert into at values (#i2);
insert into at values (#i3);
insert into at values (iri_id_from_num (-3));
insert into at values (iri_id_from_num (-3000));


insert into it values (#i1);
echo both $if $equ $sqlstate 23000 "PASSED" "***FAILED";
echo both " IRI_ID IRI_ID unq\n";

insert into at values (#i1);
echo both $if $equ $sqlstate 23000 "PASSED" "***FAILED";
echo both " any IRI_ID unq\n";

select iri_id_num (max (i)) from it;
echo both  $if $equ $last[1] 4000003000 "PASSED" "***FAILED";
echo both " IRI_ID max\n";

select iri_id_num (max (i)) from at;
echo both  $if $equ $last[1] -3 "PASSED" "***FAILED";
echo both " any  IRI_ID max\n";


select count (distinct i) from it;

select * from it a, it b table option (hash) where a.i = b.i option (order);
echo both $if $equ $rowcnt 5 "PASSED" "***FAILED";
echo both " IRI_ID hash join\n";


select * from at a, at b table option (hash) where a.i = b.i option (order);
echo both $if $equ $rowcnt 5 "PASSED" "***FAILED";
echo both " any IRI_ID hash join\n";





select * from it order by iri_id_num (i);
select * from it a, it b table option (loop) where a.i = b.i option (order);
echo both $if $equ $rowcnt 5 "PASSED" "***FAILED";
echo both " IRI_ID loop  join\n";

create table it2 (ik IRI_ID, id IRI_ID, primary key (ik));

insert into it2 select i, i from it;
insert into it2 select iri_id_from_num (iri_id_num (i) + 10), i from it;

select id, count (*) from it2 group by id;
echo both $if $equ $rowcnt 5 "PASSED" "***FAILED";
echo both " IRI_ID group by\n";

select * from it2 order by id desc;
echo both $if $equ $last[1] #i11 "PASSED" "**FAILED";
echo both " IRI_ID order by\n";

select a.ik from it2 a where not exists (select 1 from it2 b table option (loop) where b.ik = a.ik);
echo both $if $equ $rowcnt 0 "PASSED" "**FAILED";
echo both " iri id in order.\n";

-- testing ro2sq with invalid values

create procedure tro2sqv_res (in xx any)
{
  declare x any;
  result_names (x);
  foreach (any e in xx) do
    result (e);
}
;

create procedure trov ()
{
  return vector (0, null, #i1, #i1000000, 10, now (), rdf_box (0, 257, 257, 1000000, 0));
}
;

create procedure tro2sqv1 ()
{
  declare iv any;
  declare ov any;
  iv := trov ();
  for vectored (in i any := iv, out ov := o)
    {
      declare o any;
       o := __ro2sq (i);  
    }
  tro2sqv_res (ov);
}
;

create procedure tro2sqv2 ()
{
  declare iv any array;
  declare ov any array;
  iv := trov ();
  for vectored (in i any array := iv, out ov := o)
    {
      declare o any array;
       o := __ro2sq (i);  
    }
  tro2sqv_res (ov);
}
;

create procedure tro2sqv3 ()
{
  declare iv any array;
  declare ov any;
  iv := trov ();
  for vectored (in i any array := iv, out ov := o)
    {
      declare o any;
       o := __ro2sq (i);  
    }
  tro2sqv_res (ov);
}
;

create procedure tro2sqv4 ()
{
  declare iv any;
  declare ov any array;
  iv := trov ();
  for vectored (in i any := iv, out ov := o)
    {
      declare o any array;
       o := __ro2sq (i);  
    }
  tro2sqv_res (ov);
}
;

tro2sqv1 ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ro2sq heterogeneous values from any to any : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

tro2sqv2 ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ro2sq heterogeneous values from boxes to boxes : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

tro2sqv3 ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ro2sq heterogeneous values from boxes to any : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

tro2sqv4 ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ro2sq heterogeneous values from any to boxes : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure tro2sqv5 ()
{
  declare iv any;
  declare ov any array;
  declare i int;
  iv := trov ();
  i := 0;
  for vectored (in i any := iv, out ov := o)
    {
      declare o any array;
      if (i < 5)
        o := __ro2sq (i);  
      else
        o := __ro2sq (i);  
    }
  tro2sqv_res (ov);
}
;

tro2sqv5 ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ro2sq heterogeneous values from any to boxes with conditinal branch : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
