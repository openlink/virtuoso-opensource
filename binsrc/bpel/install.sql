--
--  install.sql
--
--  $Id$
--
--  BPEL support procedures
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

create procedure BPEL.BPEL.header (in script varchar:='', in body_arg varchar:='')
{
  declare messargs varchar;
  http (sprintf ('
    <HTML>
      <HEAD>
        <TITLE>OpenLink BPEL Process Manager</TITLE>
        <META HTTP-EQUIV="Cache-Control" content="no-cache">
        <META HTTP-EQUIV="Content-Type" CONTENT="text/html; windows-1251">
        <link rel="stylesheet" type="text/css" href="default.css" />
        %s
      </HEAD>
      <body bgcolor="#FFFFFF" topmargin="0" leftmargin="6" marginheight="0" marginwidth="6" %s>
  ', script, body_arg));
  set isolation='uncommitted';
}
;


create procedure BPEL.BPEL.footer ()
{
  http ('</body></HTML>');
}
;


create procedure BPEL.BPEL.trav_script (inout idarr any, in op_id integer)
{
	for select bg_childs from BPEL.BPEL.graph
		where bg_node_id = op_id
	do
	{
		idarr := BPEL.BPEL.vector_push (idarr, op_id);

		if (bg_childs is not null)
		{
			declare idx int;
			idx := 0;

--
			idarr := BPEL.BPEL.vector_push (idarr, -1);

			while (idx < length (bg_childs))
			{
				BPEL.BPEL.trav_script (idarr, aref (bg_childs, idx));
				idx := idx + 1;
			}
--
			idarr := BPEL.BPEL.vector_push (idarr, -2);

		}
	}
}
;

create procedure BPEL.BPEL.script_ids (in script_id int, in op_id integer)
{
	declare vec0 any;


	vec0 := lvector ();

	BPEL.BPEL.trav_script (vec0, op_id);

	return vec0;
}
;

create procedure BPEL.BPEL.get_activity (in op_id int)
{
	for select bg_activity, bg_parent from BPEL.BPEL.graph
		where bg_node_id = op_id
	do
	{
		declare activity BPEL.BPEL.activity;
                declare id int;

		activity := bg_activity;
                id := bg_parent;
                if (id = -1)
                  return 'Scope';
                else
		return activity.ba_type;
	}

}
;

create procedure BPEL.BPEL.get_wait (in inst_id int, in node_id varchar)
{

	if (exists (select * from BPEL.BPEL.wait
		where bw_instance = inst_id
		and bw_node = node_id))
	{
		http (sprintf ('<A HREF="wait.vsp?inst=%d&node=%d"> &gt; </a>', inst_id, node_id));
	}
}
;

create procedure BPEL.BPEL.spaces (in sp int)
{
	declare _inx integer;

	while (_inx < sp)
	{
		_inx := _inx + 1;
	}
        return _inx;
}
;

create procedure BPEL.BPEL.report_error (in err varchar, in _desc varchar)
{
  --http (sprintf('<report type="error"><res><![CDATA[%s]]></res><desc><![CDATA[%s]]></desc></report>',err,_desc));
  return sprintf('<report type="error"><res><![CDATA[%s]]></res><desc><![CDATA[%s]]></desc></report>',err,_desc);
}
;

create procedure BPEL.BPEL.report_result (in err varchar, in _desc varchar)
{
  --http (sprintf('<report type="result"><res><![CDATA[%s]]></res><desc><![CDATA[%s]]></desc></report>',err,_desc));
  return sprintf('<report type="result"><res><![CDATA[%s]]></res><desc><![CDATA[%s]]></desc></report>',err,_desc);
}
;

create procedure BPEL.BPEL.date_fmt (in dt datetime)
{
  declare y, m, d any;
  y := year (dt);
  m := month (dt);
  d := dayofmonth (dt);
  return sprintf ('%02d/%02d/%04d %02d:%02d', d,m,y, hour(dt), minute(dt));
}
;

create procedure BPEL.BPEL.datetime_format_parse (in str varchar)
{
	declare num int;
	num := 0;
	declare unit varchar;
	unit := null;
whenever sqlstate '22007' goto notdatetime;
	declare res datetime;
	res:= cast (str as datetime);
	return res;
notdatetime:
	declare terms any;
	terms := split_and_decode (str, 0, '\0\0 ');

	declare terms_idx int;
	terms_idx := 0;

	declare st varchar;
	st := 'DIG';
whenever sqlstate '22007' goto next;
	while (terms_idx < length (terms)) {
		if (st = 'DIG') {
			num := cast (aref (terms, terms_idx) as integer);
			st := 'PER';
		}
		if (st = 'PER') {
			if (ucase (aref (terms, terms_idx)) like 'DAY%') {
				unit := 'day';
				st := 'AGO?';
			}
			if (ucase (aref (terms, terms_idx)) like 'HOUR%') {
				unit := 'hour';
				st := 'AGO?';
			}
			if (ucase (aref (terms, terms_idx)) like 'MINUTES%') {
				unit := 'minute';
				num := num ;
				st := 'AGO?';
			}
		}
		if (st = 'AGO?')
			if (ucase (aref (terms, terms_idx)) = 'AGO') {
				num := -num;
		}
next:
		terms_idx:= terms_idx + 1;
		;
	}
	if (unit is null)
		return now();
	return dateadd (unit, num, now());
}
;


create procedure BPEL.BPEL.instances_vsp_reverse (inout nm varchar, in sort varchar)
{
	if (nm = sort) {
		if (sort like '%2') {
			nm := substring (sort, 1, length (sort) - 1);
		} else {
			nm := concat (sort, '2');
		}
	}
}
;

create procedure BPEL.BPEL.bpel_add_predifined_endpoint (in pNewPart varchar, in pEndPoint varchar, in pMode integer := 1)
{
  -- pMode = 0 called from UI

  declare
   _error,
   _errorE,
   _errorRes,
   _msg varchar;

  _errorRes := 0;
  _error := 'Empty values are not allowed';
  _errorE := 'Predefined partner link with this name already exists!';

  _msg := sprintf ('Added predefined endpoint %s for %s', pEndPoint, pNewPart);

  if ( pNewPart <> '' and pEndPoint <> '')
    {
      if ( exists (SELECT 1 FROM  BPEL.BPEL.partner_link_conf WHERE plc_name = pNewPart))
        {
          if ( pMode = 0 ){
             BPEL.BPEL.report_error ('error: ', _errorE);
             return;
          } else {
             return _errorE;
          };
        };
      insert into BPEL.BPEL.partner_link_conf values (pNewPart, pEndPoint);
    }
  else
    {
      _errorRes := 1;
    };

  if ( pMode = 0 and _errorRes = 0 )
    {
      -- UI and success action
      BPEL.BPEL.report_result ('info: ', _msg);
    }
  else if ( pMode = 0 and _errorRes = 1 )
    {
      -- UI and unsuccess action
      BPEL.BPEL.report_error ('error: ', _error);
    }
  else if ( pMode = 1 and _errorRes = 0 )
    {
      -- isql and success action
      return _msg;
    }
  else if ( pMode = 1 and _errorRes = 1 )
    {
      -- isql and unsuccess action
      return _error;
    }
  else
    {
      return 'Invalid parameters';
    };
  return;
}
;

create procedure BPEL.BPEL.bpel_update_predifined_endpoint (in pNewPart varchar, in pEndPoint varchar, in pMode integer := 1)
{
  -- pMode = 0 called from UI

  declare
   _error,
   _errorRes,
   _msg,
   _errorNE varchar;

  _errorRes := 0;
  _error := 'Empty values are not allowed';
  _errorNE := 'There is no Predifined Partner Link with such a name.';

  _msg := sprintf ('New predefined endpoint for %s is %s', pNewPart, pEndPoint);

  if ( pNewPart <> '' and pEndPoint <> '')
    {
      if ( not exists (SELECT 1 FROM  BPEL.BPEL.partner_link_conf WHERE plc_name = pNewPart))
       {
         if ( pMode = 0 ){
            BPEL.BPEL.report_error ('error: ', _errorNE);
            return;
         } else {
            return _errorNE;
         };
       };
      update BPEL.BPEL.partner_link_conf
         set plc_endpoint = pEndPoint
       where plc_name = pNewPart;
    }
  else
    {
      _errorRes := 1;
    };

  if ( pMode = 0 and _errorRes = 0 )
    {
      -- UI and success action
      BPEL.BPEL.report_result ('info: ', _msg);
    }
  else if ( pMode = 0 and _errorRes = 1 )
    {
      -- UI and unsuccess action
      BPEL.BPEL.report_error ('error: ', _error);
    }
  else if ( pMode = 1 and _errorRes = 0 )
    {
      -- isql and success action
      return _msg;
    }
  else if ( pMode = 1 and _errorRes = 1 )
    {
      -- isql and unsuccess action
      return _error;
    }
  else
    {
      return 'Invalid parameters';
    };
  return;
}
;

-- allow only dba group
create procedure BPEL.BPEL.sql_user_password_check (in name varchar, in pass varchar)
{
  declare gid, uid int;
  whenever not found goto nf;
  select U_ID, U_GROUP into uid, gid from SYS_USERS
      where U_NAME = name and U_SQL_ENABLE = 1 and U_IS_ROLE = 0 and pwd_magic_calc(U_NAME, U_PASSWORD, 1) = pass;
  if (gid = 0 or uid = 0)
    return 1;
  nf:
  return 0;
}
;

create procedure BPEL.BPEL.bpel_get_page_name ()
{
  declare path, url, elm varchar;
  declare arr any;
  path := http_path ();
  arr := split_and_decode (path, 0, '\0\0/');
  elm := arr [length (arr) - 1];
  url := xpath_eval ('//*[@url = "'|| elm ||'"]', xml_tree_doc (BPEL.BPEL.bpel_menu_tree ()));
  --dbg_obj_print (url);
  if (url is not null or elm = 'error.vspx')
    return elm;
  else
    return '';
}
;

create procedure BPEL.BPEL.bpel_menu_tree ()
{
  return concat (
'<?xml version="1.0" ?>
   <bpel_menu_tree>
     <node name="Home" url="home.vspx" id="7" allowed="bpel_hom">
       <node name="OpenLink BPEL Process Manager Home" url="home.vspx" id="71" allowed="bpel_hom_view"/>
     </node>
     <node name="Processes" url="process.vspx" id="0" allowed="bpel_web">
       <node name="Processes List" url="process.vspx" id="2" allowed="bpel_process">
         <node name="Process" url="script.vspx" id="21" place="left" allowed="bpel_process">
           <node name="Instance Audit" url="activity.vspx" id="211" place="left" allowed="bpel_process"/>
           <node name="Instance status" url="status.vspx" id="222" place="left" allowed="bpel_process"/>
           <node name="Partner Links" url="plinks.vspx" id="223" place="left" allowed="bpel_process"/>
           <node name="Partner Links Properties" url="plinks_props.vspx" id="223" place="left" allowed="bpel_process"/>
         </node>
       </node>
       <node name="Process upload" url="upload_new.vspx" id="3" allowed="bpel_upload">
         <node name="browser" url="browser.vspx" id="31" place="left" allowed="bpel_upload"/>
         <node name="confirm" url="bpel_confirm.vspx" id="32" place="left" allowed="bpel_upload"/>
       </node>
     </node>
    <node name="Instances" url="instances.vspx" id="12" allowed="bpel_inst">
      <node name="Instances" url="instances.vspx" id="13" allowed="bpel_inst1"/>
    </node>
    <node name="Debugger" url="incoming.vspx" id="4" allowed="bpel_debug">
      <node name="Debugger Console" url="incoming.vspx" id="5" allowed="bpel_debug_console">
        <node name="Invoke Service" url="message.vspx" id="51" place="left" allowed="bpel_debug_console"/>
        <node name="Debug Messages" url="imsgpr.vspx" id="52" place="left" allowed="bpel_debug_console"/>
        <node name="Debug Messages" url="omsgpr.vspx" id="53" place="left" allowed="bpel_debug_console"/>
        <node name="Debug Messages" url="rmsgpr.vspx" id="54" place="left" allowed="bpel_debug_console"/>
      </node>
    </node>
    <node name="Statistics and Reports" url="statproc.vspx" id="5" allowed="bpel_statistics">
       <node name="Statistics" url="statproc.vspx" id="6" allowed="bpel_1">
           <node name="Process Statistics" url="statproc.vspx" id="61" allowed="bpel_2"/>
           <node name="End Point Statistics" url="statendp.vspx" id="62" allowed="bpel_3"/>
       </node>
       <node name="Custom Reports" url="reports.vspx" id="9" allowed="bpel_4"/>
    </node>
    <node name="Configuration" url="configure.vspx" id="10" allowed="bpel_conf">
       <node name="Edit Configuration" url="configure.vspx" id="11" allowed="bpel_conf_edith"/>
    </node>
   </bpel_menu_tree>');
}
;


create procedure BPEL.BPEL.bpel_navigation_root (in path varchar)
{
  return xpath_eval ('/bpel_menu_tree/*', xml_tree_doc (BPEL.BPEL.bpel_menu_tree ()), 0);
}
;

create procedure BPEL.BPEL.bpel_navigation_child (in path varchar, in node any)
{
  path := concat (path, '[not @place]');
  return xpath_eval (path, node, 0);
}
;

create procedure BPEL.BPEL.check_grants (in user_name  varchar, in role_name varchar) {
  declare user_id, group_id, role_id, sql_enabled, dav_enabled integer;
  whenever not found goto nf;
  if (user_name='') return 0;
  select U_ID, U_GROUP into user_id, group_id from SYS_USERS where U_NAME=user_name;
  if (user_id = 0 OR group_id = 0)
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

create procedure
get_xml_meta ()
{
  declare mtd, dta any;
  exec ('select top 1 xtree_doc(''<q/>'') from db.dba.sys_users', null, null, vector (), -1, mtd, dta );
  return mtd[0];
}
;


insert soft BPEL..configuration (conf_name, conf_value, conf_desc)
	values ('MailServer', null, 'Outgoing SMTP Server')
;

insert soft BPEL..configuration (conf_name, conf_value, conf_desc)
	values ('EngineMailAddress', null, 'BPEL Operator E-Mail address')
;

insert soft BPEL..configuration (conf_name, conf_value, conf_desc)
	values ('CommonEmailHeader',   'Subject: {SUBJECT}\r\n', 'Email header for all e-mails');
;

insert soft BPEL..configuration (conf_name, conf_value, conf_desc)
	values ('ErrorSubject',   'BPEL Engine error report', 'Subject for error report mail');
;

insert soft BPEL..configuration (conf_name, conf_value, conf_desc)
	values ('AlertSubject',   'BPEL Engine alert', 'Subject for error alert mail');
;

insert soft BPEL..configuration (conf_name, conf_value, conf_desc)
	values ('ErrorReportSkeleton',   'The script {SCRIPT} (instance No {INSTANCE}) was aborted with following error:\n\r{ERROR}\n\r at {DATE}.', 'E-Mail template for error notifications')
;

insert soft BPEL..configuration (conf_name, conf_value, conf_desc)
	values ('InstanceExpiryDelay', '24', 'Interval for instance expiration (hours)')
;


insert soft BPEL..configuration (conf_name, conf_value, conf_desc)
	values ('ErrorAlertSkeleton',   '{ERROR}\n\rat {DATE}.',
		'E-Mail template for error alerts')
;

insert soft BPEL..configuration (conf_name, conf_value, conf_desc)
	values ('Statistics', 0, 'Global statistics flag')
;

insert soft BPEL..configuration (conf_name, conf_value, conf_desc)
	values ('CLRAssembliesDir', NULL, 'Directory where .NET CLR assemblies must be stored')
;

create procedure BPEL.BPEL.conf_default ()
{
  update BPEL..configuration set conf_value = null where conf_name = 'MailServer';
  update BPEL..configuration set conf_value = null where conf_name = 'EngineMailAddress';
  update BPEL..configuration set conf_value = 'Subject: {SUBJECT}\r\n' where conf_name = 'CommonEmailHeader';
  update BPEL..configuration set conf_value = 'BPEL Engine error report' where conf_name = 'ErrorSubject';
  update BPEL..configuration set conf_value = 'BPEL Engine alert' where conf_name = 'AlertSubject';
  update BPEL..configuration set conf_value = 'The script {SCRIPT} (instance No {INSTANCE}) was aborted with following error:\n\r{ERROR}\n\r at {DATE}.' where conf_name = 'ErrorReportSkeleton';
  update BPEL..configuration set conf_value = '24' where conf_name = 'InstanceExpiryDelay';
  update BPEL..configuration set conf_value = '{ERROR}\n\rat {DATE}.' where conf_name = 'ErrorAlertSkeleton';
  update BPEL..configuration set conf_value = 0 where conf_name = 'Statistics';
  update BPEL..configuration set conf_value = null where conf_name = 'CLRAssembliesDir';
}
;


