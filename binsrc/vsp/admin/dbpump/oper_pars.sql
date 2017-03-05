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
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'_datasource','','Selected Datasource','Selected Datasource')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'datasource','','Selected Datasource','Selected Datasource')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'comment','','General comment','General comment')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'user','','User Name','This string identifies the user in terms of Virtuoso DBMS core.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'owner_mask','%','Owner Filter','Template for tables selection.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'password','','User Password','This string authenticates the user in terms of Virtuoso DBMS core.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'back','','To previous page','This will discard all operational parameters changes which was made on current page.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'accept','','Accept last changes','This will accept all operational parameters changes which was made on current page.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'dump','','dump','dump')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'restore','','restore','restore')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'lpath','','Local Path','Path on local computer to oper.parsupload.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'rpath','','Remote Path','Path on server to dump schema/tables.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'print_to_screen','','Print To Screen','If true, result in text form will be sent to client. In other case it will be saved at remote path.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'tabname','%','Table Name','Filter of table names.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'qualifier','','Database Qualifier','Database Qualifier.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'selected_qualifier','%','Qualifier Filter','Template for tables selection.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'qualifier_mask','%','Qualifier Filter','Template for tables selection.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'text_flag','Binary','SQL or Binary','Choice of results format.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'split_by','','Split By','Size of maximal result parts in MB.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'sql_where','','Sql Where','This will be used as a filter in dumping of tables.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'from1','','From','.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'from2','','From','.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'to1','','To','.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'to2','','To','.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'tab_linkage_calls','','Produce Table Linkage Calls','Produce Table Linkage Calls .<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'link_none_if_fails','','Link none if any linkage fails ','Link none if any linkage fails .<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'produce_primary_key_by_any_means','','Produce Primary Key by any means ','Produce Primary Key by any means.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'surround_doublequotes','','Surround all column and index names with doublequotes ','Surround all column and index names with doublequotes .<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'prefix_names','','Prefix all names with backslash ','Prefix all names with backslash.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'prefix_select','','Like above but also in select statement ','Like above but also in select statement .<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'no_drops','','No drops ','No drops.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'no_foreach','','Never use foreach ','Never use foreach .<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'verbose_flag','','Brief/Verbose','Brief/Verbose.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'escape_flag','','Type Of Escaping','Escape strange chars/Escape also ISO-8859/1/Escape only single quotes by doubling them<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'debug_trace','','Debug Trace','Debug Trace.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'default_conversions','','Virtuoso Default Conversions ','Virtuoso Default Conversions .<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'new_name_for_tables','','New name for Table','New name for Table.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'initial_statement','','Initial Statement','Initial Statement.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'select_override','','Select Override','Select Override.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'unquoted_columns','','Unquoted Columns','Unquoted Columns.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'need_table','','Dump Tables','Dump Tables.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'need_system_table','','Dump System Tables','Dump System Tables.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'need_global_temporary','','Dump Global Temporary Tables','Dump Global Temporary Tables.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'need_view','','Dump Views','Dump Views.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'need_synonym','','Dump Synonyms','Dump Synonyms.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'need_local_temporary','','Dump Local Temporary','Dump Local Temporary.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'need_alias','','Dump Aliases','DumpAliases.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'insert_mode','1','Insert Mode','INTO/SOFT/REPLACING.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'maxline','','Max Line Length','Max Line Length.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'hexlen','','Max HexLen','Max HexLen.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'retrieve_tables','','List of Available Tables','List of Available Tables')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'choice_tables','','Component For Selecting an Available Tables','Component For Selecting an Available Tables')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'choice_sav','','internal property','internal property')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'dump_name','','Dump Name','File Name of schema/tables data to dump/restore')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'result_txt','','Text explaining the result of last action','Text explaining the result of last action')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'debug_in_footer','','This allows the debug print in footer','This allows the debug print in footer')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'upload_flag','','','')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'allow_make_path','','Allow to make Path','This allows to create nonexisting path in dump  of schema & tables')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'manual_datasource','','This allows you to change datasource by hands rather then define it from listbox.','This allows you to change datasource by hands rather then define it from listbox.')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'connected_flag','','','')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'dump_type','1','Dump Type','Choice between "Everything", "Schema only", "Data only", "Custom" Shows "Custom" when non-default values are defined in Checkboxes #3-#10 on screen "Dump Options"')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'table_defs','on','Include Definition','If true, resulting tables dumps will begin from table definitions.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'triggers','on','Include Triggers Definition','If true, resulting tables dumps will end from trigger definitions.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'stored_procs','on','Include Stored Procs Definition','If true, resulting dumps will contain procs definitions.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'constraints','on','Include Constraints','If true, resulting tables dumps will contain constraints definitions.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'fkconstraints','','Include Foreign Keys Constraints','If true, resulting tables dumps will contain foreign keys constraints definitions.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'views','on','Include Views Definition','If true, resulting dumps will contain views definitions.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'users','on','Include Users Definition','If true, resulting dumps will contain users definitions.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'grants','on','Include Grants Definition','If true, grants will be restored.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'restore_users','on','Restore Users Definition','If true, users will be restored.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'restore_grants','on','Restore Grants Definition','If true, resulting dumps will contain grants definitions.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'table_data','on','Include Table Data','If true, resulting tables dumps will contain data.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'change_qualifier','','Change Qualifier','If true, resulting tables dumps will have custom qualifier.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'change_owner','','Change Owner','If true, resulting tables dumps will have custom owner.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'new_qualifier','','New Qualifier','Custom qualifier for dumped tables.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'new_owner','','New Owner','Custom owner for dumped tables.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'change_rqualifier','','Change Restore Qualifier','If true, resulting tables restores will have custom qualifier.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'change_rowner','','Change Restore Owner','If true, resulting tables restores will have custom owner.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'new_rqualifier','','New Restore Qualifier','Custom qualifier for restored tables.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'new_rowner','','New Restore Owner','Custom owner for restored tables.<br>')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'show_content','6','Show Content','What to show in current dump directory.<br> ')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'next_url','','','')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'custom_qual','0','','')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'custom_dump_opt','0','','')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'dump_path','./backup','Path to dump\'s root directory','Path to dump\'s root directory')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'dump_dir','','Name of the dump\'s root directory','Name of the dump\'s root directory')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'selected_tables','','','')
;
--!AFTER
insert soft "PUMP"."DBA"."DBPUMP_HELP" ("name","dflt","short_help","full_help") values (
'last_error','','','')
;
