--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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
vhost_remove (lpath=>'/vspx')
;

vhost_define (lpath=>'/vspx',ppath=>'/vspx/',vsp_user=>'dba',is_brws=>1, def_page=>'index.vsp;index.vspx;')
;

create procedure
sql_user_password (in name varchar)
{
  declare pass varchar;
  pass := NULL;
  whenever not found goto none;
  select pwd_magic_calc (U_NAME, U_PASSWORD, 1) into pass
      from SYS_USERS where U_NAME = name and U_SQL_ENABLE = 1 and U_IS_ROLE = 0;
none:
  return pass;
}
;

create procedure
sql_user_password_check (in name varchar, in pass varchar)
{
  if (exists (select 1 from SYS_USERS where U_NAME = name and U_SQL_ENABLE = 1 and U_IS_ROLE = 0 and
	pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pass))
    return 1;
  return 0;
}
;

create procedure child_node (in node_name varchar, in node varchar)
{
  declare i, l int;
  declare ret, arr any;
  declare exit handler for sqlstate '*'
    {
      dbg_obj_print (__SQL_STATE, __SQL_MESSAGE, node_name);
      return vector ();
    };

  if (node = '.' or node = '..' or isstring (file_stat (node_name, 3)))
    return vector ();

  arr :=
    vector_concat (sys_dirlist (node_name, 0), sys_dirlist (node_name, 1));

  return arr;
}
;

create procedure root_node (in path varchar)
{
  declare i, l int;
  declare ret, arr any;
  arr :=
    vector_concat (sys_dirlist (path, 0), sys_dirlist (path, 1));

  return arr;
}
;


create procedure
get_cust ()
{
  declare mtd, dta any;
  exec ('select customerid, companyname, phone from demo..customers', null, null, vector (), 0, mtd, dta );
  return dta;
}
;

create procedure
get_cust_xml ()
{
  return
   xpath_eval ('//customer',
   coalesce (
   (select XMLELEMENT('customers',
     XMLAGG (
       XMLELEMENT('customer', XMLATTRIBUTES(customerid, companyname, phone)) ) )
     from demo..customers), NULL)
    , 0);
}
;


create procedure
get_cust_meta ()
{
  declare mtd, dta any;
  exec ('select customerid, companyname, phone from demo..customers', null, null, vector (), -1, mtd, dta);
  return mtd[0];
}
;

create procedure
get_xml_meta ()
{
  declare mtd, dta any;
  exec ('select top 1 xtree_doc(''<q/>'') from db.dba.sys_users', null, null, vector (), -1, mtd, dta );
  return mtd[0];
}
;

drop table Ord
;

create table Ord (o_id int primary key, o_stat int default 0)
;

insert into Ord values (1, 0)
;

insert into Ord values (2, 1)
;

insert into Ord values (3, 2)
;

drop table Enum
;

create table Enum (e_id int primary key, e_val varchar)
;

insert into Enum values (1, 'one')
;

insert into Enum values (2, 'two')
;

create procedure
date_fmt (in d datetime)
returns varchar
{
  if (d is null)
    return '';
  return sprintf ('%02d-%02d-%04d', month (d), dayofmonth (d), year (d));
}
;

create procedure
cvt_date (in ds varchar)
{
  return cast (ds as datetime);
}
;

-- permanent in vspx.sql
--create procedure
--cal_icell (inout control vspx_control, in inx int)
--{
--  return (control.vc_parent as vspx_row_template).te_rowset[inx];
--}
--;

-- load vdir_helper.sql;


create procedure xtree_src_doc ()
{
   return xml_tree_doc (
     '<root>
       <node name="row" i="0">
         <node name="row" i="1" />
         <node name="row" i="2" >
           <node name="row" i="3" />
           <node name="row" i="4" />
	 </node>
       </node>
       <node name="row" i="5">
         <node name="row" i="6" />
         <node name="row" i="7" >
           <node name="row" i="8" />
           <node name="row" i="9" />
	 </node>
       </node>
       <node name="row" i="10">
         <node name="row" i="11" />
         <node name="row" i="12" >
           <node name="row" i="13" />
           <node name="row" i="14" />
	 </node>
       </node>
       <node name="row" i="15" />
     </root>');
}
;


create procedure xml_root_node (in path varchar)
{
  return xpath_eval ('/root/*', xtree_src_doc (), 0);
}
;

create procedure xml_child_node (in path varchar, in node varchar)
{
  return xpath_eval (path, node, 0);
}
;
