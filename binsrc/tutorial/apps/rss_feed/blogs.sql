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
drop table RSS_FEEDS
;

create table RSS_FEEDS (B_CONTENT long varchar, B_TS datetime, B_USER_ID varchar, B_RSS_URL varchar)
;

create procedure
cal_icell (inout control vspx_control, in inx int)
{
  return (control.vc_parent as vspx_row_template).te_rowset[inx];
}
;

create procedure rss_feed (in url varchar)
{
  declare rss varchar;
  declare xe, xt any;
  rss := http_get (url);
  xt := xml_tree_doc (rss);
  delete from RSS_FEEDS where B_RSS_URL = url;
  xmlsql_update(xslt (TUTORIAL_XSL_DIR () ||'/tutorial/apps/rss_feed/rss2upg.xsl', xt, vector ('url', url)));
}
;


create procedure from_rfc_date (in d varchar)
{
  declare tmp1, tmp, dt varchar;
  tmp := d;
  if (regexp_match ('[0-9][0-9][0-9][0-9][\-]?[0-9][0-9][\-]?[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]', tmp) is not null)
    {
      declare t datetime;
      t := soap_box_xml_entity_validating (xml_tree ('<a>'||d||'</a>'), 'dateTime');
      return datestring (t);
    }
  tmp := d;
  tmp :=  regexp_match ('[0-9]+ [A-Za-z]+ [0-9]+ [0-9]+:[0-9]+:[0-9]+', tmp);
  tmp1 := tmp;
  tmp1 := regexp_match ('[A-Za-z]+', tmp1);
  dt := position (tmp1, vector ('Jan', 'Feb', 'Mar','Apr','May','Jun','Jul','Aug','Sep','Oct', 'Nov', 'Dec'));
  tmp := replace (tmp, tmp1 || ' ', '');
  tmp := sprintf ('%02d' , dt) || ' ' || tmp;
  return tmp;
}
;

grant execute on from_rfc_date to public
;

xpf_extension ('http://temp.uri:from_rfc_date', 'DB.DBA.from_rfc_date')
;

create procedure bs_get_posts (in f date, in url varchar)
{
 declare arr any;
 declare i, l int;
 declare content, postid varchar;
 declare dateCreated, n datetime;
 n := now ();
 if (f is null)
   f := n;
 result_names (content, dateCreated, postid);
 for select B_CONTENT, B_TS, '' as B_POST_ID from RSS_FEEDS where
   B_RSS_URL = url and
   year (B_TS) = year (f) and month (B_TS) = month (f) and dayofmonth (B_TS) = dayofmonth (f)
   order by B_TS desc
   do
    {
      result (B_CONTENT, B_TS, B_POST_ID);
    }
}
;

create procedure bs_get_days (in f date, in url varchar)
{
 declare arr any;
 declare n datetime;
 n := now ();
 if (f is null)
   f := n;
 arr := vector ();
 for select distinct dayofmonth (B_TS) as b_day from RSS_FEEDS where
   B_RSS_URL = url and
   year (B_TS) = year (f) and month (B_TS) = month (f)
   do
    {
      arr := vector_concat (arr, vector (cast (b_day as varchar)));
    }
  return arr;
}
;

create procedure bs_active (in a varchar, in b any)
{
  if (position (a, b))
    return 1;
  return 0;
}
;

create procedure bs_style (in control vspx_control, in name varchar)
{
  declare f vspx_field;
  f := control.vc_find_control (name);
  if (f is not null and f.ufl_active)
    return 'background-color: white;';
  return '';
}
;

create procedure bbs_get (in f date, in url varchar)
{
  declare mtd, dta any;
  declare st, msg varchar;
  st := '00000';
  exec ('bs_get_posts (?,?)', st, msg, vector (f, url), 0, mtd, dta);
  if (dta = 0)
    return vector ();
  return dta;
}
;

create procedure bbs_meta (in f date, in url varchar)
{
  declare mtd, dta any;
  declare st, msg varchar;
  st := '00000';
  exec ('bs_get_posts (?,?)', st, msg, vector (f, url), -1, mtd, dta );
  if (st = '00000')
   return mtd[0];
  else
   return vector ();
}
;

create procedure
bs_date_fmt (in d datetime)
returns varchar
{
  if (d is null)
    d := now();
  return sprintf ('%02d:%02d:%02d', hour (d), minute (d), second (d));
}
;

create procedure
bs_tit_fmt (in d datetime)
returns varchar
{
  if (d is null)
    d := now ();
  return sprintf ('%s, %s %d, %d', dayname (d), monthname (d), dayofmonth (d), year (d));
}
;

create procedure make_wwwroot ()
{
  if (not exists (select 1 from HTTP_PATH where HP_LPATH = '/RPC2' and HP_HOST = '*ini*'))
    {
	  declare bapi, i, l any;
	  declare grant_stmt, gst, gmsg varchar;
	  VHOST_DEFINE (lpath=>'/RPC2', ppath=>'/SOAP/', soap_user=>'MT', soap_opts=>vector ('XML-RPC', 'yes'));
	  bapi := BLOG.."mt.supportedMethods" ();
          i := 0; l := length (bapi);
 	  while (i < l)
	    {
	      grant_stmt := 'grant execute on BLOG.DBA."'||bapi[i]||'" to "MT"';
	      gst := '00000';
	      exec (grant_stmt, gst, gmsg);
	      i := i + 1;
	    }
    }
}
;


make_wwwroot ()
;
