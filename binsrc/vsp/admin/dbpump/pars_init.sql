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

create procedure "PUMP"."DBA"."RETRIEVE_HTTP_PARS" ( in afrom any )
{
  declare ato any;
  ato := vector();
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'_datasource','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'datasource','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'comment','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'user','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'owner_mask','%');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'password','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'back','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'accept','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'dump','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'restore','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'lpath','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'rpath','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'print_to_screen','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'tabname','%');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'qualifier','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'selected_qualifier','%');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'qualifier_mask','%');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'text_flag','Binary');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'split_by','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'sql_where','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'from1','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'from2','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'to1','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'to2','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'tab_linkage_calls','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'link_none_if_fails','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'produce_primary_key_by_any_means','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'surround_doublequotes','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'prefix_names','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'prefix_select','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'no_drops','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'no_foreach','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'verbose_flag','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'escape_flag','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'debug_trace','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'default_conversions','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'new_name_for_tables','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'initial_statement','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'select_override','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'unquoted_columns','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'need_table','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'need_system_table','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'need_global_temporary','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'need_view','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'need_synonym','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'need_local_temporary','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'need_alias','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'insert_mode','1');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'maxline','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'hexlen','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'retrieve_tables','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'choice_tables','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'choice_sav','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'dump_name','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'result_txt','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'debug_in_footer','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'upload_flag','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'allow_make_path','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'manual_datasource','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'connected_flag','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'dump_type','1');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'table_defs','on');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'triggers','on');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'stored_procs','on');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'constraints','on');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'fkconstraints','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'views','on');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'users','on');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'grants','on');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'restore_users','on');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'restore_grants','on');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'table_data','on');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'change_qualifier','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'change_owner','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'new_qualifier','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'new_owner','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'change_rqualifier','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'change_rowner','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'new_rqualifier','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'new_rowner','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'show_content','6');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'next_url','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'custom_qual','0');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'custom_dump_opt','0');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'dump_path','./backup');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'dump_dir','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'selected_tables','');
 "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" (afrom,ato,'last_error','');
  return ato;

}
;

