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

create procedure "VAD"."DBA"."RETRIEVE_HTTP_PARS" ( in afrom any )
{
  declare ato any;
  ato := vector();
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'reg_curdir','1'); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'tree_node_clicked','0'); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'tree_ser',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'reg_action',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'new_folder_name','new_folder'); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'new_item_name','new_item'); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'new_item_value',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'old_item_value',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'new_item_type','STRING'); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'del_item_id',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'items_list',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'result_txt',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'packages_list',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'new_pkg_name','./tmp/new_package.vad'); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'tmp',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'docs_root',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'http_root',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'code_root',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'data_root',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'last_error',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'password',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'user',''); 
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'datasource',''); 
  return ato;

}
;

