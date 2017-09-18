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

/* Aggregate concat */

create procedure yac_rep_exec (in _attached_qual varchar, in _attached_owner varchar, in _attached_name varchar,
			       inout _stmt any, inout _stat any, inout _msg any)
{
   _stmt := replace (_stmt, '''', '''''');
   _stmt := sprintf ('create nonincremental snapshot "%I"."%I"."%I" as ''%s''',
	 _attached_qual, _attached_owner, _attached_name, _stmt);
   return exec (_stmt, _stat, _msg);
}
;


create function yac_agg_concat_init (inout _agg varchar)
{
  _agg := ''; -- The "accumulator" is a string session. Initially it is empty.
};

create function yac_agg_concat_acc (
  inout _agg any,		-- The first parameter is used for passing "accumulator" value.
  in _val varchar,	-- Second parameter gets the value passed by first parameter of aggregate call.
  in _sep varchar )	-- Third parameter gets the value passed by second parameter of aggregate call.
{
  if (_val is null)	-- Attributes with NULL names should not affect the result.
    return;
  if (_sep is null)
    _agg := concat (_agg, _val);
  else
    _agg := concat (_agg, _val, _sep);
};

create function yac_agg_concat_final (inout _agg any) returns varchar
{
  declare _res varchar;
  if (_agg is null)
    return '';
  _res := _agg;
  return _res;
};

create aggregate yac_agg_concat (in _val varchar, in _sep varchar) returns varchar
  from yac_agg_concat_init, yac_agg_concat_acc, yac_agg_concat_final;

/* /Aggregate concat */


create procedure
yacutia_exec_no_error (in expr varchar)
{
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

create procedure
get_xml_meta ()
{
  declare mtd, dta any;
  exec ('select top 1 xtree_doc(''<q/>'') from db.dba.sys_users',
        null, null, vector (), -1, mtd, dta );
  return mtd[0];
}
;

create procedure
yacutia_pars_http_log_file (in log_file_name varchar,
                            inout pattern varchar,
                            inout r_sel varchar,
                            inout _type any)
{
   declare one_line varchar;
   declare pos, idx, len integer;
   declare res, res_line any;
   declare temp, l_part, _all any;

--   declare log_file_name varchar;
--   log_file_name := 'http05082002.log';

   _all := file_to_string (log_file_name);
   _all := split_and_decode (_all, 0, '\0\0\n');

   idx := 0;
   len := length (_all) - 1;
   res := vector ();
   _type := atoi (_type);

   while (idx < len)
     {
  one_line := _all [idx];

  pos := strstr (one_line, '[');
  l_part := "LEFT" (one_line, pos - 1);
  one_line := "RIGHT" (one_line, length (one_line) - pos);
  res_line := split_and_decode (l_part, 0, '\0\0 ');
  temp := split_and_decode (one_line, 0, '\0\0]');
  res_line := vector_concat (res_line, vector (concat (temp[0], ']')));
  one_line := "RIGHT" (one_line, length (one_line) - length (temp[0]) - 2);
  temp := split_and_decode (one_line, 0, '\0\0"');
  res_line := vector_concat (res_line, vector (temp[1]));
  res_line := vector_concat (res_line, split_and_decode (trim (temp[2]),  0, '\0\0 '));
  res_line := vector_concat (res_line, vector (temp[3]));
  res_line := vector_concat (res_line, vector (temp[5]));

        if (pattern <> '')
          {
--
--    FILTER
--
             if (not _type)
               {
       declare idx_f, fl integer;

       idx_f := 0;
       fl := 0;

       while (idx_f < length(res_line))
         {
            if (strstr (res_line[idx_f], pattern) is not NULL)
        fl := 1;
            idx_f := idx_f + 1;
         }

       if (fl and (yacutia_pars_http_radio_sel (res_line, r_sel)))
          res := vector_concat (res, vector (res_line));
               }
             else
               {
                   if (strstr (res_line[_type-1], pattern) and
                       (yacutia_pars_http_radio_sel (res_line, r_sel)))
          res := vector_concat (res, vector (res_line));
               }
          }
        else
          {
             if (yacutia_pars_http_radio_sel (res_line, r_sel))
         res := vector_concat (res, vector (res_line));
          }

  idx := idx + 1;
     }

   return res;
}
;

create procedure
yacutia_pars_http_radio_sel (inout _line any, in _mode varchar)
{
   if (_mode = 'all') return 1;
   if (_mode = 'fail' and _line[5] <> '200') return 1;
   if (_mode = 'succ' and _line[5] = '200') return 1;
   return 0;
}
;

create procedure
yacutia_http_log_ui_labels ()
{
   return vector ('Remote Host', 'User Name', 'Auth user', 'Datetime', 'Request',
                  'Status', 'Bytes', 'Referrer', 'User Agent');
}
;

/*
  IMPORTANT:
  Keep the ID number consistent to track pages,
  for pages that are not part of navigation bar
  put place="1" attribute, for top level items put a url for default
  second level
*/

create procedure adm_menu_tree ()
{
  declare wa_available, rdf_available, policy_vad integer;
  wa_available := VAD.DBA.VER_LT ('1.02.13', DB.DBA.VAD_CHECK_VERSION ('Framework'));
  policy_vad := DB.DBA.VAD_CHECK_VERSION ('policy_manager');
  rdf_available := check_package ('cartridges');
  return concat (
'<?xml version="1.0" ?>
<adm_menu_tree>
 <node name="Home" url="main_tabs.vspx" id="1" tip="Common Tasks" allowed="yacutia_admin">
 </node>
 <node name="System Admin" url="sys_info.vspx" id="2" tip="Administer the Virtuoso server" allowed="yacutia_admin">
   <node name="Dashboard" url="sys_info.vspx" id="171" allowed="yacutia_admin">
     <node name="Dashboard Properties" url="dashboard.vspx" id="167" place="1" allowed="yacutia_admin"/>
   </node>
   <node name="Security" url="sec_pki_1.vspx" id="23" allowed="yacutia_acl_page">
     <node name="Public Key Infrastructure" url="sec_pki_1.vspx" id="24" place="1" allowed="yacutia_acl_page">
      <node name="PKI Wizard" url="sec_pki_1.vspx" id="26" place="1" allowed="yacutia_acl_page"/>
      <node name="PKI Wizard" url="sec_pki_2.vspx" id="26" place="1" allowed="yacutia_acl_page"/>
      <node name="PKI Wizard" url="sec_pki_3.vspx" id="26" place="1" allowed="yacutia_acl_page"/>
      <node name="PKI Wizard" url="sec_pki_4.vspx" id="26" place="1" allowed="yacutia_acl_page"/>',
     case when __proc_exists ('VAL.DBA.setup_val_host') is not null then
     '<node name="PKI Wizard" url="sec_pki_val.vspx" id="26" place="1" allowed="yacutia_acl_page"/>'
     end,
     '<node name="PKI Wizard" url="sec_pki_drop.vspx" id="26" place="1" allowed="yacutia_acl_page"/>
      <node name="PKI Wizard" url="sec_pki_2_conf.vspx" id="26" place="1" allowed="yacutia_acl_page"/>
     </node>
     <node name="Access Control" url="sec_auth_serv.vspx" id="24" place="1" allowed="yacutia_acl_page">
      <node name="ACL List" url="sec_auth_serv.vspx" id="25" place="1" allowed="yacutia_acl_page"/>
      <node name="ACL Edit" url="sec_acl_edit.vspx" id="26" place="1" allowed="yacutia_acl_page"/>
     </node>
     <node name="CA Roots" url="sec_ca.vspx" id="271" place="1" allowed="yacutia_acl_page"/>
   </node>
   <node name="User Accounts" url="accounts_page.vspx" id="3" allowed="yacutia_accounts_page">
     <node name="Accounts" url="accounts.vspx" id="4" place="1" allowed="yacutia_accounts_page"/>
     <node name="Accounts" url="account_create.vspx" id="5" place="1" allowed="yacutia_accounts_page"/>
     <node name="Accounts" url="account_remove.vspx" id="6" place="1" allowed="yacutia_accounts_page"/>
     <node name="Roles" url="roles.vspx" id="7" place="1" allowed="yacutia_accounts_page"/>
     <node name="Roles" url="role_remove.vspx" id="8" place="1" allowed="yacutia_accounts_page"/>
     <node name="Grants" url="capabilities.vspx" id="9" place="1" allowed="yacutia_accounts_page"/>
     <node name="Grants" url="caps_browser.vspx" id="10" place="1" allowed="yacutia_accounts_page"/>
     <node name="Grants" url="caps_cols_browser.vspx" id="11" place="1" allowed="yacutia_accounts_page"/>
     <node name="LDAP Import" url="ldap_import.vspx" place="1" id="12" allowed="yacutia_accounts_page" />
     <node name="LDAP Import" url="ldap_import_1.vspx" place="1" id="14" allowed="yacutia_accounts_page"/>
     <node name="LDAP Import" url="ldap_import_2.vspx" place="1" id="15" allowed="yacutia_accounts_page"/>
     <node name="LDAP Import" url="ldap_import_3.vspx" place="1" id="16" allowed="yacutia_accounts_page"/>
     <node name="LDAP Servers" url="ldap_server.vspx" id="179" place="1" allowed="yacutia_accounts_page"/>
   </node>
   <node name="Scheduler" url="sys_queues.vspx"  tip="Event Scheduling" id="17" allowed="yacutia_queues_page">
     <node name="Scheduler" url="sys_queues.vspx" id="18" place="1" allowed="yacutia_queues_page">
       <node name="Scheduler" url="sys_queues_edit.vspx" id="19" place="1" allowed="yacutia_queues_page"/>
       <node name="Scheduler" url="sys_queues_remove.vspx" id="20" place="1" allowed="yacutia_queues_page"/>
       <node name="Scheduler" url="sys_queues_error.vspx" id="166" place="1" allowed="yacutia_queues_page"/>
     </node>
   </node>
   <node name="Parameters" url="inifile.vspx?page=Database" id="21" allowed="yacutia_params_page">
     <node name="Parameters" url="inifile.vspx" id="22" place="1" allowed="yacutia_params_page"/>
   </node>
   <node name="Registry" url="registries.vspx" id="221" allowed="yacutia_registry_page" />
   <node name="Packages" url="vad.vspx" id="27" allowed="yacutia_vad_page">
     <node name="Packages" url="vad.vspx" id="28" place="1" allowed="yacutia_vad_page"/>
     <node name="Install packages" url="vad_install.vspx" id="29" place="1" allowed="yacutia_vad_page"/>
     <node name="Remove packages" url="vad_remove.vspx" id="30" place="1" allowed="yacutia_vad_page"/>
     <node name="Package status" url="vad_status.vspx" id="31" place="1" allowed="yacutia_vad_page"/>
     <node name="WA Package" url="vad_wa_config.vspx" id="32" place="1" allowed="yacutia_vad_page"/>
     <node name="WA Package" url="vad_wa_create.vspx" id="312" place="1" allowed="yacutia_vad_page"/>
     <node name="Install packages" url="vad_install_batch.vspx" id="29" place="1" allowed="yacutia_vad_page"/>
     <node name="Remove packages" url="vad_remove_batch.vspx" id="30" place="1" allowed="yacutia_vad_page"/>
     <node name="Select VAD source" url="vad_src.vspx" id="30" place="1" allowed="yacutia_vad_page"/>
   </node>
   <node name="Backup" url="db_backup.vspx" id="79" allowed="yacutia_backup_page">
     <node name="Backup" url="db_backup_clear.vspx" id="169" place="1" allowed="yacutia_backup_page"/>
   </node>
   <node name="Monitor" url="logging_page.vspx" id="33" allowed="yacutia_loging_page">
     <node name="Version &amp; License Info" url="logging.vspx" id="34" place="1" allowed="yacutia_loging_page"/>
     <node name="DB Server Statistics" url="logging_db.vspx" id="35" place="1"  allowed="yacutia_loging_page"/>
     <node name="Disk Statistics" url="logging_disk.vspx"   id="36" place="1" allowed="yacutia_loging_page"/>
     <node name="Index Statistics" url="logging_index.vspx" id="37" place="1" allowed="yacutia_loging_page"/>
     <node name="Lock Statistics" url="logging_lock.vspx" id="38" place="1" allowed="yacutia_loging_page"/>
     <node name="Space Statistics" url="logging_space.vspx" id="39" place="1" allowed="yacutia_loging_page"/>
     <node name="HTTP Server Statistics" url="logging_http.vspx"    id="40" place="1" allowed="yacutia_loging_page"/>
     <node name="Profiling" url="logging_prof.vspx"   id="41" place="1" allowed="yacutia_loging_page"/>
     <node name="Log Viewer" url="logging_view.vspx"   id="42" place="1" allowed="yacutia_loging_page"/>
   </node>
 </node>
 <node name="Database" url="databases.vspx" id="43" tip="Database Server local and remote resource manipulation" allowed="yacutia_db">
   <node name="SQL Database Objects" url="databases.vspx" id="44" allowed="yacutia_databases_page">
     <node name="Databases-drop" url="databases_drop.vspx" id="45" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-drop" url="db_drop_conf.vspx" id="46" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-drop" url="db_drop_errs.vspx" id="47" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-table-edit" url="databases_table_edit.vspx" id="48" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-table-constraints" url="databases_table_constraints.vspx" id="49" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-constraints-drop" url="db_const_drop_conf.vspx" id="50" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-constraints-drop" url="db_const_drop_errs.vspx" id="51" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-view-edit" url="databases_view_edit.vspx" id="52" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-proc-edit" url="databases_proc_edit.vspx" id="53" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-udt-edit" url="databases_udt_edit.vspx" id="54" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-export" url="ie.vspx" id="176" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-export" url="databases_export.vspx" id="177" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-grants" url="databases_grants.vspx" id="191" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-grants" url="db_grant_many.vspx" id="192" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-grants" url="db_grant_errs.vspx" id="193" place="1" allowed="yacutia_databases_page"/>
   </node>',
--   <node name="Schema Editor" url="xddl.vspx?init=xddl" id="52" allowed="yacutia_xddl_page">
--     <node name="edit" url="xddl.vspx" id="53" place="1" allowed="yacutia_xddl_page"/>
--     <node name="edit" url="xddl2.vspx" id="54" place="1" allowed="yacutia_xddl_page"/>
--   </node>
  '<node name="External Data Sources" url="vdb_linked_obj.vspx" id="55" allowed="yacutia_remote_data_access_page">
     <node name="VDB Management" url="vdb_unlink_obj.vspx" id="56" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_conn_dsn.vspx" id="57" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_config_dsn.vspx" id="58" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_conn_dsn_edit.vspx" id="59" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_conn_dsn_del.vspx" id="174" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_obj_link.vspx" id="60" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_obj_link_opts.vspx" id="61" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_obj_link_pk.vspx" id="172" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_conf_dsn_remove.vspx" id="62" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_conf_dsn_edit.vspx" id="63" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_conf_dsn_new.vspx" id="64" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_main.vspx" id="65" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="Known Datasources" url="vdb_dsns.vspx" id="66" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Errors" url="vdb_errs.vspx" id="67" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="Known External Resources" url="vdb_resources.vspx" id="68" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="Link External Resources" url="vdb_link.vspx" id="69" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="Edit Datasource" url="vdb_dsn_edit.vspx" id="70" place="1" allowed="yacutia_remote_data_access_page"/>
   </node>
   <node name="Interactive SQL" url="isql_main.vspx" id="71" allowed="yacutia_isql_page"/>
   <node name="User Defined Types" url="hosted_page.vspx" id="72" allowed="yacutia_runtime">
     <node name="Loaded Modules" url="hosted_modules.vspx" id="73" place="1" allowed="yacutia_runtime_loaded"/>
     <node name="Import Files" url="hosted_import.vspx" id="74" place="1" allowed="yacutia_runtime_import"/>
     <node name="Import Files Results" url="hosted_modules_load_results.vspx" id="75" place="1" allowed="yacutia_runtime_import_result"/>
     <node name="Load Modules" url="hosted_modules_select.vspx" id="76" place="1" allowed="yacutia_runtime_loaded_select"/>
     <node name="Load Modules" url="hosted_modules_select2.vspx" id="77" place="1" allowed="yacutia_runtime_loaded_select2"/>
     <node name="Modules Grant" url="hosted_grant.vspx" id="78" place="1" allowed="yacutia_runtime_hosted_grant"/>
   </node>
   <node name="Import" url="import_csv_1.vspx" id="271" allowed="cvs_import">
   <node name="Import" url="import_csv_2.vspx" id="271" place="1" />
   <node name="Import" url="import_csv_3.vspx" id="271" place="1" />
   <node name="Import" url="import_csv_opts.vspx" id="271" place="1" />
   </node>
 </node>
 <node name="Replication" url="db_repl_basic.vspx" id="80" tip="Replications" allowed="yacutia_repl">
   <node name="Basic" url="db_repl_basic.vspx" id="8001" >
    <node name="Basic" url="db_repl_basic_create.vspx" id="8002" place="1" />
    <node name="Basic" url="db_repl_basic_local.vspx" id="8011" place="1" />
    <node name="Basic" url="db_repl_basic_local_create.vspx" id="8012" place="1" />
   </node>
   <node name="Incremental" url="db_repl_snap_pull.vspx" id="81" >
    <node name="Incremental" url="db_repl_snap_pull_create.vspx" id="82" place="1" />
    <node name="Incremental" url="db_repl_snap.vspx" id="83" place="1"/>
    <node name="Incremental" url="db_repl_snap_create.vspx" id="84" place="1" />
    <node name="Incremental" url="db_repl_snap_local.vspx" id="85" place="1"/>
    <node name="Incremental" url="db_repl_snap_local_create.vspx" id="86" place="1" />
   </node>
   <node name="Bidirectional Snapshot" url="db_repl_bi.vspx" id="87" >
    <node name="Bidirectional Snapshot" url="db_repl_bi_create.vspx" id="88" place="1" />
    <node name="Bidirectional Snapshot" url="db_repl_bi_edit.vspx" id="89" place="1" />
    <node name="Bidirectional Snapshot" url="db_repl_bi_add.vspx" id="90" place="1" />
    <node name="Bidirectional Snapshot" url="db_repl_cr_edit.vspx" id="91" place="1" />
    <node name="Bidirectional Snapshot" url="db_repl_bi_remove.vspx" id="92" place="1" />
    <node name="Bidirectional Snapshot" url="db_repl_bi_cr.vspx" id="93" place="1" />
    <node name="Bidirectional Snapshot" url="db_repl_bi_cr_edit.vspx" id="94" place="1" />
   </node>
   <node name="Transactional" url="db_repl_trans.vspx" id="95" >
      <node name="Transactional (publish)" url="db_repl_pub.vspx" id="96" place="1"/>
      <node name="Transactional (publish)" url="db_repl_pub_create.vspx" id="97" place="1" />
      <node name="Transactional (publish)" url="db_repl_pub_edit.vspx" id="98" place="1" />
      <node name="Transactional (publish)" url="db_repl_rdf_pub_edit.vspx" id="98" place="1" />
      <node name="Transactional (publish)" url="db_repl_pub_cr.vspx" id="99" place="1" />
      <node name="Transactional (publish)" url="db_repl_pub_cr_edit.vspx" id="100" place="1" />
      <node name="Transactional (publish)" url="db_repl_pub_cr_edit2.vspx" id="101" place="1" />
      <node name="Transactional (subscribe)" url="db_repl_sub.vspx"   id="102" place="1"/>
      <node name="Transactional (subscribe)" url="db_repl_sub_create.vspx" id="103" place="1" />
      <node name="Transactional (subscribe)" url="db_repl_sub_image.vspx" id="104" place="1" />
      <node name="Transactional (publish)" url="db_repl_sub_edit.vspx" id="105" place="1" />
   </node>
 </node>
 <node name="Web Application Server" url="cont_page.vspx" id="138" tip="Web server DAV repository and Web site hosting control" allowed="yacutia_http">
   <node name="Content Management" url="cont_page.vspx" id="139" allowed="yacutia_http_content_page">
      <node name="Content Management" url="cont_page.vspx" id="140" place="1" allowed="yacutia_http_content_page"/>
      <node name="Content Management" url="cont_management.vspx" id="141" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_control.vspx" id="142" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_edit.vspx" id="143" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_queues.vspx" id="144" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_sites.vspx" id="145" place="1"  allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_status.vspx" id="146" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_urls_list.vspx" id="147" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_sched.vspx" id="148" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_export.vspx" id="168" place="1" allowed="yacutia_http_content_page"/>
      <node name="Text Triggers" url="text_triggers.vspx" id="149" place="1" allowed="yacutia_http_content_page"/>
      <node name="Resource Types" url="cont_management_types.vspx" id="150" place="1" allowed="yacutia_http_content_page"/>
      <node name="Resource Types" url="cont_type_edit.vspx" id="151" place="1" allowed="yacutia_http_content_page"/>
      <node name="Resource Types" url="cont_type_remove.vspx" id="152" place="1" allowed="yacutia_http_content_page"/>
   </node>
   <node name="Virtual Domains &amp; Directories" url="http_serv_mgmt.vspx" id="153" allowed="yacutia_http_server_management_page">
      <node name="Edit Paths" url="http_edit_paths.vspx" id="154" place="1" allowed="yacutia_http_server_management_page"/>
      <node name="Add Path" url="http_add_path.vspx" id="155" place="1" allowed="yacutia_http_server_management_page"/>
      <node name="Edit Host" url="http_host_edit.vspx" id="170" place="1" allowed="yacutia_http_server_management_page"/>
      <node name="Clone Host" url="http_host_clone.vspx" id="175" place="1" allowed="yacutia_http_server_management_page"/>
      <node name="Delete Path" url="http_del_path.vspx" id="156" place="1" allowed="yacutia_http_server_management_page"/>
      <node name="URL rewrite" url="http_url_rewrite.vspx" id="193" place="1" allowed="yacutia_http_server_management_page"/>
      <node name="Content Negotiation" url="http_tcn.vspx" id="194" place="1" allowed="yacutia_http_server_management_page"/>
   </node>',
 case when check_package('inclusion-engine') then
  '<node name="Inclusion Engine" url="iengine.vspx" id="1500" allowed="yacutia_ie">
    <node name="Inclusion Engine" url="iengine.vspx" id="1510" place="1"  allowed="yacutia_ie"/>
   </node>'
 end,
'</node>
 <node name="XML" url="xml_sql.vspx" id="106" tip="XML Services permit manipulation of XML data from stored and SQL sources" allowed="yacutia_xml">
   <node name="SQL-XML" url="xml_sql.vspx" id="107" allowed="yacutia_sql_xml_page">
     <node name="SQL-XML" url="xml_sql2.vspx" id="108" place="1" allowed="yacutia_sql_xml_page">
     </node>
   </node>
   <node name="XSL Transformation" url="xslt.vspx" id="109" allowed="yacutia_xslt_page">
     <node name="XSLT" url="xslt_result.vspx" id="110" place="1" allowed="yacutia_xslt_page">
     </node>
   </node>
   <node name="XQuery" url="xquery.vspx" id="111" allowed="yacutia_xquery_page">
     <node name="XQuery" url="xquery.vspx" id="112" place="1" allowed="yacutia_xquery_page" />
     <node name="XQuery" url="xquery2.vspx" id="113" place="1" allowed="yacutia_xquery_page"/>
     <node name="XQuery" url="xquery3.vspx" id="114" place="1" allowed="yacutia_xquery_page"/>
     <node name="XQuery" url="xquery4.vspx" id="115" place="1" allowed="yacutia_xquery_page"/>
     <node name="XQuery" url="xquery_templates.vspx" id="173" place="1" allowed="yacutia_xquery_page"/>
     <node name="XQuery" url="xquery_adv.vspx" id="178" place="1" allowed="yacutia_xquery_page"/>
   </node>',
--   <node name="XML Schema" url="xml_xsd.vspx" id="116" allowed="yacutia_xml_schema_check_page">
--      <node name="XML Schema" url="xml_xsd.vspx" id="117" place="1" allowed="yacutia_xml_schema_check_page"/>
--   </node>
--   <node name="Mapping Schema" url="mapped_schema_xml.vspx" id="118" allowed="yacutia_mapped_schema_page">
--      <node name="Mapping Schema" url="mapped_schema_xml.vspx" id="119" place="1" allowed="yacutia_mapped_schema_page"/>
--   </node>
 '</node>
 <node name="Web Services" url="soap_services.vspx" id="120" tip="Web Services permit the exposure and consumption of functions for distributed applications" allowed="yacutia_web">
   <node name="Web Service Endpoints" url="soap_services.vspx" id="121" allowed="yacutia_soap_page">
     <node name="Web Service Endpoint Edit" url="soap_services_list.vspx" id="122" place="1" allowed="yacutia_soap_page"/>
     <node name="Web Service Endpoint List" url="soap_services_edit.vspx" id="123" place="1" allowed="yacutia_soap_page"/>
     <node name="Web Service Endpoint List" url="soap_options_edit.vspx" id="124" place="1" allowed="yacutia_soap_page"/>
     <node name="Delete Web Service Endpoint" url="soap_del_path.vspx" id="165" place="1" allowed="yacutia_soap_page"/>
   </node>
   <node name="WSDL Import / Export" url="wsdl_services.vspx" id="125" allowed="yacutia_wsdl_page">
     <node name="Import" url="wsdl_services.vspx" id="126" place="1" allowed="yacutia_wsdl_page">
       <node name="Import" url="wsdl_services.vspx" id="127" place="1" allowed="yacutia_wsdl_page"/>
     </node>
     <node name="Create" url="wsdl_service_create.vspx" id="128" place="1" allowed="yacutia_wsdl_page">
       <node name="Create" url="wsdl_service_create.vspx" id="129" place="1" allowed="yacutia_wsdl_page"/>
     </node>
   </node>
   <node name="BPEL" url="bpel_service.vspx" id="165" allowed="yacutia_bpel_page"/>',
--   <node name="UDDI Services" url="uddi_serv.vspx" id="130" allowed="yacutia_uddi_page">
--     <node name="Server" url="uddi_serv.vspx" id="131" place="1" allowed="yacutia_uddi_page"/>
--     <node name="Browse" url="uddi_serv_browse.vspx" id="132" place="1" allowed="yacutia_uddi_page"/>
--     <node name="Create" url="uddi_serv_create.vspx" id="133" place="1" allowed="yacutia_uddi_page"/>
--     <node name="Find" url="uddi_serv_find.vspx" id="134" place="1" allowed="yacutia_uddi_page"/>
--     <node name="Remove" url="uddi_remove.vspx" id="135" place="1" allowed="yacutia_uddi_page"/>
--   </node>',
--case wa_available
--when 1 then '<node name="Applications" url="site.vspx" id="136" allowed="yacutia_app_page">
--               <node name="edit" url="site.vspx" id="137" place="1" allowed="yacutia_app_page"/>
--             </node>'
--when 0 then '' end,
'</node>
 <node name="Linked Data" url="sparql_input.vspx" id="189" tip="Linked Data" allowed="yacutia_message">',
  '<node name="SPARQL" url="sparql_input.vspx" id="180" allowed="yacutia_sparql_page">
     <node name="SPARQL" url="sparql_load.vspx" id="181" place="1" allowed="yacutia_sparql_page" />
   </node>',
  case when 0 and check_package('rdf_mappers') then
  '<node name="Stylesheets" url="sparql_filters.vspx" id="190" tip="GRDDL " allowed="yacutia_message">
     <node name="Stylesheets" url="sparql_filters.vspx" id="182" place="1" allowed="yacutia_sparql_page" />
   </node>' end,
   '<node name="Sponger" url="rdf_filters.vspx" id="191" tip="Linked Data Cartridges " allowed="yacutia_message">
     <node name="Cartridges" url="rdf_filters.vspx" id="192" place="1" allowed="yacutia_sparql_page" />
     <node name="CSV patterns" url="csv_patterns.vspx" id="199" place="1" allowed="yacutia_sparql_page" />
     <node name="Meta Cartridges" url="rdf_filters_pp.vspx" id="193" place="1" allowed="yacutia_sparql_page" />
    <node name="Entity URIs" url="entity_uri_patterns.vspx" id="195" place="1" allowed="yacutia_sparql_page" />
     <node name="Stylesheets" url="sparql_filters.vspx" id="182" place="1" allowed="yacutia_sparql_page" />
     <node name="Console" url="rdf_console.vspx" id="182" place="1" allowed="yacutia_sparql_page" />
     <node name="Configuration" url="rdf_conf.vspx" id="182" place="1" allowed="yacutia_sparql_page" />
   </node>',
   '<node name="Statistics" url="rdf_void.vspx" id="194" tip="RDF Statistics" allowed="yacutia_sparql_page" />',
   '<node name="Graphs" url="graphs_page.vspx" id="183" allowed="yacutia_sparql_page">
     <node name="Graphs" url="sparql_graph.vspx" id="184" place="1" allowed="yacutia_sparql_page" />
     <node name="User Security" url="graphs_users_security.vspx" id="185" place="1" allowed="yacutia_sparql_page" />
     <node name="Roles Security" url="graphs_roles_security.vspx" id="186" place="1" allowed="yacutia_sparql_page" />
     <node name="Audit Security" url="graphs_audit_security.vspx" id="187" place="1" allowed="yacutia_sparql_page" />
   </node>',
   '<node name="Schemas"  url="rdf_schemas.vspx" id="188" allowed="yacutia_message">
     <node name="Schemas" url="rdf_schemas.vspx" id="189" place="1" allowed="yacutia_sparql_page" />
   </node>
   <node name="Namespaces"  url="persistent_xmlns.vspx" id="183" allowed="yacutia_message" />',
     case when (rdf_available > 0) then
     '<node name="Access Control" url="sparql_acl.vspx" id="274" allowed="yacutia_acls">
        <node name="ACL List" url="sec_auth_serv_sp.vspx" id="277" place="1" allowed="yacutia_acls"/>
        <node name="Sponger Groups" url="sec_auth_sponger_1.vspx" id="277" place="1" allowed="yacutia_acls"/>
        <node name="Sponger ACL" url="sec_auth_sponger_2.vspx" id="277" place="1" allowed="yacutia_acls"/>
        <node name="ACL Edit" url="sec_acl_edit_sp.vspx" id="276" place="1" allowed="yacutia_acls"/>
        <node name="SPARQL ACL" url="sparql_acl.vspx" id="277" place="1" allowed="yacutia_acls"/>
      </node>'
     end,
   '<node name="Views" url="db_rdf_objects.vspx" id="271" allowed="yacutia_rdf_schema_objects_page"/>
   <node name="Views" url="db_rdf_class.vspx" id="272" place="1"/>
   <node name="Views" url="db_rdf_owl.vspx" id="273" place="1"/>
   <node name="Views" url="db_rdf_view_1.vspx" id="273" place="1"/>
   <node name="Views" url="db_rdf_view_2.vspx" id="273" place="1"/>
   <node name="Views" url="db_rdf_view_3.vspx" id="273" place="1"/>
   <node name="Views" url="db_rdf_view_tb.vspx" id="273" place="1"/>
   <node name="Views" url="db_rdf_view_cols.vspx" id="273" place="1"/>
   <node name="Views" url="db_rdf_view_pk.vspx" id="273" place="1"/>',
   case when check_package('VAL') then
  '<node name="OAuth Service Binding" url="login_keys.vspx" id="281" allowed="yacutia_val">
      <node name="OAuth Service Binding" url="login_keys.vspx" id="282" place="1"  allowed="yacutia_val"/>
   </node>'
   end,
   case when check_package('rdb2rdf') then
  '<node name="R2RML" url="r2rml_import.vspx" id="273" />
   <node name="R2RML" url="r2rml_validate.vspx" id="273" place="1"/>
   <node name="R2RML" url="r2rml_gen.vspx" id="273" place="1"/>'
   end,
  '<node name="Quad Store Upload" url="rdf_import.vspx" id="271" allowed="rdf_import_page"/>',
   case when __proc_exists ('PSH.DBA.cli_subscribe') is not null then
  '<node name="Subscriptions (PHSB)" url="rdf_psh_subs.vspx" id="271" allowed="rdf_psh_sub_page"/>'
   end,
'</node>
 <node name="NNTP" url="msg_news_conf.vspx" id="157" tip="Mail and news messaging" allowed="yacutia_message">',
   --<node name="Mail Configuration" url="msg_mail_conf.vspx" id="158" yacutia_mail_config_page"">
   --</node>
   '<node name="News Servers" url="msg_news_conf.vspx" id="159" allowed="yacutia_news_config_page">
     <node name="News Groups" url="msg_news_groups.vspx" id="160" place="1"  allowed="yacutia_news_config_page"/>
     <node name="News Group Subscripting" url="msg_news_group_subscribe.vspx" id="161" place="1"  allowed="yacutia_news_config_page"/>
     <node name="News Group Messages" url="msg_news_group_messages.vspx" id="162" place="1"  allowed="yacutia_news_config_page"/>
     <node name="News Group Message Body" url="msg_news_group_message_body.vspx" id="163" place="1"  allowed="yacutia_news_config_page"/>
     <node name="News Server Global" url="msg_news_conf_global.vspx" id="164" place="1"  allowed="yacutia_news_config_page"/>
   </node>
 </node>
</adm_menu_tree>');
}
;


create procedure
adm_navigation_root (in path varchar)
{
  return xpath_eval ('/adm_menu_tree/*', xml_tree_doc (adm_menu_tree ()), 0);
}
;


create procedure adm_belongs_to (in page any, in refr any)
{
  declare tree, page1, page2, tmp, part any;
  tree := xtree_doc (adm_menu_tree ());
  tmp := split_and_decode (page, 0, '\0\0/');
  page1 := tmp[length (tmp) - 1];
  tmp := split_and_decode (refr, 0, '\0\0/');
  page2 := tmp[length (tmp) - 1];
  part := xpath_eval (sprintf ('/adm_menu_tree//node[@url = "%s"]//node[@url = "%s" and @place="1" ]', page1, page2), tree);
  if (part is not null)
    {
      return 1;
    }
  return 0;
}
;

/*
  Conductor routines
*/

create procedure
adm_navigation_child (in path varchar, in node any)
{
  path := concat (path, '[not @place]');
  return xpath_eval (path, node, 0);
}
;

create procedure
adm_get_node_by_url (in url varchar)
{
  declare page varchar;
  declare part any;
  declare xt any;
  xt := xml_tree_doc (adm_menu_tree ());
  page := split_and_decode (url, 0, '\0\0/');
  page := page[length (page) - 1];
  part := xpath_eval (sprintf ('/adm_menu_tree//node[@url = "%s"]/parent::node', page), xt, 1);
  return vector (serialize(part));
}
;

create procedure
adm_db_tree_1 ()
{
  declare res varchar;
  declare i int;
  set isolation='uncommitted';
  res := '<db_tree>\n'; i := 0;
  for select distinct name_part (KEY_TABLE, 0) as TABLE_QUAL from SYS_KEYS
    union select distinct name_part (P_NAME, 0) from SYS_PROCEDURES
    do
    {
       i := i + 1;
       res := concat (res,
                      '<node name="',
                      TABLE_QUAL,
                      '" not-selected-image="images/icons/foldr_16.png" selected-image="images/icons/open_16.png" url="" id="',
                      cast (i as varchar),
                      '">\n');
       for select distinct name_part (KEY_TABLE, 1) as TABLE_OWNER
             from SYS_KEYS
             where name_part (KEY_TABLE, 0) = TABLE_QUAL
       union select distinct name_part (P_NAME, 0) from SYS_PROCEDURES
       where name_part (P_NAME, 0) = TABLE_QUAL
       do
         {
	   declare tcnt, pcnt int;
           i := i + 1;

	   whenever not found goto nfc;
	   select count (distinct KEY_TABLE) into tcnt from SYS_KEYS where name_part (KEY_TABLE, 0) = TABLE_QUAL
	       and name_part (KEY_TABLE, 1) = TABLE_OWNER;

	   select count(*) into pcnt from SYS_PROCEDURES where name_part (P_NAME, 0) = TABLE_QUAL
	       and name_part (P_NAME, 1) = TABLE_OWNER;
	   nfc:

           res := concat (res,
                          '\t<node name="',
                          TABLE_OWNER,
                          '"  not-selected-image="images/icons/foldr_16.png" selected-image="images/icons/open_16.png" url="" id="',
                          cast (i as varchar),
                          sprintf ('" procs="%d" tables="%d">\n', pcnt, tcnt));


           for select distinct name_part (KEY_TABLE, 2) as TABLE_NAME
             from SYS_KEYS
             where 0 and
                   name_part (KEY_TABLE, 0) = TABLE_QUAL and
                   name_part (KEY_TABLE, 1) = TABLE_OWNER do
             {
               i := i + 1;
               res := concat (res, '\t\t<node name="', TABLE_NAME, '" id="' , cast (i as varchar) , '">\n');
               res := concat (res, '\t\t</node>\n');
             }
           res := concat (res, '\t</node>\n');
         }
       res := concat (res, '</node>\n');
     }
  res := concat (res, '</db_tree>\n');
  set isolation='repeatable';
  return res;
}
;

create procedure db_root_1 (in path varchar)
{
  return xpath_eval ('/db_tree/*', xml_tree_doc (adm_db_tree_1 ()), 0);
}
;

create procedure
adm_rdf_db_tree ()
{
  declare ses any;
  declare i int;

  ses := string_output ();
  http ('<db_tree>\n', ses); i := 0;
  for select distinct name_part (KEY_TABLE, 0) as TABLE_QUAL from SYS_KEYS
    union select distinct name_part (P_NAME, 0) from SYS_PROCEDURES
    order by TABLE_QUAL
    do
    {
       i := i + 1;
       http (sprintf ('<node name="%V" id="%d">', TABLE_QUAL, i), ses);
--       http (sprintf ('<node name="Create for all tables" id="1-%d" value="%V"/>\n', i, TABLE_QUAL), ses);
         http (sprintf ('<node name="Tables" id="2-%d"/>\n', i), ses);
       http ('</node>\n', ses);
     }
  http ('</db_tree>\n', ses);
  return string_output_string (ses);
}
;

create procedure
adm_db_tree ()
{
  declare ses any;
  declare i int;

  ses := string_output ();
  http ('<db_tree>\n', ses); i := 0;
  for select distinct name_part (KEY_TABLE, 0) as TABLE_QUAL from SYS_KEYS
    union select distinct name_part (P_NAME, 0) from SYS_PROCEDURES
    order by TABLE_QUAL
    do
    {
       i := i + 1;
       http (sprintf ('<node name="%V" id="%d">', TABLE_QUAL, i), ses);
         http (sprintf ('<node name="Tables" id="1-%d"/>\n', i), ses);
         http (sprintf ('<node name="Views (SQL)" id="2-%d"/>\n', i), ses);
         http (sprintf ('<node name="Views (Linked Data)" id="5-%d"/>\n', i), ses);
         http (sprintf ('<node name="Procedures" id="3-%d"/>\n', i), ses);
         http (sprintf ('<node name="User Defined Types" id="4-%d"/>\n', i), ses);
       http ('</node>\n', ses);
     }
  http ('</db_tree>\n', ses);
  return string_output_string (ses);
}
;

create procedure rdf_db_root (in path varchar)
{
  return xpath_eval (sprintf ('/db_tree/*[@name like "%s"]', path), xml_tree_doc (adm_rdf_db_tree ()), 0);
}
;


create procedure db_root (in path varchar)
{
  return xpath_eval (sprintf ('/db_tree/*[@name like "%s"]', path), xml_tree_doc (adm_db_tree ()), 0);
}
;

create procedure rdf_db_child (in path varchar, in node any)
{
  return xpath_eval (path, node, 0);
}
;

create procedure db_child (in path varchar, in node any)
{
  return xpath_eval (path, node, 0);
}
;

create procedure adm_db_repl_pub_tree()
{
  declare res varchar;
  declare i int;

  res := '<db_tree>\n';
  i := 0;
  for select ACCOUNT from SYS_REPL_ACCOUNTS where SERVER = repl_this_server() and ACCOUNT <> repl_this_server () do
  {
    i := i + 1;
    res := concat(res, '<node name="', ACCOUNT, '" not-selected-image="images/Folder.gif" selected-image="images/open_folder.gif" url="" id="', cast (i as varchar), '">\n');
    i := i + 1;
    res := concat(res, '<node name="', ACCOUNT, '" not-selected-image="images/Folder.gif" selected-image="images/open_folder.gif" url="" id="', cast (i as varchar), '">\n');
    res := concat (res, '</node>\n');
    res := concat (res, '</node>\n');
  }
  res := concat (res, '</db_tree>\n');
  return res;
}
;

create procedure
db_repl_pub_root (in path varchar)
{
  return xpath_eval ('/db_tree/*', xml_tree_doc (adm_db_repl_pub_tree ()), 0);
}
;

create procedure
db_repl_pub_child (in path varchar, in node any)
{
  return xpath_eval (path, node, 0);
}
;

create procedure
adm_exec_stmt_2 (inout control vspx_control, in stmt varchar)
{
  declare stat, msg varchar;
  stat := '00000';
  commit work;
  exec (stmt, stat, msg);
  if (stat <> '00000')
    {
      rollback work;
      control.vc_page.vc_is_valid := 0;
      control.vc_error_message := msg;
      return 0;
    }
  return 1;
}
;

create procedure
adm_uid_to_name (in id int)
{
  declare r varchar;
  whenever not found goto none;
  select U_NAME into r from SYS_USERS where U_ID = id;
  return r;

 none:
  return 'none';
}
;

create procedure
adm_name_to_uid (inout name varchar)
{
  declare i integer;
  whenever not found goto none;
  select U_ID into i from SYS_USERS where U_NAME = name;
  return i;

 none:
  return NULL;
}
;

--
-- Just a mere stub now
--

create procedure
adm_u_is_admin (in uid integer)
{
  if (uid = 1 or uid = 0)
    return 1;
  return 0;
}
;

create procedure
y_sql_user_password (in name varchar)
{
  declare pass varchar;
  pass := NULL;
  whenever not found goto none;
  select pwd_magic_calc (U_NAME, U_PASSWORD, 1) into pass from SYS_USERS where U_NAME = name and U_SQL_ENABLE = 1 and U_IS_ROLE = 0;
none:
  return pass;
}
;

--/* login */
create procedure
y_sql_user_password_check (in name varchar, in pass varchar)
{
  declare nonce, pass1 varchar;
  declare rc int;
  declare ltm datetime;

  nonce := connection_get ('vspx_nonce');
  rc := 0;

  whenever not found goto nfu;
  select pwd_magic_calc (U_NAME, U_PASSWORD, 1), U_LOGIN_TIME into pass1, ltm from SYS_USERS where U_NAME = name and
      U_SQL_ENABLE = 1 and U_IS_ROLE = 0;

  if (length (nonce) and md5 (nonce||pass1) = pass)
    rc := 1;
  else if (not length (nonce) and pass1 = pass)
    rc := 1;

  if (rc and (ltm is null or ltm < dateadd ('minute', -2, now ())))
    {
      update SYS_USERS set U_LOGIN_TIME = now () where U_NAME = name;
      commit work;
    }

nfu:
  return rc;
}
;

create procedure adm_get_page_name ()
{
  declare path, url, elm varchar;
  declare arr any;
  path := http_path ();
  arr := split_and_decode (path, 0, '\0\0/');
  elm := arr [length (arr) - 1];
  url := xpath_eval ('//*[@url = "'|| elm ||'"]', xml_tree_doc (adm_menu_tree ()));
  if (url is not null or elm = 'error.vspx')
    return elm;
  else
    return '';
}
;

create procedure
space_fmt (in d integer) returns varchar
{
  declare ret float;
  if (d is null or d = 0)
    return 'N/A';
  if (d >= 1024 and d < 1048576)
  {
    ret := cast(d as float)/1024;
    return sprintf('%.2f KB', ret);
  }
  if (d >= 1048576)
  {
    ret := cast(d as float)/1024/1024;
    return sprintf('%.2f MB', ret);
  }
  else
    return sprintf('%d B', d);
}
;

create procedure
space_fmt_long (in d integer) returns varchar
{
  declare ret float;
  if (d is null or d = 0)
    return 'N/A';
  if (d >= 1024 and d < 1048576)
  {
    ret := cast(d as float)/1024;
    return sprintf('%.2f Kbytes', ret);
  }
  if (d >= 1048576)
  {
    ret := cast(d as float)/1024/1024;
    return sprintf('%.2f Mbytes', ret);
  }
  else
    return sprintf('%d bytes', d);
}
;

create procedure
date_fmt (in d datetime) returns varchar
{
  if (d is null)
    return '';
  return yac_hum_datefmt(d);
}
;

create procedure
interval_fmt (in d varchar) returns varchar
{
  return coalesce(cast((select yac_hum_min_to_dur(SE_INTERVAL) from SYS_SCHEDULED_EVENT where SE_NAME = d) as varchar), 'none');
}
;

create procedure
repl_no_fmt (in d any) returns integer
{
  declare _stat, _rno integer;
  repl_status (d[0], d[1], _rno, _stat);
  return _rno;
}
;

create procedure
repl_user_fmt (in d any) returns varchar
{
  declare _sync_user varchar;
  _sync_user := d[2];
  if (repl_is_pushback(d[0], d[1]) = 0)
  {
    if (_sync_user is null or _sync_user = '')
      _sync_user := 'dba';
  }
  else
    _sync_user := 'N/A';
  return _sync_user;
}
;

create procedure
repl_shed_fmt (in d any) returns varchar
{
  declare shed varchar;

  if (repl_is_pushback (d[0], d[1]) = 0)
    {
      shed := cast (coalesce ((select SE_INTERVAL from SYS_SCHEDULED_EVENT where SE_NAME = concat ('repl_', d[0], '_', d[1])), 'No') as varchar);
    }
  else
    shed := 'N/A';

  return shed;
}
;

create procedure
repl_sch_fmt (in d any) returns varchar
{
  declare _stat, _rno integer;
  declare _cstat varchar;

  repl_status (d[0], d[1], _rno, _stat);

  if (_stat = 0)
    _cstat := 'OFF';
  else if (_stat = 1)
    _cstat := 'SYNCING';
  else if (_stat = 2)
    _cstat := 'IN SYNC';
  else if (_stat = 3)
    _cstat := 'REMOTE DISCONNECTED';
  else if (_stat = 4)
    _cstat := 'DISCONNECTED';
  else if (_stat = 5)
    _cstat := 'TO DISCONNECT';

  return _cstat;
}
;

create procedure
cvt_date (in ds varchar)
{
  return cast (ds as datetime);
}
;

create procedure
longstring_fmt (in ls varchar)
{
  declare tmp varchar;
  declare i, l integer;

  if (ls is null)
    return '';

  tmp := '';
  i := 1;

  while (i < length(ls))
    {
      l := 30;

      if ((length(ls) - i) < 30)
        l := length(ls) - i;

      tmp := concat(tmp, substring(ls, i, l));
      tmp := concat(tmp, '\n');

      i := i + 30;
  }

  return tmp;
}
;

create procedure
disk_stat (in par integer)
{
  declare mtd, dta any;
  declare sql_str varchar;

  par := 3;

  -- Temporary patch due to bug #10696, Just removed the where... We'll put it back later
  --if (par = 1)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by KEY_TABLE asc';
  --else if (par = 2)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by INDEX_NAME asc';
  --else if (par = 3)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by TOUCHES desc';
  --else if (par = 4)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by READS asc';
  --else if (par = 5)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by READ_PCT asc';
  --else
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by KEY_TABLE asc';
  if (par = 1)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by KEY_TABLE asc';
  else if (par = 2)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by INDEX_NAME asc';
  else if (par = 3)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by TOUCHES desc';
  else if (par = 4)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by READS asc';
  else if (par = 5)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by READ_PCT asc';
  else
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by KEY_TABLE asc';

  exec (sql_str, null, null, vector (), 0, mtd, dta);
  return dta;
}
;

create procedure
disk_stat_meta(in par integer)
{
  declare mtd, dta any;
  declare sql_str varchar;
    par := 3;

  -- Temporary patch due to bug #10696, Just removed the where... We'll put it back later
  --if (par = 1)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by KEY_TABLE asc';
  --else if (par = 2)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by INDEX_NAME asc';
  --else if (par = 3)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by TOUCHES desc';
  --else if (par = 4)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by READS asc';
  --else if (par = 5)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by READ_PCT asc';
  --else
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by KEY_TABLE asc';
  if (par = 1)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by KEY_TABLE asc';
  else if (par = 2)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by INDEX_NAME asc';
  else if (par = 3)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by TOUCHES desc';
  else if (par = 4)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by READS asc';
  else if (par = 5)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by READ_PCT asc';
  else
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by KEY_TABLE asc';
  exec (sql_str, null, null, vector (), -1, mtd, dta );
  return mtd[0];
}
;

create procedure true_if (in sel varchar, in val varchar)
{
  if (sel = val)
      return ('true');
  return ('false');
}
;

create procedure make_full_name (in cat varchar, in sch varchar, in name varchar, in quoted integer := 0) returns varchar
{
    declare ret, quote varchar;
    if (quoted <> 0) quote := '"';
    else quote := '';

    ret := '';

    if (length (cat)) ret := concat (quote, replace (cat, '.', '\x0A'), quote, '.');
    if (length (sch)) ret := concat (ret, quote, replace (sch, '.', '\x0A'), quote);
    if (length (ret))  ret := concat (ret, '.');
    if (length (name))
      ret := concat (ret, quote, replace (name, '.', '\x0A'), quote);
    return ret;
}
;


create procedure
adm_lt_getRPKeys2 (in dsn varchar,
                   in tbl_qual varchar,
                   in tbl_user varchar,
                   in tbl_name varchar)
{
  declare pkeys, pkey_curr, pkey_col, my_pkeys any;
  declare pkeys_len, idx integer;

  if (length (tbl_qual) = 0)
    tbl_qual := NULL;
  if (length (tbl_user) = 0)
    tbl_user := NULL;

  if (sys_stat ('vdb_attach_autocommit') > 0) vd_autocommit (dsn, 1);
    {
      declare exit handler for SQLSTATE '*'
        goto next;
      pkeys := sql_primary_keys (dsn, tbl_qual, tbl_user, tbl_name);
    };
next:

  if (not pkeys) pkeys := NULL;

  pkeys_len := length (pkeys);
  idx := 0;
  my_pkeys := vector();
  if (0 <> pkeys_len)
    {
      while (idx < pkeys_len)
      {
	  pkey_curr := aref (pkeys, idx);
	  pkey_col := aref (pkey_curr, 3);
	  my_pkeys := vector_concat (my_pkeys, vector(pkey_col));
	  idx := idx +1;
      }
    }
  else
    {
      declare inx_name varchar;
      inx_name := null;
      if (sys_stat ('vdb_attach_autocommit') > 0) vd_autocommit (dsn, 1);
        {
           declare exit handler for SQLSTATE '*'
             goto next2;

           pkeys := sql_statistics (dsn, tbl_qual, tbl_user, tbl_name, 0, 1);
        };
      next2:

      if (not pkeys) pkeys := NULL;

      pkeys_len := length (pkeys);

      if (0 <> pkeys_len)
        {
	  while (idx < pkeys_len)
	    {
	       pkey_curr := aref (pkeys, idx);
	       if (inx_name is null)
	         inx_name := pkey_curr[5];
	       if (inx_name <> pkey_curr[5])
	         goto pk_end;
	       pkey_col := aref (pkey_curr, 8);
	       if (pkey_col is not null)
	         my_pkeys := vector_concat (my_pkeys, vector(pkey_col));
	       idx := idx +1;
	    }
	  pk_end:;
	}
      else
	{
	  pkeys := NULL;
	  pkeys_len := 0;
	}
    }
  return my_pkeys;
}
;

/*
   VDB table/view linking
 */
create procedure
vdb_link_tables (in pref any,
         in params any,
                 in ds_name varchar,
                 in tables any,
                 in keys any,
     inout errs any)
{
  declare sql_stt, sql_msg, sql_stt1, sql_msg1 varchar;
  declare i, n integer;
  declare tbl_qual, tbl_user, tbl_name, rname varchar;
  declare n_qual, n_user, n_name,  lname varchar;
  declare tbl_key any;
  declare _r_tbl, _l_tbl any;

  sql_stt := ''; sql_msg := ''; sql_stt1 := ''; sql_msg1 := '';

  i := 0;
  n := length (tables);

  while (i < n)
    {
      _r_tbl := aref (aref (tables, i), 0);
      _l_tbl := aref (aref (tables, i), 1);

      tbl_key := aref (keys, i);


      if (length (tbl_key) = 0) tbl_key := NULL;

      tbl_qual := aref (_r_tbl, 0);
      tbl_user := aref (_r_tbl, 1);
      tbl_name := aref (_r_tbl, 2);
      rname := make_full_name (null, tbl_user, tbl_name);

      n_qual := get_keyword (sprintf ('%s_catalog_%d', pref, i), params, '');
      n_user := get_keyword (sprintf ('%s_schema_%d', pref, i), params, '');
      n_name := get_keyword (sprintf ('%s_name_%d', pref, i), params, '');

      if (n_qual = '' or n_user = '' or n_name = '')
        {
          errs := vector_concat (errs, vector (vector (rname, '22023', 'Catalog, Schema and Name fields should not be empty.')));
          goto error;
        }

      lname := make_full_name (n_qual, n_user, n_name);
      if (exists (select RT_NAME from DB.DBA.SYS_REMOTE_TABLE where RT_NAME = lname))
        {
	  errs := vector_concat (errs, vector (vector (rname, '22023', 'Table is already linked.')));
          goto error;
        }

      sql_stt := '00000';
      sql_stt1 := '00000';
      sql_msg := '';

      exec ('DB.DBA.vd_attach_view (?, ?, ?, ?, ?, ?, 1)',
              sql_stt,
              sql_msg,
              vector (ds_name, rname, lname, NULL, NULL, tbl_key),
              0, NULL, NULL);

       if (sql_stt <> '00000')
         {
           rollback work;
           errs := vector_concat (errs, vector (vector (rname, sql_stt, sql_msg)));
           goto error;
         }
       exec ('commit work', sql_stt1, sql_msg);
       if (sql_stt1 <> '00000')
         {
     rollback work;
     errs := vector_concat (errs, vector (vector (rname, sql_stt, sql_msg)));
           goto error;
         }

     error:
      i := i + 1;
    }
}
;

create procedure
vdb_link_procedures (in params any,
                     in ds_name varchar,
                     in procs any,
                     inout errs any)
{
  declare i, l, j, m integer;
  declare pro, lname, lname1, stmt, st, msg varchar;

  j := 0; m := length(procs);
  while (j < m)
    {
      declare pars any;
      declare q,o,n, par, typ varchar;
      declare q1,o1,n1, cmn1 varchar;
      declare meta any;
      declare _comment varchar;
      declare att_type varchar;

      meta := vector ();
      lname := sprintf ('%s.%s.%s', aref (procs, j + 1), aref (procs, j + 2), aref (procs, j + 3));
      lname1 := sprintf ('"%I"."%I"."%I"', aref (procs, j + 1), aref (procs, j + 2), aref (procs, j + 3));

      att_type := aref (procs, j + 4);
      _comment := aref (procs, j + 5);

      if (__proc_exists (lname))
        {
          errs := vector_concat (errs, vector (vector (procs[j], '22023', 'Procedure already linked.')));
          goto error;
        }

      q := name_part (procs[j], 0);
      o := name_part (procs[j], 1);
      n := name_part (procs[j], 2);

      if (q <> '')
        stmt := sprintf ('attach procedure "%I"."%I"."%I" (', q, o, n);
      else
        stmt := sprintf ('attach procedure "%I"."%I" (', o, n);

      pars := aref (procs, j + 6);

      declare br integer;

      i := 0; l := length (pars); br := 0;

      while (i < l)
        {
          declare t, na, dt, st, t1 varchar;
          t1 := '';

          if (not isarray (pars[i]))
          goto nexti;

          t  := pars[i][0];
          na := pars[i][1];
          dt := pars[i][2];
          st := pars[i][3];

        --if (t = 'UNDEFINED')

          t1 := get_keyword (sprintf ('parm_%d_%s_io',i, na), params, '');

          if (t1 <> '')
            t := t1;

          meta := vector_concat (meta, vector (vector (t, concat('"',na,'"'), dt, st)));

          if (t = 'RESULTSET')
              goto nexti;

          if (t = 'RETURNS')
            {
              stmt := concat (trim (stmt, ', '), ') RETURNS ', dt);
              br := 1;
            }

          else
            if (t <> 'RESULTSET')
              stmt := concat (stmt, t, ' ', na, ' ', dt);

          if (st <> '')
              stmt := concat (stmt, ' __soap_type ''', st, '''');

          stmt := concat (stmt, ',');
         nexti:
          i := i + 1;
        }

      stmt := trim (stmt, ', ');

      if (not br)
        stmt := concat (stmt, ')');

      stmt := concat (stmt, sprintf (' as %s from ''%s''', lname1, ds_name));


          -- here we are ready to attach

      if (att_type = 'wrap' or att_type = 'rset')
        {
          declare make_resultset integer;

          if (att_type = 'rset')
            make_resultset := 1;
          else
            make_resultset := 0;

          st := '00000';
          vd_remote_proc_wrapper (ds_name,
                                  aref (procs, j),
                                  lname,
                                  meta,
                                  st,
                                  msg,
                                  make_resultset,
                                  _comment);
        }
      else
        {
          st := '00000';
          exec (stmt, st, msg);
        }

      if (st <> '00000')
        {
          errs := vector_concat (errs, vector (vector (procs[j], st, msg)));
          goto error;
        }

     error:
      j := j + 7;
    }
}
;

sequence_set ('dbpump_temp', 0, 0)
;

sequence_set ('dbpump_id', 1, 0)
;

create procedure "PUMP"."DBA"."RETRIEVE_TABLES_VIA_PLSQL" ( in qual_mask varchar, in owner_mask varchar, in table_mask varchar, in out_type integer := 1 )
{

  declare str, s varchar;
  declare first integer;

  first := 1;
  str := '';
  whenever not found goto fin;
  for( select
           name_part("KEY_TABLE",0) as t_qualifier,
           name_part("KEY_TABLE",1) as t_owner,
           name_part("KEY_TABLE",2) as t_name,
           table_type("KEY_TABLE")  as t_type
         from DB.DBA.SYS_KEYS
         where
           __any_grants ("KEY_TABLE") and
           name_part("KEY_TABLE",0) like qual_mask and
           name_part("KEY_TABLE",1) like owner_mask and
           name_part("KEY_TABLE",2) like table_mask and
           table_type("KEY_TABLE") = 'TABLE' and
           KEY_IS_MAIN = 1 and
           KEY_MIGRATE_TO is NULL
           order by "KEY_TABLE") do {
      if (not first) {
        if (out_type = 1)
          str := concat (str, '&');
        else if (out_type = 2)
          str := concat (str, '@');
      }
      s := concat (t_qualifier, '.', t_owner, '.', t_name);
      if (out_type = 1)
        str := concat (str, s, '=', s);
      else if (out_type = 2)
        str := concat (str, s);
      first := 0;
  }
fin:
  return str;
}
;

create procedure "PUMP"."DBA"."GET_DSN" () returns varchar
{
  declare port, sect, item varchar;
  declare nitems integer;
  port := '1111';
  sect := 'Parameters';
  nitems := cfg_item_count(virtuoso_ini_path(), sect);

  while ( nitems >= 0 ) {
    item := cfg_item_name(virtuoso_ini_path(), sect, nitems);
    if (equ(item,'ServerPort')) {
      port := cfg_item_value(virtuoso_ini_path(), sect, item);
      goto next;
    }
    nitems := nitems - 1;
  }
next:
  return concat('localhost:',port);
}
;

create procedure "PUMP"."DBA"."GET_USER" () returns varchar
{
  declare auth varchar;
  declare _user varchar;
  declare _pwd varchar;
  --sql_user_password (in name varchar)
  --auth  := db.dba.vsp_auth_vec (lines);
  --_user := get_keyword ('username', auth, '');
--  _pwd  := get_keyword ('pass', auth, '');
  _user := connection_get('vspx_user');
  return _user;
}
;

create procedure "DB"."DBA"."BACKUP_VIA_DBPUMP" (
                        in username varchar,
                        in passwd varchar,
                        in datasource varchar,
                        in dump_path varchar,
                        in dump_dir varchar,
                        in out_fmt integer,
                        in dump_items varchar,
                        in ins_mode integer,
                        in chqual varchar,
                        in chuser varchar,
                        in sel_tables varchar
                          ) returns varchar
{
  declare pars, res any;
  pars:= null;

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'user', username);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'password', passwd);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'datasource', datasource);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'dump_path', dump_path);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'dump_dir', dump_dir);

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'table_defs', case dump_items[0] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'table_data', case dump_items[1] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'triggers', case dump_items[2] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'stored_procs', case dump_items[3] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'constraints', case dump_items[4] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'fkconstraints', case dump_items[5] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'views', case dump_items[6] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'users', case dump_items[7] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'grants', case dump_items[8] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'text_flag', case out_fmt when 1 then 'Binary' else 'SQL' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'insert_mode', chr(ins_mode + ascii('1')));
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'change_qualifier', case when length(chqual) > 0 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'new_qualifier', chqual );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'change_owner', case when length(chuser) > 0 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'new_owner', chuser );

/*
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'custom_qual', '1');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'qualifier_mask', '%');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'owner_mask', '%');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'tabname', '%');
*/

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'choice_sav',  sel_tables);
  res := "PUMP"."DBA"."DUMP_TABLES_AND_PARS_RETRIEVE" (pars);

  declare str varchar;
  str := get_keyword ('result_txt', res, NULL);
  if(str is null)
    str := get_keyword ('last_error', res, '');

  return str;
}
;

--drop procedure html_choice_rpath;
create procedure "PUMP"."DBA"."DBPUMP_CHOICE_RPATH"( in path varchar := './backup' ) returns any
{
  declare str varchar;
  declare outarr any;
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" ( vector(), 'choice_rpath', path, 0);
  outarr := split_and_decode(str,0);
  return outarr;
}
;

create procedure "PUMP"."DBA"."DBPUMP_CHOICE_RSCHEMA" ( in path varchar := './backup' ) returns any
{
  declare str varchar;
  declare pars any;
  declare outarr any;
  pars:= null;
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'show_content', '6');
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (pars,'choice_rschema',path, 0);
  outarr := split_and_decode(str,0);
  return outarr;
}
;

create procedure check_grants(in user_name  varchar, in role_name varchar)
{
  declare user_id, group_id, role_id integer;
  whenever not found goto nf;

  if (DB.DBA.is_empty_or_null (user_name))
    return 0;

  select U_ID, U_GROUP into user_id, group_id from SYS_USERS where U_NAME=user_name;
  if (user_id = 0 or group_id = 0)
    return 1;

  if (role_name is null or role_name = '')
    return 0;

  select U_ID into role_id from SYS_USERS where U_NAME=role_name;
  if (exists(select 1 from SYS_ROLE_GRANTS where GI_SUPER=user_id and GI_SUB=role_id))
    return 1;

nf:
  return 0;
}
;

create procedure create_inifile_page(in section varchar, in rel_path varchar, in file varchar, in is_dav integer)
{
  declare xslt_uri, src_uri, res, path  varchar;
  declare src_tree, pars any;
  declare vspx any;
  if (is_dav = 0)
  {
    xslt_uri := concat ('file://', rel_path, '/inifile_style.xsl');
    src_uri := concat ('file://', rel_path, '/inifile_metadata.xml');
  }
  else
  {
    xslt_uri := concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', rel_path, '/inifile_style.xsl');
    src_uri := concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', rel_path, '/inifile_metadata.xml');
  }
  src_tree := xtree_doc (XML_URI_GET_STRING ('', src_uri));
  vspx := string_output();
  pars := vector('section_name', section);
  res := xslt(xslt_uri, src_tree, pars);
  http_value(res, 0, vspx);
  if (is_dav = 0)
    string_to_file(concat(path,'/', rel_path, '/',file),string_output_string(vspx),-2);
  else
    DAV_RES_UPLOAD(concat(rel_path, '/', file), string_output_string(vspx), '', '111101101R', 'dav', 'administrators', 'dav');
}
;

create procedure get_ini_location() {
   declare num, pos integer;
   declare fpath, res varchar;
   res:='';
  fpath:= virtuoso_ini_path();
 pos:=0;
 while((num:=locate('/',fpath,pos+1)) > 0)
  pos:=num;

 if (pos=0 )  {
   while( (num:=locate('\\',fpath,pos+1)) > 0)
        pos:=num;
 }


 if (pos > 0)
   res:=substring(fpath,1,pos);

 return res;
}
;

create procedure column_is_pk( in tablename varchar, in colname varchar ) returns integer
{
  if (exists( select 1 from DB.DBA.SYS_KEYS v1, DB.DBA.SYS_KEYS v2, DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS
              where upper(v1.KEY_TABLE) = upper(tablename) and upper("DB"."DBA"."SYS_COLS"."COLUMN") = upper(colname)
                    and v1.KEY_IS_MAIN = 1 and v1.KEY_MIGRATE_TO is NULL
                    and v1.KEY_SUPER_ID = v2.KEY_ID
                    and kp.KP_KEY_ID = v1.KEY_ID
                    and kp.KP_NTH < v1.KEY_DECL_PARTS
                    and DB.DBA.SYS_COLS.COL_ID = kp.KP_COL
                    and "DB"."DBA"."SYS_COLS"."COLUMN" <> '_IDN' )
    )
    return 1;
  else
    return 0;
}
;

create procedure column_is_fk( in tablename varchar, in colname varchar ) returns integer
{
  if (exists( select 1 from DB.DBA.SYS_FOREIGN_KEYS as SYS_FOREIGN_KEYS
              where upper(FK_TABLE) = upper(tablename) and upper(FKCOLUMN_NAME) = upper(colname))
    )
    return 1;
  else
    return 0;
}
;

create procedure create_table_sql( in tablename varchar, in constr int := 1) returns varchar
{
  declare sql, pks, fks, full_tablename varchar;
  declare k integer;
  full_tablename := make_full_name ( name_part(tablename,0), name_part(tablename,1), name_part(tablename,2), 1 );
  sql := concat('create table ', full_tablename, '\n(');
  pks := '';
  fks := '';
  k := 0;

    for SELECT c."COLUMN" as COL_NAME, dv_type_title (c."COL_DTP") as COL_TYPE, c."COL_PREC" as "COL_PREC",
           c."COL_SCALE" as "COL_SCALE", c."COL_NULLABLE" as "COL_NULLABLE", c.COL_CHECK as COL_CHECK
      from  DB.DBA.SYS_KEYS k, DB.DBA.SYS_KEY_PARTS kp, "SYS_COLS" c
      where
            name_part (k.KEY_TABLE, 0) =  name_part (tablename, 0) and
            name_part (k.KEY_TABLE, 1) =  name_part (tablename, 1) and
            name_part (k.KEY_TABLE, 2) =  name_part (tablename, 2)
            and __any_grants (k.KEY_TABLE)
        and c."COLUMN" <> '_IDN'
        and k.KEY_IS_MAIN = 1
        and k.KEY_MIGRATE_TO is null
        and kp.KP_KEY_ID = k.KEY_ID
        and c.COL_ID = kp.KP_COL
	order by kp.KP_NTH do {


      if (k > 0 )
          sql := concat( sql, ',' );
      else k := 1;

      sql := concat( sql, '\n  "', COL_NAME,  '" ', COL_TYPE );
      if(COL_TYPE = 'VARCHAR' and COL_PREC > 0)
        sql := sprintf( '%s(%d)', sql, COL_PREC );

      if (strchr (coalesce (COL_CHECK, ''), 'I') is not null)
	sql := sql ||' IDENTITY';

      if (column_is_pk(tablename, COL_NAME) = 1 ) {
        if (length(pks) > 0 )
          pks := concat( pks, ', "', COL_NAME,  '"' );
        else
          pks := concat( '"', COL_NAME,  '"' );
      }
  }
  if (pks <> '' ) {
    sql := concat(sql, ',\n  PRIMARY KEY (', pks, ')');
  }
  sql := concat(sql, '\n);');

  if (not constr)
    goto endt;

  for select PK_TABLE,
       FK_NAME,
       trim(yac_agg_concat('"' || PKCOLUMN_NAME || '"',', '),' ,') PKCOLUMNS,
       trim(yac_agg_concat('"' || FKCOLUMN_NAME || '"',', '),' ,') FKCOLUMNS,
       UPDATE_RULE,DELETE_RULE
      from DB.DBA.SYS_FOREIGN_KEYS as SYS_FOREIGN_KEYS
      where upper(FK_TABLE) = upper(tablename)
      group by PK_TABLE, FK_NAME, UPDATE_RULE, DELETE_RULE do {

      declare PKTABLE_NAME varchar;
      PKTABLE_NAME := make_full_name ( name_part(PK_TABLE,0), name_part(PK_TABLE,1), name_part(PK_TABLE,2), 1);

      fks := concat(fks, '\nALTER TABLE ', full_tablename, '\n');
      fks := concat(fks, '  ADD CONSTRAINT "',FK_NAME,'" FOREIGN KEY (', FKCOLUMNS, ')\n');
      fks := concat(fks, '    REFERENCES ', PKTABLE_NAME, ' (', PKCOLUMNS, ')');
      if (UPDATE_RULE = 1)
        fks := concat(fks, ' ON UPDATE CASCADE');
      else if (UPDATE_RULE = 2)
        fks := concat(fks, ' ON UPDATE SET NULL');
      else if (UPDATE_RULE = 3)
        fks := concat(fks, ' ON UPDATE SET DEFAULT');
      if (DELETE_RULE = 1)
        fks := concat(fks, ' ON DELETE CASCADE');
      else if (DELETE_RULE = 2)
        fks := concat(fks, ' ON DELETE SET NULL');
      else if (DELETE_RULE = 3)
        fks := concat(fks, ' ON DELETE SET DEFAULT');
      fks := concat(fks,';\n' );
  }

  for select C_TEXT,sql_text(deserialize(blob_to_string(C_MODE))) SQL_TEXT
        from DB.DBA.SYS_CONSTRAINTS
       where upper(C_TABLE) = upper(tablename) do {
      fks := concat(fks, '\nALTER TABLE ', full_tablename, '\n');
      fks := concat(fks, '  ADD', either(equ(C_TEXT,'0'),'',concat(' CONSTRAINT "',C_TEXT,'"\n   ')));
      fks := concat(fks, ' CHECK (', SQL_TEXT, ');\n' );
  }

  if (fks <> '' ) {
    sql := concat(sql, '\n', fks);
  }

  endt:

  return sql;
}
;

create procedure sql_dump_vdb_tables (in table_list any)
{
  declare ses any;
  declare tmp any;
  ses := string_output ();
  http ('-- Data Sources \n', ses);
  for select distinct DS_DSN, DS_UID, pwd_magic_calc (DS_UID, DS_PWD, 1) as pwd
    from DB.DBA.SYS_DATA_SOURCE join DB.DBA.SYS_REMOTE_TABLE on (DS_DSN = RT_DSN) where RT_NAME in (table_list) do
      {
	http (sprintf ('vd_remote_data_source (\'%S\', \'\', \'%S\', \'%S\'); \n', DS_DSN, DS_UID, pwd), ses);
      }
  http ('\n\n-- Tables \n', ses);
  for select RT_DSN, RT_NAME, RT_REMOTE_NAME from DB.DBA.SYS_REMOTE_TABLE where RT_NAME in (table_list) do
    {
      tmp := create_table_sql (RT_NAME);
      http (tmp, ses);
      http ('\n', ses);
      http (sprintf ('vd_remote_table (\'%S\', \'%S\', \'%S\'); \n', RT_DSN, RT_NAME, RT_REMOTE_NAME), ses);
      http (sprintf ('__ddl_changed (\'%S\'); \n\n', RT_NAME), ses);
    }
  return ses;
}
;

yacutia_exec_no_error('drop view db.dba.sql_statistics')
;

create view db.dba.sql_statistics as
  select
    iszero(SYS_KEYS.KEY_IS_UNIQUE) AS NON_UNIQUE SMALLINT,
    SYS_KEYS.KEY_TABLE AS TABLE_NAME VARCHAR(128),
    name_part (SYS_KEYS.KEY_TABLE, 0) AS INDEX_QUALIFIER VARCHAR(128),
    name_part (SYS_KEYS.KEY_NAME, 2) AS INDEX_NAME VARCHAR(128),
    ((SYS_KEYS.KEY_IS_OBJECT_ID*8) +
     (3-(2*iszero(SYS_KEYS.KEY_CLUSTER_ON_ID)))) AS INDEX_TYPE SMALLINT,
    (SYS_KEY_PARTS.KP_NTH+1) AS SEQ_IN_INDEX SMALLINT,
    "SYS_COLS"."COLUMN" AS COLUMN_NAME VARCHAR(128)
  from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS, DB.DBA.SYS_COLS SYS_COLS
  where SYS_KEYS.KEY_IS_MAIN = 0 and SYS_KEYS.KEY_MIGRATE_TO is NULL
    and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID
    and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS
    and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL
    and "SYS_COLS"."COLUMN" <> '_IDN'
  order by SYS_KEYS.KEY_TABLE, SYS_KEYS.KEY_NAME, SYS_KEY_PARTS.KP_NTH
;

create procedure db.dba.sql_table_indexes( in tablename varchar )
{
  declare cols varchar;
  declare TABLE_NAME, INDEX_NAME, COLUMNS varchar;
  declare NON_UNIQUE, INDEX_TYPE integer;

  if (tablename is null)
    tablename := '%';

  result_names(TABLE_NAME, INDEX_NAME, NON_UNIQUE, INDEX_TYPE, COLUMNS);

  for ( select TABLE_NAME as TABLE_N, INDEX_NAME as INDEX_N, NON_UNIQUE, INDEX_TYPE
      from db.dba.sql_statistics
      where upper(TABLE_NAME) like upper(tablename)
      group by TABLE_NAME, INDEX_NAME, NON_UNIQUE, INDEX_TYPE
      order by 1, 2 )
  do {
       declare kopts any;
       kopts := (select KEY_OPTIONS from SYS_KEYS where KEY_NAME = INDEX_N and KEY_TABLE = TABLE_N);
       if (isvector (kopts))
	 {
	   if (position ('bitmap', kopts))
	     INDEX_TYPE := 4;
	   if (position ('column', kopts))
	     INDEX_TYPE := 5;
	 }
    cols := '';
    for ( select COLUMN_NAME from db.dba.sql_statistics as ss
          where ss.TABLE_NAME = TABLE_N and ss.INDEX_NAME = INDEX_N )
    do {
      if(cols='')
        cols := COLUMN_NAME;
      else
        cols := concat(cols, ', ', COLUMN_NAME);
    };
    result(TABLE_N, INDEX_N, NON_UNIQUE, INDEX_TYPE, cols);
  }
  --end_result();
}
;

yacutia_exec_no_error('drop view DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS_T')
;

create procedure view DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS_T as
DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS () (GRAPH_IRI varchar)
;


yacutia_exec_no_error('drop view db.dba.sql_table_indexes')
;

create procedure view db.dba.sql_table_indexes as
db.dba.sql_table_indexes (tablename) (TABLE_NAME varchar, INDEX_NAME varchar, NON_UNIQUE integer, INDEX_TYPE integer, COLUMNS varchar)
;

create procedure db.dba.vad_packages_meta() returns any
{
  declare retval any;
  retval := vector('id','item_name','Version', 'Release Date', 'Install Date');
  return retval;
}
;



-- Sample content providing procedures for vdir browser.
-- 2 procedures should be supplied - for meta-information and for content.
-- Meta procedure: doesn't have parameters and returns a vector of string names of content columns.
-- Content-providing procedure:
-- Parameters:
-- path - path to get content for
-- filter - filter mask for content
-- Return value:
-- Vector of vectors each describes one content item.
-- Format of item vector:
-- [0] - integer = 1 if item is a container (node), 0 if item is a leaf;
-- [1] - varchar item name;
-- [2] - varchar item icon name (e.g. 'images/txtfile.gif' etc.),
--       if NULL, predefined icons for folder and document will be used according to [0] element
-- [3], [4] .... - optional !varchar! fields to show as item describing info,
--       each element will be placed in its own column in details view.
-- 3rd procedure is optional - it is used for folder creation
-- Parameters:
-- path - path to get content for
-- newfolder - name of the folder to create
-- Return value:
-- integer 1 on success, 0 on error.

create procedure db.dba.vdir_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME','Description');
  return retval;
}
;

create procedure
db.dba.vdir_browse_proc( in path varchar, in filter varchar := '' ) returns any
{
  declare level, is_node integer;
  declare cat, sch, tbl, descr varchar;
  declare retval any;

  retval := vector();
  --  retval := vector_concat(retval,
  --                          vector(vector('ITEM_IS_CONTAINER',
  --                                        'ITEM_NAME',
  --                                        'ICON_NAME',
  --                                        'Description')));

  path := trim(path,'.');

  if (isnull(filter) or filter = '' )
    filter := '%.%.%';
  replace(filter, '*', '%');
  cat := left( path, coalesce(strchr(path,'.'),length(path)));
  path := ltrim(subseq( path, length(cat)), '.');
  cat := trim(cat,'"');
  sch := left( path, coalesce(strchr(path,'.'), length(path)));
  path := ltrim(subseq( path, length(sch)), '.');
  sch := trim(sch,'"');
  tbl := trim(left( path, coalesce(strchr(path,'.'), length(path))),'"');
  --if(tbl<>'') level := 3;
  if(sch<>'') level := 2;
  else if(cat<>'') level := 1;
  else level := 0;
  cat := case when cat <> '' then cat else '%' end;
  sch := case when sch <> '' then sch else '%' end;
  is_node := case when level < 2 then 1 else 0 end;
  descr := case level when 0 then 'Catalog' when 1 then 'Schema' else 'Table' end;

  for( select distinct name_part (KEY_TABLE, level) as ITEM from DB.DBA.SYS_KEYS
       where name_part (KEY_TABLE, 0) like cat and
             name_part (KEY_TABLE, 1) like sch and
             KEY_TABLE LIKE filter
     ) do {
     retval := vector_concat(retval, vector(vector(is_node, ITEM, NULL,descr)));
  }
  return retval;
}
;

create procedure
db.dba.dav_br_map_icon (in type varchar)
{
  if ('folder' = type)
    return ('foldr_16.png');
  if ('application/pdf' = type)
    return ('pdf_16.png');
  if ('application/ms-word' = type or 'application/msword' = type)
    return ('docs_16.png');
  if ('application/zip' = type)
    return ('zip_16.png');
  if ('text/html' = type)
    return ('html_16.png');
  if ('text' = "LEFT" (type, 4))
    return ('docs_16.gif');
  if ('image' = "LEFT" (type, 5))
    return ('image_16.png');
  if ('audio' = "LEFT" (type, 5))
    return ('music_16.png');
  if ('video' = "LEFT" (type, 5))
    return ('video_16.png');
  return ('gen_file_16.png');
}
;


--
-- XXX add weeks, months, years.
--

create procedure db.dba.yac_hum_plural_suffux (
  in n integer)
{
  return case when (n = 1) then '' else 's' end;
}
;

create procedure db.dba.yac_hum_min_to_dur (
  in mins integer)
{
  declare d, h, m any;
  declare S varchar;

  if (mins < 60)
    return sprintf ('%d minute%s', mins, db.dba.yac_hum_plural_suffux (mins));

  if (mins < 1440)
  {
    h := mins / 60;
    m := mod (mins, 60);
    S := sprintf ('%d hour%s', h, db.dba.yac_hum_plural_suffux (h));
    if (m <> 0)
      S := S || sprintf (', %d min%s', m, db.dba.yac_hum_plural_suffux (m));

    return S;
  }

  d := mins / 1440;
  h := mod (mins, 1440) / 60;
  m := mod (mod (mins, 1440), 60);
  S := sprintf ('%d day%s', d, db.dba.yac_hum_plural_suffux (d));
  if (h <> 0)
    S := S || sprintf (', %d hour%s', h, db.dba.yac_hum_plural_suffux (h));

  if (m <> 0)
    S := S || sprintf (', %d min%s', m, db.dba.yac_hum_plural_suffux (m));

  return S;
}
;

create procedure db.dba.yac_hum_datefmt (
  in d datetime)
{

  declare date_part varchar;
  declare time_part varchar;
  declare min_diff integer;
  declare day_diff integer;

  if (isnull (d))
    return ('Never');

  d := dateadd ('second', -30, d);
  day_diff := datediff ('day', d, now ());
  if (day_diff < 1)
  {
    min_diff := datediff ('minute', d, now ());
    if (min_diff = 1)
      return ('A minute ago');

    if (min_diff < 1)
      return ('Less than a minute ago');

    if (min_diff < 60)
      return (sprintf ('%d minutes ago', min_diff));

    return sprintf ('Today at %02d:%02d', hour (d), minute (d));
  }
  if (day_diff < 2)
    return (sprintf ('Yesterday at %02d:%02d', hour (d), minute (d)));

  return (sprintf ('%02d/%02d/%02d %02d:%02d',
                   year (d),
                   month (d),
                   dayofmonth (d),
                   hour (d),
                   minute (d)));
}
;

--
-- Return byte counts in human-friendly format
--
-- XXX: not localized
--

create procedure
db.dba.yac_hum_fsize (in sz integer) returns varchar
{
  if (sz = 0)
    return ('Zero');
  if (sz < 1024)
    return (sprintf ('%dB', cast (sz as integer)));
  if (sz < 102400)
    return (sprintf ('%.1fkB', sz/1024));
  if (sz < 1048576)
    return (sprintf ('%dkB', cast (sz/1024 as integer)));
  if (sz < 104857600)
    return (sprintf ('%.1fMB', sz/1048576));
  if (sz < 1073741824)
    return (sprintf ('%dMB', cast (sz/1048576 as integer)));
  return (sprintf ('%.1fGB', sz/1073741824));
}
;

create procedure
db.dba.dav_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector('ITEM_IS_CONTAINER',
                   'ITEM_NAME',
                   'ICON_NAME',
                   'Size',
                   'Created',
                   'Description');
  return retval;
}
;

create procedure
db.dba.dav_browse_proc_meta1(in show_details integer := 0) returns any
{
  declare retval any;
  if (show_details = 0)
    retval := vector('ITEM_IS_CONTAINER',
                     'ITEM_NAME',
                     'ICON_NAME',
                     'Size',
                     'Modified',
                     'Type',
                     'Owner',
                     'Group',
                     'Permissions');
  else
    retval := vector('ITEM_IS_CONTAINER', 'ITEM_NAME');
  return retval;
}
;

create procedure
db.dba.dav_browse_proc1 (in path varchar,
                         in show_details integer := 0,
                         in dir_select integer := 0,
                         in filter varchar := '',
                         in search_type integer := -1,
                         in search_word varchar := '',
                  			 in ord varchar := '',
                  			 in ordseq varchar := 'asc'
                  			 ) returns any
{
  declare i, j, len, len1 integer;
  declare dirlist, retval any;
  declare cur_user, cur_group, user_name, group_name, perms, perms_tmp, cur_file varchar;
  declare stat, msg, mdt, dta any;

  cur_user := connection_get ('vspx_user');
  path := replace (path, '"', '');

  if (length (path) = 0 and search_type = -1)
    {
      if (show_details = 0)
        retval := vector (vector (1, 'DAV', NULL, '0', '', 'Root', '', '', ''));
      else
        retval := vector (vector (1, 'DAV'));
      return retval;
    }
  else
    if (length(path) = 0 and search_type <> -1)
      path := 'DAV';

  if (path[length (path) - 1] <> ascii ('/'))
    path := concat (path, '/');

  if (path[0] <> ascii ('/'))
    path := concat ('/', path);

  if (isnull (filter) or filter = '')
    filter := '%';

  replace (filter, '*', '%');
  retval := vector ();
  if (search_type = 0 or search_type = -1)
    {
      if (ord = 'name')
	ord := 11;
      else if (ord = 'size')
	ord := 3;
      else if (ord = 'type')
	ord := 10;
      else if (ord = 'modified')
	ord := 4;
      else if (ord = 'owner')
	ord := 8;
      else if (ord = 'group')
	ord := 7;

      if (isinteger (ord))
	ord := sprintf (' order by %d %s', ord, ordseq);

      if (search_type = 0)
	{
	  exec (concat ('select * from Y_DAV_DIR where path = ? and recursive = ? and auth_uid = ? ', ord),
	     stat, msg, vector (path, 1, cur_user), 0, mdt, dirlist);
	  -- old behaviour
          --dirlist := YACUTIA_DAV_DIR_LIST (path, 1, cur_user);
	}
      else
	{
	  exec (concat ('select * from Y_DAV_DIR where path = ? and recursive = ? and auth_uid = ? ', ord),
	     stat, msg, vector (path, 0, cur_user), 0, mdt, dirlist);
	  -- old behaviour
          -- dirlist := YACUTIA_DAV_DIR_LIST (path, 0, cur_user);
	}

      if (not isarray (dirlist))
        return retval;

      len := length (dirlist);
      i := 0;

      while (i < len)
        {
          if (lower (dirlist[i][1]) = 'c') --  and dirlist[i][10] like filter) -- lets not filter out collections!
            {
              cur_file := trim (dirlist[i][0], '/');
              cur_file := subseq (cur_file, strrchr (cur_file, '/') + 1);

              if (search_type = -1 or
                  (search_type = 0 and cur_file like search_word))
                {
                  if (show_details = 0)
                    {
                      if (dirlist[i][7] is not null)
                        user_name := dirlist[i][7];
                      else
                        user_name := 'none';

                      if (dirlist[i][6] is not null)
                        group_name := dirlist[i][6];
                      else
                        group_name := 'none';

	              perms_tmp := dirlist[i][5];
                      if (length (perms_tmp) = 9)
                        perms_tmp := perms_tmp || 'N';
                      perms := DAV_PERM_D2U (perms_tmp);

                      if (search_type = 0)
                        retval :=
                          vector_concat(retval,
                                        vector (vector (1,
                                                        dirlist[i][0],
                                                        NULL,
                                                        '<span class="filesize">N/A</span>',
                                                        Y_UI_DATE (dirlist[i][3]),
                                                        '<span class="filetype">[folder]</span>',
                                                        user_name,
                                                        group_name,
                                                        perms)));
                      else
                        retval :=
                          vector_concat(retval,
                                        vector (vector (1,
                                                        dirlist[i][10],
                                                        NULL,
                                                        '<span class="filesize">N/A</span>',
                                                        Y_UI_DATE (dirlist[i][3]),
                                                        '<span class="filetype">[folder]</span>',
                                                        user_name,
                                                        group_name,
                                                        perms)));
                    }
                  else
                    {
                      if (search_type = 0)
                        retval := vector_concat(retval,
                                                vector (vector (1, dirlist[i][0])));
                      else
                        retval := vector_concat(retval,
                                                vector (vector (1, dirlist[i][10])));
                    }
                  }
                }
              i := i + 1;
            }
          if (dir_select = 0 or dir_select = 2)
            {
              i := 0;
              while (i < len)
                {
                  if (lower (dirlist[i][1]) <> 'c' and dirlist[i][10] like filter)
                    {
                      cur_file := trim (aref (aref (dirlist, i), 0), '/');
                      cur_file := subseq (cur_file, strrchr (cur_file, '/') + 1);

                      if (search_type = -1 or
                          (search_type = 0 and cur_file like search_word))
                        {
                          if (show_details = 0)
                            {
                              if (dirlist[i][7] is not null)
				                        user_name := dirlist[i][7];
                              else
                                user_name := 'none';

                              if (dirlist[i][6] is not null)
				                        group_name := dirlist[i][6];
                              else
                                group_name := 'none';

	              	            perms_tmp := dirlist[i][5];
                      	      if (length (perms_tmp) = 9)
                        	      perms_tmp := perms_tmp || 'N';
			                        perms := DAV_PERM_D2U (perms_tmp);

                              if (search_type = 0)
                                retval :=
                                  vector_concat(retval,
                                                vector (vector (0,
                                                                dirlist[i][0],
                                                                NULL,
                                                                Y_UI_SIZE (dirlist[i][2]),
                                                                Y_UI_DATE (dirlist[i][3]),
                                                                dirlist[i][9],
                                                                user_name,
                                                                group_name,
                                                                perms )));
                              else
                                retval :=
                                  vector_concat(retval,
                                                vector( vector (0,
                                                                dirlist[i][10],
                                                                NULL,
                                                                Y_UI_SIZE (dirlist[i][2]),
                                                                Y_UI_DATE (dirlist[i][3]),
                                                                dirlist[i][9],
                                                                user_name,
                                                                group_name,
                                                                perms )));
                            }
                          else
                            {
                              if (search_type = 0)
                                retval := vector_concat (retval,
                                                         vector(vector(0, dirlist[i][0])));
                              else
                                retval := vector_concat (retval,
                                                         vector(vector(0, dirlist[i][10])));
                            }
                        }
                    }
                    i := i + 1;
                  }
         }
            }
          else
            if (search_type = 1)
              {
                retval := vector();
                declare _u_name, _g_name varchar;
                declare _maxres integer;
                declare _qtype varchar;
                declare _out varchar;
                declare _style_sheet varchar;
                declare inx integer;
                declare _qfrom varchar;
                declare _root_elem varchar;
                declare _u_id, _cutat integer;
                declare _entity any;
                declare _res_name_sav varchar;
                declare _out_style_sheet, _no_matches, _trf, _disp_result varchar;
                declare _save_as, _own varchar;

    -- These parameters are needed for WebDAV browser

                declare _current_uri, _trf_doc, _q_scope, _sty_to_ent,
                _sid_id, _sys, _mod varchar;
                declare _dav_result any;
                declare _e_content any;
                declare stat, err varchar;
                declare _no_match, _last_match, _prev_match, _cntr integer;

                err := ''; stat := '00000';
                _dav_result := null;

                declare exit handler for sqlstate '*'
                  {
                    stat := __SQL_STATE; err := __SQL_MESSAGE;
                  };

	      if (ord = 'name')
		ord := 2;
	      else if (ord = 'size')
		ord := 10;
	      else if (ord = 'type')
		ord := 6;
	      else if (ord = 'modified')
		ord := 7;
	      else if (ord = 'owner')
		ord := 4;
	      else if (ord = 'group')
		ord := 5;

	      if (isinteger (ord))
		ord := sprintf (' order by %d %s', ord, ordseq);

                if (not is_empty_or_null (search_word))
                  {
		    stat := '00000';
                    exec (concat ('select RES_ID, RES_NAME, RES_CONTENT, RES_OWNER, RES_GROUP, RES_TYPE, RES_MOD_TIME, RES_PERMS,
                                RES_FULL_PATH, length (RES_CONTENT)
                           from WS.WS.SYS_DAV_RES
                           where contains (RES_CONTENT, ?)', ord), stat, msg, vector (search_word), 0, mdt, dta);


		    if (stat = '00000')
		      {
			declare RES_ID, RES_NAME, RES_CONTENT, RES_OWNER, RES_GROUP, RES_TYPE,
				RES_MOD_TIME, RES_PERMS, RES_FULL_PATH any;

			foreach (any elm in dta) do
			  {
			    RES_ID := elm[0];
			    RES_NAME := elm[1];
		            RES_CONTENT := elm[2];
	    		    RES_OWNER := elm[3];
	                    RES_GROUP  := elm[4];
	                    RES_TYPE  := elm[5];
	                    RES_MOD_TIME  := elm[6];
	                    RES_PERMS  := elm[7];
	                    RES_FULL_PATH := elm[8];

			    if (exists (select 1 from WS.WS.SYS_DAV_PROP
					  where PROP_NAME = 'xper' and
						PROP_TYPE = 'R' and
						PROP_PARENT_ID = RES_ID))
			      {
				_e_content := string_output ();
				http_value (xml_persistent (RES_CONTENT), null, _e_content);
				_e_content := string_output_string (_e_content);
			      }
			    else
			      _e_content := RES_CONTENT;

			    if (RES_GROUP is not null and RES_GROUP > 0)
			      {
				_g_name := (select G_NAME from WS.WS.SYS_DAV_GROUP where G_ID = RES_GROUP);
			      }
			    else
			      {
				_g_name := 'no group';
			      }

			    if (RES_OWNER is not null and RES_OWNER > 0)
			      {
				_u_name := (select U_NAME from WS.WS.SYS_DAV_USER where U_ID = RES_OWNER);
			      }
			    else
			      {
				_u_name := 'Public';
			      }

			    if (show_details = 0)
			      {
				retval :=
				  vector_concat (retval,
						 vector (vector (0,
								 RES_FULL_PATH,
								 NULL,
								 yac_hum_fsize (length (RES_CONTENT)),
								 yac_hum_datefmt (RES_MOD_TIME),
								 RES_TYPE,
								 _u_name,
								 _g_name,
								 adm_dav_format_perms (RES_PERMS))));
			      }
			    else
			      {
				retval := vector_concat(retval,
							vector (vector (0,
									RES_FULL_PATH)));
			      }
		            inx := inx + 1;
	                 }
		      }
       }
    }
  return retval;
}
;

create procedure
db.dba.dav_browse_proc (in path varchar,
                        in filter varchar := '' ) returns any
{
  declare i, len integer;
  declare dirlist, retval any;

  path := replace (path, '"', '');
  if (length (path) = 0) {
    retval := vector( vector( 1, 'DAV', NULL, '0', '', 'Root' ));
    return retval;
  }
  if (path[length(path)-1] <> ascii('/'))
    path := concat (path, '/');
  if (path[0] <> ascii('/'))
    path := concat ('/', path);

  if (isnull(filter) or filter = '' )
    filter := '%';
  replace(filter, '*', '%');
  retval := vector();
  dirlist := DAV_DIR_LIST( path, 0, 'dav', 'dav');
  if(not isarray(dirlist))
    return retval;
  len:=length(dirlist);
  i:=0;
  while( i < len ) {
    if (dirlist[i][1] = 'c' /* and dirlist[i][10] like filter */ ) -- let's don't filter out catalogs!
      retval := vector_concat (retval,
                               vector (vector (1,
                                               dirlist[i][10],
                                               NULL,
                                               sprintf('%d', dirlist[i][2]),
                                               left(cast(dirlist[i][3] as varchar), 19),
                                               'Collection' )));
    i := i+1;
  }
  i:=0;
  while( i < len ) {
    if (dirlist[i][1] <> 'c' and dirlist[i][10] like filter )
    retval := vector_concat(retval, vector(vector( 0, dirlist[i][10], NULL, sprintf('%d', dirlist[i][2]), left(cast(dirlist[i][3] as varchar), 19), 'Document' )));
    i := i+1;
  }
  return retval;
}
;

create procedure
db.dba.dav_crfolder_proc (in path varchar,
                          in folder varchar ) returns integer
{
  declare ret integer;

  path := replace (path, '"', '');

  if (length (path) = 0)
    path := '.';

  if (path[length (path)-1] <> ascii ('/'))
    path := concat (path, '/');

  if (folder[length (folder) - 1] <> ascii ('/'))
    folder := concat (folder, '/');

  ret := DB.DBA.DAV_COL_CREATE (path || folder, '110100000R', 'dav', 'dav', 'dav', 'dav');
  return case when ret <> 0 then 0 else 1 end;
}
;

create procedure DB.DBA.Y_VAD_CHECK (in vad_name varchar)
{
  if (isnull (VAD_CHECK_VERSION (vad_name)))
    return 0;
  return 1;
}
;

create procedure db.dba.fs_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector ('ITEM_IS_CONTAINER',
                    'ITEM_NAME',
                    'ICON_NAME',
                    'Size',
                    'Created',
                    'Description');
  return retval;
}
;


create procedure fs_chek_filter (in dirlist any, in filters any)
{
   declare idx, len, ret integer;

   len := length (filters);
   ret := 0;
   idx := 0;

   while (idx < len)
     {
  if (dirlist like filters[idx])
    return 1;
  idx := idx + 1;
     }

   return ret;
}
;


create procedure
hm_filter_list ()
{
   if (adm_is_hosted () = 1)
     return '*.dll; *.exe';
   if (adm_is_hosted () = 2)
     return '*.class; *.zip';
   if (adm_is_hosted () = 3)
     return '*.dll; *.exe; *.class; *.zip';

   return '';
}
;

create procedure
db.dba.fs_browse_proc_empty (in path varchar, in show_details integer := 0, in filter varchar := '', in ord any := '', in ordseq any := 'asc')
{
  return vector();
};

create procedure fs_browse_proc (in path varchar, in show_details integer := 0, in filter varchar := '', in ord any := '', in ordseq any := 'asc')
{
  declare stat, msg, mdt, dta any;

      if (ord = 'name')
	ord := 2;
      else if (ord = 'size')
	ord := 4;
      else if (ord = 'modified')
	ord := 5;
      else if (ord = 'description')
	ord := 6;

      if (isinteger (ord))
	ord := sprintf (' order by %d %s', ord, ordseq);
      else
        ord := '';

  exec ('select * from Y_FS_DIR where path = ? and show_details = ? and filter = ? ' || ord
      , stat, msg, vector (path,show_details,filter), 0, mdt, dta);

  return dta;
}
;

yacutia_exec_no_error('create procedure view Y_FS_DIR as db.dba.fs_browse_proc_p (path,show_details,filter) (TYPE int, NAME varchar, MIME varchar, SIZE int, MODF datetime, FTYPE varchar)');

create procedure
db.dba.fs_browse_proc_p (in path varchar,
                       in show_details integer := 0,
                       in filter varchar := '' ) returns any
{
  declare i, len integer;
  declare dirlist, retval, filters any;
  declare f_type, f_name, f_mime, f_size, f_date, f_ftype any;

  result_names (f_type, f_name, f_mime, f_size, f_date, f_ftype);

  path := replace (path, '"', '');

  if (length (path) = 0)
    path := '.';

  if (path [length (path) - 1] <> ascii ('/'))
    path := concat (path, '/');

  if (filter = '__hosted_modules_list')
    filter := hm_filter_list ();

  if (isnull (filter) or filter = '' )
    filter := '%';

  filter := replace (filter, '*', '%');
  filter := replace (filter, ' ', '');

  if (strstr (filter, ';') is NULL)
   filters := vector (filter);
  else
   filters := split_and_decode (filter, 0, '\0\0;');

  retval := vector ();

  dirlist := sys_dirlist (path, 0);

  if (not isarray (dirlist))
    return;

  len := length (dirlist);

  i := 0;

  while (i < len)
    {
      if (dirlist[i] <> '.' and dirlist[i] <> '..')
        {
	  declare mod any;
	  f_type := 1;
	  f_name := dirlist[i];
	  f_mime := null;
	  f_size := -1;
	  mod := file_stat (path||dirlist[i], 0);
	  if (isstring(mod))
	    {
	      f_date := stringdate(mod);
	      f_ftype := 'Folder';
	      result (f_type, f_name, f_mime, f_size, f_date, f_ftype);
	    }
        }
      i := i + 1;
    }

  dirlist := sys_dirlist (path, 1);

  if (not isarray (dirlist))
    return;

 len := length (dirlist);

  i := 0;

  while (i < len)
    {
      if (fs_chek_filter (dirlist [i], filters))  -- we filter out files only
        {
	  declare ssize any;
	  f_type := 0;
	  f_name := dirlist[i];
	  f_mime := null;
	  ssize := file_stat (path || dirlist[i], 1);
	  if (isstring (ssize))
	    {
	      f_size := atoi(ssize);
	      f_date := stringdate (file_stat (path||dirlist[i], 0));
	      f_ftype := 'File';
	      result (f_type, f_name, f_mime, f_size, f_date, f_ftype);
	    }
        }
      i :=  i + 1;
    }
  return;
}
;

create procedure
db.dba.fs_crfolder_proc (in path varchar,
                         in folder varchar ) returns integer
{
  declare mk_dir_id integer;

  path := replace (path, '"', '');

  if (length (path) = 0)
    path := '.';

  if (path [length (path) - 1] <> ascii ('/'))
    path := concat (path, '/');

  return sys_mkdir (path || folder);
}
;

create procedure
db.dba.vproc_browse_proc_meta () returns any
{
  declare retval any;
  retval := vector ('ITEM_IS_CONTAINER', 'ITEM_NAME', 'ICON_NAME', 'Description');
  return retval;
}
;

create procedure
db.dba.vproc_browse_proc (in path varchar,
                          in filter varchar := '' ) returns any
{
  declare level, is_node integer;
  declare cat, sch, tbl, descr varchar;
  declare retval any;

  retval := vector();

  --retval := vector_concat(retval, vector(vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME','Description')));

  if (isnull (filter) or filter = '')
    filter := '%.%.%';

  replace (filter, '*', '%');

  path := trim (path,'.');
  cat := left (path, coalesce (strchr (path,'.'), length (path)));
  path := ltrim (subseq (path, length (cat)), '.');
  cat := trim (cat,'"');

  sch := left (path, coalesce (strchr (path,'.'), length (path)));
  path := ltrim (subseq (path, length(sch)), '.');
  sch := trim (sch,'"');
  tbl := trim (left (path, coalesce (strchr (path,'.'), length (path))),'"');

  if (sch <> '')
    level := 2;
  else if (cat <> '')
    level := 1;
  else
    level := 0;

  cat := case when cat <> '' then cat else '%' end;
  sch := case when sch <> '' then sch else '%' end;

  is_node := case when level < 2 then 1 else 0 end;
  descr := case level when 0 then 'Catalog' when 1 then 'Schema' else 'Procedure' end;

  if (cat = 'DB' AND sch = 'DBA')
    {
      retval := vector_concat (retval,
                               vector (vector (is_node,
                                               'HP_AUTH_SQL_USER',
                                               NULL,
                                               'Built-in')));
      retval := vector_concat (retval,
                               vector (vector (is_node,
                                               'HP_AUTH_DAV_ADMIN',
                                               NULL,
                                               'Built-in')));
      retval := vector_concat (retval,
                               vector (vector (is_node,
                                               'HP_AUTH_DAV_PROTOCOL',
                                               NULL,
                                               'Built-in')));
    }
  if (cat = 'WS' AND sch = 'WS')
    {
      retval := vector_concat(retval,
                              vector (vector (is_node,
                                              'DIGEST_AUTH',
                                              NULL,
                                              'Built-in')));
    }

  for (select DISTINCT name_part (P_NAME, level) AS ITEM
         from SYS_PROCEDURES
         where name_part(P_NAME, 0) LIKE cat and
               name_part (P_NAME, 1) like sch and
               P_NAME not like '%.%./%' and
               P_NAME like filter
         order by P_NAME) do
    {
      retval := vector_concat(retval,
                              vector(vector(is_node, ITEM, NULL, descr)));
    }
  return retval;
}
;

create procedure
db.dba.vview_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector ('ITEM_IS_CONTAINER', 'ITEM_NAME', 'ICON_NAME', 'Description');
  return retval;
}
;

create procedure
db.dba.vview_browse_proc (in path varchar,
                          in filter varchar := '') returns any
{
  declare level, is_node integer;
  declare cat, sch, tbl, descr varchar;
  declare retval any;

  retval := vector ();
  --retval := vector_concat(retval, vector(vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME','Description')));

  if (isnull (filter) or filter = '' )
    filter := '%.%.%';
  replace(filter, '*', '%');

  path := trim (path,'.');
  cat := left (path, coalesce (strchr (path,'.'), length(path)));
  path := ltrim (subseq (path, length (cat)), '.');
  cat := trim (cat,'"');

  sch := left (path, coalesce (strchr (path,'.'), length (path)));
  path := ltrim (subseq (path, length (sch)), '.');
  sch := trim (sch,'"');
  tbl := trim (left (path, coalesce (strchr (path,'.'), length (path))),'"');

  --if(tbl<>'') level := 3;

  if (sch <> '')
    level := 2;
  else if (cat <> '')
    level := 1;
  else
    level := 0;

  cat := case when cat <> '' then cat else '%' end;
  sch := case when sch <> '' then sch else '%' end;

  is_node := case when level < 2 then 1 else 0 end;
  descr := case level when 0 then 'Catalog' when 1 then 'Schema' else 'View' end;

  for(select distinct name_part (KEY_TABLE, level) as ITEM
        from DB.DBA.SYS_KEYS
        where name_part (KEY_TABLE, 0) like cat and
              name_part (KEY_TABLE, 1) like sch and
              table_type (KEY_TABLE) = 'VIEW' and
              KEY_IS_MAIN = 1 and
              KEY_MIGRATE_TO is NULL and
              KEY_TABLE like filter) do
    {
      retval := vector_concat (retval,
                               vector (vector (is_node, ITEM, NULL, descr)));
    }
  return retval;
}
;

create procedure DB.DBA.MSG_NEWS_DOWNLOAD_MESSAGES(in _ns_id integer, in _ng_id integer, in _mode varchar)
{
  if (isstring (_ng_id))
    new_news (atoi (_ng_id));
  return '';
}
;

create procedure
DB.DBA.MSG_NEWS_CLEAR_MESSAGES (in _ns_id integer,
                                in _ng_id integer,
                                in _mode varchar default '')
{
  declare _group_status, _group_pass, _group_first, _group_last, _group_last_out any;
  declare _server, _user, _password, _group_name, _max_body_id any;

  -- get news group parameters
  select NG_NAME,
         NG_PASS,
         NG_FIRST,
         NG_LAST,
         NG_LAST_OUT,
         NG_STAT
    into _group_name,
         _group_pass,
         _group_first,
         _group_last,
         _group_last_out,
         _group_status
    from DB.DBA.NEWS_GROUPS
    where NG_GROUP = _ng_id and
          NG_SERVER = _ns_id;

  -- check if retrieving already started by another process

  if (_group_status = 9)
    return 'Group already updating...';

  -- mark group as updating
  update DB.DBA.NEWS_GROUPS
  set NG_STAT = 9
  where NG_GROUP = _ng_id and
        NG_SERVER = _ns_id;

  commit work;

  {
    declare _nm_num_group, _nm_key_id any;
    declare cr cursor for
      select NM_NUM_GROUP, NM_KEY_ID
      from DB.DBA.NEWS_MULTI_MSG
      where NM_GROUP = _ng_id
      order by 1;

    whenever not found goto _end_cycle;

    open cr (exclusive, prefetch 1);

    while (1)
      {
        fetch cr into _nm_num_group, _nm_key_id;

        if (_nm_num_group >= _group_last_out and _mode <> 'clear all')
          goto _end_cycle;

        delete from DB.DBA.NEWS_MULTI_MSG
          where NM_KEY_ID = _nm_key_id;

        delete from DB.DBA.NEWS_MSG
          where NM_ID = _nm_key_id;
    }
_end_cycle:
      commit work;
  }

  update DB.DBA.NEWS_GROUPS
    set NG_STAT = 1
    where NG_GROUP = _ng_id and
          NG_SERVER = _ns_id;

  commit work;

  return '';
}
;

create procedure db.dba.yac_user_caps_meta() returns any
{
  return vector ('Type', 'Name', 'Permissions', 'Inherited Permissions');
}
;

create procedure
db.dba.yac_user_caps (in username varchar,
                      in filter varchar,
                      in show_all integer,
                      in tabls integer := 1,
                      in views integer := 1,
                      in procs integer := 1,
		      in ord any := null,
		      in ordseq any := 'asc')
{
  declare mtd, dta any;
  declare inh any;
  declare sql varchar;
  DECLARE user_ident, pars VARCHAR;



  select U_ID into user_ident from SYS_USERS where U_NAME = username;

  inh := vector ();
  GET_INHERITED_GRANTS (user_ident, user_ident, inh);

  inh := vector_concat (vector (user_ident), inh);


  if (isnull (filter) or filter = '' )
    filter := '%.%.%';

 if (length (ord))
   {
     if (ord = 'name')
       ord := ' order by 2 ' || ordseq;
     else if (ord = 'type')
       ord := ' order by 5 ' || ordseq;
     else if (ord = 'owner')
       ord := ' order by 6 ' || ordseq;
     else
       ord := '';
   }
 else
   ord := '';


  sql := '';

  pars := vector ();

  if (tabls <> 0)
    {
      sql := sql ||
       'select distinct 1, KEY_TABLE, cast (direct_grants(KEY_TABLE, ? ) as int) as dg, indirect_grants(KEY_TABLE, ?) as ig
       , ''Table'' as rt, name_part (KEY_TABLE, 1) as own
       from DB.DBA.SYS_KEYS
       where KEY_TABLE like ?
         and table_type (KEY_TABLE) = ''TABLE''
         and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is NULL ' ||
       case when show_all = 0 then 'AND __any_grants_to_user(KEY_TABLE, ?) ' else '' end ;
       --	   || 'order by KEY_TABLE';
       pars := vector (user_ident, inh, filter);
       if (show_all = 0)
	 pars := vector_concat (pars, vector (username));
      --exec (sql, null, null, vector (1, user_ident, inh, filter, 'TABLE', username), 0, mtd, dta);
      --retval := vector_concat (retval, dta);
    }

  if ( views <> 0)
    {
      sql := sql || case when length (sql) then ' union all ' else '' end ||
       'select distinct 2, KEY_TABLE, cast (direct_grants(KEY_TABLE, ? ) as int) as dg, indirect_grants(KEY_TABLE, ?) as ig
       , ''View'' as rt, name_part (KEY_TABLE, 1) as own
       from DB.DBA.SYS_KEYS
       where KEY_TABLE like ?
         and table_type (KEY_TABLE) = ''VIEW''
         and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is NULL ' ||
       case when show_all = 0 then 'AND __any_grants_to_user(KEY_TABLE, ?) ' else '' end ;
      pars := vector_concat (pars, vector (user_ident, inh, filter));
      if (show_all = 0)
	pars := vector_concat (pars, vector (username));
      --exec (sql, null, null, vector (2, user_ident, inh, filter, 'VIEW', username), 0, mtd, dta);
      --retval := vector_concat (retval, dta);
    }

  if (procs <> 0)
    {
      sql := sql || case when length (sql) then ' union all ' else '' end ||
      'select 3, P_NAME, cast (direct_grants(P_NAME, ? ) as int) as dg, indirect_grants(P_NAME, ?) as ig
       , ''Procedure'' as rt, name_part (P_NAME, 1) as own
       from DB.DBA.SYS_PROCEDURES
       where P_NAME like ? ' || case when show_all=0 then 'AND __any_grants_to_user(P_NAME, ?) ' else '' end;
       --|| 'order by P_NAME';

      pars := vector_concat (pars, vector (user_ident, inh, filter));
      if (show_all = 0)
	pars := vector_concat (pars, vector (username));
      --exec (sql, null, null, vector (user_ident, inh, filter, username), 0, mtd, dta);
      --retval := vector_concat(retval, dta);
  }

 if (sql = '')
   return vector ();

 sql := sql || ord;

 exec (sql, null, null, pars, 0, mtd, dta);
 done:
  return dta;
}
;

create procedure
direct_grants( in object_name varchar, in user_id integer, in colname varchar := '_all' ) returns integer
{
  declare dg int;
  dg := 0;

  for( select G_OP from SYS_GRANTS where G_USER = user_id and G_OBJECT = object_name and G_COL in ('_all', colname)) do {
    dg := bit_or( dg, G_OP );
  }
  return dg;
}
;

create procedure
indirect_grants (in object_name varchar,
                 in user_ids any,
                 in colname varchar := '_all') returns varchar
{
  declare dg int;
  declare grants varchar;
  grants := '------';
  declare i, u int;

  i := 0;

  while (i < length(user_ids))
    {
      if (user_ids[i] = 0 or user_ids[i] = 3) -- DBA user or group
        return 'AAAAAA';
      i := i + 1;
    }

  -- public object
    for (select G_OP
           from SYS_GRANTS
           where G_USER = 1 and
                 G_OBJECT = object_name and
                 G_COL in ('_all', colname)) do
      {
        i := 0;

        while(i < 6)
          {
            if (bit_and (bit_shift (1, i), G_OP))
              grants[i] := ascii ('P');
            i := i + 1;
          }
      }

    u := 0;

    while (u < length (user_ids))
      {
    -- object is granted to user

        for (select G_OP
               from SYS_GRANTS
               where G_USER = user_ids[u] and
                     G_OBJECT = object_name and
                     G_COL in ('_all', colname)) do
          {
            i := 0;
            while (i < 6)
              {
                if (bit_and (bit_shift (1, i), G_OP))
                  grants[i] := ascii('+');
                i := i + 1;
              }
          }
        u := u + 1;
      }
  return grants;
}
;

create procedure adm_get_users (in mask any := '%', in ord any := '', in seq any := 'asc')
{
  declare sql, dta, mdta, rc, h, tmp any;

  declare U_NAME, U_FULL_NAME, U_LOGIN_TIME, U_EDIT_TIME any;
  result_names (U_NAME, U_FULL_NAME, U_LOGIN_TIME, U_EDIT_TIME);
  if (not isstring (mask))
    mask := '%';
  sql := 'select U_NAME, coalesce (U_FULL_NAME, \'\') as U_FULL_NAME, U_LOGIN_TIME, cast (USER_GET_OPTION (U_NAME, \'ConductorEdit\') as datetime)
          from SYS_USERS where  U_IS_ROLE = 0 and (upper (U_NAME) like upper (?)) ';
  if (length (ord))
    {
      tmp := case ord when 'name' then '1' when 'fullname' then '2' when 'login' then '3' when 'edit' then '4' else '' end;
      if (tmp <> '')
	{
	  ord := 'order by ' || tmp || ' ' || seq;
	  sql := sql || ord;
	}
    }
  rc := exec (sql, null, null, vector (mask), 0, null, null, h);
  while (0 = exec_next (h, null, null, dta))
    exec_result (dta);
  exec_close (h);
}
;

create procedure adm_get_all_users (in mask any := '%', in ord any := '', in seq any := 'asc')
{
  declare sql, dta, mdta, rc, h, tmp any;

  declare U_NAME, U_FULL_NAME, U_LOGIN_TIME, U_EDIT_TIME any;
  result_names (U_NAME, U_FULL_NAME, U_LOGIN_TIME, U_EDIT_TIME);
  if (not isstring (mask))
    mask := '%';
  sql := 'select U_NAME, coalesce (U_FULL_NAME, \'\') as U_FULL_NAME, U_IS_ROLE
          from SYS_USERS where (upper (U_NAME) like upper (?)) ';
  if (length (ord))
    {
      tmp := case ord when 'name' then '1' when 'fullname' then '2' when 'type' then '3' else '' end;
      if (tmp <> '')
	{
	  ord := 'order by ' || tmp || ' ' || seq;
	  sql := sql || ord;
	}
    }
  rc := exec (sql, null, null, vector (mask), 0, null, null, h);
  while (0 = exec_next (h, null, null, dta))
    exec_result (dta);
  exec_close (h);
}
;

yacutia_exec_no_error('create procedure view Y_SYS_USERS_USERS as adm_get_users (mask, ord, seq) (U_NAME varchar, U_FULL_NAME varchar, U_LOGIN_TIME datetime, U_EDIT_TIME datetime)');

yacutia_exec_no_error('create procedure view Y_SYS_USERS as adm_get_all_users (mask, ord, seq) (U_NAME varchar, U_FULL_NAME varchar, U_IS_ROLE int)');

create procedure adm_get_scheduled_events (in ord any := '', in seq any := 'asc')
{
  declare SE_NAME, SE_START, SE_LAST_COMPLETED, SE_INTERVAL, SE_LAST_ERROR, SE_NEXT any;
  declare  sql, dta, mdta, rc, h, tmp any;
  result_names (SE_NAME, SE_START, SE_LAST_COMPLETED, SE_INTERVAL, SE_LAST_ERROR, SE_NEXT);
  sql := 'select SE_NAME, SE_START, SE_LAST_COMPLETED, SE_INTERVAL, case when length (SE_LAST_ERROR) then ''error'' else null end,
          case when SE_LAST_COMPLETED is not null then datediff (''minute'', SE_LAST_COMPLETED, now()) else null end
          from DB.DBA.SYS_SCHEDULED_EVENT';
  if (length (ord))
    {
      tmp := case ord when 'name' then '1' when 'start' then '2' when 'last' then '3'
       when 'interval' then '4' when 'error' then '5' when 'next' then '6' else '' end;
      if (tmp <> '')
	{
	  ord := ' order by ' || tmp || ' ' || seq;
	  sql := sql || ord;
	}
    }
  rc := exec (sql, null, null, vector (), 0, null, null, h);
  while (0 = exec_next (h, null, null, dta))
    exec_result (dta);
  exec_close (h);
}
;

yacutia_exec_no_error('create procedure view Y_SYS_SCHEDULED_EVENT as adm_get_scheduled_events (ord, seq) (SE_NAME varchar, SE_START datetime, SE_LAST_COMPLETED datetime, SE_INTERVAL int, SE_LAST_ERROR varchar, SE_NEXT int)');

--select indirect_grants( 'WS.SOAP.countTheEntities', vector(103));
--select G_OP from SYS_GRANTS where G_USER = 103 and G_OBJECT = 'WS.SOAP.countTheEntities' and G_COL in ('_all', '_all');


create procedure
YACUTIA_DAV_COPY (in path varchar,
                  in destination varchar,
                  in overwrite integer := 0,
                  in permissions varchar := '110100000R',
                  in uid integer := NULL,
                  in gid integer := NULL)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = cur_user);

  rc := DAV_COPY (path, destination, overwrite, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_MOVE (in path varchar,
                  in destination varchar,
                  in overwrite varchar)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = cur_user);

  rc := DAV_MOVE (path, destination, overwrite, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_STATUS (in status integer) returns varchar
{
  if (status = -1)
    return 'Invalid target path';

  if (status = -2)
    return 'Invalid destination path';

  if (status = -3)
    return 'Destination already exists and overwrite flag not set';

  if (status = -4)
    return 'Invalid target type (resource) in copy/move';

  if (status = -5)
    return 'Invalid permissions';

  if (status = -6)
    return 'Invalid uid';

  if (status = -7)
    return 'Invalid gid';

  if (status = -8)
    return 'Target is locked';

  if (status = -9)
    return 'Destination is locked';

  if (status = -10)
    return 'Property name is reserved (protected or private)';

  if (status = -11)
    return 'Property does not exists';

  if (status = -12)
    return 'Authentication failed';

  if (status = -13)
    return 'Insufficient privileges for operation';

  if (status = -14)
    return 'Invalid target type';

  if (status = -15)
    return 'Invalid umask';

  if (status = -16)
    return 'Property already exists';

  if (status = -17)
    return 'Invalid property value';

  if (status = -18)
    return 'No such user';

  if (status = -19)
    return 'No home directory';

  return sprintf ('Unknown error %d', status);
}
;

create procedure
YACUTIA_DAV_DELETE (in path varchar,
                    in silent integer := 0,
                    in extern integer := 1)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = cur_user);

  rc := DAV_DELETE_INT (path, silent, cur_user, pwd1, extern);
  return rc;
}
;

create procedure
YACUTIA_DAV_RES_UPLOAD (in path varchar,
                        inout content any,
                        in type varchar := '',
                        in permissions varchar := '110100000R',
                        in uid varchar := 'dav',
                        in gid varchar := 'dav',
                        in cr_time datetime := null,
                        in mod_time datetime := null,
                        in _rowguid varchar := null)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = cur_user);

  rc := DAV_RES_UPLOAD_STRSES (path, content, type, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_COL_CREATE (in path varchar,
                        in permissions varchar,
                        in uid varchar,
                        in gid varchar)
{
  declare rc integer;
  declare pwd1, cur_user any;

  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = cur_user);

  rc := DAV_COL_CREATE (path, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_DIR_LIST (in path varchar := '/DAV/',
                      in recursive integer := 0,
                      in auth_uid varchar := 'dav')
{
  declare res, pwd1 any;

  if (auth_uid = 'dba')
    auth_uid := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = auth_uid);
  res := DAV_DIR_LIST (path, recursive, auth_uid, pwd1);
  return res;
}
;

create procedure
YACUTIA_DAV_DIR_LIST_P (in path varchar := '/DAV/', in recursive integer := 0, in auth_uid varchar := 'dav')
{
  declare arr, pwd1 any;
  declare i, l integer;
  declare FULL_PATH, PERMS, MIME_TYPE, NAME varchar;
  declare TYPE char(1);
  declare RLENGTH, ID, GRP, OWNER integer;
  declare MOD_TIME, CR_TIME datetime;
  result_names (FULL_PATH, TYPE, RLENGTH, MOD_TIME, ID, PERMS, GRP, OWNER, CR_TIME, MIME_TYPE, NAME);

  if (auth_uid = 'dba')
    auth_uid := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = auth_uid);
  arr := DAV_DIR_LIST (path, recursive, auth_uid, pwd1);
  i := 0; l := length (arr);
  while (i < l)
    {
      declare own, grp any;
      own := 'none';
      grp := 'none';
      if (arr[i][7] is not null)
        own := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = arr[i][7]), 'none');
      if (arr[i][6] is not null)
        grp := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = arr[i][6]), 'none');
      result (arr[i][0],
	  arr[i][1],
	  arr[i][2],
	  arr[i][3],
	  case when isinteger (arr[i][4]) then arr[i][4] else -1 end,
	  arr[i][5],
	  grp,
	  own,
	  arr[i][8],
	  arr[i][9],
	  arr[i][10]);
      i := i + 1;
    }
}
;

yacutia_exec_no_error ('drop view Y_DAV_DIR');
yacutia_exec_no_error('create procedure view Y_DAV_DIR as YACUTIA_DAV_DIR_LIST_P (path,recursive,auth_uid) (FULL_PATH varchar, TYPE varchar, RLENGTH integer, MOD_TIME datetime, ID integer, PERMS varchar, GRP varchar, OWNER varchar, CR_TIME datetime, MIME_TYPE varchar, NAME varchar)')
;

create procedure
dav_path_validate (in path varchar,
                   out folder_owner integer,
                   out folder_group integer,
                   out folder_perms varchar,
                   out message varchar)
{
  declare  sl_pos, cname_size,c_id, flag, c_owner, c_group integer;
  declare path_tree, cname, cperm varchar;

  message := 'Folder not found.';
  whenever not found goto not_found;

  if (substring(path,1,5) <> '/DAV/' )
    {
      message := sprintf('path %s is incorrect. Must start from /DAV/...', path );
      goto not_found;
    }

  sl_pos := coalesce (strrchr (path, '/'), 0);
  path_tree :=  substring(path,1,sl_pos);
  flag := 0;

  while (sl_pos > 0)
    {
      sl_pos := coalesce ( strrchr (path_tree, '/'),0);
      cname_size :=  length(path_tree) - sl_pos;
      cname := substring(path_tree, sl_pos +2, cname_size);
      if (exists (select 1 from WS.WS.SYS_DAV_COL where COL_NAME = cname))
        {
          select COL_ID,
                 COL_OWNER,
                 COL_GROUP,
                 COL_PERMS
            into c_id,
                 c_owner,
                 c_group,
                 cperm
            from WS.WS.SYS_DAV_COL
            where COL_NAME = cname;

          if (flag = 0)
            {
              folder_perms := cperm;
              folder_owner := c_owner;
              folder_group := c_group;
              flag := 1;
            }

        }
      else
        {
          message := sprintf ('Folder %s does not exist.', path_tree );
          goto not_found;
        }
      if (sl_pos > 0)
        path_tree := substring (path_tree,1,sl_pos);
    }
  return 1;
 not_found:
  return 0;
}
;

create procedure
dav_check_permissions (in user_name varchar,
                       in file_perms varchar,
                       in mask varchar,
                       in dav_folder_owner integer,
                       in dav_folder_group integer,
                       out message varchar)
{
  declare a_user_name, user_id, g_id, vmask varchar;
  declare i integer;

  vmask := '000';
  whenever not found goto not_found;

  if (user_name = 'dba')
    return 1;

  if (exists (select 1 from ws.ws.SYS_DAV_USER where U_NAME = user_name))
    {
      select U_ID, U_GROUP into user_id, g_id from ws.ws.SYS_DAV_USER where U_NAME = user_name;

      if (user_id = http_dav_uid () or g_id = http_dav_uid () + 1)
        return 1;

      if (length (file_perms) < 9 or length (mask) < 3)
        goto not_found;

      if (dav_folder_owner = user_id)
        {
       ; -- You are owner of this folder

          i:= 0;

          while (i < 3)
            {
              if (chr (aref (mask,i)) = '1' and chr (aref (file_perms,i)) = '1')
                aset(vmask,i,ascii('1'));
              i := i + 1;
            }

          if (
              ((chr(aref(mask,0)) = '1' and chr(aref(vmask,0)) = '1') or
               (chr(aref(mask,0)) = '0' and chr(aref(vmask,0)) = '0')) and
              ((chr(aref(mask,1)) = '1' and chr(aref(vmask,1)) = '1') or
               (chr(aref(mask,1)) = '0' and chr(aref(vmask,1)) = '0')) and
              ((chr(aref(mask,2)) = '1' and chr(aref(vmask,2)) = '1') or
               (chr(aref(mask,2)) = '0' and chr(aref(vmask,2)) = '0'))
             )
            return 1;
        }

      if (dav_folder_group = g_id)
        {
    ; -- you are member if group, to which this folder belongs.

          i:= 0;

          while (i < 3)
            {
              if (chr(aref(mask,i)) = '1' and chr(aref(file_perms,i +3)) = '1')
                aset(vmask,i,ascii('1'));

              i := i + 1;
            }

          if (
              ((chr(aref(mask,0)) = '1' and chr(aref(vmask,0)) = '1') or
               (chr(aref(mask,0)) = '0' and chr(aref(vmask,0)) = '0' )) and
              ((chr(aref(mask,1)) = '1' and chr(aref(vmask,1)) = '1') or
               (chr(aref(mask,1)) = '0' and chr(aref(vmask,1)) = '0')) and
              ((chr(aref(mask,2)) = '1' and chr(aref(vmask,2)) = '1') or
               (chr(aref(mask,2)) = '0' and chr(aref(vmask,2)) = '0'))
             )
            return 1;
        }
      if (exists (select 1
                   from SYS_ROLE_GRANTS
                   where GI_SUPER=user_id and GI_SUB = dav_folder_group ))
        {
      ; --  group, to which folder belongs , is granted to you

          i:= 0;

          while (i < 3)
            {
              if (chr (aref (mask, i)) = '1' and chr (aref (file_perms, i + 3)) = '1')
                aset(vmask,i,ascii('1'));

              i := i + 1;
            }
          if (
              ((chr (aref (mask, 0)) = '1' and chr (aref (vmask, 0)) = '1') or
               (chr (aref (mask, 0)) = '0' and chr (aref (vmask, 0)) = '0'))
              and
              ((chr (aref (mask, 1)) = '1' and chr (aref (vmask, 1)) = '1') or
               (chr (aref (mask, 1)) = '0' and chr (aref (vmask, 1)) = '0'))
              and
              ((chr (aref (mask, 2)) = '1' and chr (aref (vmask, 2)) = '1') or
               (chr (aref (mask, 2)) = '0' and chr (aref (vmask, 2)) = '0')))
            return 1;
        }
    -- You are among others

      i:= 0;

      while (i < 3)
        {
          if (chr (aref (mask,i)) = '1' and chr (aref (file_perms, i + 6)) = '1')
            aset (vmask,i,ascii('1'));
          i := i + 1;
        }

      if (
          ((chr (aref (mask, 0)) = '1' and chr (aref (vmask, 0)) = '1') or
           (chr (aref (mask, 0)) = '0' and chr (aref (vmask, 0)) = '0' ))
          and
          ((chr (aref (mask, 1)) = '1' and chr (aref (vmask, 1)) = '1') or
           (chr (aref (mask, 1)) = '0' and chr (aref (vmask, 1)) = '0'))
          and
          ((chr (aref (mask, 2)) = '1' and chr (aref (vmask, 2)) = '1') or
           (chr (aref (mask, 2)) = '0' and chr (aref (vmask, 2)) = '0' ))
         )
        return 1;

      goto not_found;

    }
  else
    {
      message := sprintf ('Account %s does not have DAV login enabled.', user_name);
      return 0;
    }

 not_found:
  message := 'Access denied.';
  return 0;
}
;

create procedure
check_dav_file_permissions (in path varchar,
                            in user_name varchar,
                            in actions varchar,
                            out message varchar)
{
  declare file_perms varchar;
  declare file_owner, file_group  integer;

  whenever  not found goto not_found;
  if (not exists (select 1 from ws.ws.SYS_DAV_USER where U_NAME = user_name))
    {
      message := sprintf('Access into DAV is denied for user: %s.',user_name);
      return 0;
    }

  if (not exists (select 1 from WS.WS.SYS_DAV_RES  where RES_FULL_PATH = path))
    goto not_found;

  select RES_PERMS,
         RES_OWNER,
         RES_GROUP
    into file_perms,
         file_owner,
         file_group
    from WS.WS.SYS_DAV_RES
    where RES_FULL_PATH = path;

  return dav_check_permissions (user_name,
                                file_perms,
                                actions,
                                file_owner,
                                file_group,
                                message);
 not_found:
  message := sprintf ('File %s does not exist.', path);
  return 0;
}
;

create procedure
get_sql_tables (in dsn varchar,
                in cat varchar,
                in sch varchar,
                in table_mask varchar,
                in obj_type varchar)
{
  declare key_list, cat_list, sch_list, tables_list any;
  declare i, len, j, lz, sz, n, is_found integer;
  declare c_cat, c_sch, m_mask, v varchar;

  cat_list := vector ();
  sch_list := vector ();
  if (cat ='%' or sch = '%')
  {
    key_list := sql_tables (dsn, null, null, null, null);
  }

  if (cat = '%')
  {
    len := length (key_list);
    for (i:= 0; i < len; i := i + 1)
    {
      v := key_list[i][0];
  	  if (v is null)
	      v := '%';

      if (not position (v, cat_list))
        cat_list := vector_concat (cat_list, vector (v));
    }
  }
  else
  {
    cat_list := vector_concat (cat_list, vector(cat));
  }

  if (sch = '%')
  {
    len :=  length (key_list);
    for (i := 0; i < len; i := i + 1)
    {
      v := key_list[i][1];
  	  if (v is null)
	      v := '%';

      if (v is not null and not position (v, sch_list))
        sch_list := vector_concat (sch_list, vector (v));
    }
  }
  else
  {
    sch_list := vector_concat (sch_list, vector (sch));
  }

   -- now  fetch all records
  if (table_mask is not null)
    m_mask := table_mask;
  else
    m_mask := '%';

  tables_list := vector();
  len := length (cat_list);
  for (i := 0; i < len; i := i + 1)
  {
    c_cat := cat_list[i];
    if (c_cat = '%')
      c_cat := null;

    lz := length (sch_list);
    for (j := 0; j < lz; j := j + 1)
    {
      declare tbls any;

      c_sch := sch_list[j];
      if (c_sch = '%')
        c_sch := null;

	    tbls := sql_tables (dsn, c_cat, c_sch, null, obj_type);
	    if (m_mask = '%')
	    {
	      tables_list := vector_concat (tables_list, tbls);
	    }
	    else
	    {
	      foreach (any tbl in tbls) do
	      {
	        if (length (tbl) > 1 and tbl[2] is not null and tbl[2] like m_mask)
	        {
	          tables_list := vector_concat (tables_list, vector (tbl));
	        }
	      }
	    }
	  }
  }
  return tables_list;
}
;


create procedure
get_sql_procedures (in dsn varchar, in cat varchar, in sch varchar, in table_mask varchar)
{
  declare key_list, cat_list, sch_list, tables_list any;
  declare i, len, j, lz, sz, n, is_found integer;
  declare c_cat, c_sch, m_mask, v varchar;
  cat_list:= vector();
  sch_list:= vector();

  if (cat ='%' or sch = '%')
    {
      key_list := sql_procedures (dsn, null, null, null);
    }

  if (cat ='%')
    {
      i:= 0; len :=  length (key_list);
      while (i < len)
        {
          v := aref (aref (key_list, i), 0);
          n := 0; sz := length (cat_list);
          is_found := 0;
          while(n < sz)
            {
              if (v = aref (cat_list, n) or (v is null and aref (cat_list, n) is null))
                is_found := 1;
              n := n + 1;
            }

          if (is_found = 0)
            cat_list := vector_concat (cat_list, vector (v));

          i := i + 1;
        }
    }
  else
    cat_list := vector_concat (cat_list, vector (cat));

  if (sch = '%')
    {
      i:= 0; len :=  length (key_list);
      while (i < len)
        {
          v := aref (aref (key_list, i), 1);
          n := 0; sz := length (sch_list);
          is_found := 0;

          while(n < sz)
            {
              if (v = aref (sch_list, n) or (v is null and aref (sch_list, n) is null))
                is_found := 1;
              n := n + 1;
            }

          if (is_found = 0)
            sch_list := vector_concat (sch_list, vector (v));

          i := i + 1;
        }
    }
  else
    sch_list := vector_concat (sch_list, vector (sch));

   -- now  fetch all records

   if (table_mask is not null)
     m_mask := table_mask;
   else
     m_mask := '%';
  tables_list := vector ();
  i := 0; len := length (cat_list);

  while (i < len)
    {
      c_cat := aref (cat_list, i);
      j := 0; lz := length (sch_list);

       while(j < lz)
         {
	   declare tbls any;
           c_sch := aref (sch_list, j);
	   tbls :=  sql_procedures(dsn, c_cat, c_sch, null);
	   if (m_mask = '%')
	     {
               tables_list := vector_concat (tables_list, tbls);
	     }
	   else
	     {
	       foreach (any tbl in tbls) do
		 {
		   if (length (tbl) > 1 and tbl[2] is not null and tbl[2] like m_mask)
		     {
		       tables_list := vector_concat (tables_list, vector (tbl));
		     }
		 }
	     }
           j := j + 1;
         }

       i:= i + 1;
    }
  return  tables_list;
}
;

create procedure get_vdb_data_types() {
    return vector('INTEGER','NUMERIC','DECIMAL','DOUBLE PRECISION','REAL','CHAR','CHARACTER','VARCHAR','NVARCHAR','ANY','NCHAR','SMALLINT','FLOAT','DATETIME','DATE','TIME','BINARY');
}
;


create procedure
vdb_get_pkeys (in dsn varchar, in tbl_qual varchar, in tbl_user varchar, in tbl_name varchar)
  {
    declare pkeys, pkey_curr, pkey_col, my_pkeys any;
    declare pkeys_len, idx integer;

    if (length (tbl_qual) = 0)
      tbl_qual := NULL;
    if (length (tbl_user) = 0)
      tbl_user := NULL;

    if (sys_stat ('vdb_attach_autocommit') > 0) vd_autocommit (dsn, 1);
      {
  declare exit handler for SQLSTATE '*'
  goto next;

  pkeys := sql_primary_keys (dsn, tbl_qual, tbl_user, tbl_name);
      };
    next:

    if (not pkeys) pkeys := NULL;

    pkeys_len := length (pkeys);
    idx := 0;
    my_pkeys := vector();
    if (0 <> pkeys_len)
      {
  while (idx < pkeys_len)
    {
      pkey_curr := aref (pkeys, idx);
      pkey_col := aref (pkey_curr, 3);
      my_pkeys := vector_concat (my_pkeys, vector(pkey_col));
      idx := idx +1;
    }
      }
    else
      {
  if (sys_stat ('vdb_attach_autocommit') > 0) vd_autocommit (dsn, 1);
    {
      declare exit handler for SQLSTATE '*'
      goto next2;

      pkeys := sql_statistics (dsn, tbl_qual, tbl_user, tbl_name, 0, 1);
    };
  next2:

  if (not pkeys) pkeys := NULL;

    pkeys_len := length (pkeys);

  if (0 <> pkeys_len)
    {
      while (idx < pkeys_len)
        {
    pkey_curr := aref (pkeys, idx);
    pkey_col := aref (pkey_curr, 8);
                if (idx > 0 and aref (pkey_curr, 7) = 1 and length (my_pkeys) > 0)
                  goto key_ends;
    if (pkey_col is not null)
      my_pkeys := vector_concat (my_pkeys, vector(pkey_col));
    idx := idx +1;
        }
   key_ends:;
    }
  else
    {
      pkeys := NULL;
      pkeys_len := 0;
    }
      }

   return my_pkeys;
  }
;

yacutia_exec_no_error ('CREATE TABLE DB.DBA.SYS_REMOTE_PROCEDURES (RP_NAME varchar primary key, RP_REMOTE_NAME varchar, RP_DSN varchar)');

create procedure R_GET_REMOTE_NAME (inout pr_text any, inout rname any, inout dsn any)
{
  declare rc int;
  rname := null;
  dsn := null;
  rc := 0;

  declare exit handler for sqlstate '*'
    {
      rname := null;
      dsn := null;
      return 0;
    };

  if (regexp_match ('\-\-PL Wrapper ', pr_text) is not null)
    {
      declare tmp any;
      declare dsnofs, profs int;
      tmp := regexp_match ('\-\-"DSN:.*PROCEDURE:.*', pr_text);
      tmp := trim (tmp, '" ');
      dsnofs := strstr (tmp, '--"DSN:');
      profs := strstr (tmp, 'PROCEDURE:');
      if (dsnofs is not null and profs is not null)
        {
          dsn := subseq (tmp, dsnofs + 7, profs);
          rname := subseq (tmp, profs + 10);
          rname := trim (rname);
          dsn := trim (dsn);
    rc := 1;
        }
    }
  else if (regexp_match ('^attach procedure', lower (pr_text)) is not null)
   {
      declare exp any;
      exp := sql_parse (pr_text);
      dsn := exp[6];
      rname := exp[2];
      rc := 1;
   }
  return rc;
}
;

create procedure R_PROC_INIT ()
{
  if (registry_get ('R_PROC_INIT') = '1')
    return;
  for select P_NAME, coalesce (P_TEXT, blob_to_string (P_MORE)) as pr_text
        from DB.DBA.SYS_PROCEDURES
        where P_NAME not like '%.vsp' and
              (
         regexp_match ('^attach procedure',
     lower (coalesce (P_TEXT, blob_to_string (P_MORE)))) is not null or
               regexp_match ('\-\-PL Wrapper ', coalesce (P_TEXT, blob_to_string (P_MORE))) is not null
              ) do
    {
      declare rname, dsn varchar;

      if (R_GET_REMOTE_NAME (pr_text, rname, dsn))
  {
          insert soft  DB.DBA.SYS_REMOTE_PROCEDURES (RP_NAME, RP_REMOTE_NAME, RP_DSN)
            values (P_NAME, rname, dsn);
  }
    }
  registry_set ('R_PROC_INIT', '1');
}
;

create trigger SYS_PROCEDURES_REMOTE_AI after insert on SYS_PROCEDURES
{
  declare pr_text any;
  declare rname, dsn varchar;

  pr_text := coalesce (P_TEXT, blob_to_string (P_MORE));
  R_GET_REMOTE_NAME (pr_text, rname, dsn);
  if (R_GET_REMOTE_NAME (pr_text, rname, dsn))
    {
      insert soft  DB.DBA.SYS_REMOTE_PROCEDURES (RP_NAME, RP_REMOTE_NAME, RP_DSN)
         values (P_NAME, rname, dsn);
    }
}
;

create trigger SYS_PROCEDURES_REMOTE_AU after update on SYS_PROCEDURES
referencing old as O, new as N
{
  declare pr_text any;
  declare rname, dsn varchar;
  pr_text := coalesce (N.P_TEXT, blob_to_string (N.P_MORE));
  delete from DB.DBA.SYS_REMOTE_PROCEDURES where RP_NAME = O.P_NAME;
  if (R_GET_REMOTE_NAME (pr_text, rname, dsn))
    {
      insert soft  DB.DBA.SYS_REMOTE_PROCEDURES (RP_NAME, RP_REMOTE_NAME, RP_DSN)
         values (N.P_NAME, rname, dsn);
    }
}
;

create trigger SYS_PROCEDURES_REMOTE_AD after delete on SYS_PROCEDURES
{
  delete from DB.DBA.SYS_REMOTE_PROCEDURES where RP_NAME = P_NAME;
}
;

create procedure YAC_GET_DAV_ERR (in code int)
{
  return 'The WebDAV operation failed. Error code: ' || DAV_PERROR (code);
}
;

create procedure YAC_DAV_RES_UPLOAD
    (
    in path varchar,
    in body any,
    in tp any,
    in perms varchar,
    in own any,
    in grp any,
    in usr varchar := null
    )
{
  declare rc, flag, pwd int;

  flag := 0; pwd := null;
  if (usr is not null)
    {
      if (usr = 'dba')
        usr := 'dav';
      whenever not found goto err;
      rc := -12;
      flag := 1;
      select pwd_magic_calc (U_NAME, U_PASSWORD) into pwd from SYS_USERS where U_NAME = usr;
      rc := 0;
    }

  rc := DAV_RES_UPLOAD_STRSES_INT
        (
   path,
   body,
   tp,
   perms,
   own,
   grp,
   usr,
   pwd,
   flag
  );

err:
  if (rc <= 0)
    signal ('22023', YAC_GET_DAV_ERR (rc));
}
;

create procedure YAC_DAV_PROP_SET (in path varchar, in prop varchar, in val any, in usr varchar := null)
{
  declare rc, flag, pwd any;

  flag := 0; pwd := null;
  if (usr is not null)
    {
      if (usr = 'dba')
	usr := 'dav';
      whenever not found goto err;
      rc := -12;
      flag := 1;
      select pwd_magic_calc (U_NAME, U_PASSWORD) into pwd from SYS_USERS where U_NAME = usr;
      rc := 0;
    }
  if (flag = 0)
    usr := 'dav';

  rc := DB.DBA.DAV_PROP_SET_INT (path, prop, val, usr, pwd, flag);
err:
  if (rc <= 0)
    signal ('22023', YAC_GET_DAV_ERR (rc));
}
;

create procedure YAC_DAV_PROP_REMOVE (in path varchar, in prop varchar, in usr varchar, in silent int := 0)
{
  declare rc, flag, pwd any;

  pwd := null;
  whenever not found goto err;
  if (usr = 'dba')
    usr := 'dav';
  rc := -12;
  select pwd_magic_calc (U_NAME, U_PASSWORD) into pwd from SYS_USERS where U_NAME = usr;
  rc := 0;
  rc := DB.DBA.DAV_PROP_REMOVE (path, prop, usr, pwd);
err:
  if (rc < 0 and silent = 0)
    signal ('22023', YAC_GET_DAV_ERR (rc));
}
;

create procedure www_split_host (in fhost any, out host any, out port any)
{
  declare pos int;
  pos := strrchr (fhost, ':');
  if (pos is not null)
    {
      host := substring (fhost, 1, pos);
      port := substring (fhost, pos + 2, length (fhost));
    }
  else
    {
      host := fhost;
      if (host not in ('*ini*', '*sslini*'))
        port := '80';
    }
}
;

create procedure www_listeners ()
{
  declare xt, xp any;
  declare VHOST, PORT, INTF, HOST, LHOST varchar;
  declare NO_EDIT, NO_CTRL int;
  result_names (VHOST, PORT, INTF, NO_EDIT, HOST, LHOST, NO_CTRL);
  xt := www_tree ('*LISTENERS*');
  xp := xpath_eval ('/www/node', xt, 0);
  foreach (any xpp in xp) do
    {
      VHOST := cast (xpath_eval ('@host', xpp) as varchar);
      PORT := cast (xpath_eval ('@port', xpp) as varchar);
      INTF := cast (xpath_eval ('@lhost', xpp)  as varchar);
      NO_EDIT := xpath_eval ('number (@edit)', xpp);
      HOST := cast (xpath_eval ('@chost', xpp)  as varchar);
      LHOST := cast (xpath_eval ('@clhost', xpp)  as varchar);
      NO_CTRL := xpath_eval ('number (@control)', xpp);
      result (VHOST, PORT, INTF, NO_EDIT, HOST, LHOST, NO_CTRL);
    }
}
;

create procedure www_tree (in path any)
{
  declare ss, i any;
  set isolation='uncommitted';
  if (path is null)
    path := '*LISTENERS*';
  ss := string_output ();
  http ('<www>', ss);
  for select distinct HP_HOST as HOST, HP_LISTEN_HOST as LHOST from DB.DBA.HTTP_PATH order by HOST, LHOST do
     {
       declare vhost, intf, port, tmp any;
       declare HP_NO_EDIT, HP_NO_CTRL any;

       HP_NO_EDIT := case HOST when '*ini*' then 0 when '*sslini*' then 0 else 1 end;
       HP_NO_CTRL := case LHOST when '*ini*' then 0 when '*sslini*' then 0
    when (':' || cfg_item_value (virtuoso_ini_path(), 'HTTPServer', 'SSLPort')) then 0
    else 1 end;

       vhost := HOST;
       intf := LHOST;
       port := '';


       if (vhost = '*ini*')
   {
     vhost := '{Default Web Site}';
     port := cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'ServerPort');
     intf := '0.0.0.0';
   }
       else if (vhost = '*sslini*')
   {
           vhost := '{Default SSL Web Site}';
     port := cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'SSLPort');
     if (port is null)
       port := '';
     intf := '0.0.0.0';
   }
       else
   {
     www_split_host (HOST, vhost, tmp);
     www_split_host (LHOST, intf, port);
     if (intf = '' or intf = '*ini*' or intf = '*sslini*')
       {
	   if (intf = '*ini*')
	     port := cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'ServerPort');
	   else if (intf = '*sslini*')
	     port := cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'SSLPort');
          intf := '0.0.0.0';
       }
   }


       http (sprintf ('<node host="%s" port="%s" lhost="%s" edit="%d" chost="%s" clhost="%s" control="%d">\n', vhost, port, intf, HP_NO_EDIT, HOST, LHOST, HP_NO_CTRL), ss);
       i := 0;
       for select HP_LPATH, HP_PPATH, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_SECURITY, HP_OPTIONS
	 from DB.DBA.HTTP_PATH where HP_HOST = HOST and HP_LISTEN_HOST = LHOST and path <> '*LISTENERS*' do
   {
      declare tp, usr any;
      declare hp_opts, url_rew any;

      hp_opts := deserialize (HP_OPTIONS);
      if (not isarray (hp_opts))
	hp_opts := vector ();

      url_rew := get_keyword ('url_rewrite', hp_opts, '');

      if (HP_PPATH like '/DAV/%')
        tp := 'DAV';
      else if (HP_PPATH like '/SOAP/%' or HP_PPATH = '/SOAP')
        tp := 'SOAP';
      else if (HP_PPATH like '/INLINEFILE/%')
        tp := 'INL';
      else if (HP_PPATH like 'http%://%')
        tp := 'PROXY';
      else if (HP_PPATH like '/!sparql/')
        tp := 'SPARQL';
      else
        tp := 'FS';

        if (tp = 'SOAP' and length (HP_RUN_SOAP_AS))
	  usr := HP_RUN_SOAP_AS;
        else if (length (HP_RUN_VSP_AS))
	  usr := HP_RUN_VSP_AS;
        else
          usr := '*disabled*';

      if (path = '*ALL*' or path = tp)
        {
	  http (sprintf ('\t<node lpath="%s" type="%s" user="%s" sec="%s" url_rew="%s"/>\n',
		HP_LPATH, tp, usr, coalesce (HP_SECURITY, ''), url_rew), ss);
	  i := i + 1;
        }
      if (i > 1000)
	goto term;
   }
       term:;
       if (not i)
	 http (sprintf ('\t<node />\n'), ss);
       http ('</node>\n', ss);
     }
  http ('</www>', ss);
  return xtree_doc (ss);
}
;


create procedure www_root_node (in path any)
{
  return xpath_eval ('/www/*', www_tree (path), 0);
}
;


create procedure www_chil_node (in path varchar, in node varchar)
{
  return xpath_eval (path, node, 0);
}
;

create procedure y_get_host_name (in vhost varchar, in port varchar, in lines varchar)
{
  declare host, hpa any;

  host := http_request_header (lines, 'Host', null, sys_connected_server_address ());
  if (vhost = '*ini*' or vhost = '*sslini*' or vhost[0] = ascii (':') or length (vhost) = 0)
    hpa := split_and_decode (host, 0, '\0\0:');
  else
    hpa := split_and_decode (vhost, 0, '\0\0:');
  return hpa[0] || ':' || port;
}
;


create procedure y_base_uri (in p any)
{
  declare path any;
  path := http_physical_path ();
  path := WS.WS.EXPAND_URL (path, p);
  if (path like '/DAV/%')
    path := 'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:' || path;
  else
    path := 'file:' || path;
  return path;
}
;

create procedure y_get_file_dsns ()
{
  declare arr, pwd, dsns any;
  pwd := server_root ();
  dsns := vector ();
  if (not (sys_stat('st_build_opsys_id') = 'Win32'))
    goto done;
  declare exit handler for sqlstate '*'
  {
    goto done;
  };
  arr := sys_dirlist ('.', 1);
  foreach (any elm in arr) do
   {
     if (elm like '%.dsn')
       dsns := vector_concat (dsns, vector (vector (pwd || elm, '')));
   }
  done:
  return dsns;
}
;

create procedure get_granted_xml_templates (in uid int, inout plist any)
{
  declare arr any;
  arr := vector ();
  plist := vector ();
  for select G_OBJECT from SYS_GRANTS where G_OP = 32 and G_USER = uid do
    {
      for select blob_to_string (PROP_VALUE) as PROP_VALUE, RES_FULL_PATH
  from WS.WS.SYS_DAV_PROP, WS.WS.SYS_DAV_RES
  where PROP_TYPE = 'R' and PROP_NAME = 'xml-soap-method' and RES_ID = PROP_PARENT_ID do
    {
      if (PROP_VALUE = G_OBJECT)
        {
          arr := vector_concat (arr, vector (RES_FULL_PATH));
          plist := vector_concat (plist, vector (G_OBJECT));
          goto next;
              }
    }
      next:;
    }
  return arr;
}
;

create procedure grant_xml_template (in path varchar, in uname varchar)
{
  declare p_name any;
  p_name := make_xml_template_wrapper (path, uname, 1);
  exec (sprintf ('GRANT EXECUTE ON %s to "%s"', p_name, uname));
}
;

create procedure revoke_xml_template (in path varchar, in uname varchar)
{
  declare p_name any;
  p_name := make_xml_template_wrapper (path, uname, 0);
  if (p_name is not null)
    exec (sprintf ('REVOKE EXECUTE ON %s FROM "%s"', p_name, uname));
}
;

create procedure make_xml_template_wrapper (in path varchar, in uname varchar, in make_proc int := 1)
{
   declare n_name, proc_text, tp_name varchar;
   declare e_stat, e_msg, ext_type varchar;
   declare res_id integer;
   declare res_cnt varchar;
   declare descr varchar;
   declare xm any;
   declare exist_pr varchar;
   declare prop_v varchar;

   n_name := SYS_ALFANUM_NAME (path);
   ext_type := '';
   e_stat := '00000';

   if (strchr (n_name, '.') is null)
     tp_name := concat ('"XT"."', uname, '"."', n_name, '"');
   else
     tp_name := n_name;

   whenever not found goto err;
   select blob_to_string (RES_CONTENT), RES_ID into res_cnt, res_id from WS.WS.SYS_DAV_RES where RES_FULL_PATH = path;
   descr := coalesce ((select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP where
      PROP_NAME = 'xml-sql-description' and PROP_TYPE= 'R' and PROP_PARENT_ID = res_id), '');
   exist_pr := coalesce ((select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP
      where PROP_NAME = 'xml-soap-method' and PROP_TYPE = 'R' and PROP_PARENT_ID = res_id), tp_name);

   if (__proc_exists (exist_pr) is not null)
     {
       tp_name := sprintf ('"%I"."%I"."%I"',
       name_part (exist_pr, 0), name_part (exist_pr, 1), name_part (exist_pr, 2));
       goto ret;
     }
   else if (not make_proc)
     return null;

   xm := cast (xpath_eval ('local-name (/*[1])', xml_tree_doc (res_cnt)) as varchar);

   ext_type := sprintf (' returns xmltype __soap_options (__soap_type:=\'__VOID__\',PartName:=\'%s\')', xm);

   if (descr <> '')
     descr := concat ('\n--##', descr, '\n');


   proc_text := sprintf ('CREATE PROCEDURE %s () %s \n{', tp_name, ext_type);
   proc_text := concat (proc_text, descr, 'declare temp, content any;\n temp := string_output ();\n');
   proc_text := concat (proc_text, '\n if (exists (select 1 from WS.WS.SYS_DAV_RES where RES_ID = ',
     cast (res_id as varchar),'))\n   select RES_CONTENT into content from WS.WS.SYS_DAV_RES ',
     'where RES_ID = ', cast (res_id as varchar), ';\n',
     '  else \n  return NULL;\n xml_template (xml_tree_doc (content),',
     'vector (), temp); \n',
     'return xml_tree_doc (string_output_string (temp)); }\n\n');


   if (strchr (n_name, '.') is null)
     prop_v := sprintf ('XT.%s.%s', uname, n_name);
   else
     prop_v := n_name;

   exec (proc_text, e_stat, e_msg);
   YAC_DAV_PROP_SET (path, 'xml-soap-method', prop_v);

   ret:
   return tp_name;
   err:
   if (e_stat = '00000')
     {
       e_stat := 'XT000';
       e_msg := 'No such resource';
     }
   signal (e_stat, e_msg);
}
;

/*
  SQL-XML or SQLX detection
*/

create procedure y_check_query_type (in query_text any)
{
  declare lexems, i, lex_text, len, flag, pos any;

  lexems := sql_lex_analyze (query_text);
  len := length (lexems);
  flag := -2; -- SQLX case
  i :=  length (aref (lexems, len - 1));
  if (i = 3 and len > 3)
    {
      pos := 0;
      i := len - 1;
      while (i >= 0)
        {
          lex_text := upper (aref (aref (lexems, i), 1));
          if ((lex_text = 'RAW' or lex_text = 'AUTO' or lex_text = 'EXPLICIT' ) and flag = -2)
            {
	      flag := 4;
	      pos := i;
            }

          if (lex_text = 'XML' and flag = 4 and pos = (i + 1))
            {
	      flag := 3;
            }
          else if (lex_text = 'FOR' and flag = 3 and pos = (i + 2))
	      {
		flag := 2;
	      }
	  else if (lex_text = 'XMLELEMENT' and flag = -2)
	    {
	      flag := 0;
	    }
          i := i - 1;
        }
      if (flag <> 0 and flag <> 2 and upper (aref (aref (lexems, 0), 1)) = 'SELECT')
	flag := 2;
    }
  return flag;
};

create procedure y_execute_xq (in q any, in root any, in base any, in url any, in ctx any, in pmode any)
{
  declare doc, res, nuri, coll any;
  declare ses any;

  ctx := atoi (ctx);
  if (ctx = 0)
    doc := xtree_doc('<empty/>', atoi (pmode), base);
  else if (ctx <> 4)
    {
      nuri := DB.DBA.XML_URI_RESOLVE_LIKE_GET (base, url);
      doc := DB.DBA.XML_URI_GET ('', nuri);
      if (not isentity (doc))
        doc := xtree_doc (doc, atoi (pmode), nuri);
    }
  else
    {
      nuri := DB.DBA.XML_URI_RESOLVE_LIKE_GET (base, url);
      coll := xquery_eval (sprintf ('<%s>{ for \044doc in collection ("%s",.,1,2) return \044doc/* }</%s>',
      		root, nuri, root), xtree_doc('<empty/>', 0, nuri), 0);
      doc := coll[0];
    }
  res := xquery_eval (q, doc, 0);
  ses := string_output ();
  foreach (any elm in res) do
    {
      if (isentity (elm))
        {
	  xml_tree_doc_set_output (elm, 'xml');
	  http_value (elm, null, ses);
        }
    }
  return string_output_string (ses);
}
;


create procedure y_cli_status_proc ()
{
  declare stat, msg, dta, mta any;
  declare name, trx, cli_id, os, app, ip varchar;
  declare bin, bout, threads, st, lck, pid int;

  commit work;
  result_names (name, bin, bout, threads, lck, trx, cli_id, pid, os, app, ip);
  stat := '00000';
  exec ('status (\'c\')', stat, msg, vector (), 1000, mta, dta);

  if (stat <> '00000')
    {
      rollback work;
      return;
    }
  st := 0;
  trx := '';
  foreach (any elm in dta) do
    {
      declare tmp1, tmp2, tmp3, tmp4, ctmp, line any;
      line := elm[0];
      if (st = 0)
        {
	  ctmp := null;
	  ctmp := regexp_match ('Client [[:alnum:]:]+', line);
	  tmp1 := regexp_match ('Account: [[:alnum:]_]+', line);
	  tmp2 := regexp_match ('[0-9]+ bytes in', line);
	  tmp3 := regexp_match ('[0-9]+ bytes out', line);
	  if (ctmp is not null)
	    {
	      cli_id := trim (substring (ctmp, 7, length (ctmp)), ' :');
	    }
	  if (tmp1 is not null and tmp2 is not null and tmp3 is not null)
	    {
	      name := substring (tmp1, 9, length (tmp1));
	      bin := atoi(tmp2);
	      bout := atoi(tmp3);
	      st := 1;
	    }
	}
      else if (st = 1)
       {
         tmp1 := sprintf_inverse (line, 'PID: %d, OS: %s, Application: %s, IP#: %s', 0);
	 pid := null; os := null; app := null; ip := null;
	 if (length (tmp1) > 3)
	   {
	     pid := tmp1[0];
	     os := tmp1[1];
	     app := tmp1[2];
	     ip := tmp1[3];
	   }
         st := 2;
       }
      else if (st = 2)
	{
	  tmp4 := regexp_match ('[0-9]+ threads\.', line);
          tmp1 := regexp_match ('Transaction status: [A-Z]+,', line);
	  if (tmp4 is not null)
	    {
	      threads := atoi (tmp4);
	    }
	  if (tmp1 is not null)
            {
	      trx := rtrim (substring (tmp1, 20, length (tmp1)), ',');
            }
	  st := 3;
	}
      else if (st = 3)
        {
	  tmp1 := regexp_match ('Locks:.*', line);
	  if (tmp1 is not null)
	    {
	      lck := length (split_and_decode (tmp1, 0, '\0\0,')) - 1;
	      result (name, bin, bout, threads, lck, trx, cli_id, pid, os, app, ip);
	    }
	  st := 0;
	}
    }
}
;

yacutia_exec_no_error('drop view DB.DBA.CLI_STATUS_REPORT');

create procedure view CLI_STATUS_REPORT as y_cli_status_proc () (name varchar, bin int, bout int, threads int, locks int, trx_status varchar, cli_id varchar, pid int, os varchar, app varchar, ip varchar);



create procedure check_package (in pname varchar)
{
  if (vad_check_version (pname) is null)
    return 0;
  return 1;
}
;

create procedure y_check_if_bit (inout bits any, in bit int)
{
  if (bits[bit] = ascii ('1'))
    return 'checked';
  return '';
}
;


/* HTTP port check */
create procedure y_check_host (in host varchar, in listen varchar, in port varchar)
{
  declare inihost, ihost, iport varchar;
  declare pos int;

  inihost := cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'ServerPort');

  pos := strrchr (inihost, ':');

  if (pos is not null)
    {
      ihost := substring (inihost, 1, pos);
      iport := substring (inihost, pos + 2, length (inihost));
    }
  else if (atoi (inihost))
    {
      ihost := '';
      iport := inihost;
    }
  else
    {
      ihost := inihost;
      iport := '80';
    }

  if (ihost = '0.0.0.0')
    ihost := '';

  if (listen = '0.0.0.0')
    listen := '';

  if (not length (port))
    port := '80';

  if (port = iport and host = ihost)
    signal ('22023', 'The default listener and host are configurable via INI file only');

}
;

create procedure y_make_url_from_vd (in host varchar, in lhost varchar, in path varchar, in sec varchar := null)
{
  declare pos, port any;
  pos := strrchr (host, ':');
  if (pos is not null)
    host := subseq (host, 0, pos);
  pos := strrchr (lhost, ':');
  if (pos is not null)
    port := subseq (lhost, pos, length (lhost));
  else if (lhost = '*ini*')
    port := ':'||server_http_port ();
  else
    port := '';
  if (sec = 'SSL')
    return sprintf ('https://%s%s%s/', host, port, rtrim(path, '/'));
  else
    return sprintf ('http://%s%s%s/', host, port, rtrim(path, '/'));
};

create procedure y_escape_local_name (in nam varchar)
{
  declare q, o, n varchar;
  if (nam is null or nam[0] = ascii ('"'))
    return nam;
  q := name_part (nam, 0);
  o := name_part (nam, 1);
  n := name_part (nam, 2);
  return sprintf ('"%I"."%I"."%I"', q, o, n);
}
;

create procedure y_get_tbl_row_count (in q any, in o any, in n any)
{
  declare stat, msg, dta, mdta any;
  stat := '00000';
  exec (sprintf ('select count(*) from "%I"."%I"."%I"', q, o, n), stat, msg, vector (), 0, mdta, dta);
  if (stat = '00000')
    return dta[0][0];
  return 0;
}
;

create procedure y_get_first_table_name (in q any)
{
   declare tree, tbn any;
   tree := sql_parse (q);
   tbn := '';
   y_get_first_table (tree, tbn);
   return tbn;
}
;

create procedure y_get_first_table (in tree any, inout tbn any)
{
  if (isarray (tree) and length (tree) > 1 and tree[0] = 200)
    {
      if (length (tbn))
	tbn := tbn || '_' ;
      tbn := tbn || name_part (tree[1], 2);
      return;
    }
  else if (isarray (tree))
    {
      foreach (any tree1 in tree) do
	{
	  y_get_first_table (tree1, tbn);
	}
    }
}
;

create procedure y_make_tb_from_query (in tb any, in q any)
{
  declare stat, msg, meta any;
  declare stmt varchar;

  stat := '00000';
  exec_metadata (q, stat, msg, meta);
  if (stat <> '00000')
    signal (stat, msg);
  if (not isarray (meta))
    signal ('22023', 'Invalid query');

  tb := complete_table_name  (tb, 1);
  stmt := sprintf ('create table "%I"."%I"."%I" (',
  		name_part (tb,0),
  		name_part (tb,1),
  		name_part (tb,2));

  foreach (any col in meta[0]) do
    {
      declare col_name, col_type, col_tb, org_col varchar;
      declare dt int;
      -- ("ID" 189 0 10 1 1 1 "DB" "WAI_ID" "DBA" "WA_INSTANCE" 2 )
      col_tb := sprintf ('%s.%s.%s', col[7], col[9], col[10]);
      org_col := col[8];
      col_name := col[0];
      dt := col[1];
      if (dt = 254)
        {
	  col_type := (SELECT get_keyword('sql_class',COL_OPTIONS)
	    FROM DB.DBA.SYS_COLS WHERE "TABLE" = col_tb AND "COLUMN" = org_col);
	}
      else
        {
	  col_type := REPL_COLTYPE (col);
        }
      if (isnull (col_type))
	signal('Error', sprintf('Counld not find column type for column: %s', org_col));
      stmt := concat (stmt, col_name, ' ', col_type);
      stmt := concat (stmt, ', ');
    }
   stmt := rtrim (stmt, ', ');
   stmt := concat (stmt, ')');
   return stmt;
}
;

create procedure Y_SYNCML_DETECT (
  in path varchar)
{
  if (__proc_exists ('DB.DBA.yac_syncml_detect') is not null)
    return DB.DBA.yac_syncml_detect (path);

  return 0;
}
;

create procedure Y_SYNCML_VERSIONS ()
{
  if (__proc_exists ('DB.DBA.yac_syncml_version') is not null)
    return DB.DBA.yac_syncml_version ();

  return vector ();
}
;

create procedure Y_SYNCML_VERSION (
  in path varchar)
{
  if (__proc_exists ('DB.DBA.yac_syncml_version_get') is not null)
    return DB.DBA.yac_syncml_version_get (path);

  return 'N';
}
;

create procedure Y_SYNCML_TYPES ()
{
  if (__proc_exists ('DB.DBA.yac_syncml_type') is not null)
    return DB.DBA.yac_syncml_type ();

  return vector ();
}
;

CREATE PROCEDURE Y_SYNCML_TYPE (
  in path varchar)
{
  if (__proc_exists ('DB.DBA.yac_syncml_type_get') is not null)
    return DB.DBA.yac_syncml_type_get (path);

  return 'N';
}
;

create procedure y_sprintf_to_reg (in fmt varchar, in in_list any, in o_list any)
{
  declare pc, cp_fmt varchar;
  declare inx, pos, _from, _to, res, _left, _right, par, fchar any;

  cp_fmt := fmt;
  pc := regexp_match ('%[sdU]', fmt, 1);
  inx := 0;
  while (pc is not null)
    {
      _from := strstr (cp_fmt, pc);
      _to := _from + length (pc);

      _left := substring (cp_fmt, 1, _from);
      _right := substring (cp_fmt, _to+1, length (cp_fmt));

      if (inx < length (o_list))
        pos := position (o_list[inx], in_list);
      else
        pos := 0;

      fchar := ltrim (pc, '%');
      par := sprintf ('\x24%s%d', fchar, pos);
      if (pos = 0 and inx < length (o_list) and o_list[inx] = '*accept*')
	par := '\x24accept';

      cp_fmt := _left || par || _right;

      pc := regexp_match ('%[sdU]', fmt, 1);
      inx := inx + 1;
    }
  cp_fmt := replace (cp_fmt, '%%', '%');
  return cp_fmt;
};


create procedure y_reg_to_sprintf (in fmt varchar, out in_list any, out o_list any)
{
  declare pc, cp_fmt varchar;
  declare inx, pos, _from, _to, res, _left, _right, par, fchar any;

  cp_fmt := fmt;
  cp_fmt := replace (cp_fmt, '%', '%%');
  pc := regexp_match ('(\\x24[sdU]?[0-9]+)|(\\x24accept)', fmt, 1);
  inx := 0;

  in_list := vector ();
  o_list := vector ();

  while (pc is not null)
    {
      _from := strstr (cp_fmt, pc);
      _to := _from + length (pc);

      _left := substring (cp_fmt, 1, _from);
      _right := substring (cp_fmt, _to+1, length (cp_fmt));

      if (pc = '\x24accept')
	{
	  o_list := vector_concat (o_list, vector ('*accept*'));
	}
      else
	{
	  pos := atoi (ltrim (pc, '\x24sdU'));
	  o_list := vector_concat (o_list, vector (sprintf ('par_%d', pos)));
        }

      if (length (in_list) < pos)
	{
	  declare to_add int;
	  to_add := pos - length (in_list);
	  in_list := vector_concat (in_list, make_array (to_add, 'any'));
	  in_list [pos - 1] := sprintf ('par_%d', pos);
	}
      else
	in_list [pos - 1] := sprintf ('par_%d', pos);

      fchar := ltrim (pc, '\x24');
      fchar := fchar[0];
      fchar := chr (fchar);
      if (fchar not in ('s', 'd', 'U'))
	fchar := 'U';
      cp_fmt := _left || '%' || fchar  || _right;

      pc := regexp_match ('(\\x24[sdU]?[0-9]+)|(\\x24accept)', fmt, 1);
      inx := inx + 1;
    }
  for (inx := 0; inx < length (in_list); inx := inx + 1)
    {
      if (in_list[inx] = 0)
	in_list[inx] := sprintf ('par_%d', inx + 1);
    }
  return cp_fmt;
};




create procedure URL_REWRITE_LIST_DUMP (in rule_list varchar)
{
  declare U_DIR, U_CONT, U_RULE, U_RULE_TYPE, U_NICE_FORMAT, U_HM_NICE_FMT, U_NICE_MIN_PARAMS, U_TARGET_FORMAT,
	  U_TARGET_EXPR, U_ACCEPT_PATTERN, U_NO_CONTINUATION, U_HTTP_REDIRECT, U_HTTP_HEADERS, U_IDX any;

  result_names (U_DIR, U_RULE, U_RULE_TYPE, U_NICE_FORMAT, U_HM_NICE_FMT, U_NICE_MIN_PARAMS, U_TARGET_FORMAT,
      U_TARGET_EXPR, U_ACCEPT_PATTERN, U_NO_CONTINUATION, U_HTTP_REDIRECT, U_HTTP_HEADERS, U_IDX);

  URL_REWRITE_LIST_DUMP_REC (rule_list, '');


};

create procedure URL_REWRITE_LIST_DUMP_REC (in rule_list varchar, in parent_list varchar)
{
  for select distinct URRL_MEMBER as cur_iri, URRL_INX as idx from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = rule_list
    order by URRL_INX
	do
	  {
	    if (exists (select 1 from DB.DBA.URL_REWRITE_RULE_LIST where URRL_LIST = cur_iri))
	      {
		URL_REWRITE_LIST_DUMP_REC (cur_iri, parent_list ||'/'||cur_iri);
	      }
	    else
	      {
		for select
		  URR_RULE,
		      URR_RULE_TYPE,
		      URR_NICE_FORMAT,
		      y_sprintf_to_reg (URR_TARGET_FORMAT, deserialize (URR_NICE_PARAMS), deserialize (URR_TARGET_PARAMS)) as nice_fmt,
		      URR_NICE_MIN_PARAMS,
		      URR_TARGET_FORMAT,
		      URR_TARGET_EXPR,
		      URR_ACCEPT_PATTERN,
		      URR_NO_CONTINUATION,
		      URR_HTTP_REDIRECT,
		      URR_HTTP_HEADERS
			  from DB.DBA.URL_REWRITE_RULE where URR_RULE = cur_iri
			  do
			    {
			      result (rule_list, parent_list, URR_RULE, URR_RULE_TYPE, URR_NICE_FORMAT, nice_fmt, URR_NICE_MIN_PARAMS, URR_TARGET_FORMAT, URR_TARGET_EXPR, URR_ACCEPT_PATTERN, URR_NO_CONTINUATION, URR_HTTP_REDIRECT, URR_HTTP_HEADERS, idx);
			    }

	      }
	  }
};

yacutia_exec_no_error('drop view DB.DBA.URL_REWRITE_LIST_DUMP');

create procedure view URL_REWRITE_LIST_DUMP as URL_REWRITE_LIST_DUMP (rule_list) (U_DIR varchar, U_CONT varchar,
    	U_RULE varchar, U_RULE_TYPE int, U_NICE_FORMAT varchar,
	U_HM_NICE_FMT varchar, U_NICE_MIN_PARAMS int, U_TARGET_FORMAT varchar,
	U_TARGET_EXPR varchar, U_ACCEPT_PATTERN varchar,
	U_NO_CONTINUATION int, U_HTTP_REDIRECT int, U_HTTP_HEADERS varchar, U_IDX int);

create procedure URL_REWRITE_UPDATE_VHOST (in rulelist varchar, in lpath varchar, in vhost varchar, in lhost varchar)
{
  declare h_opts any;
  declare upd_vd int;
  h_opts := (select deserialize (HP_OPTIONS) from DB.DBA.HTTP_PATH
  	where HP_LPATH = lpath and HP_HOST = vhost and HP_LISTEN_HOST = lhost);
  upd_vd := 0;
  if (not isvector (h_opts))
    {
      h_opts := vector ('url_rewrite', rulelist);
      upd_vd := 1;
    }
  else if (not position ('url_rewrite', h_opts))
    {
      h_opts := vector_concat (h_opts, vector ('url_rewrite', rulelist));
      upd_vd := 1;
    }

  if (upd_vd = 1)
    {
      update DB.DBA.HTTP_PATH set HP_OPTIONS = serialize (h_opts)
	  where HP_LPATH = lpath and HP_HOST = vhost and HP_LISTEN_HOST = lhost;
      DB.DBA.VHOST_MAP_RELOAD (vhost, lhost, lpath);
    }
}
;

create procedure yac_list_keys (in username varchar)
{
  declare xenc_name, xenc_type varchar;
  declare arr any;
  result_names (xenc_name, xenc_type);
  if (not exists (select 1 from SYS_USERS where U_NAME = username))
    return;
  arr := USER_GET_OPTION (username, 'KEYS');
  for (declare i, l int, i := 0, l := length (arr); i < l; i := i + 2)
    {
      if (length (arr[i]))
        result (arr[i], arr[i+1][0]);
    }
}
;

create procedure yac_vec_add (in k varchar, in v varchar, inout opts any)
{
  declare pos any;
  if (not isarray (opts) or isstring (opts))
    opts := vector ();
  pos := position (k, opts);
  if (pos > 0)
    opts [pos] := v;
  else
    opts := vector_concat (opts, vector (k, v));
}
;


create procedure
yac_set_ssl_key (in k varchar, in v varchar, in extra varchar, inout opts any)
{
  if (k = 'none' or not length (k))
    {
      declare new_opts any;
      new_opts := vector ();
      for (declare i, l int, i := 0, l := length (opts); i < l; i := i + 2)
        {
	  if (opts[i] not in ('https_cert', 'https_key', 'https_verify', 'https_cv_depth', 'https_extra_chain_certificates'))
	    new_opts := vector_concat (new_opts, vector (opts[i], opts[i+1]));
	}
      opts := new_opts;
    }
  else
    {
      yac_vec_add ('https_cert', 'db:'||k, opts);
      yac_vec_add ('https_key',  'db:'||k, opts);
      yac_vec_add ('https_extra_chain_certificates', extra, opts);
      yac_vec_add ('https_verify', cast (v as int), opts);
      yac_vec_add ('https_cv_depth', 10, opts);
    }
}
;

create procedure yac_uri_curie (in uri varchar, in label varchar := null)
{
  declare delim integer;
  declare uriSearch, nsPrefix varchar;

  delim := -1;
  uriSearch := uri;
  nsPrefix := null;
  if (not length (label))
    label := null;
  while (nsPrefix is null and delim <> 0)
    {
      delim := coalesce (strrchr (uriSearch, '/'), 0);
      delim := __max (delim, coalesce (strrchr (uriSearch, '#'), 0));
      delim := __max (delim, coalesce (strrchr (uriSearch, ':'), 0));
      nsPrefix := coalesce (__xml_get_ns_prefix (subseq (uriSearch, 0, delim + 1), 2),
      			    __xml_get_ns_prefix (subseq (uriSearch, 0, delim),     2));
      uriSearch := subseq (uriSearch, 0, delim);
    }
  if (nsPrefix is not null)
    {
      declare rhs varchar;
      rhs := subseq(uri, length (uriSearch) + 1, null);
      if (not length (rhs))
	return uri;
      else
	return nsPrefix || ':' || coalesce (label, rhs);
    }
  return uri;
}
;

CREATE PROCEDURE OWL_N3 ()
{
  declare ses any;
  ses := string_output ();
  http ('@prefix ns7: <http://www.w3.org/TR/2004/REC-owl-test-20040210/> .\n', ses);
  http ('@prefix ns4: <http://www.w3.org/2000/01/> .\n', ses);
  http ('@prefix owl: <http://www.w3.org/2002/07/owl#> .\n', ses);
  http ('@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n', ses);
  http ('@prefix ns5: <http://www.w3.org/TR/2004/REC-owl-features-20040210/> .\n', ses);
  http ('@prefix ns6: <http://www.w3.org/TR/2004/REC-owl-semantics-20040210/> .\n', ses);
  http ('@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n', ses);
  http ('@prefix ns3: <http://www.w3.org/2002/07/> .\n', ses);
  http ('@prefix ns8: <http://www.daml.org/2001/03/daml+oil> .\n', ses);
  http ('@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n', ses);
  http ('owl:sameAs rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "sameAs" .\n', ses);
  http ('owl:Thing rdf:type owl:Class ;\n', ses);
  http ('	rdfs:label "Thing" .\n', ses);
  http ('_:bnode0 rdf:first owl:Nothing .\n', ses);
  http ('_:bnode1 rdf:type owl:Class ;\n', ses);
  http ('	owl:complementOf owl:Nothing .\n', ses);
  http ('_:bnode2 rdf:first _:bnode1 ;\n', ses);
  http ('	rdf:rest rdf:nil .\n', ses);
  http ('_:bnode0 rdf:rest _:bnode2 .\n', ses);
  http ('owl:Thing owl:unionOf _:bnode0 .\n', ses);
  http ('owl:sameAs rdfs:domain owl:Thing ;\n', ses);
  http ('	rdfs:range owl:Thing .\n', ses);
  http ('ns3:owl rdf:type owl:Ontology ;\n', ses);
  http ('	owl:imports ns4:rdf-schema ;\n', ses);
  http ('	rdfs:isDefinedBy <http://www.w3.org/TR/2004/REC-owl-features-20040210/> ,\n', ses);
  http ('		<http://www.w3.org/TR/2004/REC-owl-semantics-20040210/> ,\n', ses);
  http ('		<http://www.w3.org/TR/2004/REC-owl-test-20040210/> ;\n', ses);
  http ('	rdfs:comment "This file specifies in RDF Schema format the\\r\\n    built-in classes and properties that together form the basis of\\r\\n    the RDF/XML syntax of OWL Full, OWL DL and OWL Lite.\\r\\n    We do not expect people to import this file\\r\\n    explicitly into their ontology. People that do import this file\\r\\n    should expect their ontology to be an OWL Full ontology. \\r\\n  " ;\n', ses);
  http ('	owl:versionInfo "10 February 2004, revised \x24Date: 2004/09/24 18:12:02 \x24" ;\n', ses);
  http ('	owl:priorVersion <http://www.daml.org/2001/03/daml+oil> .\n', ses);
  http ('owl:Ontology rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "Ontology" .\n', ses);
  http ('owl:imports rdf:type owl:OntologyProperty ,\n', ses);
  http ('		rdf:Property ;\n', ses);
  http ('	rdfs:label "imports" ;\n', ses);
  http ('	rdfs:domain owl:Ontology ;\n', ses);
  http ('	rdfs:range owl:Ontology .\n', ses);
  http ('rdfs:isDefinedBy rdf:type owl:AnnotationProperty .\n', ses);
  http ('rdfs:comment rdf:type owl:AnnotationProperty .\n', ses);
  http ('owl:versionInfo rdf:type rdf:Property ,\n', ses);
  http ('		owl:AnnotationProperty ;\n', ses);
  http ('	rdfs:label "versionInfo" .\n', ses);
  http ('owl:priorVersion rdf:type rdf:Property ,\n', ses);
  http ('		owl:OntologyProperty ;\n', ses);
  http ('	rdfs:label "priorVersion" ;\n', ses);
  http ('	rdfs:domain owl:Ontology ;\n', ses);
  http ('	rdfs:range owl:Ontology .\n', ses);
  http ('owl:Class rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "Class" ;\n', ses);
  http ('	rdfs:subClassOf rdfs:Class .\n', ses);
  http ('rdfs:label rdf:type owl:AnnotationProperty .\n', ses);
  http ('owl:Nothing rdf:type owl:Class ;\n', ses);
  http ('	rdfs:label "Nothing" ;\n', ses);
  http ('	owl:complementOf owl:Thing .\n', ses);
  http ('owl:complementOf rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "complementOf" ;\n', ses);
  http ('	rdfs:domain owl:Class ;\n', ses);
  http ('	rdfs:range owl:Class .\n', ses);
  http ('owl:unionOf rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "unionOf" ;\n', ses);
  http ('	rdfs:domain owl:Class ;\n', ses);
  http ('	rdfs:range rdf:List .\n', ses);
  http ('owl:equivalentClass rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "equivalentClass" ;\n', ses);
  http ('	rdfs:subPropertyOf rdfs:subClassOf ;\n', ses);
  http ('	rdfs:domain owl:Class ;\n', ses);
  http ('	rdfs:range owl:Class .\n', ses);
  http ('owl:disjointWith rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "disjointWith" ;\n', ses);
  http ('	rdfs:domain owl:Class ;\n', ses);
  http ('	rdfs:range owl:Class .\n', ses);
  http ('owl:equivalentProperty rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "equivalentProperty" ;\n', ses);
  http ('	rdfs:subPropertyOf rdfs:subPropertyOf .\n', ses);
  http ('owl:differentFrom rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "differentFrom" ;\n', ses);
  http ('	rdfs:domain owl:Thing ;\n', ses);
  http ('	rdfs:range owl:Thing .\n', ses);
  http ('owl:distinctMembers rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "distinctMembers" .\n', ses);
  http ('owl:AllDifferent rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "AllDifferent" .\n', ses);
  http ('owl:distinctMembers rdfs:domain owl:AllDifferent ;\n', ses);
  http ('	rdfs:range rdf:List .\n', ses);
  http ('owl:intersectionOf rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "intersectionOf" ;\n', ses);
  http ('	rdfs:domain owl:Class ;\n', ses);
  http ('	rdfs:range rdf:List .\n', ses);
  http ('owl:oneOf rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "oneOf" ;\n', ses);
  http ('	rdfs:domain rdfs:Class ;\n', ses);
  http ('	rdfs:range rdf:List .\n', ses);
  http ('owl:Restriction rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "Restriction" ;\n', ses);
  http ('	rdfs:subClassOf owl:Class .\n', ses);
  http ('owl:onProperty rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "onProperty" ;\n', ses);
  http ('	rdfs:domain owl:Restriction ;\n', ses);
  http ('	rdfs:range rdf:Property .\n', ses);
  http ('owl:allValuesFrom rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "allValuesFrom" ;\n', ses);
  http ('	rdfs:domain owl:Restriction ;\n', ses);
  http ('	rdfs:range rdfs:Class .\n', ses);
  http ('owl:hasValue rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "hasValue" ;\n', ses);
  http ('	rdfs:domain owl:Restriction .\n', ses);
  http ('owl:someValuesFrom rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "someValuesFrom" ;\n', ses);
  http ('	rdfs:domain owl:Restriction ;\n', ses);
  http ('	rdfs:range rdfs:Class .\n', ses);
  http ('owl:minCardinality rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "minCardinality" ;\n', ses);
  http ('	rdfs:domain owl:Restriction ;\n', ses);
  http ('	rdfs:range xsd:nonNegativeInteger .\n', ses);
  http ('owl:maxCardinality rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "maxCardinality" ;\n', ses);
  http ('	rdfs:domain owl:Restriction ;\n', ses);
  http ('	rdfs:range xsd:nonNegativeInteger .\n', ses);
  http ('owl:cardinality rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "cardinality" ;\n', ses);
  http ('	rdfs:domain owl:Restriction ;\n', ses);
  http ('	rdfs:range xsd:nonNegativeInteger .\n', ses);
  http ('owl:ObjectProperty rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "ObjectProperty" ;\n', ses);
  http ('	rdfs:subClassOf rdf:Property .\n', ses);
  http ('owl:DatatypeProperty rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "DatatypeProperty" ;\n', ses);
  http ('	rdfs:subClassOf rdf:Property .\n', ses);
  http ('owl:inverseOf rdf:type rdf:Property ;\n', ses);
  http ('	rdfs:label "inverseOf" ;\n', ses);
  http ('	rdfs:domain owl:ObjectProperty ;\n', ses);
  http ('	rdfs:range owl:ObjectProperty .\n', ses);
  http ('owl:TransitiveProperty rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "TransitiveProperty" ;\n', ses);
  http ('	rdfs:subClassOf owl:ObjectProperty .\n', ses);
  http ('owl:SymmetricProperty rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "SymmetricProperty" ;\n', ses);
  http ('	rdfs:subClassOf owl:ObjectProperty .\n', ses);
  http ('owl:FunctionalProperty rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "FunctionalProperty" ;\n', ses);
  http ('	rdfs:subClassOf rdf:Property .\n', ses);
  http ('owl:InverseFunctionalProperty rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "InverseFunctionalProperty" ;\n', ses);
  http ('	rdfs:subClassOf owl:ObjectProperty .\n', ses);
  http ('owl:AnnotationProperty rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "AnnotationProperty" ;\n', ses);
  http ('	rdfs:subClassOf rdf:Property .\n', ses);
  http ('rdfs:seeAlso rdf:type owl:AnnotationProperty .\n', ses);
  http ('owl:OntologyProperty rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "OntologyProperty" ;\n', ses);
  http ('	rdfs:subClassOf rdf:Property .\n', ses);
  http ('owl:backwardCompatibleWith rdf:type rdf:Property ,\n', ses);
  http ('		owl:OntologyProperty ;\n', ses);
  http ('	rdfs:label "backwardCompatibleWith" ;\n', ses);
  http ('	rdfs:domain owl:Ontology ;\n', ses);
  http ('	rdfs:range owl:Ontology .\n', ses);
  http ('owl:incompatibleWith rdf:type rdf:Property ,\n', ses);
  http ('		owl:OntologyProperty ;\n', ses);
  http ('	rdfs:label "incompatibleWith" ;\n', ses);
  http ('	rdfs:domain owl:Ontology ;\n', ses);
  http ('	rdfs:range owl:Ontology .\n', ses);
  http ('owl:DeprecatedClass rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "DeprecatedClass" ;\n', ses);
  http ('	rdfs:subClassOf rdfs:Class .\n', ses);
  http ('owl:DeprecatedProperty rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "DeprecatedProperty" ;\n', ses);
  http ('	rdfs:subClassOf rdf:Property .\n', ses);
  http ('owl:DataRange rdf:type rdfs:Class ;\n', ses);
  http ('	rdfs:label "DataRange" .\n', ses);
  return string_output_string (ses);
}
;

TTLP (OWL_N3 (), 'http://www.w3.org/2002/07/owl#', 'http://www.w3.org/2002/07/owl#');

RDFS_RULE_SET ('http://www.w3.org/2002/07/owl#', 'http://www.w3.org/2002/07/owl#');

-- we need to do a special procedure as on www we hit the dynamic local iris
create procedure y_set_gg ()
{
  declare gr any;
  gr := 'http://www.openlinksw.com/schemas/virtrdf#schemas';
  if (not exists (select top 1 1 from DB.DBA.RDF_GRAPH_GROUP where RGG_IRI = gr))
    {
      RDF_GRAPH_GROUP_CREATE (gr, 1);
    }
}
;

y_set_gg ()
;

create procedure yac_get_pk (in tb varchar)
{
  declare pka, pkn any;
  pka := rdf_view_get_primary_key (tb);
  pkn := vector ();
  foreach (any x in pka) do
    pkn := vector_concat (pkn, vector (x[0]));
}
;

create procedure DB.DBA.BACKUP_MAKE_CL (in prefix varchar, in max_pages integer, in is_full integer)
{
  declare patha any;

  if (sys_stat ('cl_run_local_only') = 1)
    {
      return DB.DBA.BACKUP_MAKE (prefix, max_pages, is_full);
    }

  if (is_full)
    cl_exec ('backup_context_clear()');
  patha := null;
  for select bd_dir from DB.DBA.SYS_BACKUP_DIRS order by bd_id do
    {
      if (patha is null)
	patha := vector (bd_dir);
      else
	patha := vector_concat (patha, vector (bd_dir));
    }

  if (patha is null)
    cl_exec ('backup_online (?,?)', vector (prefix, max_pages));
  else
    cl_exec ('backup_online (?, ?, ?, ?)', vector (prefix, max_pages, 0, patha));

  if (__proc_exists ('DB.DBA.BACKUP_COMPLETED') is not null)
    DB.DBA.BACKUP_COMPLETED ();
  update DB.DBA.SYS_SCHEDULED_EVENT set SE_SQL = sprintf ('DB.DBA.BACKUP_MAKE_CL (\'%s\', %d, 0)', prefix, max_pages)
   where SE_NAME = DB.DBA.BACKUP_SCHED_NAME ();
}
;

create procedure Y_RDF_VIEW_DROP_STMT (in q any)
{
  if (__proc_exists ('DB.DBA.RDF_VIEW_DROP_STMT') is not null)
    return RDF_VIEW_DROP_STMT (q);
  else
    return '';

}
;

create procedure Y_SQL_ESC_NAME (in fn varchar)
{
  declare q, o, n, tmp any;
  fn := complete_table_name (fn, 0);
  q := name_part (fn, 0);
  o := name_part (fn, 1);
  tmp := q || '.' || o || '.';
  n := subseq (fn, length (tmp));
  return sprintf ('"%I"."%I"."%I"', q, o, n);
}
;

create procedure y_trunc_uri (
  in s varchar,
  in maxlen int := 80)
{
  declare _s varchar;
  declare _h int;

  _s := trim (s);
  if ((s not like 'http://%') and (s not like 'https://%'))
    s := 'http://' || s;

  if (length(_s) <= maxlen)
    return _s;

  _h := floor ((maxlen-3) / 2);
  _s := sprintf ('%s...%s', "LEFT"(_s, _h), "RIGHT"(_s, _h-1));

  return _s;
}
;

create procedure y_rdf_api_type (in t int)
{
  if (t = 0)
    return 'content';
  else if (t = 1)
    return 'URL';
  else if (t = 2)
    return 'keywords';
  else if (t = 3)
    return 'preprocess';
  return '';
}
;

create procedure y_csv_cb (inout r any, in inx int, inout cbd any)
{
  if (cbd is null)
    cbd := vector ();
  cbd := vector_concat (cbd, vector (r));
}
;

create procedure  y_csv_get_cols (inout ss any, in hr int, in offs int, in opts any)
{
  declare h, res any;
  declare inx, j, ncols, no_head int;

  h := null;
  no_head := 0;
  if (hr < 0)
    {
      no_head := 1;
      hr := 0;
    }
  if (offs < 0)
    offs := 0;
  res := vector ();
  csv_parse (ss, 'DB.DBA.y_csv_cb', h, 0, offs + 10, opts);
  if (h is not null and length (h) > offs)
    {
      declare _row any;
      _row := h[hr];
      for (j := 0; j < length (_row); j := j + 1)
        {
	  res := vector_concat (res, vector (vector (SYS_ALFANUM_NAME (cast (_row[j] as varchar)), null)));
        }
      for (inx := offs; inx < length (h); inx := inx + 1)
       {
	 _row := h[inx];
         for (j := 0; j < length (_row); j := j + 1)
	   {
	     if (res[j][1] is null and not (isstring (_row[j]) and _row[j] = '') and _row[j] is not null)
               res[j][1] := __tag (_row[j]);
             else if (__tag (_row[j]) <> res[j][1] and 189 = res[j][1] and (isdouble (_row[j]) or isfloat (_row[j])))
	       res[j][1] := __tag (_row[j]);
             else if (__tag (_row[j]) <> res[j][1] and isinteger (_row[j]) and (res[j][1] = 219 or 190 = res[j][1]))
	       ;
             else if (__tag (_row[j]) <> res[j][1])
               res[j][1] := -1;
	   }
       }
    }
  for (inx := 0; inx < length (res); inx := inx + 1)
    {
       if (not isstring (res[inx][0]) and not isnull (res[inx][0]))
         no_head := 1;
       else if (trim (res[inx][0]) = '' or isnull (res[inx][0]))
         res[inx][0] := sprintf ('COL%d', inx);
    }
  for (inx := 0; inx < length (res); inx := inx + 1)
    {
       if (res[inx][1] = -1 or res[inx][1] is null)
         res[inx][1] := 'VARCHAR';
       else
         res[inx][1] := dv_type_title (res[inx][1]);
    }
  if (no_head)
    {
      for (inx := 0; inx < length (res); inx := inx + 1)
	{
	   res[inx][0] := sprintf ('COL%d', inx);
	}
    }
--  dbg_obj_print (res);
  return res;
}
;

create procedure y_col_dts (in t varchar)
{
  for select TYPE_NAME from DB.DBA.oledb_get_types (m,n) (TYPE_NAME nvarchar) x where m = null and n = null do
    {
       TYPE_NAME := cast (TYPE_NAME as varchar);
       if (TYPE_NAME = 'int')
	 TYPE_NAME := 'integer';
       http (sprintf ('<option %s>%s</option>', case when upper (TYPE_NAME) = t then 'selected' else '' end, upper (TYPE_NAME)));
    }
  http (sprintf ('<option %s>ANY</option>', case when 'ANY' = t then 'selected' else '' end));
}
;

create procedure y_tab_or_space (in x any)
{
  if (x = 'tab')
    return '\t';
  else if (x = 'space')
    return ' ';
  return x;
}
;

create procedure WS.WS.VFS_EXPORT_DEFS (in ids any := null)
{
  declare ses any;
  ses := string_output ();
  for select * from WS.WS.VFS_SITE do
  {
    if (ids is not null and not position (VS_ID, ids))
      goto skipit;

    http (sprintf ('-- Crawling descriptor for %s\n', VS_DESCR), ses);
    http (
      'INSERT SOFT WS.WS.VFS_SITE (\n\tVS_DESCR,\n\tVS_HOST,\n\tVS_URL,\n\tVS_INX,\n\tVS_OWN,\n\tVS_ROOT,\n\tVS_NEWER,\n' ||
      '\tVS_DEL,\n\tVS_FOLLOW,\n\tVS_NFOLLOW,\n\tVS_SRC,\n\tVS_OPTIONS,\n\tVS_METHOD,\n\tVS_OTHER,\n\tVS_OPAGE,\n\tVS_REDIRECT,\n'||
      '\tVS_STORE,\n\tVS_UDATA,\n\tVS_DLOAD_META,\n\tVS_INST_ID,\n\tVS_EXTRACT_FN,\n\tVS_STORE_FN,\n\tVS_DEPTH,'||
      '\n\tVS_CONVERT_HTML,\n\tVS_XPATH,\n\tVS_BOT,\n\tVS_IS_SITEMAP,\n\tVS_ACCEPT_RDF,\n\tVS_THREADS,\n\tVS_ROBOTS,\n\tVS_DELAY,\n\tVS_TIMEOUT,\n\tVS_HEADERS)\n VALUES (\n',
      ses
    );
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_DESCR),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_HOST),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_URL),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_INX),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_OWN),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_ROOT),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (cast (VS_NEWER as varchar)),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_DEL),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_FOLLOW),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_NFOLLOW),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_SRC),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_OPTIONS),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_METHOD),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_OTHER),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_OPAGE),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_REDIRECT),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_STORE),ses); http (',\n', ses);
    http ('\t', ses);
    http (sprintf ('serialize (%s)', DB.DBA.SYS_SQL_VAL_PRINT (deserialize (VS_UDATA))),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_DLOAD_META),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_INST_ID),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_EXTRACT_FN),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_STORE_FN),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_DEPTH),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_CONVERT_HTML),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_XPATH),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_BOT),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_IS_SITEMAP),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_ACCEPT_RDF),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_THREADS),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_ROBOTS),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_DELAY),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_TIMEOUT),ses); http (',\n', ses);
    http ('\t', ses);
    http (DB.DBA.SYS_SQL_VAL_PRINT (VS_HEADERS),ses); http ('\n', ses);
    http (');\n', ses);
    for (select * from WS.WS.VFS_SITE_RDF_MAP where VM_HOST = VS_HOST and VM_ROOT = VS_ROOT order by VM_SEQ) do
    {
      http ('\n', ses);
      http ('insert soft WS.WS.VFS_SITE_RDF_MAP (VM_HOST, VM_ROOT, VM_RDF_MAP, VM_RDF_MAP_TYPE) values (', ses);
      http (DB.DBA.SYS_SQL_VAL_PRINT (VM_HOST),ses); http (',', ses);
      http (DB.DBA.SYS_SQL_VAL_PRINT (VM_ROOT),ses); http (',', ses);
      if (coalesce (VM_RDF_MAP_TYPE, 0) = 0)
      {
        http ('(select RM_PID from DB.DBA.SYS_RDF_MAPPERS where RM_PID = ', ses);
        http (DB.DBA.SYS_SQL_VAL_PRINT (VM_RDF_MAP), ses);
        http (')', ses);
      }
      else if ((coalesce (VM_RDF_MAP_TYPE, 0) = 1) and not isnull (VAD_CHECK_VERSION ('cartridges')))
      {
        http ('(select MC_ID from DB.DBA.RDF_META_CARTRIDGES where MC_ID = ', ses);
        http (DB.DBA.SYS_SQL_VAL_PRINT (VM_RDF_MAP), ses);
        http (')', ses);
      }
      http (');\n', ses);
      http (DB.DBA.SYS_SQL_VAL_PRINT (coalesce (VM_RDF_MAP_TYPE, 0)),ses); http ('\n', ses);
      http (');\n', ses);
    }
    http ('\n', ses);
    http ('\n', ses);
    http ('\n', ses);
  skipit:;
  }
  http ('WS.WS.VFS_INIT_QUEUE ();\n', ses);
  return ses;
}
;

create procedure WS.WS.VFS_INIT_QUEUE ()
{
  for select * from WS.WS.VFS_SITE do
    {
      insert soft WS.WS.VFS_QUEUE (VQ_HOST, VQ_ROOT, VQ_URL, VQ_TS, VQ_STAT, VQ_OTHER) values
	  (VS_HOST, VS_ROOT, VS_URL, now (), 'waiting', case VS_OTHER when 'checked' then 'other' else null end);
    }
}
;

create procedure y_parse_link_headers (in s varchar, in rel varchar, in val varchar)
{
  declare exps, res any;
  declare st, en, cur int;
  s := replace (s, '\r', '');
  s := replace (s, '\n', '');
  cur := 0;
  res := null;
  while (cur < length (s))
    {
      declare tmp, ll, cur_rel any;
      exps := regexp_parse ('(<([^<>]+)>;([ ]*([a-zA-Z]+)="([^"]*)";?)+[,]*)', s, cur);
      if (not isarray (exps))
	goto done;
      st := exps[0];
      en := exps[1];
      tmp := subseq (s, st, en);
      ll := subseq (s, exps[4], exps[5]);
      tmp := replace (tmp, '<' || ll || '>;', '');
      tmp := trim (tmp, ' ,');
      tmp := split_and_decode (tmp, 0, '\0\0;=');
      for (declare i, l int, i := 0, l := length (tmp); i < l; i := i + 1)
        tmp[i] := trim (tmp[i], '" ');
      cur := en;
      cur_rel := get_keyword (rel, tmp);
      if (cur_rel = val)
	{
	  res := ll;
	  goto done;
	}
    }
  done:
  return res;
}
;

create procedure y_list_webids (in uname varchar)
{
  declare keys, webids any;

  webids := vector ();
  if (not exists (select 1 from SYS_USERS where U_NAME = uname))
    goto finish;
  keys := coalesce (USER_GET_OPTION (uname, 'KEYS'), vector ());
  for (declare i, l int, i := 0, l := length (keys); i < l; i := i + 2)
    {
      declare tp, fmt, cert, pass, id, alts, x any;
      x := keys[i + 1];
      if (x is null)
	goto next;
      tp := x[0];
      if (tp = 'X.509')
	{
	  fmt := x[1];
	  cert := x[2];
	  pass := x[3];
	  if (fmt = 3)
	    fmt := 1;
	  else if (fmt = 1)
	    fmt := 0;
	  id := get_certificate_info (7, cert, fmt, pass, '2.5.29.17');
	  if (id is null)
	    goto next;
	  alts := regexp_replace (id, ',[ ]*', ',', 1, null);
	  alts := split_and_decode (alts, 0, '\0\0,:');
	  if (alts is null)
	    goto next;
	  id := get_keyword ('URI', alts);
	  if (id is null)
	    goto next;
          webids := vector_concat (webids, vector (id));
	  next:;
	}
    }
  finish:
  return webids;
}
;

create procedure construct_table_sql( in tablename varchar ) returns varchar
{
  declare sql varchar;
  declare k integer;

  sql := 'SELECT ';
  k := 0;

    for SELECT c."COLUMN" as COL_NAME
      from  DB.DBA.SYS_KEYS k, DB.DBA.SYS_KEY_PARTS kp, "SYS_COLS" c
      where
            name_part (k.KEY_TABLE, 0) =  name_part (tablename, 0) and
            name_part (k.KEY_TABLE, 1) =  name_part (tablename, 1) and
            name_part (k.KEY_TABLE, 2) =  name_part (tablename, 2)
            and __any_grants (k.KEY_TABLE)
        and c."COLUMN" <> '_IDN'
        and k.KEY_IS_MAIN = 1
        and k.KEY_MIGRATE_TO is null
        and kp.KP_KEY_ID = k.KEY_ID
        and c.COL_ID = kp.KP_COL
	order by kp.KP_NTH do
	{
      if (k > 0 )
          sql := concat( sql, ',' );
      else k := 1;

      sql := concat( sql, COL_NAME);

  }
  sql := concat(sql, ' FROM ', tablename);

  return sql;
}
;


create procedure vector_to_text_opt (in v any)
{
  declare i int;
  declare r varchar;
  if (v is null) return '';
  r := '';
  for (i := 0; i < length (v); i := i + 2)
    r := r || v[i] || '=' || v[i+1] || ';\r\n';
  return r;
}
;

create procedure text_opt_to_vector (in s varchar)
{
  declare inx int;
  declare arr any;
  s := replace (s, '\n', '');
  s := replace (s, '\r', '');
  s := trim (s);
  s := rtrim (s, ';');
  s := replace (s, ';', '&');
  arr := split_and_decode (s);
  if (0 = length (arr))
    return NULL;
  inx := 0;
  foreach (varchar x in arr) do
    {
      arr[inx] := trim (x);
      inx := inx + 1;
    }
  return arr;
}
;

create procedure DI_TAG (in fp any, in w any, in dgst any := 'MD5', in fmt any := 'json')
{
  declare x, u, pref any;
  u := sprintf ('&http=%{WSHost}s');
  x := hex2bin (lower (replace (fp, ':', '')));
  x := encode_base64url (cast (x as varchar));
  if (fmt <> 'sparql')
    pref := 'ID Claim: ';
  else
    pref := '';
  return sprintf ('%sdi:%s;%s?hashtag=webid%s', pref, lower (dgst), x, u);
}
;

create procedure URL_REMOVE_FRAG (in uri any)
{
  declare h any;
  h := WS.WS.PARSE_URI (uri);
  h [5] := '';
  uri := WS.WS.VFS_URI_COMPOSE (h);
  return uri;
}
;

create procedure
make_cert_iri (in key_name varchar)
{
  return sprintf ('http://%{WSHost}s/issuer/key/%s/%s#this', user, key_name);
}
;

create procedure
make_cert_stmt (in key_name varchar, in digest_type varchar := 'sha1')
{
  declare key_iri, cer_iri, webid varchar;
  declare cert_fingerprint, cert_modulus, cert_exponent varchar;
  declare info any;
  declare cert_serial, cert_subject, cert_issuer, cert_val_not_before, cert_val_not_after varchar;
  declare tag, san, ian varchar;
  declare stmt varchar;

  cert_serial         := get_certificate_info (1, key_name, 3);
  cert_subject        := get_certificate_info (2, key_name, 3);
  cert_issuer         := get_certificate_info (3, key_name, 3);
  cert_val_not_before := get_certificate_info (4, key_name, 3);
  cert_val_not_after  := get_certificate_info (5, key_name, 3);
  cert_fingerprint    := get_certificate_info (6, key_name, 3, null, digest_type);
  info := get_certificate_info (9, key_name, 3);
  san := get_certificate_info (7, key_name, 3, '', '2.5.29.17');
  ian := get_certificate_info (7, key_name, 3, '', '2.5.29.18');
  if (san is null) san := make_cert_iri (key_name);
  if (ian is null) ian := make_cert_iri (key_name);

  cert_exponent    := info[1];
  cert_modulus     := bin2hex(info[2]);
  cert_fingerprint := replace (cert_fingerprint, ':', '');

  tag := DI_TAG (cert_fingerprint, webid, digest_type, 'sparql');

  key_iri := sprintf ('http://%{WSHost}s/issuer/key/%s/%s', user, key_name);
  webid := make_cert_iri (key_name);
  cer_iri := url_remove_frag (webid) || '#cert' || replace (cert_fingerprint, ':', '');

  stmt := sprintf ('
SPARQL
PREFIX rsa: <http://www.w3.org/ns/auth/rsa#>
PREFIX cert: <http://www.w3.org/ns/auth/cert#>
PREFIX oplcert: <http://www.openlinksw.com/schemas/cert#>
PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
INSERT
INTO GRAPH <http://%{WSHost}s/pki>
 {
    <%s>       cert:key <%s> ;
    	       a foaf:Agent .
    <%s>       a cert:RSAPublicKey ;
               cert:modulus "%s"^^xsd:hexBinary ;
               cert:exponent "%d"^^xsd:int .

    <%s>       oplcert:hasCertificate <%s> .
    <%s>       a oplcert:Certificate ;
               oplcert:fingerprint "%s" ;
               oplcert:fingerprint-digest "%s" ;
               oplcert:subject "%s" ;
       	       oplcert:issuer "%s" ;
               oplcert:notBefore "%s"^^xsd:dateTime ;
               oplcert:notAfter "%s"^^xsd:dateTime ;
               oplcert:serial "%s" ;
	       oplcert:digestURI <%s> ;
	       %s
    	       %s
	       oplcert:hasPublicKey <%s> .
 }
',  webid, key_iri,
    key_iri, cert_modulus, cert_exponent,
    webid, cer_iri,
    cer_iri, cert_fingerprint, digest_type, cert_subject, cert_issuer,
    DB..date_iso8601 (DB..X509_STRING_DATE (cert_val_not_before)), DB..date_iso8601 (DB..X509_STRING_DATE (cert_val_not_after)),
    cert_serial, tag,
    case when san is not null then sprintf ('oplcert:subjectAltName <%s> ; ', san) else '' end,
    case when ian is not null then sprintf ('oplcert:issuerAltName <%s> ;', ian) else '' end,
    key_iri);

--  dbg_printf ('%s', stmt);

  return stmt;

}
;


create procedure PKI.DBA."key" (in "key_name" varchar, in "username" varchar) __SOAP_HTTP 'text/plain'
{
  declare accept, pref_acc any;
  accept := http_request_header_full (http_request_header (), 'Accept', 'text/plain');
  pref_acc := DB.DBA.HTTP_RDF_GET_ACCEPT_BY_Q (accept);
  set_user_id ("username");
  if (xenc_key_exists ("key_name"))
    {
      declare k any;
      k := "key_name";
      if (strstr (pref_acc, 'application/x-ssh-key') is not null)
       http (xenc_pubkey_ssh_export (k));
      else if (strstr (pref_acc, 'application/x-der-key') is not null)
        http (xenc_pubkey_DER_export (k));
      else if (strstr (pref_acc, 'text/x-der-key') is not null)
        http (encode_base64 (cast (xenc_pubkey_DER_export (k) as varchar)));
      else if (strstr (pref_acc, 'text/plain') is not null)
        http (xenc_pubkey_PEM_export (k));
      else if (strstr (pref_acc, 'text/html') is not null or strstr (pref_acc, '*/*') is not null)
	{
	   http_status_set (303);
	   http_header (http_header_get () || sprintf ('Location: /describe/?url=http://%{WSHost}s/issuer/key/%s/%s\r\n', "username", "key_name"));
	   return '';
	}
      else
        {
	  declare qr, path, params, lines any;
	  qr := sprintf ('DESCRIBE <http://%{WSHost}s/issuer/key/%s/%s> FROM <http://%{WSHost}s/pki>', "username", "key_name");
	  http_header ('');
	  path := vector ('sparql');
	  params := vector ('query', qr);
	  lines := http_request_header ();
	  WS.WS."/!sparql/" (path, params, lines);
	  return '';
	}
      http_header (sprintf ('Content-Type: %s\r\n', pref_acc));
    }
  return '';
}
;

create procedure PKI_INIT ()
{
  if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = 'PKI'))
    return;
  DB.DBA.USER_CREATE ('PKI', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'PKI'));
};

PKI_INIT ();

DB.DBA.VHOST_REMOVE (lpath=>'/issuer/key');
DB.DBA.VHOST_DEFINE (lpath=>'/issuer/key', ppath=>'/SOAP/Http/key', soap_user=>'PKI', opts=>vector ('url_rewrite', 'pki_certs_list1'));

DB.DBA.URLREWRITE_CREATE_RULELIST ('pki_certs_list1', 1, vector ('pki_cert_rule1'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('pki_cert_rule1', 1,
    '/issuer/([^/]*)/([^/]*)/([^/]*)\x24',
    vector('m', 'uid', 'id'), 1,
    '/issuer/%s?key_name=%s&username=%U', vector('m', 'id', 'uid'),
    null,
    null,
    2);

grant execute on PKI.DBA."key" to PKI;

create procedure y_utf2wide (
  in S any)
{
  declare retValue any;

  if (isstring (S))
  {
    retValue := charset_recode (S, 'UTF-8', '_WIDE_');
    if (iswidestring (retValue))
      return retValue;
  }
  return S;
}
;

create procedure y_wide2utf (
  in S any)
{
  declare retValue any;

  if (iswidestring (S))
  {
    retValue := charset_recode (S, '_WIDE_', 'UTF-8' );
    if (isstring (retValue))
      return retValue;
  }
  return charset_recode (S, null, 'UTF-8' );
}
;

create procedure y_registries (
  in _filter varchar := '')
{
  declare N integer;
  declare V, v0, v1 any;
  declare c0, c1 varchar;

  result_names (c0, c1);

  V := registry_get_all ();
  for (N := 0; N < length (V); N := N + 2)
  {
    v0 := cast (V[N] as varchar);
    v1 := V[N+1];
    if ((_filter <> '') and (v0 not like _filter))
      goto _skip;

    result (v0, v1);
  _skip:;
  }
}
;
