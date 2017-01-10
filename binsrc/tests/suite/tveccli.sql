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

create procedure p (in r int)
{
  result_names (r);
  result (r);
  end_result ();
  result (r + 1);
  return r + 2;
}


p (2);
echo both $if $equ $last[1]  2 "PASSED" "***FAILED";
echo both ": veccli 1\n";

call p (2);
echo both $if $equ $last[1]  3 "PASSED" "***FAILED";
echo both ": veccli 2\n";

foreach integer between 1 1  p (?);

foreach integer between 1 1 call p (?);
echo both $if $equ $last[1]  2 "PASSED" "***FAILED";
echo both ": veccli 3\n";


create procedure pv (in r int)
{
  vectored;
  result_names (r);
  result (r);
  end_result ();
  result (r + 1);
  return r + 2;
}




pv (2);
echo both $if $equ $last[1]  2 "PASSED" "***FAILED";
echo both ": veccli 1\n";


call pv (2);
echo both $if $equ $last[1]  3 "PASSED" "***FAILED";
echo both ": veccli 2\n";


foreach integer between 1 1  pv (?);


foreach integer between 1 1 call pv (?);
echo both $if $equ $last[1]  2 "PASSED" "***FAILED";
echo both ": veccli 3\n";

create procedure inc1 (in i int) returns int
{
  vectored;
  return i + 1;
}


create procedure inc2 (in i int)
{
  return inc1 (i);
}

call inc1 (22);


foreach integer between 1 1 inc1 (?);

select inc1 (22);
echo both $if $equ $last[1] 23 "PASSED" "***FAI:FAILED";
echo both ": inc1 vec\n";



foreach integere between 1 1 select inc1 (?);
