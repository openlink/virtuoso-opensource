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




select * from (select n_nationkey from nation except corresponding by (n_nationkey) select r_regionkey from region) f;

select n_nationkey, n_name from nation union corresponding by (n_nationkey) select r_regionkey, r_name from region;

select 1 + regionkey from nation, region where n_regionkey = r_regionkey order by n_name;

explain ('select 1 + r_regionkey, 1 + n_regionkey, n_name, r_name from nation, region where n_regionkey = r_regionkey order by n_name');
select 1 + r_regionkey, 1 + n_regionkey, n_name, r_name from nation, region where n_regionkey = r_regionkey order by n_name;

explain ('select r_regionkey, n_regionkey, n_name, r_name from nation, d..region where n_regionkey = r_regionkey order by n_nationkey');

explain ('select r_regionkey, n_regionkey, n_name, r_name from d..region, nation where n_regionkey = r_regionkey order by n_nationkey');

explain ('select r_regionkey, n_regionkey, n_name, r_name from d..region, nation where n_regionkey = r_regionkey order by n_nationkey + 0');

explain ('select r_regionkey, n_regionkey, n_name, r_name from region, nation where n_regionkey = r_regionkey order by n_nationkey + 0');


select top 1 * from (select * from lineitem group by l_returnflag) f);
select top 1 * from (select * from d..lineitem group by l_returnflag) f);

select top 1 * from (select * from d..lineitem group by l_returnflag) f;

select top 1 * from lineitem group by l_returnflag;

select top 1 * from d..lineitem group by l_returnflag;

select top 1 * from d..lineitem;

select top 1 * from (select distinct * from lineitem) f;

select top 1 * from (select distinct * from d..lineitem) f;

select * from  (select * from lineitem union select * from d..lineitem) f;


----------------------

select a.row_no, b.row_no from t1 a, (select row_no, max (string2) as ms  from t1 group by row_no) b where a.row_no = b.row_no and ms > '200';

select a.row_no, b.row_no from r1..t1 a, r1..t1 b where a.row_no = b.fi2 order by b.row_no, a.row_no;

select a.row_no, b.row_no from r1..t1 a, r1..t1 b where a.fi2 = b.fi2 order by b.row_no, a.row_no;

select a.row_no, b.row_no from r1..t1 a, r1..t1 b where a.fi2 = b.fi2 order by b.row_no, f(a.row_no);


select a.row_no, b.row_no from r1..t1 a left join t1 b on b.row_no + 1 = a.row_no order by a.row_no;

select a.row_no, b.row_no from r1..t1 a left join t1 b on b.row_no = a.row_no + 1 order by a.row_no;

select a.row_no, b.row_no from r1..t1 a left join t1 b on b.row_no = a.row_no + 1 order by a.fi2;

-- ***
select  a.row_no, b.row_no, mi  from t1, (select row_no, string1, string2, max (fi2) as mi from r1..t1 group by 1, 2, 3) b order by mi;


select  a.row_no, b.row_no, mi  from t1, (select row_no, string1, string2, max (fi2) as mi from r1..t1 group by 1, 2, 3) b order by mi;

select  a.row_no, b.row_no, mi  from t1, (select row_no, string1, string2, max (fi2) as mi from r1..t1 group by 1, 2, 3) b order by a.row_no;

select  a.row_no, b.row_no, mi  from t1 a, (select row_no, string1, string2, max (fi2) as mi from r1..t1 group by 1, 2, 3) b where a.row_no = b.row_no order by a.row_no desc;

select row_no + 1 as r, count (string1) from r1..t1 group by r order by r;
