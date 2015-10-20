--#pragma begin head
--
--  vspx.vsp
--
--  $Id$
--
--  Virtuoso VSPX core componets classes
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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

--drop table VSPX_SESSION
--;

--#pragma end head
--#pragma begin session

--exec('drop table DB.DBA.VSPX_SESSION')
--;

create table DB.DBA.VSPX_SESSION
     (VS_REALM varchar,
      VS_SID varchar,
      VS_UID varchar,
      VS_STATE long varchar,
      VS_EXPIRY datetime,
      VS_IP varchar,
      primary key (VS_REALM, VS_SID))
;
--#pragma end session

alter table DB.DBA.VSPX_SESSION add VS_IP varchar
;

create table WS.WS.HTTP_SES_TRAP_DISABLE
      (
      EXT varchar,
      primary key (EXT)
      )
;

create trigger VSPX_SESSION_INSERT_AFTER after insert on DB.DBA.VSPX_SESSION {
  declare v_sql any;
  declare result, name, content, reg any;
  declare pwd any;
  declare _state varchar;

  if (not is_http_ctx ())
    return;

  if(registry_get('__block_http_history') = http_path()) {
    -- do nor record itself
    return;
  }
  -- detect password
  select pwd_magic_calc('dav', U_PASSWORD, 1) into pwd from DB.DBA.SYS_USERS where U_NAME='dav' and U_IS_ROLE=0;
  reg := registry_get('__save_http_history');
  -- on a new DB reg is 0 not a DB NULL
  if(isstring (reg) and reg <> '' and http_path() like concat(reg, '/%')) {
    if(VS_STATE is NULL) {
      _state := 'NULL';
    }
    else {
      _state := WS.WS.STR_SQL_APOS(VS_STATE);
    }
    v_sql := sprintf('insert replacing DB.DBA.VSPX_SESSION values(\'%s\', \'%s\', \'%s\', %s, now());\n', VS_REALM, VS_SID, VS_UID, _state);
    v_sql := concat('SET TRIGGERS OFF;\n',
                    v_sql,
                    'update DB.DBA.VSPX_SESSION set VS_STATE = coalesce ((select top 1 VS_STATE from DB.DBA.VSPX_SESSION where VS_STATE is not NULL), serialize (vector (''vspx_user'', ''dba''))) where VS_STATE is NULL;');
    name := sprintf('%06d_sql_exec', sequence_next('sys_http_recording'));
    name := concat('/DAV/sys_http_recording/', name);
    -- check if necessary DAV path exists
    result := cast(DB.DBA.DAV_SEARCH_ID('/DAV/sys_http_recording/', 'c') as integer);
    if(result < 0) {
      -- create DAV collection
      result := cast(DB.DBA.DAV_COL_CREATE('/DAV/sys_http_recording/', '110110110R', 'dav', 'dav', 'dav', pwd) as integer);
      if(result < 0) {
        return;
      }
    }
    result := cast(DB.DBA.DAV_RES_UPLOAD(name, v_sql,'text/html','110110110R','dav','dav','dav', pwd) as INTEGER);
  }
}
;

-- VSPX Trigger for delete graphs used for WebID verifivation
--
create trigger VSPX_SESSION_WEBID_D before delete on DB.DBA.VSPX_SESSION order 100 referencing old as O
{
  -- dbg_obj_print ('VSPX_SESSION_WEBID_D');
  declare _state, webidGraph any;

  _state := deserialize (O.VS_STATE);
  if (not isnull (get_keyword ('agent', _state)) and not isnull (get_keyword ('vtype', _state)))
  {
    webidGraph := 'http:' || replace (O.VS_SID, ':', '');
    DB.DBA.SPARUL_CLEAR (webidGraph, 0, 0, silent=>1);
  }
}
;

--#pragma begin base, event
-- Event class

create type vspx_event
as (
    ve_params any,          -- name value pairs of post data or get arguments after '?'
    ve_lines  any,      -- HTTP header lines
    ve_path   any,      -- requested path , paresd as vector this and above are for compatibility
    ve_button vspx_control,         -- which control originated the event. Only for internal or POST events
    ve_initiator vspx_control,	    -- when auto-post is performed that is the control raised the POST event
    ve_is_post int default 0          -- 0 for GET 1 for POST
   )  temporary self as ref
;

--#pragma end base, event

--#pragma begin base, control

-- Generic VSPX control class
create type vspx_control
as (
    vc_parent  vspx_control default null,      -- next up the tree
    vc_name varchar,        -- name of the control, repeated if inside repeating section;
    vc_instance_name varchar,     -- unique name, different for each even if in a repeating group.
    vc_enabled int default 1,     -- true if meant to be visible
    vc_error_message varchar default null,
    vc_page vspx_page,      -- enclosing page
    vc_focus int default 0, -- is in the post thread or not
    vc_handlers any default null, 	    -- an array of (event-name-1 (h1 h2... hn) ... event_name_n (h1 .. hn))
    vc_attributes any,      -- ordered list of attributes: name/value pairs of the HTML attributes can be appiled to that control
    vc_data_bound int default 0,   -- flag to prevent double binding
    vc_inside_form int default 0,  -- flag : under FORM
    vc_inx   int default null,
    vc_level int default null,
    vc_instantiate int default -1,     -- internal use only
    vc_top_form vspx_form,
    vc_repeater vspx_control,
    vc_control_state int default null, -- internal use only
    vc_have_state int default 0,       -- true if control have page state
    vc_children any default null       -- ordered list of children
    ) temporary self as ref
  method vc_data_bind (e vspx_event) returns any,
  method vc_disable_child (ct_name varchar) returns any,
  method vc_enable_child (ct_name varchar) returns any,
  method vc_error_summary () returns any,
  method vc_error_summary (esc_mode int) returns any,
  method vc_error_summary (esc_mode int, pattern varchar) returns any,
  method vc_find_control (name varchar) returns vspx_control,  -- find a direct child by name
  method vc_find_descendant_control (name varchar) returns vspx_control,  -- find a direct child by name
  method vc_find_parent_by_name (control vspx_control, name varchar) returns vspx_control, -- find any ancestor by desired vc_name
  method vc_find_parent (control vspx_control, udt_name varchar) returns vspx_control, -- find any ancestor by desired name of UDT of parent
  method vc_find_parent_form (control vspx_control) returns vspx_control, -- find any ancestor by name
  method vc_find_rpt_control (name varchar) returns vspx_control, -- find a direct child by internal name
  method vc_sibling_value (name varchar) returns any,  -- find a ufl_value of a field value control that is a direct child of the parent of self
  method vc_get_focus (e vspx_event) returns any,
  method vc_set_childs_focus (flag any, e vspx_event) returns any,
  method vc_post (e vspx_event) returns any,
  method vc_user_post (e vspx_event) returns any,
  method vc_action (e vspx_event) returns any,
  method vc_pre_render (stream any, n int) returns any,
  method vc_render () returns any,
  method vc_xrender () returns any,
  method vc_render (ct_name varchar) returns any,
  method vc_set_view_state (e vspx_event) returns any,
  method vc_view_state (stream any, n int) returns any,
  method vc_attribute (name varchar) returns vspx_attribute,
  method vc_set_attribute (name varchar, value any) returns any,
  method vc_add_attribute (name varchar, value any) returns any,
  method vc_get_attribute (name varchar) returns any,
  method vc_handle_error (state any, message any, deadl any) returns any,
  method vc_init (name varchar, parent vspx_control) returns any,
  method vc_get_name () returns any,
  method vc_set_model () returns any,
  method vc_add_handler (name varchar, method_name varchar) returns any,
  method vc_invoke_handlers (name varchar) returns any,
  method vc_debug_log (rectype varchar, txt varchar, more_data any) returns any,
  method vc_debug_log_endgroup (begin_id integer, rectype varchar, txt varchar, more_data any) returns any,
  method vc_push_in_state (stream any, state any) returns any,
  method vc_push_in_stream (stream any, state any, n int) returns any,
  method vc_get_control_state (def any) returns any,
  method vc_set_control_state (state any) returns any,
  constructor method vspx_control (name varchar, parent vspx_control)
;
--#pragma end base

--#pragma begin base, attribute
create type vspx_attribute as
    (
    va_name varchar,
    va_value varchar,
    va_parent vspx_control
    ) temporary self as ref
    method vc_render () returns any,
    constructor method vspx_attribute (name varchar, parent vspx_control)
;
--#pragma end base, attribute

-- VSPX Page Class , from it must be derived all VSPX pages, no subcalsses for others
create type vspx_page under vspx_control
as (
    vc_view_state any,
    vc_is_postback int default 0,
    vc_persisted_vars any,
    vc_event vspx_event,
    vc_is_valid int default 1,          -- set to 0 when first validator fails
    vc_authenticated int default 0,     -- is true if login control in the page suceeded
    vc_current_id int default 0,
    vc_browser_caps any default 0,
    vc_authentication_mode int default 1, -- authentication mode 0 - cookie, 1 - url, 2 - digest
    vc_debug_log_acc any default null	-- The accumulator in xte_nodebld_... style for keeping debugging info.
    )  temporary self as ref
  method vc_state_deserialize (stream any, n int) returns any,
  method vc_get_debug_log (title varchar) returns any
;


create constructor method vspx_attribute (in name varchar, inout parent vspx_control) for vspx_attribute
{

  self.va_name := name;
  self.va_parent := parent;
}
;

create method vc_render () for vspx_attribute
{
  if(self.va_value='@@hidden@@') return;
  http (' ' || self.va_name || '="');
  http_value (self.va_value);
  http ('"');
}
;

create method vc_attribute (in name varchar) returns vspx_attribute for vspx_control
{
  declare i, l int;
  i := 0; l := length (self.vc_attributes);

  while (i < l)
    {
      declare attr vspx_attribute;
      attr := self.vc_attributes[i];
      if (attr is not null and attr.va_name = name)
        return attr;
      i := i + 1;
    }
  return null;
}
;

create method vc_set_attribute (in name varchar, in value any) for vspx_control
{
  declare i, l int;
  i := 0; l := length (self.vc_attributes);

  while(i < l) {
    declare attr vspx_attribute;
    attr := self.vc_attributes[i];
    if (attr is not null and attr.va_name = name) {
      attr.va_value := value;
      aset(self.vc_attributes, i, attr);
      return attr;
    }
    i := i + 1;
  }
  return null;
}
;

create method vc_add_attribute (in name varchar, in value any) for vspx_control
{
  -- new attribute
  declare attrs any;
  declare attr vspx_attribute;

  attr := self.vc_set_attribute (name, value);
  if (attr is not null)
    return attr;
  attr := vspx_attribute (name, self);
  attr.va_value := value;
  attrs := self.vc_attributes;
  attrs := vector_concat (attrs, vector (attr));
  self.vc_attributes := attrs;
  return attr;
}
;

create method vc_get_attribute (in name varchar) for vspx_control
{
  declare i, l int;
  i := 0; l := length (self.vc_attributes);
  while (i < l)
    {
      declare attr vspx_attribute;
      attr := self.vc_attributes[i];
      if (attr is not null and attr.va_name = name)
    {
      return attr.va_value;
        }
      i := i + 1;
    }
  return null;
}
;

create method vc_add_handler (in name varchar, in method_name varchar) for vspx_control
  {
    declare pos, arr, hdl int;
    declare meth any;
    if (self.vc_handlers is null)
      {
	self.vc_handlers := vector (
	'on-init', null,
	'before-data-bind', null,
	'after-data-bind', null,
	'on-post', null,
	'before-render', null
	);
      }

    arr := self.vc_handlers;
    pos := position (name, arr);
    if (pos < 1)
      signal ('22023', 'Invalid handler type, must be one of following: on-init, before-data-bind, after-data-bind, on-post or before-render');

    hdl := arr [pos];
    if (hdl is null)
      hdl := vector ();

    meth := udt_implements_method (self.vc_page, fix_identifier_case (method_name));
    if (meth)
      {
	hdl := vector_concat (hdl, vector (method_name));
      }
    else
      {
	signal ('22023', 'Not existing page method: "'||method_name||'".');
      }

    arr[pos] := hdl;
    self.vc_handlers := arr;
  }
;

create method vc_invoke_handlers (in name varchar) for vspx_control
  {
    declare meth, arr, hdl any;
    declare i, l int;
    if (self.vc_handlers is null)
      return;
    arr := self.vc_handlers;
    hdl := get_keyword (name, arr);
    if (hdl is null)
      return;
    l := length (hdl); i := 0;
    while (i < l)
      {
	meth := udt_implements_method (self.vc_page, fix_identifier_case (hdl[i]));
	call (meth) (self.vc_page, self);
	i := i + 1;
      }
  }
;

create method vc_init (in name varchar, inout parent vspx_control) for vspx_control
  {
    declare id int;

    if (not isstring (name))
      {
	signal ('22023', 'Missing control name');
      }

    self.vc_name := name;
    self.vc_parent := parent;
    self.vc_page := parent.vc_page;

    if (self.vc_inx is null and parent.vc_inx is not null)
      self.vc_inx := parent.vc_inx;
    if (self.vc_level is null and parent.vc_level is not null)
      self.vc_level := parent.vc_level;

    if (parent.vc_repeater is null and self.vc_inx is not null and parent.vc_inx is not null)
      {
        self.vc_repeater := parent;
      }
    else if (parent.vc_repeater is not null)
      {
        self.vc_repeater := parent.vc_repeater;
      }

    --if (self.vc_inx is null)
    --  {
    --	id := self.vc_page.vc_current_id;
    --	id := id + 1;
    --	self.vc_page.vc_current_id := id;
    --	self.vc_instance_name := sprintf ('%s$%d', self.vc_name, self.vc_page.vc_current_id);
    --  }

    -- make instance name by index in repeater and using
    -- repeater's name

    if (self.vc_inx is not null
	--and self.vc_level is null
       )
      {
        if (self.vc_repeater is null)
	  self.vc_instance_name := sprintf ('%s$%d', self.vc_name, self.vc_inx);
        else
	  self.vc_instance_name := sprintf ('%s:%s$%d',
	      self.vc_repeater.vc_instance_name, self.vc_name, self.vc_inx);
      }
    -- do not use vc_level; it's wrong way because makes a dublicates
    --if (self.vc_inx is not null and self.vc_level is not null)
    --  {
    --	self.vc_instance_name := sprintf ('%s$%d$%d', self.vc_name, self.vc_inx, self.vc_level);
    --  }

    if (self.vc_inside_form or parent.vc_inside_form or
        udt_instance_of (parent, fix_identifier_case ('vspx_form')))
      self.vc_inside_form := 1;

    if (udt_instance_of (self, fix_identifier_case ('vspx_form')) and not self.vc_inside_form)
      {
	self.vc_top_form := self;
      }
    else if (parent.vc_top_form is not null)
      {
	self.vc_top_form := parent.vc_top_form;
      }
  }
;

create method vc_get_name () for vspx_control
  {
    if (self.vc_instance_name is null)
      return self.vc_name;
    return self.vc_instance_name;
  }
;

create method vc_debug_log (in rectype varchar, in txt varchar, in more_data any) returns any for vspx_control
{
  declare acc any;
  declare head any;
  declare id any;
  if (self is null or self.vc_page is null)
    return 0;
  acc := self.vc_page.vc_debug_log_acc;
  if (acc is null)
    xte_nodebld_init (acc);
  id := sequence_next('vspx_vc_debug_log');
  head := xte_head (rectype, 'text', txt, 'control-name', self.vc_name, 'instance-name', self.vc_instance_name, 'id', cast (id as varchar));
  if (more_data is null)
    xte_nodebld_acc (acc, xte_node (head));
  else if (isentity (more_data))
    xte_nodebld_acc (acc, xte_node (head, more_data));
  else
    xte_nodebld_acc (acc, xte_node (head, cast (more_data as varchar)));
  self.vc_page.vc_debug_log_acc := acc;
  return id;
}
;

create method vc_debug_log_endgroup (in begin_id integer, in rectype varchar, in txt varchar, in more_data any) returns any for vspx_control
{
  declare acc any;
  declare head any;
  declare id any;
  if (self is null or self.vc_page is null)
    return 0;
  acc := self.vc_page.vc_debug_log_acc;
  if (acc is null)
    xte_nodebld_init (acc);
  id := sequence_next('vspx_vc_debug_log');
  head := xte_head (rectype, 'text', txt, 'control-name', self.vc_name, 'instance-name', self.vc_instance_name, 'id', cast (id as varchar), 'begin-id', cast (begin_id as varchar));
  if (more_data is null)
    xte_nodebld_acc (acc, xte_node (head));
  else if (isentity (more_data))
    xte_nodebld_acc (acc, xte_node (head, more_data));
  else
    xte_nodebld_acc (acc, xte_node (head, cast (more_data as varchar)));
  self.vc_page.vc_debug_log_acc := acc;
  return id;
}
;

create method vc_state_deserialize (inout stream any, inout n int) returns any for vspx_page
{
  declare ss any;
  declare h any;
  declare inx, len int;
  h := udt_implements_method (self.vc_page, fix_identifier_case (concat ('vc_view_state_', self.vc_name)));
  if (h <> 0)
    {
      call (h) (self.vc_page, self, stream, n);
    }
  ss := string_output ();
  http (chr (193), ss);
  http (serialize (n), ss);
  http (string_output_string (stream), ss);
  stream := null;
  self.vc_view_state := deserialize (string_output_string (ss));
  --dbg_obj_print ('VIEW STATE', self.vc_view_state);
}
;

create method vc_get_debug_log (in title varchar) returns any for vspx_page
{
  declare acc any;
  acc := self.vc_debug_log_acc;
  if (acc is null)
    return xml_tree_doc (xte_node (xte_head(title)));
  xte_nodebld_final(acc, xte_head(title));
  self.vc_debug_log_acc := null;
  return xml_tree_doc (acc);
}
;

--#pragma begin base, row_template
-- Repeatable control
create type vspx_row_template under vspx_control
as (
    te_rowset any,    -- the row
    te_ctr int default 0, -- index in the result set
    te_editable int default 0 -- editing on this row is enabled, render update form on it's place
   )  temporary self as ref
constructor method vspx_row_template (name varchar,rowset any, parent vspx_control, ctr int),
constructor method vspx_row_template_fast (name varchar,rowset any, parent vspx_control, ctr int, nth int),
method te_column_value (name varchar) returns any
;
--#pragma end base, row_template

create type vspx_form under vspx_control
   as
     (
       uf_action varchar default '',
       uf_method varchar default 'post',
       --uf_inside_form int default 0,
       uf_validators any,
       uf_xmodel any default null,
       uf_xsubmit any default null,
       uf_xschema any default null
     )  temporary self as ref
   constructor method vspx_form (name varchar, parent vspx_control),
   method prologue_render (sid varchar, realm varchar, nonce varchar) returns any,
   method epilogue_render () returns any,
   overriding method vc_set_model () returns any
;

--Tab Deck
create type vspx_tab under vspx_form
as
   (
     tb_active vspx_template,
     tb_is_input int default 0,
     tb_style varchar
   )
    temporary self as ref
   constructor method vspx_tab (name varchar, parent vspx_control),
   --overriding method vc_render () returns any,
   overriding method vc_set_view_state (e vspx_event) returns any,
   overriding method vc_view_state (stream any, n int) returns any
;

create type vspx_template under vspx_control
  temporary self as ref
 constructor method vspx_template (name varchar, parent vspx_control)
;

-- Single row update form
create type vspx_update_form under vspx_form
as (
    uf_keys  any,
    uf_fields any,
    uf_row any,
    uf_columns any,
    uf_table varchar,
    uf_if_not_exists int,
    uf_concurrency int default 0
   )  temporary self as ref
 overriding method vc_view_state (stream any, n int) returns any,
 overriding method vc_set_view_state (e vspx_event) returns any,
 constructor method vspx_update_form (name varchar, parent vspx_control),
 method uf_column_value (name varchar) returns any
;

create type vspx_login_form under vspx_form
as
  (
   vlf_title varchar,
   vlf_user_title varchar,
   vlf_password_title varchar,
   vlf_submit_title varchar,
   vlf_login vspx_login
  ) temporary self as ref
constructor method vspx_login_form (name varchar,  parent vspx_control),
constructor method vspx_login_form (name varchar, title varchar, user_title varchar, password_title varchar, submit_tile varchar, login vspx_login),
overriding method vc_render () returns any
;


create type vspx_field_value under vspx_control
as
  (
    ufl_value any default null,
    ufl_element_value any default null,
    ufl_element_place any default null,
    ufl_element_path any default null,
    ufl_element_params any default null,
    ufl_element_update_path any default null,
    ufl_element_update_params any default null,
    ufl_true_value any default 1,
    ufl_false_value any default 0,
    ufl_null_value any default null,
    ufl_selected int default 0,
    ufl_is_boolean int default 0
  )
  temporary self as ref
  constructor method vspx_field_value (name varchar, parent vspx_control),
  method vc_get_from_element () returns any,
  method vc_put_to_element (val any) returns any,
  method vc_get_value_from_element () returns any,
  method vc_put_value_to_element () returns any,
  method vc_get_selected_from_value () returns any
;

--#pragma begin base, field
create type vspx_field under vspx_field_value
as
  (
    ufl_fmt_fn varchar default null,
    ufl_cvt_fn varchar default null,
    ufl_validators any,
    ufl_column varchar default null,
    ufl_error varchar default null,
    ufl_error_glyph varchar default null,
    ufl_failed int default 0,
    ufl_group varchar default '',
    ufl_name_suffix varchar default '',
    ufl_active int default 1,
    ufl_client_validate int default 0,
    ufl_auto_submit int default 0
 )
  temporary self as ref
  constructor method vspx_field (name varchar, parent vspx_control),
  method ufl_schema (sch any, name varchar) returns any,
  method vc_validate () returns any
;
--#pragma end base, field

--#pragma begin base, column
create type vspx_column under vspx_field
 as
   (
     ufl_col_label varchar,
     ufl_col_offs int,
     ufl_col_meta any,
     ufl_table varchar default null,
     ufl_is_key int default 0
   )
  temporary self as ref
  constructor method vspx_column (col varchar, label varchar, infmt varchar, outfmt varchar, parent vspx_control)
;
--#pragma end base, column

--#pragma begin obsolete

-- A cell represantation
create type vspx_update_field under vspx_text
  temporary self as ref
  constructor method vspx_update_field (name varchar, parent vspx_control),
  overriding method vc_render () returns any,
  overriding method vc_view_state (stream any, n int) returns any
;

--#pragma end obsolete

-- A isql control
create type vspx_isql under vspx_form
as
 (
   -- parameters
   isql_custom_exec integer default 0,  -- do nothing to allow vspx code to perform actual exec (i.e. dataset open)
   isql_explain integer default 0,  -- explain instead of execute
   isql_maxrows integer default 20,
   isql_chunked integer default 0,
   isql_current_stmt varchar default null,
   isql_current_state any default null,
   isql_current_meta any default null,
   isql_current_pos int default 0,
   isql_current_row int default 0,
   isql_rows_fetched int default 0,
   isql_user varchar default null,
   isql_password varchar default null,
   isql_isolation varchar default 'committed',
   isql_timeout integer default 60,
   isql_text varchar default '', -- sql text to execute
   --results
   --also used vc_error_message as vector(vector('sqlstate','sqlmessage'), ... ) for multiple statements
   isql_mtd any default null, --as vector(mtd, ... ) for multiple statements
   isql_res any default null,  --as vector(res, ... ) for multiple statements
   isql_stmts any default null -- array of statements to be executed on render as cursors
 )
   temporary self as ref
  constructor method vspx_isql (name varchar, parent vspx_control),
  method isql_exec () returns any
;

create type vspx_text under vspx_field
as
 (
   tf_default varchar default '',
   tf_style any default 0 -- 0 is text, 1 is password, 2 is hidden
 )
 temporary self as ref
  overriding method vc_render () returns any,
  overriding method vc_set_view_state (e vspx_event) returns any,
  overriding method vc_view_state (stream any, n int) returns any,
  overriding method vc_set_model () returns any,
  overriding method vc_xrender () returns any,
  constructor method vspx_text (name varchar, parent vspx_control)
;

create type vspx_textarea under vspx_text  temporary self as ref
  constructor method vspx_textarea (name varchar, parent vspx_control),
  overriding method vc_xrender () returns any,
  overriding method vc_render () returns any
;

create type vspx_label under vspx_field
as
(
  vl_format varchar default '%s'
) temporary self as ref
constructor method vspx_label (name varchar, parent vspx_control),
overriding method vc_render () returns any
;

create type vspx_check_box under vspx_field
temporary self as ref
constructor method vspx_check_box (name varchar, parent vspx_control),
overriding method vc_render () returns any,
overriding method vc_xrender () returns any,
overriding method vc_view_state (stream any, n int) returns any,
overriding method vc_set_view_state (e vspx_event) returns any,
overriding method vc_set_model () returns any
;

create type vspx_radio_button under vspx_field
temporary self as ref
constructor method vspx_radio_button (name varchar, parent vspx_control),
overriding method vc_view_state (stream any, n int) returns any,
overriding method vc_set_view_state (e vspx_event) returns any,
overriding method vc_render () returns any,
overriding method vc_xrender () returns any,
overriding method vc_set_model () returns any
;

create type vspx_radio_group under vspx_field
temporary self as ref
constructor method vspx_radio_group (name varchar, parent vspx_control),
method vc_choose_selected () returns any,
overriding method vc_xrender () returns any,
overriding method vc_set_model () returns any
;

create type vspx_url under vspx_field
as
  (
    vu_format varchar default '%s',
    vu_url varchar default '',
    vu_l_pars varchar default '',
    vu_is_local int default 0
  )
temporary self as ref
overriding method vc_render () returns any,
constructor method vspx_url (name varchar, parent vspx_control)
;

-- Button class, encapsulate all controls originating a event
create type vspx_button under vspx_field as
(
  bt_pressed int default 0,
  bt_style  varchar default 'submit',
  bt_close_img varchar,
  bt_open_img varchar,
  bt_url varchar default '',
  bt_l_pars varchar default '',
  bt_text varchar default '',
  bt_anchor int default 0
)  temporary self as ref
overriding method vc_render () returns any,
overriding method vc_xrender () returns any,
overriding method vc_set_model () returns any,
constructor method vspx_button (name varchar, parent vspx_control)
;

create type vspx_submit under vspx_button
 temporary self as ref
constructor method vspx_submit (name varchar, parent vspx_control)
;

create type vspx_logout_button under vspx_button
temporary self as ref
constructor method vspx_logout_button (name varchar, parent vspx_control)
;

create type vspx_return_button under vspx_button
temporary self as ref
overriding method vc_render () returns any,
constructor method vspx_return_button (name varchar, parent vspx_control)
;

create type vspx_delete_button under vspx_button as
(
  btd_table varchar,
  btd_key varchar
) temporary self as ref
constructor method vspx_delete_button (name varchar, parent vspx_control)
;

create type vspx_calendar under vspx_control as
(
  cal_date date,
  cal_meta any,
  cal_selected datetime,
  cal_current_row vspx_row_template
) temporary self as ref
method vc_get_date_array () returns any,
overriding method vc_view_state (stream any, n int) returns any,
overriding method vc_set_view_state (e vspx_event) returns any,
constructor method vspx_calendar (name varchar, parent vspx_control)
;

--#pragma begin validator
-- Generic Validation Class
create type vspx_validator
as
    (
      vv_format varchar,
      vv_test   varchar,
      vv_expr   varchar,
      vv_message varchar,
      vv_empty_allowed int default 0
    )  temporary self as ref
;

-- Range Validation Class
create type vspx_range_validator under vspx_validator
as
   (
     vr_min any,
     vr_max any
   )  temporary self as ref
   method vv_validate (control vspx_control) returns any
;

--#pragma end validator

create type vspx_data_set under vspx_form
as (
    ds_nrows int,     -- how many rows to show on single page
    ds_scrollable int,      -- scroll on form is enabled
    ds_editable int default 1,          -- disable edit/add on whole grid
    ds_row_meta any,      -- metadata
    ds_row_data any,      -- data coming from a function, rowset
    ds_current_row vspx_row_template,   -- current row template
    ds_rowno_edit int default null, -- last edited row in result set, to re-display the edit box on error
    ds_rows_fetched int default 0,  -- how many rows are fetched for current page
    ds_rows_total int default 0,  -- how many data rows do we have in total (for vector)
    ds_rows_offs    int default 0,  -- this is the zero-based index of the first row of the current page in the whole list
    ds_rows_offs_saved int default 0,  -- this is the value of ds_rows_offs that was saved in the page state.
    ds_scrolled     int default 0,
    ds_has_next_page int default 0,	-- Flag if there are rows after the current page (so 'next page' button should be enabled).
    ds_prev_bookmark any default null, -- Bookmark of the record that was at the beginning of previous retrieval of the page (bmk of the first row of the displayed page)
    ds_last_bookmark any default null, -- Bookmark of the record that was at the end of previous retrieval of the page (bmk of the last row of the displayed page)
    ds_rows_cache any,
    ds_data_source vspx_data_source default null
   )  temporary self as ref
  method vc_templates_clean () returns any,
  method vc_reset () returns any,
  method ds_column_offset (name varchar) returns any,
  method ds_iterate_rows (inx int) returns any,
  constructor method vspx_data_set (name varchar, parent vspx_control),
  overriding method vc_set_view_state (e vspx_event) returns any,
  overriding method vc_view_state (stream any, n int) returns any
;

create type vspx_data_source under vspx_control
as    (
    ds_row_meta any,      -- metadata
    ds_row_data any,      -- data coming from a function, rowset
    ds_array_data any,    -- data coming from @data=... where @expression-type='array'
    ds_rows_fetched int default 0,  -- these are to keep state for scrolling
    ds_rows_offs    int default 0,  -- this is the pos of row at 0 offset
    ds_nrows int,     -- how many rows to show on single page
    ds_total_pages int default 0,
    ds_current_page int default 0,
    ds_current_pager_idx int default 0,
    ds_npages int default 10,
    ds_first_page int default 0,
    ds_last_page int default 0,
    ds_total_rows int default 0,
    ds_prev_bookmark any default null,
    ds_next_bookmark any default null,
    ds_parameters any default null,
    ds_columns any default null,
    ds_sql varchar default null,
    ds_sql_type varchar default 'sql',
    ds_current_inx int default 0,
    ds_update_inx int default -1,
    ds_tables any default null,
    ds_insert any default null,
    ds_update any default null,
    ds_delete any default null,
    ds_rb_data any default null,
    ds_have_more any default null
      )
temporary self as ref
method set_parameter (num any, value any) returns any,
method get_parameter (num any) returns any,
method add_parameter (value any) returns any,
method delete_parameter (num any) returns any,
method get_column_name (num any) returns any,
method set_column_label (num any, value any) returns any,
method get_column_label (num any) returns any,
method get_column_label (col varchar) returns any,
--method set_column_add_style (num int, style any) returns any,
--method get_column_add_style (num int) returns any,
--method set_column_edit_style () returns any,
--method get_column_edit_style () returns any,
--method set_column_browse_style () returns any,
--method get_column_browse_style () returns any,
--method set_column_add_format () returns any,
--method get_column_add_format () returns any,
--method set_column_edit_format () returns any,
--method get_column_edit_format () returns any,
--method set_column_browse_format () returns any,
--method get_column_browse_format () returns any,
method set_item_value (row any, col any, value any) returns any,
method set_item_value (col varchar, value any) returns any,
method get_item_value (row any, col any) returns any,
method get_rb_item_value (row any, col any) returns any,
method get_item_value (col any) returns any,
method get_item_value (col varchar) returns any,
method set_expression (expression varchar) returns any,
method get_expression () returns varchar,
method set_expression_type (type varchar) returns any,
method get_expression_type () returns varchar,
method reset () returns any,
method ds_data_bind (e vspx_event) returns any,
method ds_make_statistic () returns any,
method ds_insert (e vspx_event) returns any,
method ds_update (e vspx_event) returns any,
method ds_delete (e vspx_event) returns any,
method ds_key_params (tbl varchar) returns any,
method ds_tbl_params (tbl varchar) returns any,
method get_current_row () returns any,
constructor method vspx_data_source (name varchar, parent vspx_control)
;

-- XXX: clear all members here
create method reset () for vspx_data_source
{
  self.ds_prev_bookmark := null;
  self.ds_last_bookmark := null;
}
;

create method ds_key_params (in tbl varchar) for vspx_data_source
{
  declare i, l, r int;
  declare pars any;
  pars := vector ();
  i := 0; l := length (self.ds_columns);
  r := self.ds_update_inx;
  while (i < l)
    {
      declare col vspx_column;
      col := self.ds_columns[i];
      if (col.ufl_table = tbl and col.ufl_is_key)
        {
          declare par any;
          if (self.ds_rb_data is not null)
        par := self.get_rb_item_value (r,i);
          else
        par := self.get_item_value (r,i);
      pars := vector_concat (pars, vector (par));
        }
      i := i + 1;
    }
  return pars;
}
;

create method ds_tbl_params (in tbl varchar) for vspx_data_source
{
  declare i, l, r int;
  declare pars any;
  pars := vector ();
  i := 0; l := length (self.ds_columns);
  r := self.ds_update_inx;
  while (i < l)
    {
      declare col vspx_column;
      col := self.ds_columns[i];
      if (col.ufl_table = tbl)
        {
          declare par any;
          par := self.get_item_value (r,i);
      pars := vector_concat (pars, vector (par));
        }
      i := i + 1;
    }
  return pars;
}
;

create method ds_insert (inout e vspx_event) for vspx_data_source
{
  declare stat, msg, pars any;
  declare pos, ia any;
  declare stmt varchar;
  declare i, l int;

  ia := self.ds_insert;
  i := 0;
  l := length (ia);
  while (i < l)
    {
      declare k, p any;
      declare tbl varchar;
      declare npars any;

      tbl := self.ds_tables[i];
      p := self.ds_tbl_params (tbl);
      stmt := ia[i];
      npars := p;
      stat := '00000';
      exec (stmt, stat, msg, npars);
      --dbg_obj_print (stmt, npars, stat, msg);
      if (stat <> '00000')
        {
          rollback work;
      signal (stat, msg);
    }
      i := i + 1;
    }

}
;

create method ds_update (inout e vspx_event) for vspx_data_source
{
  declare stat, msg, pars any;
  declare pos any;
  declare stmt varchar;
  declare i, l int;
  declare ua, ia any;

  ua := self.ds_update;
  i := 0;
  l := length (ua);
  while (i < l)
    {
      declare k, p any;
      declare tbl varchar;
      declare npars any;

      tbl := self.ds_tables[i];
      k := self.ds_key_params (tbl);
      p := self.ds_tbl_params (tbl);
      stmt := ua[i];
      npars := vector_concat (p, k);
      stat := '00000';
      exec (stmt, stat, msg, npars);
      --dbg_obj_print (stmt, npars, stat, msg, ' row_count: ', row_count ());
      if (stat <> '00000')
        {
          rollback work;
      signal (stat, msg);
    }
      i := i + 1;
    }
}
;

create method ds_delete (inout e vspx_event) for vspx_data_source
{
  declare stat, msg, pars any;
  declare pos any;
  declare stmt varchar;
  declare i, l int;
  declare da any;

  da := self.ds_delete;
  i := 0;
  l := length (da);
  while (i < l)
    {
      declare k, p any;
      declare tbl varchar;
      declare npars any;

      tbl := self.ds_tables[i];
      k := self.ds_key_params (tbl);
      stmt := da[i];
      npars := k;
      stat := '00000';
      exec (stmt, stat, msg, npars);
      --dbg_obj_print (stmt, npars, stat, msg);
      if (stat <> '00000')
        {
          rollback work;
      signal (stat, msg);
    }
      i := i + 1;
    }

}
;

create method ds_make_statistic () for vspx_data_source
{
  declare stat, msg, data, meta any;
  declare pos any;
  declare stmt varchar;
  declare i, l int;
  declare j, k int;

  stat := '00000';
  if(self.ds_sql_type = 'sql') {
    stmt := sprintf('select count(*) from (%s) %s',  self.ds_sql, self.vc_name);
  }
  else if(self.ds_sql_type = 'procedure') {
    return 0;
  }
  else if(self.ds_sql_type = 'array') {
    self.ds_total_rows := length(self.ds_array_data);
    goto skip_sql;
  }
  else if(self.ds_sql_type = 'table') {
    stmt := sprintf('select count(*) from %s',  self.ds_sql);
  }
  exec(stmt, stat, msg, self.ds_parameters, 1, meta, data);
  if(stat <> '00000') {
    rollback work;
    signal (stat, msg);
  }
  self.ds_total_rows := data[0][0];
skip_sql:
  self.ds_total_pages := self.ds_total_rows / self.ds_nrows;
  self.ds_current_page := self.ds_rows_offs / self.ds_nrows + 1;
  if(mod(self.ds_current_page, self.ds_npages + 1) = 0) {
    self.ds_first_page := self.ds_current_page;
  }
  else {
    self.ds_first_page := self.ds_current_page - mod(self.ds_current_page, self.ds_npages + 1);
  }
  if(self.ds_first_page < 1) {
    self.ds_first_page := 1;
  }
  self.ds_last_page := self.ds_first_page + self.ds_npages - 1;
  if(self.ds_last_page > self.ds_total_pages + 1) {
    self.ds_last_page := self.ds_total_pages + 1;
  }
}
;

create method ds_data_bind (inout e vspx_event) for vspx_data_source
{
  declare stat, msg, data, meta any;
  declare pos any;
  declare stmt varchar;
  declare i, l int;
  declare j, k int;

  stat := '00000';
  stmt := self.ds_sql;

  if (self.ds_sql_type = 'sql')
    {
      stmt := sprintf ('select top %d,%d * from (', self.ds_rows_offs, self.ds_nrows + 1)
    || stmt || ') "' || self.vc_name || '"';
    }
  else if (self.ds_sql_type = 'procedure')
    {
      ;
    }
  else if (self.ds_sql_type = 'array')
    {
      self.ds_rows_fetched := length(self.ds_array_data) - self.ds_rows_offs;
      if(self.ds_rows_fetched > self.ds_nrows) self.ds_rows_fetched := self.ds_nrows;
      self.ds_row_data := subseq(self.ds_array_data, self.ds_rows_offs, self.ds_rows_offs + self.ds_rows_fetched);
      return;
    }
  else if (self.ds_sql_type = 'table')
    {
      stmt := sprintf ('select top %d,%d * from %s', self.ds_rows_offs, self.ds_nrows + 1, self.ds_sql);
    }

  --dbg_obj_print (stmt);
  exec (stmt, stat, msg, self.ds_parameters, self.ds_nrows + 1, meta, data);
  if (stat <> '00000')
    {
      rollback work;
      signal (stat, msg);
    }

  if (isarray (data) and length (data) > self.ds_nrows)
    {
      self.ds_have_more := 1;
      data := subseq (data, 0, self.ds_nrows);
    }
  else
    {
      self.ds_have_more := 0;
    }

  -- normalize meta and data as per ds_columns
  meta := meta [0];
  l := length (self.ds_columns);
  j := 0; k := length (meta);
  while (i < l)
    {
      declare col vspx_column;
      col := self.ds_columns[i];
      j := 0;
      while (j < k)
        {
          declare colname varchar;
          if (isstring (meta[j][8]))
        colname := meta[j][8];
      else
            colname := meta[j][0];
          if (colname = col.ufl_column)
            {
              declare cmeta any;
              cmeta := meta[j];
              if (not isstring (meta[j][8]))
                aset (cmeta, 8, colname);
              col.ufl_col_offs := j;
              col.ufl_col_meta := cmeta;
              j := k;
            }
          j := j + 1;
        }
      i := i + 1;
    }
  -- fill the target tables(s)
  declare tables any;
  i := 0; l := length (self.ds_columns);
  tables := vector ();
  while (i < l)
    {
      declare col vspx_column;
      declare tblname varchar;
      col := self.ds_columns[i];
      if (isstring (col.ufl_col_meta[10])
     and isstring (col.ufl_col_meta[9])
      and isstring (col.ufl_col_meta[7])
    )
        {
      tblname := sprintf ('"%I"."%I"."%I"', col.ufl_col_meta[7], col.ufl_col_meta[9], col.ufl_col_meta[10]);
      col.ufl_table := tblname;
      if (not position (tblname, tables))
        tables := vector_concat (tables, vector (tblname));
        }
      i := i + 1;
    }
  -- make insert, update & delete statements
  declare ins, upd, del, whe, cols, vals varchar;
  declare ua, ia, da any;
  i := 0; l := length (tables);
  j := 0; k := length (self.ds_columns);
  ua := make_array (l, 'any');
  ia := make_array (l, 'any');
  da := make_array (l, 'any');
  while (i < l)
    {
      j := 0;
      ins := 'insert into ' || tables[i] || ' ';
      upd := 'update ' || tables[i] || ' set ';
      del := 'delete from ' || tables[i] || ' ';
      whe := ' where ';
      cols := ''; vals := '';
      while (j < k)
        {
          declare col vspx_column;
          declare tblname varchar;
          col := self.ds_columns[j];
          if (tables[i] = col.ufl_table)
            {
              upd := upd || col.ufl_col_meta[8] || ' = ?, ';
              if (not col.ufl_col_meta[4] and col.ufl_col_meta[6])
                {
                  whe := whe || col.ufl_col_meta[8] || ' = ? and ';
                  col.ufl_is_key := 1;
                }
              cols := cols || col.ufl_col_meta[8] || ', ';
              vals := vals || '?, ';
            }
      j := j + 1;
    }
        upd := rtrim (upd,', '); whe := whe || '1';
        cols := rtrim (cols,', '); vals :=  rtrim (vals,', ');
        upd := upd || whe;
        del := del || whe;
        ins := ins || ' (' || cols || ') values (' || vals ||')';
        aset (ua, i, upd);
        aset (ia, i, ins);
        aset (da, i, del);
      i := i + 1;
    }

  self.ds_tables := tables;
  self.ds_insert := ia;
  self.ds_update := ua;
  self.ds_delete := da;

  self.ds_rows_fetched := length (data);
  self.ds_row_data := data;
  self.ds_row_meta := meta;

}
;

create method get_current_row () for vspx_data_source
{
  return self.ds_current_inx;
}
;

create method set_parameter (in num any, in value any) for vspx_data_source
{
  declare pars any;
  if (length (self.ds_parameters) > num)
    {
      pars := self.ds_parameters;
      aset (pars, num, value);
      self.ds_parameters := pars;
    }
}
;

create method get_parameter (in num any) for vspx_data_source
{
  declare exit handler for sqlstate '22003' { return 'out-of-index'; };
  return self.ds_parameters[num];
}
;

create method add_parameter (in value any) for vspx_data_source
{
  declare pars any;
  pars := self.ds_parameters;
  if (pars is null)
    pars := vector ();
  pars := vector_concat (pars, vector (value));
  self.ds_parameters := pars;
}
;

create method delete_parameter (in num any) for vspx_data_source
{
  declare pars any;
  if (length (self.ds_parameters) > num)
    {
      declare i,j, l int;
      pars := make_array(length(self.ds_parameters) - 1, 'any');
      i := 0; l := length (self.ds_parameters); j := 0;
      while (i < l)
        {
          if (i <> num)
            {
              aset (pars, j, self.ds_parameters[i]);
              j := j + 1;
        }
          i := i + 1;
        }
      self.ds_parameters := pars;
    }
}
;

create method set_column_label (in num any, in value any) for vspx_data_source
{
  declare cols any;
  if (length (self.ds_columns) > num)
    {
      declare col vspx_column;
      cols := self.ds_columns;
      col := cols[num];
      col.ufl_col_label := value;
      aset (cols, num, col);
      self.ds_columns := cols;
    }
}
;

create method get_column_label (in num any) for vspx_data_source
{
  declare exit handler for sqlstate '*' { return 'out-of-index'; };
  return (self.ds_columns[num] as vspx_column).ufl_col_label;
}
;

create method get_column_name (in num any) for vspx_data_source
{
  --declare exit handler for sqlstate '*' { return 'out-of-index'; };
  return (self.ds_columns[num] as vspx_column).ufl_column;
}
;

create method get_column_label (in col varchar) for vspx_data_source
{
  declare colum vspx_column;
  declare i, l int;
  declare exit handler for sqlstate '*' { return 'out-of-index'; };
  i := 0; l := length (self.ds_columns);
  while (i < l)
    {
      colum := self.ds_columns[i];
      if (colum.ufl_column = col)
        goto endf;
      i := i + 1;
    }
  signal ('22003', 'Non-existing column');
endf:;
  return colum.ufl_col_label;
}
;

create method set_item_value (in row any, in col any, in value any) for vspx_data_source
{
  declare data, drow any;
  declare cols any;
  declare colum vspx_column;
  if (length (self.ds_row_data) <= row)
    return;
  data := self.ds_row_data;
  drow := data[row];
  cols := self.ds_columns;
  if (length (cols) <= col)
    return;
  colum := cols[col];
  aset (drow, colum.ufl_col_offs, value);
  aset (data, row, drow);
  if (self.ds_rb_data is null) self.ds_rb_data := self.ds_row_data;
  self.ds_row_data := data;
}
;

create method set_item_value (in col varchar, in value any) for vspx_data_source
{
  declare row int;
  declare data, drow any;
  declare colum vspx_column;
  declare i, l int;

  row := self.ds_update_inx;
  i := 0; l := length (self.ds_columns);
  while (i < l)
    {
      colum := self.ds_columns[i];
      if (colum.ufl_column = col)
        goto endf;
      i := i + 1;
    }
  signal ('22003', 'Non-existing column');
endf:;
  data := self.ds_row_data;
  drow := data[row];
  aset (drow, colum.ufl_col_offs, value);
  aset (data, row, drow);
  if (self.ds_rb_data is null) self.ds_rb_data := self.ds_row_data;
  self.ds_row_data := data;
}
;

create method get_item_value (in row any, in col any) for vspx_data_source
{
  declare colum vspx_column;
  declare exit handler for sqlstate '22003' { return 'out-of-index'; };
  colum := self.ds_columns[col];
  return self.ds_row_data[row][colum.ufl_col_offs];
}
;

create method get_rb_item_value (in row any, in col any) for vspx_data_source
{
  declare colum vspx_column;
  if (self.ds_rb_data is null)
    return null;
  declare exit handler for sqlstate '22003' { return 'out-of-index'; };
  colum := self.ds_columns[col];
  return self.ds_rb_data[row][colum.ufl_col_offs];
}
;

create method get_item_value (in col any) for vspx_data_source
{
  declare colum vspx_column;
  declare exit handler for sqlstate '22003' { return ''; };
  colum := self.ds_columns[col];
  return self.ds_row_data[self.get_current_row ()][colum.ufl_col_offs];
}
;

create method get_item_value (in col varchar) for vspx_data_source
{
  declare colum vspx_column;
  declare i, l int;
  declare exit handler for sqlstate '22003' { return ''; };
  i := 0; l := length (self.ds_columns);
  while (i < l)
    {
      colum := self.ds_columns[i];
      if (colum.ufl_column = col)
        goto endf;
      i := i + 1;
    }
  signal ('22003', 'Non-existing column');
endf:;
  return self.ds_row_data[self.get_current_row ()][colum.ufl_col_offs];
}
;

create method set_expression (in expression varchar) for vspx_data_source
{
  self.ds_sql := expression;
}
;

create method get_expression () for vspx_data_source
{
  return self.ds_sql;
}
;

create method set_expression_type (in type varchar) for vspx_data_source
{
  if (lower(type) not in ('sql', 'procedure', 'table'))
    signal ('22023', 'Bad type of sql expression fo data-source');
  self.ds_sql_type := lower(type);
}
;

create method get_expression_type () for vspx_data_source
{
  return self.ds_sql_type;
}
;
-- duplicate
--create method reset () for vspx_data_source
--{
--  self.ds_prev_bookmark := null;
--  self.ds_last_bookmark := null;
--}
--;

create method vc_templates_clean () for vspx_data_set
{
  declare i, l int;
  declare chils any;
  chils := self.vc_children;
  i := 0; l := length (chils);
  while (i < l)
    {
      declare chil any;
      chil := chils[i];
      if (chil is not null and udt_instance_of (chil, fix_identifier_case ('vspx_row_template')))
  {
          --chils := vector_concat (chils, vector (chil));
    aset (chils, i, NULL);
  }
      i := i + 1;
    }
  self.vc_children := chils;
}
;

create method vc_reset () for vspx_data_set
{
  self.ds_prev_bookmark := null;
  self.ds_last_bookmark := null;
  self.ds_rows_offs := 0;
}
;

create method ds_column_offset (in name varchar) for vspx_data_set
{
  if (self.ds_data_source is null)
    return (position (name, self.ds_row_meta) - 1);
  else
    {
      declare i, l int;
      i := 0; l := length (self.ds_row_meta);
      while (i < l)
	{
	  declare elm any;
	  elm := self.ds_row_meta[i];
	  if (isarray (elm) and length (elm) and elm[0] = name)
	    return i;
	  i := i + 1;
        }
    }
}
;

create method ds_iterate_rows (inout inx int) for vspx_data_set
{
  declare i, l int;
  declare chil vspx_control;
  declare c any;
  i := inx;
  c := self.vc_children;
  l := length (c);
  chil := null;
  while (i < l)
    {
      chil := c[i];
      if (chil is not null and udt_instance_of (chil, fix_identifier_case ('vspx_row_template')))
	{
	  inx := i + 1;
	  return chil;
        }
      else
	chil := null;
      i := i + 1;
    }
  inx := l;
  return chil;
}
;

create method vc_choose_selected () for vspx_radio_group
{
  declare i, l int;
  i := 0; l := length (self.vc_children);
  while (i < l)
    {
      declare chil any;
      chil := self.vc_children[i];
      if (chil is not null and udt_instance_of (chil, fix_identifier_case ('vspx_radio_button')))
  {
          if ((chil as vspx_field).ufl_value = self.ufl_value)
      (chil as vspx_field).ufl_selected := 1;
    else
      (chil as vspx_field).ufl_selected := 0;
  }
      i := i + 1;
    }
}
;

create method vc_push_in_state (inout stream any, inout state any) for vspx_control
{
  declare nam varchar;
  nam := self.vc_get_name ();
  if (not position (nam, stream))
    stream := vector_concat (stream, vector (nam, null));
  aset (stream, position (nam, stream), case when isblob (state) then blob_to_string (state) else state end);
  return;
}
;

create method vc_push_in_stream (inout stream any, inout state any, inout n int) for vspx_control
{
  declare nam varchar;
  nam := self.vc_get_name ();
  http (serialize (nam), stream);
  http (serialize (case when isblob (state) then blob_to_string (state) else state end), stream);
  n := n + 2;
  return;
}
;

create method vc_get_control_state (in def any) for vspx_control
{
  declare stream, nam any;
  nam := self.vc_get_name ();
  stream := coalesce (self.vc_page.vc_view_state, vector ());
  return get_keyword (nam, stream, def);
}
;

create method vc_set_control_state (inout state any) for vspx_control
{
  declare stream any;
  stream := self.vc_page.vc_view_state;
  self.vc_push_in_state (stream, state);
  self.vc_page.vc_view_state := stream;
}
;

create method vc_view_state (inout stream any, inout n int) for vspx_data_set
{
  declare state, flds any;
  flds :=  vector (serialize(self.ds_last_bookmark), serialize (self.ds_prev_bookmark), self.ds_rows_fetched, self.ds_rowno_edit, self.vc_enabled, self.ds_editable, self.ds_rows_offs);
  self.vc_push_in_stream (stream, flds, n);
  return;
}
;

-- Scrollable, Multi-Row data grid Class
create type vspx_data_grid under vspx_form
as (
    dg_nrows int default -1,    -- how many rows to show on single page
    dg_scrollable int default 0,  -- scroll on form is enabled
    dg_editable int default 1,          -- disable edit/add on whole grid
    dg_row_meta any,      -- metadata
    dg_row_data any,      -- the data for procedure binding
    dg_current_row vspx_row_template,   -- current row template
    dg_rowno_edit int default null, -- last edited row in result set, to re-display the edit box on error
    dg_rows_fetched int default 0,  -- these are to keep state for scrolling
    dg_prev_bookmark any default null,
    dg_last_bookmark any default null
   )  temporary self as ref
  method vc_templates_clean () returns any,
  constructor method vspx_data_grid (name varchar, parent vspx_control),
  overriding method vc_set_view_state (e vspx_event) returns any,
  overriding method vc_view_state (stream any, n int) returns any
;

create type vspx_select_list under vspx_field
as (
     vsl_items any,
     vsl_item_values any,
     vsl_selected_inx any default null,
     vsl_change_script int default 0,
     vsl_list_document any default null,
     vsl_list_match varchar default null,
     vsl_list_key_path varchar default null,
     vsl_list_value_path varchar default null,
     vsl_multiple int default 0
   )
  temporary self as ref
 overriding method vc_render () returns any,
 overriding method vc_view_state (stream any, n int) returns any,
 overriding method vc_set_view_state (e vspx_event) returns any,
 overriding method vc_set_model () returns any,
 overriding method vc_xrender () returns any,
 method vs_set_selected () returns any,
constructor method vspx_select_list (name varchar, parent vspx_control)
;

create type vspx_data_list under vspx_select_list temporary self as ref
constructor method vspx_data_list (name varchar, parent vspx_control)
;


create type vspx_login under vspx_form
as (
    vl_realm varchar,
    vl_mode varchar,
    vl_pwd_get varchar,
    vl_usr_check varchar,
    vl_authenticated int default 0,
    vl_user varchar,
    vl_sid varchar,
    vl_no_login_redirect varchar,
    vl_logout_in_progress int default 0
   )
 temporary self as ref
overriding method vc_view_state (stream any, n int) returns any,
overriding method vc_set_view_state (e vspx_event) returns any,
constructor method vspx_login (name varchar, parent vspx_control)
;

create type vspx_browse_button under vspx_button
as
 (
   vcb_selector varchar,
   vcb_chil_options varchar default '',
   vcb_browser_options varchar default '',
   vcb_fields any,
   vcb_ref_fields any,
   vcb_params any default null, -- additional parameters fields to pass wondow.open(...
   vcb_browser_mode varchar default 'RES', -- COL, RES, STANDALONE
   vcb_list_mode integer default '1', -- 1 full list, 0 short list
   vcb_system varchar default '', -- 'dav', 'file', '' (none)
   vcb_xfer varchar default 'DOM',
   vcb_current integer default 0,
   vcb_filter varchar default '*'
 )
 temporary self as ref
 constructor method vspx_browse_button (name varchar, parent vspx_control),
 overriding method vc_render () returns any
;


create type vspx_tree under vspx_control
as
  (
    vt_current_node int default -1,
    vt_node any default null,
    vt_open_at varchar default null,
    vt_xpath_id varchar default null
  )
temporary self as ref
overriding method vc_view_state (stream any, n int) returns any,
method vc_get_state () returns any,
method vc_open_at (path varchar) returns any,
constructor method vspx_tree (name varchar, parent vspx_control)
;

--#pragma begin base, tree_node
create type vspx_tree_node under vspx_control
as
  (
    tn_tree vspx_tree default null,
    tn_open int default 0,
    tn_value varchar,
    tn_element any default null,
    tn_level int default 0,
    tn_position int default 0,
    tn_is_leaf int default 0
  )
temporary self as ref
method vc_close_all_childs () returns any,
method vc_get_state (stream any) returns any,
constructor method vspx_tree_node (name varchar, parent vspx_control, leaf int, ctr int, lev int)
;
--#pragma end base, tree_node

create type vspx_vscx under vspx_form
self as ref temporary
constructor method vspx_vscx (name varchar, parent vspx_control, uri varchar),
overriding method vc_pre_render (stream any, n int) returns any
;

create method vc_pre_render (inout stream any, inout n int) for vspx_vscx
  {
    declare tmp, ss, icnt any;
    declare page vspx_page;
    declare id varchar;

    id := self.vc_get_name ();

    page := self.vc_children[0];
    ss := string_output ();
    icnt := 0;
    page.vc_pre_render (ss, icnt);
    page.vc_state_deserialize (ss, icnt);

    self.vc_push_in_stream (stream, vspx_state_serialize (vspx_do_compact (page.vc_view_state)), n);

    return;
  }
;

--!AWK PUBLIC
create procedure vspx_state_serialize (inout state any)
{
  return encode_base64 (serialize (state));
  --return encode_base64 (gz_compress (serialize (state)));
}
;

--!AWK PUBLIC
create procedure vspx_state_deserialize (inout state any)
{
  return deserialize (decode_base64 (state));
  --declare ss any;
  --ss := string_output ();
  --gz_uncompress (decode_base64 (state), ss);
  --return deserialize (string_output_string (ss));
}
;

-- this is to instantiate a page class of the control's page,
-- similar logic to the vspx_dispatch, but no call to data-bind, post, render
create constructor method vspx_vscx (in name varchar, in parent vspx_control, in uri varchar)
	for vspx_vscx
  {
    declare h, vx any;
    declare thispage, page vspx_page;
    declare resource_name, vspxm_name, sql_name, signature,
    	vspx_dbname, vspx_user, class_name, full_class_name, q_full_class_name, stat, msg varchar;
    declare unlink int;
    declare path, params, lines, inner_state, enc_inner any;
    declare id varchar;

    uri := WS.WS.EXPAND_URL (http_physical_path (), uri);

    --vspx_dbname := fix_identifier_case (dbname());
    --vspx_user := fix_identifier_case (user);
    vspx_get_user_info (vspx_dbname, vspx_user);
    resource_name := uri;

    class_name := vspx_get_class_name (resource_name);
    full_class_name := concat (vspx_dbname, '.', vspx_user, '.', class_name);
    q_full_class_name := concat ('"',vspx_dbname, '"."', vspx_user, '".', class_name);
    signature := vspx_get_signature (vspx_dbname, vspx_user, resource_name);

    if (not udt_is_available (full_class_name) or (registry_get (resource_name) <> signature))
      {
	stat := '00000'; msg := '';
	exec (concat ('drop type ', q_full_class_name), stat, msg);
	unlink := vspx_make_temp_names (resource_name, vspxm_name, sql_name);
	vspx_make_sql (vspx_dbname, vspx_user, resource_name, vspxm_name, sql_name, class_name);
	vspx_load_sql (vspx_dbname, vspx_user, resource_name, sql_name);
	registry_set (resource_name, signature);
	if (unlink)
	  {
	    file_delete (vspxm_name, 1);
	    file_delete (vspxm_name||'0', 1);
	    file_delete (sql_name, 1);
	  }
	log_enable (0, 1);
	exec (sprintf ('grant execute on %s to "%s"', q_full_class_name, vspx_user));
	commit work;
	log_enable (1, 1);
      }

    self.vc_init (name, parent);
    self.vc_have_state := 1;
    id := self.vc_get_name ();

    thispage := parent.vc_page;
    path := thispage.vc_event.ve_path;
    params := thispage.vc_event.ve_params;
    lines := thispage.vc_event.ve_lines;
    inner_state := get_keyword (id, thispage.vc_view_state);
    enc_inner := vector (concat (class_name, '_view_state'), inner_state);
    params := vector_concat (params, enc_inner);

    page := __udt_instantiate_class (full_class_name, 0);
    page.vc_inside_form := 1;
    -- set unique id for vscx control; when it's inside repeating group use
    -- the current id otherwise use global counter
    if (self.vc_inx is null)
      {
        thispage.vc_current_id := thispage.vc_current_id + 1;
        page.vc_inx := thispage.vc_current_id;
      }
    else
      page.vc_inx := self.vc_inx;
    page.vc_parent := self;
    page.vc_instance_name := id;

    self.vc_children := vector (page);
    vx := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
    if (vx)
      {
	call (vx) (parent.vc_page, self, parent);
      }

    h := udt_implements_method (page, class_name, 1);
    call (h) (page, path, params, lines);
  }
;


-- Constructor methods
create constructor method vspx_tree_node (in name varchar, inout parent vspx_control, in leaf int, in ctr int, in lev int) for vspx_tree_node
{
  --self.vc_instance_name := sprintf ('%s%06d_%06d', name, ctr, lev);
  self.tn_is_leaf := leaf;
  self.tn_level := lev;
  self.tn_position := ctr;
  self.vc_inx := ctr;
  self.vc_level := lev;
  self.vc_init (name, parent);
  self.vc_repeater := self;
  if (parent is not null and udt_instance_of (parent, fix_identifier_case ('vspx_tree')))
    self.tn_tree := parent;
  else if (parent is not null and udt_instance_of (parent, fix_identifier_case ('vspx_tree_node')))
    self.tn_tree := (parent as vspx_tree_node).tn_tree;
}
;


create constructor method vspx_row_template (in name varchar, inout rowset any, inout parent vspx_control, inout ctr int) for vspx_row_template
{
  declare childs any;
  self.vc_inx := ctr;
  self.vc_init (name, parent);
  self.te_ctr := ctr;
  self.te_rowset := rowset;
  --self.vc_instance_name := sprintf ('%s%06d', name, ctr);
  childs := parent.vc_children;
  if (childs is not null)
    childs := vector_concat (childs, vector (self));
  else
    childs := vector (self);
  parent.vc_children := childs;
}
;

create constructor method vspx_row_template_fast (in name varchar, inout rowset any, inout parent vspx_control, inout ctr int, in nth int) for vspx_row_template
{
  declare childs any;
  self.vc_inx := ctr;
  self.vc_init (name, parent);
  self.te_ctr := ctr;
  self.te_rowset := rowset;
}
;

create method te_column_value (in name varchar) for vspx_row_template
{
  declare ds vspx_data_set;
  declare i int;
  ds := self.vc_parent;
  i := ds.ds_column_offset (name);
  if (i >= 0 and i < length (self.te_rowset))
    return self.te_rowset [i];
  else
    return null;
}
;

create constructor method vspx_control (in name varchar, inout parent vspx_control) for vspx_control
{
  declare childs any;
  self.vc_init (name, parent);
}
;

create constructor method vspx_tree (in name varchar, inout parent vspx_control) for vspx_tree
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_radio_group (in name varchar, inout parent vspx_control) for vspx_radio_group
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_isql (in name varchar, inout parent vspx_control) for vspx_isql
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
  --self.isql_active := 'init';
}
;

create method isql_exec () for vspx_isql
{
  declare err_sqlstate, commit_err_sqlstate, err_msg, commit_err_msg varchar;
  declare m_dta, result any;
  declare _maxres, stmt_text varchar;
  declare parsed_text any;

  self.vc_error_message := vector();
  self.isql_mtd := vector();
  self.isql_res := vector();

  _maxres := self.isql_maxrows;
  stmt_text := self.isql_text;

  if( length(stmt_text) = 0 )
    return;

  commit_err_sqlstate := '00000';

  commit work;

whenever sqlstate '*' goto text_split_error;

  parsed_text := sql_split_text (self.isql_text);
  goto text_split_complete;

text_split_error:
  self.vc_error_message := vector_concat( self.vc_error_message, vector(vector(__SQL_STATE, __SQL_MESSAGE)) );
  self.isql_mtd := vector_concat( self.isql_mtd, vector(0) );
  self.isql_res := vector_concat( self.isql_res, vector(vector()) );
  self.isql_stmts := vector_concat(self.isql_stmts, vector (self.isql_text));
  return;

text_split_complete:
  whenever not found goto run_error;
  whenever sqlstate '*' goto run_error;

  set isolation=self.isql_isolation;

  if (exists (select 1 from db.dba.sys_users where u_name = self.isql_user and u_sql_enable = 1))
    {
      if (exists( select 1 from db.dba.sys_users where U_NAME = connection_get ('vspx_user') and
	    (U_ID = 0 or U_GROUP = 0) ) )
        __set_user_id (self.isql_user, 1);
      else
        __set_user_id (self.isql_user, 1, coalesce (self.isql_password, ''));
      --dbg_obj_print('setuid', self.isql_user, user );
    }
  else
    {
      __set_user_id (connection_get ('vspx_user'), 1);
      --dbg_obj_print('setuid', connection_get ('vspx_user'), user );
    }

  declare i int;
  i := 0;
  while( i < length(parsed_text) ) {
    --aset(parsed_text, i, trim(parsed_text[i], '\r\n ') );
    err_sqlstate := '00000'; err_msg := '';
   -- dbg_obj_print('self.isql_explain',self.isql_explain);
    result := null;
    if( self.isql_explain )
      exec ( 'explain(?)', err_sqlstate, err_msg, vector(parsed_text[i]), _maxres, m_dta, result);
    else
    {
      commit work;
      m_dta := 0;
      if (self.isql_chunked)
        {
          exec_metadata (parsed_text[i], err_sqlstate, err_msg, m_dta);
	  if (err_sqlstate = '00000' and
	    regexp_match ('^([[:space:]]*)[Uu][Ss][Ee]([[:space:]]*)([[:alnum:]]*)', parsed_text[i]) is not null)
	    exec (parsed_text[i], err_sqlstate, err_msg);
	}
      else
        exec ( parsed_text[i], err_sqlstate, err_msg, vector(), _maxres, m_dta, result);
    }
    if( err_sqlstate <> '00000' )
    {
      err_msg := err_msg || '\n' || parsed_text[i];
      rollback work;
    }
    self.vc_error_message := vector_concat( self.vc_error_message, vector(vector(err_sqlstate,err_msg)) );
    self.isql_mtd := vector_concat( self.isql_mtd, vector(m_dta) );
    self.isql_res := vector_concat( self.isql_res, vector(result) );
    -- Once sql_split_text is fixed we should see how will this change.
    if (self.isql_chunked)
      {
	declare stmt any;
	stmt := parsed_text[i];
	if (self.isql_explain)
	  {
	    stmt := concat ('explain(', WS.WS.STR_SQL_APOS(stmt), ')');
	  }
        self.isql_stmts := vector_concat(self.isql_stmts, vector (stmt));
      }
    i := i+1;
  }
  exec ('commit work', commit_err_sqlstate, commit_err_msg);
  set isolation='committed';
  return;

run_error:
    self.vc_error_message := vector_concat( self.vc_error_message, vector(vector(__sql_state,__sql_message)) );
    self.isql_mtd := vector_concat( self.isql_mtd, vector(0) );
    self.isql_res := vector_concat( self.isql_res, vector(vector()) );
    self.isql_stmts := vector_concat(self.isql_stmts, vector (self.isql_text));
    set isolation='committed';
    rollback work;
    return;
}
;

create procedure
vspx_unqualify (in name varchar)
{
  declare name_str varchar;

  if (not isstring (name))
    {
      name_str := cast (name as varchar);
    }
  else
    {
      name_str := name;
    }
  return (subseq (name_str, coalesce (strrchr (name_str, '.') + 1, 0)));
}
;

create procedure
vspx_result_tbl_hdrs (in m_dta any)
{

  declare m_dta_col varchar;
  declare inx, n_cols integer;
  declare col_names varchar;

  if (not isarray (m_dta[0]))
    return;

  n_cols := length (m_dta[0]);

  while (inx < n_cols)
    {
      m_dta_col := m_dta[0][inx];

      http ('<td class="resheader"><SPAN class="rescolname">');
      col_names := m_dta_col[0];

      http_value (vspx_unqualify (col_names));

      http ('</span><br/><span class="rescoltype">');
      http (dv_type_title (m_dta_col[1]));
      http ('</span></td>\n');

      inx := inx + 1;
    }
}
;


create procedure
vspx_result_row_render (in result any, in m_dta any, in inx int := 0, in cset varchar := 'UTF-8')
{
  declare jnx integer;
  declare res_row varchar;
  declare res_col varchar;
  declare res_cols, n_cols integer;
  declare res_len integer;
  declare dt_nfo any;
  declare col_type integer;

  n_cols := length (aref (m_dta, 0));
  dt_nfo := aref(m_dta, 0);

      http (sprintf ('<tr class="%s">', case when mod(inx, 2) then 'resrowodd' else 'resroweven' end));

      res_row := result;
      res_cols := length (res_row);

      jnx := 0;


      while (jnx < res_cols)
	{
	  declare exit handler for sqlstate '*'
	    {
	      http ('Can\'t display result');
	      goto next;
	    };
	  http ('<td class="resdata"> &nbsp;');
	  res_col := aref (res_row, jnx);
	  col_type := aref (aref (dt_nfo, jnx), 1);
	  again:
	  if (__tag (res_col) = 193)
	    http_value (concat ('(', vector_print (res_col), ')'));
	  else if (__tag (res_col) = 230 and res_col is not null)
	    {
	      declare ses any;
	      ses := string_output ();
	      http_value (res_col, NULL, ses);
	      http_value (string_output_string (ses));
	    }
	  else if (__tag (res_col) = 246 and res_col is not null)
	    {
	      declare dat any;
	      dat := __rdf_sqlval_of_obj (res_col, 1);
	      res_col := dat;
	      goto again;
	    }
	  else
	    {
	      declare res any; 
	      res := 0;
	      if (__tag (res_col) = 182 and cset is not null)
		res := charset_recode (res_col, cset, '_WIDE_');
              if (res <> 0)
	        res_col := res;		
	      http_value (coalesce (res_col, '<DB NULL>'));
	    }
	  next:
	  http ('</td>');
	  jnx := jnx + 1;
	}
      http ('</tr>\n');
}
;

create constructor method vspx_field_value (in name varchar, inout parent vspx_control) for vspx_field_value
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;


create constructor method vspx_field (in name varchar, inout parent vspx_control) for vspx_field
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;


create constructor method vspx_column (in col varchar, in label varchar, in infmt varchar, in outfmt varchar, inout parent vspx_control) for vspx_column
{
  self.vc_init (parent.vc_name || '_' || col, parent);
  self.ufl_column := col;
  self.ufl_fmt_fn := outfmt;
  self.ufl_cvt_fn := infmt;
  self.ufl_col_label := label;
}
;


create constructor method vspx_calendar (in name varchar, inout parent vspx_control) for vspx_calendar
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create method vc_view_state (inout stream any, inout n int) for vspx_calendar
{
  declare state any;
  self.vc_push_in_stream (stream, self.cal_date, n);
  return;
}
;

create method
vc_get_date_array () for vspx_calendar
{
  declare i, l int;
  declare m, y, w, d int;
  declare dw int;
  declare arr, res any;
  declare dt date;

  dt := self.cal_date;

  arr := vector ('','','','','','','');
  i := 0;
  m := month (dt);
  y := year (dt);

  res := vector ();
  for (i := 1; i < 32; i := i + 1)
    {
      declare tmp date;
      whenever sqlstate '*' goto next;
      tmp := stringdate (sprintf ('%d-%d-%d', y, m, i));
      if (i > 1 and dayofmonth (tmp) = 1)
        goto endd;
      dw := dayofweek(tmp);
      aset (arr, dw - 1, cast (i as varchar));
      if (0 = mod (dw, 7))
        {
          res := vector_concat (res, vector (arr));
          arr := vector ('','','','','','','');
        }
next:;
    }
endd:
  res := vector_concat (res, vector (arr));
  return res;
}
;

create constructor method vspx_update_field (in name varchar, inout parent vspx_control) for vspx_update_field
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_tab (in name varchar, inout parent vspx_control) for vspx_tab
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
  if (h)
    {
      call (h) (parent.vc_page, self, parent);
      return;
    }
}
;

create constructor method vspx_login (in name varchar, inout parent vspx_control) for vspx_login
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
  if (h)
    {
      call (h) (parent.vc_page, self, parent);
      return;
    }
}
;

create constructor method vspx_update_form (in name varchar, inout parent vspx_control) for vspx_update_form
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
  if (h)
    {
      call (h) (parent.vc_page, self, parent);
      return;
    }
}
;

create constructor method vspx_form (in name varchar, inout parent vspx_control) for vspx_form
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
  if (h)
    {
      call (h) (parent.vc_page, self, parent);
      return;
    }
}
;

create constructor method vspx_template (in name varchar, inout parent vspx_control) for vspx_template
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
  if (h)
    {
      call (h) (parent.vc_page, self, parent);
      return;
    }
}
;

create constructor method vspx_text (in name varchar, inout parent vspx_control) for vspx_text
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_textarea (in name varchar, inout parent vspx_control) for vspx_textarea
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;


create constructor method vspx_button (in name varchar, inout parent vspx_control) for vspx_button
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_radio_button (in name varchar, inout parent vspx_control) for vspx_radio_button
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;


create constructor method vspx_submit (in name varchar, inout parent vspx_control) for vspx_submit
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_delete_button (in name varchar, in parent vspx_control) for vspx_delete_button
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_return_button (in name varchar, in parent vspx_control) for vspx_return_button
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;



create constructor method vspx_browse_button (in name varchar, in parent vspx_control) for vspx_browse_button
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;


create constructor method vspx_data_grid (in name varchar, inout parent vspx_control) for vspx_data_grid
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;


create constructor method vspx_data_set (in name varchar, inout parent vspx_control) for vspx_data_set
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_data_source (in name varchar, inout parent vspx_control) for vspx_data_source
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;


create constructor method vspx_label (in name varchar, inout parent vspx_control) for vspx_label
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_check_box (in name varchar, inout parent vspx_control) for vspx_check_box
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_url (in name varchar, inout parent vspx_control) for vspx_url
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_select_list (in name varchar, inout parent vspx_control) for vspx_select_list
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_data_list (in name varchar, inout parent vspx_control) for vspx_data_list
{
  declare h any;
  self.vc_init (name, parent);
  self.vc_have_state := 1;
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_logout_button (in name varchar, inout parent vspx_control) for vspx_logout_button
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_login_form (in name varchar, inout parent vspx_control) for vspx_login_form
{
  declare h any;
  self.vc_init (name, parent);
  h := udt_implements_method (parent.vc_page, fix_identifier_case (concat ('vc_init_', name)));
   if (h)
     {
       call (h) (parent.vc_page, self, parent);
       return;
     }
}
;

create constructor method vspx_login_form (in name varchar, in title varchar, in user_title varchar, in password_title varchar, in submit_tile varchar, in login vspx_login) for vspx_login_form
{

   declare usr, pwd vspx_text;
   declare loginb vspx_button;

   self.vc_init (name, login);

   self.vlf_title := title;
   self.vlf_user_title := user_title;
   self.vlf_password_title := password_title;
   self.vlf_submit_title := submit_tile;
   self.vlf_login := login;

   self.vc_inside_form := 1;

   usr := vspx_text ('username', self);
   pwd := vspx_text ('password', self);
   pwd.tf_style := 1;
   loginb := vspx_button ('login', self);
   loginb.ufl_value := submit_tile;

   self.vc_children := vector (usr, pwd, loginb);
}
;

create method prologue_render (in sid varchar, in realm varchar, in nonce varchar) for vspx_form
  {
    if (self.vc_page.vc_browser_caps and self.uf_xmodel is not null)
      {
	declare model, submit, sch any;
	declare inst, fmodel any;
	declare xslt_text varchar;

	model := self.uf_xmodel;
	fmodel := self.uf_xsubmit;
	sch := self.uf_xschema;

	xte_nodebld_init (inst);
	xte_nodebld_acc (model, xte_node (xte_head ('sid'), coalesce (sid, '')));
	xte_nodebld_acc (model, xte_node (xte_head ('realm'), coalesce (realm, '')));
	xte_nodebld_acc (model, xte_node (xte_head (sprintf ('%s_view_state', self.vc_page.vc_name)),
		vspx_state_serialize (self.vc_page.vc_view_state)));
	xte_nodebld_acc (model, xte_node (xte_head ('event__target'), ''));
	xte_nodebld_final (model, xte_head ('post', 'xmlns', 'http://www.openlinksw.com/vspx/xforms/'));
	if (sch is not null)
	  {
	    xte_nodebld_final (sch, xte_head ('schema', 'xmlns', 'http://www.w3.org/2001/XMLSchema',
	    'targetNamespace', 'http://www.openlinksw.com/virtuoso/vspx/xforms/types'
	    --, 'id', self.vc_get_name () || '_sch'
	    ));
	    xte_nodebld_acc (fmodel, sch);
	  }

	xte_nodebld_acc (inst, model);

	xte_nodebld_final (inst, xte_head ('instance'));
	xte_nodebld_acc (fmodel, inst);

	if (0 and sch is not null)
	  {
	    xte_nodebld_final (fmodel,
	    xte_head ('model', 'xmlns', 'http://www.w3.org/2002/xforms', 'id',
	    	self.vc_get_name (), 'schema', '#' || self.vc_get_name () || '_sch'));
	  }
	else
	  {
	    xte_nodebld_final (fmodel,
	    xte_head ('model', 'xmlns', 'http://www.w3.org/2002/xforms', 'id', self.vc_get_name ()));
	  }

	fmodel := xte_expand_xmlns (fmodel);
	fmodel := xml_tree_doc (fmodel);

	-- add the xforms namespace
	-- XXX: there should be a function to add ns prefixes to the tree
        if (not xslt_is_sheet ('__xforms_model'))
	  {
	    xslt_text :=
	    '<?xml version=''1.0''?>
	    <xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
	    xmlns:xforms="http://www.w3.org/2002/xforms"
	    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
	    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	    xmlns:vxf="http://www.openlinksw.com/vspx/xforms/"
	    xmlns:vxt="http://www.openlinksw.com/virtuoso/vspx/xforms/types"
	    >
	    <xsl:output method="xml" omit-xml-declaration="yes" indent="yes" />
	    <xsl:template match="/">
	      <xsl:apply-templates />
	    </xsl:template>
	    <xsl:template match="@*|node()" priority="0">
	      <xsl:copy>
	      <xsl:apply-templates />
	      </xsl:copy>
	    </xsl:template>
	    </xsl:stylesheet>';
            xslt_sheet ('__xforms_model', xtree_doc (xslt_text, 0));
	  }

        fmodel := xslt ('__xforms_model', fmodel);

	--xml_tree_doc_set_ns_output (fmodel, 1);

	http_value (fmodel);
      }

    if (self.uf_action = '')
      self.uf_action := http_path ();
    if (not self.vc_inside_form)
      {
	if (self.vc_page.vc_browser_caps)
	  {
	    return;
	  }
	http (sprintf ('<form name="%s" method="%s" action="%s"',
	self.vc_name, self.uf_method, self.uf_action));
	vspx_print_html_attrs (self); http ('>\n');

	http (sprintf ('<input type="hidden" name="%s_view_state" value="%s" />\n',
	self.vc_page.vc_name, vspx_state_serialize (self.vc_page.vc_view_state)));
        if (self.vc_page.vc_authentication_mode)
	  {
	    if (length (sid) > 0)
	      {
	        http (sprintf ('<input type="hidden" name="sid" value="%s" />\n', sid));
	        http (sprintf ('<input type="hidden" name="realm" value="%s" />\n', realm));
	      }
	    else
	      {
	        http (sprintf ('<input type="hidden" name="nonce" value="%s" />\n', nonce));
	      }
	  }
	http ('<input type="hidden" name="__submit_func" value="" />\n');
	http ('<input type="hidden" name="__event_target" value="" />\n');
	http ('<input type="hidden" name="__event_initiator" value="" />\n');
      }
  }
;

create procedure vspx_xtext_node (in val any)
{
  if (val is null)
    return '';
  else if (isstring (val))
    return val;
  else
    return cast (val as varchar);
}
;

create method epilogue_render () for vspx_form
  {
    if (self.vc_page.vc_browser_caps)
      return;
    if (not self.vc_inside_form)
      http ('</form>\n');
  }
;

create method vc_set_model () for vspx_form
  {
    declare model, submit any;
    if (self.uf_action = '')
      self.uf_action := http_path ();
    xte_nodebld_init (model);
    xte_nodebld_init (submit);
    self.uf_xmodel := model;
    self.uf_xsubmit := submit;
    return;
  }
;

create method vc_set_model () for vspx_text
  {
    if (self.vc_top_form is null or self.vc_top_form.uf_xmodel is null)
      return;

    declare model, val, sch any;

    model := self.vc_top_form.uf_xmodel;

    val := self.ufl_value;
    if (val is null)
      val := self.vc_get_control_state (null);
    if (val is null)
      val := self.tf_default;

    if (length (self.ufl_validators))
      {
	declare nam varchar;
	nam :=  self.vc_name || '_t';
	sch := self.vc_top_form.uf_xschema;
	self.ufl_schema (sch, nam);
	self.vc_top_form.uf_xschema := sch;
	xte_nodebld_acc (model,
	xte_node (xte_head (self.vc_get_name (), 'http://www.w3.org/2001/XMLSchema-instance:type',
	'http://www.openlinksw.com/virtuoso/vspx/xforms/types:' || nam), vspx_xtext_node(val)));
      }
    else
      {
	xte_nodebld_acc (model,
	xte_node (xte_head (self.vc_get_name ()), vspx_xtext_node (val)));
      }

    self.vc_top_form.uf_xmodel := model;

    return;
  }
;


create method vc_set_model () for vspx_select_list
  {
    if (self.vc_top_form is null or self.vc_top_form.uf_xmodel is null)
      return;

    declare model, val any;
    model := self.vc_top_form.uf_xmodel;

    if (not self.vsl_multiple)
      val := self.ufl_value;
    else
      {
	declare i, l int;
	if (isarray (self.ufl_value))
          {
	    i := 0; l := length (self.ufl_value);
	    val := '';
	    while (i < l)
	      {
		val := val || self.ufl_value[i] || ' ';
		i := i + 1;
	      }
	  }
	else
	  {
	    val := '';
	  }
      }

    xte_nodebld_acc (model,
    xte_node (xte_head (self.vc_get_name ()), vspx_xtext_node (val))
    );

    self.vc_top_form.uf_xmodel := model;

    return;
  }
;

create method vc_set_model () for vspx_check_box
  {
    if (self.vc_top_form is null or self.vc_top_form.uf_xmodel is null)
      return;

    declare model any;
    model := self.vc_top_form.uf_xmodel;

    xte_nodebld_acc (model,
    xte_node (xte_head (self.vc_get_name (), 'http://www.w3.org/2001/XMLSchema-instance:type',
    	'http://www.w3.org/2001/XMLSchema:boolean'), vspx_xtext_node (self.ufl_value))
    );

    self.vc_top_form.uf_xmodel := model;

    return;
  }
;


create method vc_set_model () for vspx_radio_button
  {
    if (self.vc_top_form is null or self.vc_top_form.uf_xmodel is null)
      return;

    declare model any;
    model := self.vc_top_form.uf_xmodel;

    xte_nodebld_acc (model,
    xte_node (xte_head (self.vc_get_name ()), vspx_xtext_node (self.ufl_value))
    );

    self.vc_top_form.uf_xmodel := model;

    return;
  }
;


create method vc_set_model () for vspx_radio_group
  {
    if (self.vc_top_form is null or self.vc_top_form.uf_xmodel is null)
      return;

    declare model any;
    model := self.vc_top_form.uf_xmodel;

    xte_nodebld_acc (model,
    xte_node (xte_head (self.vc_get_name ()), vspx_xtext_node (self.ufl_value))
    );

    self.vc_top_form.uf_xmodel := model;

    return;
  }
;


create method vc_set_model () for vspx_button
  {
    if (self.vc_top_form is null or self.vc_top_form.uf_xsubmit is null)
      return;

    declare submit any;

    submit := self.vc_top_form.uf_xsubmit;

    xte_nodebld_acc (submit,
    xte_node (xte_head ('submission', 'id', self.vc_get_name (),
    		'action', self.vc_top_form.uf_action, 'method', self.vc_top_form.uf_method,
			'mediatype', 'application/xml'))
    );

    self.vc_top_form.uf_xsubmit := submit;

    return;
  }
;

-- Methods
create method vc_render () for vspx_label
{
  if (not self.vc_enabled)
    return;
  if (self.ufl_value is not null)
    http (sprintf (self.vl_format, self.ufl_value));
  else if (self.ufl_null_value is not null)
    http (self.ufl_null_value);
  else
    http (sprintf ('%s', null));
}
;

create method vs_set_selected () for vspx_select_list
{
  declare val, ival any;

  val := self.ufl_value;
  ival := self.vsl_item_values;

  if (self.vsl_multiple and not isstring (val) and isarray (val))
    {
      declare i, l int;
      declare sel any;
      i := 0; l := length (ival);
      sel := make_array (l, 'any');
      while (i < l)
	{
	  if (position (ival[i], val))
	    sel[i] := 1;
          else
	    sel[i] := 0;
	  i := i + 1;
	}
      self.vsl_selected_inx := sel;
    }
  else
    {
      self.vsl_selected_inx := position (cast (self.ufl_value as varchar), self.vsl_item_values) - 1;
    }
}
;

-- printing of the vspx_control attributes

--!AWK PUBLIC
create procedure
vspx_print_html_attrs (inout control vspx_control)
{
  declare i, l int;
  i := 0; l := length (control.vc_attributes);
  -- render the attributes
  while (i < l)
    {
      declare attr vspx_attribute;
      attr := control.vc_attributes[i];
      if (attr is not null)
    {
      attr.vc_render ();
        }
      i := i + 1;
    }
}
;

create method vc_render () for vspx_url
{
  declare url varchar;
  declare uinfo any;
  if (not self.vc_enabled)
    return;
  uinfo := WS.WS.PARSE_URI (self.vu_url);
  url := self.vu_url;

   -- if it's local reference and we have sid
  if ((uinfo[0] = '' or self.vu_is_local) and self.vu_l_pars <> '')
    {
      if (uinfo[4] = '')
        url := vspx_uri_add_parameters (self.vu_url, self.vu_l_pars);
      else
        url := vspx_uri_add_parameters (self.vu_url, self.vu_l_pars);
    }
  http (sprintf ('<a href="%V"', case when self.ufl_active > 0 then url else 'javascript:void(0)' end));
  vspx_print_html_attrs (self);
  http('>');
  if (230 = __tag (self.ufl_value))
    http (sprintf (self.vu_format, cast(self.ufl_value as varchar)));
  else
    http (sprintf (self.vu_format, self.ufl_value));
  http('</a>');
}
;

create method vc_render () for vspx_check_box
{
  if (not self.vc_enabled)
    return;
  if (self.ufl_is_boolean)
    self.vc_get_selected_from_value();
  http (sprintf ('<input type="checkbox" name="%s%s" value="%s" %s %s',
  case self.ufl_group when '' then self.vc_get_name () else self.ufl_group end,
  self.ufl_name_suffix,
  case self.ufl_is_boolean when 0 then cast(self.ufl_value as varchar) else '1' end,
  case self.ufl_selected when 1 then 'checked="checked"' else '' end,
  case self.ufl_client_validate when 0 then '' else ' onchange="javascript: vv_validate_' || self.vc_name || '(this)"' end));
  if (self.ufl_auto_submit) http (' onclick="doAutoSubmit (this.form, this)"');
  vspx_print_html_attrs (self);
  http ('/>');
}
;

create method vc_view_state (inout stream any, inout n int) for vspx_check_box
{
  if (self.ufl_is_boolean)
    self.vc_get_selected_from_value ();
  self.vc_push_in_stream (stream, self.ufl_selected, n);
  return;
}
;

create method vc_view_state (inout stream any, inout n int) for vspx_radio_button
{
  self.vc_push_in_stream (stream, self.ufl_selected, n);
  return;
}
;


create method vc_set_view_state (inout e vspx_event) for vspx_check_box
{
  if (not e.ve_is_post or not position (self.vc_get_name(), self.vc_page.vc_view_state))
    {
      return;
    }
  self.ufl_selected := self.vc_get_control_state (self.ufl_selected);
  if (self.ufl_is_boolean)
    self.ufl_value := case self.ufl_selected when 0 then self.ufl_false_value else self.ufl_true_value end;
  return;
}
;

create method vc_set_view_state (inout e vspx_event) for vspx_radio_button
{
  if (not e.ve_is_post or not position (self.vc_get_name(), self.vc_page.vc_view_state))
    {
      return;
    }
  self.ufl_selected := self.vc_get_control_state (self.ufl_selected);
  return;
}
;

create method vc_view_state (inout stream any, inout n int) for vspx_text
{
  declare state any;
  self.vc_push_in_stream (stream, self.ufl_value, n);
  return;
}
;


create method vc_set_view_state (inout e vspx_event) for vspx_text
{
  if (not e.ve_is_post or not position (self.vc_get_name(), self.vc_page.vc_view_state)
       -- XXX: vc_set_view_state is before initiator knowing or self.vc_parent.vc_focus
     )
    {
      return;
    }
  declare vst any;
  vst := self.vc_get_control_state (null);
  if (vst is not null)
    self.ufl_value := vst;
  return;
}
;

create method vc_set_view_state (inout e vspx_event) for vspx_data_grid
{
  declare state any;
  if (not e.ve_is_post)
    return;

  state := self.vc_get_control_state (null);
  if (isarray (state))
    {
      self.dg_rows_fetched  := state[2];
      self.dg_last_bookmark := deserialize(state[0]);
      self.dg_prev_bookmark := deserialize(state[1]);
      self.dg_rowno_edit    := state[3];
      self.vc_enabled       := state[4];
      self.dg_editable      := state[5];
    }
}
;

create method vc_set_view_state (inout e vspx_event) for vspx_data_set
{
  declare state any;
  if (not e.ve_is_post)
    return;
  state := self.vc_get_control_state (null);
  if (isarray (state))
    {
      self.ds_rows_fetched := state[2];
      self.ds_last_bookmark := deserialize(state[0]);
      self.ds_prev_bookmark := deserialize(state[1]);
      self.ds_rowno_edit := state[3];
      self.vc_enabled := state[4];
      self.ds_editable := state[5];
      self.ds_rows_offs := state[6];
    }
}
;

create method vc_set_view_state (inout e vspx_event) for vspx_update_form
{
  if (not length (self.uf_keys))
    {
      declare keys any;
      keys := self.vc_get_control_state (null);
      self.uf_keys := keys;
    }
}
;

create method vc_set_view_state (inout e vspx_event) for vspx_select_list
{
   if (e.ve_is_post and self.vc_page.vc_view_state is not null)
     {
       self.ufl_value := self.vc_get_control_state (null);
     }
}
;

create method vc_set_view_state (inout e vspx_event) for vspx_login
{
  if (e.ve_is_post and self.vc_page.vc_view_state is not null)
    {
       declare state any;
       state := self.vc_get_control_state (null);
       if (state is not null)
         {
           self.vl_logout_in_progress := get_keyword ('vl_logout_in_progress', state, 0);
           if (self.vl_mode in ('url', 'cookie'))
             self.vl_authenticated := get_keyword ('vl_authenticated', state, 0);
         }
     }
}
;

create method vc_set_view_state (inout e vspx_event) for vspx_calendar
{
  if (e.ve_is_post and self.vc_page.vc_view_state is not null)
    {
      self.cal_date := self.vc_get_control_state (null);
    }
}
;

create method vc_set_view_state (inout e vspx_event) for vspx_tab
{
  if (e.ve_is_post and self.vc_page.vc_view_state is not null)
    {
      declare state any;
      state := self.vc_get_control_state (null);
      if (state is not null)
        self.tb_active := self.vc_find_control (state);
    }
}
;

create function XMLS_VALUE_OF_SUBTREE (in _ent any, in _path varchar, in _params any, in _place varchar) returns any
{
--  dbg_obj_print('XMLS_VALUE_OF_SUBTREE',_ent,_path,_place);
  if (not isentity (_ent))
    return _ent;
  if (_path is not null)
    {
      _ent := xquery_eval (_path, _ent, 1, _params);
      if (_ent is null)
	return null;
    }
  if (_place is not null)
    {
      if (not isentity (_ent))
	signal ('22023', sprintf ('Unable to apply place=''%s'' to a non-XML value', _place));
      if (_place = 'text()')
        {
          if (xpath_eval ('[xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"] @xsi:nil[.="1" or .="true"]', _ent) is not null)
	    return null;
	  if (isentity (_ent))
            return cast (_ent as varchar);
          return _ent;
        }
      if (left (_place, 1) = '@')
        return xpath_eval (_place, _ent);
      if (_place = '.')
        return _ent;
      signal ('22023', sprintf ('Unsupported value ''%s'' of place argument', _place));
    }
  return cast (_ent as varchar);
}
;

create method vc_get_from_element () for vspx_field_value
{
  declare _ent any;
  _ent := self.ufl_element_value;
  if (not isentity (_ent))
    return _ent;
  if (self.ufl_element_path is not null)
    {
--dbg_obj_print('xquery_eval:', self.ufl_element_path, _ent, self.ufl_element_params);
      _ent := xquery_eval (self.ufl_element_path, _ent, 1, self.ufl_element_params);
      if (_ent is null)
	return null;
--dbg_obj_print(_ent);
    }
  if (self.ufl_element_place is not null)
    {
      if (not isentity (_ent))
	signal ('22023', sprintf ('Unable to apply element-place=''%s'' in VSPX control ''%s'' to a non-entity value', self.ufl_element_place, self.vc_name));
      if (self.ufl_element_place = 'text()')
        {
          if (xpath_eval ('[xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"] @xsi:nil[.="1" or .="true"]', _ent) is not null)
	    return null;
	  if (isentity (_ent))
            return cast (_ent as varchar);
          return _ent;
        }
      if (left (self.ufl_element_place, 1) = '@')
        return xpath_eval (self.ufl_element_place, _ent);
      if (self.ufl_element_place = '.')
        return _ent;
      signal ('22023', sprintf ('Unsupported value ''%s'' of element-place attribute of VSPX control ''%s''', self.ufl_element_place, self.vc_name));
    }
--dbg_obj_print('_ent without element-place:', _ent, cast (_ent as varchar));
  return cast (_ent as varchar);
}
;

create method vc_put_to_element (inout _val any) for vspx_field_value
{
  declare _ent any;
  declare _path_used integer;
  _ent := self.ufl_element_value;
  if (not isentity (_ent))
    return;
  if (self.ufl_element_update_path is not null)
    {
      _ent := xquery_eval (self.ufl_element_update_path, _ent, 1, self.ufl_element_update_params);
      if (_ent is null)
	return;
      _path_used := 1;
    }
  else if (self.ufl_element_path is not null)
    {
      _ent := xquery_eval (self.ufl_element_path, _ent, 1, self.ufl_element_params);
      if (_ent is null)
	return;
      _path_used := 1;
    }
  else
    _path_used := 0;
  if (self.ufl_element_place is null or self.ufl_element_place = '.')
    {
      XMLReplace (_ent, _ent, self.ufl_value);
      goto ent_is_set;
    }
  if (not isentity (_ent))
    signal ('22023', sprintf ('Unable to apply element-place=''%s'' in VSPX control ''%s'' to a non-entity value', self.ufl_element_place, self.vc_name));
  if (self.ufl_element_place = 'text()')
    {
      declare _chld_no integer;
      _chld_no := xpath_eval ('count (node())', _ent);
      if (_chld_no > 1)
        signal ('22023', sprintf ('Unable to apply element-place=''%s'' in VSPX control ''%s'' to an value that have more than one child', self.ufl_element_place, self.vc_name));
      if (_val is null)
        {
	  XMLAddAttribute (_ent, 2, 'http://www.w3.org/2001/XMLSchema-instance:nil', '1');
	  goto ent_is_set;
	  if (_chld_no)
	    XMLReplace (_ent, xpath_eval ('node()', _ent), null);
	}
      else
        {
	  declare _xsinil any;
	  _xsinil := xpath_eval ('[xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"] @xsi:nil', _ent);
	  if (_xsinil is not null)
            XMLReplace (_ent, _xsinil, null);
	  if (_chld_no)
	    XMLReplace (_ent, xpath_eval ('node()', _ent), cast (_val as varchar));
	  else
	    XMLAppendChildren (_ent, cast (_val as varchar));
          goto ent_is_set;
        }
    }
  if (left (self.ufl_element_place, 1) = '@')
    {
      if (_val is null)
        XMLReplace (_ent, xquery_eval (self.ufl_element_place, _ent), null);
      else
        XMLAddAttribute (_ent, 2, subseq (self.ufl_element_place, 1), cast (_val as varchar));
      goto ent_is_set;
    }
  signal ('22023', sprintf ('Unsupported value ''%s'' of element-place attribute of VSPX control ''%s''', self.ufl_element_place, self.vc_name));
ent_is_set:
  if (not _path_used)
    self.ufl_element_value := _ent;
}
;

create method vc_get_value_from_element () for vspx_field_value
{
  self.ufl_value := self.vc_get_from_element();
}
;

create method vc_put_value_to_element () for vspx_field_value
{
  self.vc_put_to_element (self.ufl_value);
}
;

create method vc_get_selected_from_value () for vspx_field_value
{
  declare _val varchar;
  if ((self.ufl_value is null and self.ufl_true_value is null) or
    self.ufl_value is not null and self.ufl_true_value is not null and (self.ufl_true_value = _val) )
    {
      self.ufl_selected := 1;
      return;
    }
  if ((self.ufl_value is null and self.ufl_false_value is null) or
    self.ufl_value is not null and self.ufl_false_value is not null and (self.ufl_false_value = _val) )
    {
      self.ufl_selected := 0;
      return;
    }
  if (self.ufl_value is null)
    {
      self.ufl_selected := 0;
      return;
    }
  _val := cast (self.ufl_value as varchar);
  if (_val <> 'false' and _val <> '0' and _val <> '')
    {
      self.ufl_selected := 1;
      return;
    }
}
;

create method vc_validate() for vspx_field
{
  declare i, l int;
  i := 0;
  l := length(self.ufl_validators);
  while(i < l) {
    declare vldt vspx_range_validator;
    vldt := self.ufl_validators[i];
    if(vldt.vv_validate(self)) {
      i := l;
    }
    i := i + 1;
  }
}
;

create method ufl_schema (inout sch any, in name varchar) for vspx_field
  {
    declare i, l int;
    declare vv, typ, xsd_type any;
    declare vld vspx_range_validator;

    vv := self.ufl_validators;
    i := 0; l := length (vv);
    if (sch is null)
      xte_nodebld_init (sch);

    xte_nodebld_init (typ);
    xsd_type := '';

    while (i < l)
      {
	vld := vv[i];
	if (vld is not null)
	  {
	    if (vld.vv_test = 'regexp' and xsd_type <> 'int')
	      {
		xte_nodebld_acc (typ, xte_node (xte_head ('pattern', 'value', vld.vv_expr)));
		xsd_type := 'string';
	      }
	    else if (vld.vv_test = 'length' and xsd_type <> 'int')
	      {
		xte_nodebld_acc (typ, xte_node (xte_head ('minLength', 'value',
			cast (vld.vr_min as varchar))));
		xte_nodebld_acc (typ, xte_node (xte_head ('maxLength', 'value',
			cast (vld.vr_max as varchar))));
		xsd_type := 'string';
	      }
	    else if (vld.vv_test = 'value' and xsd_type <> 'string')
	      {
		xte_nodebld_acc (typ, xte_node (xte_head ('minInclusive', 'value',
			cast (vld.vr_min as varchar))));
		xte_nodebld_acc (typ, xte_node (xte_head ('maxInclusive', 'value',
			cast (vld.vr_max as varchar))));
		xsd_type := 'int';
	      }

	  }
	i := i + 1;
      }
    xsd_type := 'http://www.w3.org/2001/XMLSchema:' || xsd_type;
    xte_nodebld_final (typ, xte_head ('restriction', 'base', xsd_type));
    xte_nodebld_acc (sch, xte_node (xte_head ('simpleType', 'name', name), typ));
  }
;

create method vc_view_state (inout stream any, inout n int) for vspx_tab
{
  if (self.tb_active is not null)
    {
      self.vc_push_in_stream (stream, self.tb_active.vc_name, n);
    }
  return;
}
;


create method vc_get_state (inout stream any) for vspx_tree_node
{
  declare i, l int;
  if (self.tn_open)
    {
      declare csum any;
      declare parent_tree vspx_tree;
      parent_tree := self.tn_tree;
      if (parent_tree.vt_xpath_id is not null)
	csum := xpath_eval (parent_tree.vt_xpath_id, self.tn_element);
      else
        csum := tree_md5(serialize (self.tn_element), 1);
      stream := vector_concat (stream, vector (csum));
    }
  i := 0; l := length (self.vc_children);
  while (i < l)
    {
      declare chil any;
      chil := self.vc_children[i];
      if (chil is not null and udt_instance_of (chil, fix_identifier_case ('vspx_tree_node')))
  {
    declare child_node vspx_tree_node;
          child_node := chil;
          child_node.vc_get_state (stream);
  }
      i := i + 1;
    }
}
;

create method vc_get_state () for vspx_tree
{
  declare state any;
  declare i, l int;
  state := vector ();
  i := 0; l := length (self.vc_children);
  while (i < l)
    {
      declare chil any;
      chil := self.vc_children[i];
      if (chil is not null and udt_instance_of (chil, fix_identifier_case ('vspx_tree_node')))
  {
    declare child_node vspx_tree_node;
          child_node := chil;
          child_node.vc_get_state (state);
  }
      i := i + 1;
    }
  return state;
}
;


create method vc_open_at (in path varchar) for vspx_tree
{
  self.vt_open_at := path;
}
;

create method vc_view_state (inout stream any, inout n int) for vspx_tree
{
  self.vc_push_in_stream (stream, self.vc_get_state (), n);
  return;
}
;

create method vc_close_all_childs () for vspx_tree_node
{
  declare i, l int;
  i := 0; l := length (self.vc_children);
  while (i < l)
    {
      declare chil vspx_tree_node;
      chil := self.vc_children [i];
      if (chil is not null and udt_instance_of (chil, fix_identifier_case ('vspx_tree_node')))
  {
    chil.tn_open := 0;
          chil.vc_close_all_childs ();
  }
      i := i + 1;
    }
  return;
}
;

create method vc_render () for vspx_login_form
{
  if (not self.vc_enabled)
    return;
  if (not self.vc_inside_form)
    http (sprintf ('<form name="%s" method="post">', self.vc_name));

  if (self.vlf_login.vl_mode <> 'digest')
    {
      http('<table border="0"><tr><td>');
      http (self.vlf_user_title);
      http ('</td><td>');
      self.vc_render ('username');
      http ('</td></tr><tr><td>');
      http (self.vlf_password_title);
      http ('</td><td>');
      self.vc_render ('password');
      http ('</td></tr><tr><td colspan="2">');
      self.vc_render ('login');
      http ('</td></tr></table>');
    }
  else
    {
      self.vc_render ('login');
    }
  if (not self.vc_inside_form)
    http ('</form>');
}
;

create method vc_templates_clean () for vspx_data_grid
{
  declare i, l int;
  declare chils any;
  i := 0; l := length (self.vc_children);
  chils := self.vc_children;
  while (i < l)
    {
      declare chil any;
      chil := self.vc_children[i];
      if (chil is not null and udt_instance_of (chil, fix_identifier_case ('vspx_row_template')))
  {
          --chils := vector_concat (chils, vector (chil));
    aset (chils, i, NULL);
  }
      i := i + 1;
    }
  self.vc_children := chils;
}
;

create method vc_find_parent_by_name (inout control vspx_control, in name varchar) for vspx_control
{
  if (control.vc_parent is null)
    return NULL;
  if (control.vc_parent.vc_name = name)
    return control.vc_parent;
  return self.vc_find_parent_by_name (control.vc_parent, name);
}
;

create method vc_find_parent (inout control vspx_control, in udt_name varchar) for vspx_control
{
  if (control.vc_parent is null)
    return NULL;
  if (udt_instance_of (control.vc_parent, fix_identifier_case (udt_name)))
    return control.vc_parent;
  return self.vc_find_parent (control.vc_parent, udt_name);
}
;

create method vc_find_parent_form (inout control vspx_control) for vspx_control
{
  if (control.vc_parent is null)
    return NULL;
  if (udt_instance_of (control.vc_parent, fix_identifier_case ('vspx_form')))
    {
      declare form vspx_form;
      form := control.vc_parent;
      if (not form.vc_inside_form)
        return control.vc_parent;
      else
        return self.vc_find_parent_form (control.vc_parent);
    }
  return self.vc_find_parent_form (control.vc_parent);
}
;

-- TODO: add more validations, REGEXP is most convinient
create method vv_validate (inout control vspx_control) for vspx_range_validator
{
  declare fail int;
  fail := 0;
  if (udt_instance_of (control, fix_identifier_case ('vspx_field'))) {
    declare uf vspx_field;
    declare val any;
    val := control;
    uf := val;
    val := uf.ufl_value;
    if (isstring (val) and val = '' and self.vv_empty_allowed) {
      return 0;
    }
    if (self.vv_test = 'value') {
      declare mini, maxi any;
      mini := self.vr_min;
      maxi := self.vr_max;
      if (isstring (val)) {
        val := atoi (val);
      }
      if (val < mini or val > maxi) {
        fail := 1;
      }
    }
    else if (self.vv_test = 'length') {
      if (length(val) < self.vr_min or length(val) > self.vr_max) {
        fail := 1;
      }
    }
    else if (self.vv_test = 'regexp') {
      val := cast (val as varchar);
      if (regexp_match (self.vv_expr, val) is null) {
        fail := 1;
      }
    }
    if(fail) {
      control.vc_page.vc_is_valid := 0;
      control.vc_error_message := self.vv_message;
      uf.ufl_error := self.vv_message;
      uf.ufl_failed := 1;
    }
  }
  return fail;
}
;


create method vc_find_control (in name varchar) for vspx_control
{
  declare inx, len int;
  inx := 0;
  len := length (self.vc_children);
--ches
--  http(sprintf('[ %s try search %s ...', self.vc_name, name));
  while (inx < len)
    {
      declare child vspx_control;
      child := self.vc_children[inx];
      if (child is not null and child.vc_name = name)
  {
--ches
--          http('OK ]');
          return child;
        }
      inx := inx + 1;
    }
--ches
--  http('FAILED ]');
  return NULL;
}
;

create method vc_find_descendant_control (in name varchar) for vspx_control
{
  declare inx, len int;
  inx := 0;
  len := length (self.vc_children);
  while (inx < len)
    {
      declare child vspx_control;
      child := self.vc_children[inx];
      if (child is not null and (child.vc_name = name or child.vc_instance_name = name))
  {
          return child;
        }
      else if (child is not null)
  {
    declare ret vspx_control;
          ret := child.vc_find_descendant_control (name);
          if (ret is not null)
            return ret;
  }
      inx := inx + 1;
    }
  return NULL;
}
;

create method vc_find_rpt_control (in name varchar) for vspx_control
{
  declare inx, len int;
  if (self.vc_repeater is not null)
    name := concat (self.vc_repeater.vc_instance_name, ':', name);
  inx := 0;
  declare c any;
  c := self.vc_children;
  len := length (c);
  while (inx < len)
    {
      declare child vspx_control;
      child := c[inx];
      if (child is not null and child.vc_instance_name = name)
        {
          return child;
        }
      inx := inx + 1;
    }
  return NULL;
}
;

create method vc_sibling_value (in name varchar) for vspx_control
{
  declare inx, len int;
  inx := 0;
  len := length (self.vc_parent.vc_children);
  while (inx < len)
    {
      declare child vspx_control;
      child := self.vc_parent.vc_children[inx];
      if (child is not null and child.vc_name = name)
        return (child as vspx_field_value).ufl_value;
      inx := inx + 1;
    }
  signal ('VSPX0', sprintf('vspx_control.vc_sibling_value() has failed to find a control ''%s'' that is a sibling of ''%s''', name, self.vc_name));
}
;

create method vc_render (in ct_name varchar) for vspx_control
{
  declare ctrl vspx_control;
  if (not self.vc_enabled)
    return;
  ctrl := self.vc_find_control (ct_name);
--  dbg_obj_print ('vc_render by name');
--  dbg_obj_print (ct_name, ctrl);
  if ((ctrl is not null) and (ctrl.vc_enabled))
    {
      if (ctrl.vc_xrender ())
        return;
      ctrl.vc_render ();
    }
  return;
}
;

create method vc_disable_child (in ct_name varchar) for vspx_control
{
  declare ctrl vspx_control;
  ctrl := self.vc_find_control (ct_name);
  if (ctrl is not null)
    ctrl.vc_enabled := 0;
  return;
}
;

create method vc_enable_child (in ct_name varchar) for vspx_control
{
  declare ctrl vspx_control;
  ctrl := self.vc_find_control (ct_name);
  if (ctrl is not null)
    ctrl.vc_enabled := 1;
  return;
}
;

create method vc_get_focus (inout e vspx_event) for vspx_control
{
  declare inx, len int;
  declare event_target varchar;

  -- If there are no params at all; skip traversal.
  if (not length (e.ve_params) or not e.ve_is_post)
    return 0;

  event_target := get_keyword ('__event_target', e.ve_params, '');
  inx := 0;
  declare c any;
  c := self.vc_children;
  len := length (c);
  while (inx < len) {
    declare child vspx_control;
    declare cname varchar;

    child := c[inx];
    cname := '@@none@@';
    if (child is not null)
      cname := child.vc_get_name();

    if (get_keyword (cname, e.ve_params) is not null or cname = event_target) {

      if(udt_instance_of(child, fix_identifier_case ('vspx_button')) or
         udt_instance_of(child, fix_identifier_case ('vspx_form'))) {

	declare initiator varchar;

	initiator := get_keyword ('__event_initiator', e.ve_params, '');

        e.ve_button := child;
        child.vc_focus := 1;
        self.vc_focus := 1;

	if (initiator <> '' and e.ve_initiator is null)
	  e.ve_initiator := child.vc_find_descendant_control (initiator);

        -- Find parent form fere
        {
          declare parent, parent_form vspx_control;
          parent := child;
          parent_form := NULL;
          while(parent is not null) {
            if(udt_instance_of(parent, fix_identifier_case ('vspx_tree_node'))) {
              goto end_while;
            }
            if(udt_instance_of(parent, fix_identifier_case ('vspx_form')) and not
               udt_instance_of(parent, fix_identifier_case ('vspx_data_set')) and not
               udt_instance_of(parent, fix_identifier_case ('vspx_data_grid')) and not
               udt_instance_of(parent, fix_identifier_case ('vspx_tab')) and not
               udt_instance_of(parent, fix_identifier_case ('vspx_isql'))) {
              parent_form := parent;
              goto end_while;
            }
            parent := parent.vc_parent;
          }
end_while:
          if(parent_form is not NULL) {
            -- Mark all controls inside form as vc_focus := 1
            parent_form.vc_set_childs_focus(1, e);
          }
        }
        return 1;
      }
    }
    if (child is not null and child.vc_get_focus (e)) {
      self.vc_focus := 1;
      return 1;
    }
    inx := inx + 1;
  }
  return 0;
}
;

create method vc_error_summary () for vspx_control
{
  self.vc_error_summary (1);
}
;

create method vc_error_summary (in esc_mode int) for vspx_control
{
  if (self.vc_page.vc_is_valid)
    return 0;
  declare i, l integer;
  if (self.vc_error_message is not null)
    {
      --dbg_obj_princ('Error summary for ', self.vc_name, ' is ', self.vc_error_message);
      if (esc_mode)
      http_value (self.vc_error_message);
      else
	http (self.vc_error_message);
      return 1;
    }
  declare c any;
  c := self.vc_children;
  i := 0; l := length (c);
  while (i < l)
    {
      declare chil vspx_control;
      chil := c[i];
      if (chil is not null and chil.vc_error_summary (esc_mode))
  return 1;
      i := i + 1;
    }
  return 0;
}
;

create method vc_error_summary (in esc_mode int, in pattern varchar) for vspx_control
{
  if (self.vc_page.vc_is_valid)
    return 0;
  declare i, l integer;
  declare cname varchar;
  cname := self.vc_name;
  if (self.vc_error_message is not null and regexp_match (pattern, cname) is not null)
    {
      --dbg_obj_princ('Error summary for ', self.vc_name, ' matching ', pattern, ' is ', self.vc_error_message);
      if (esc_mode)
      http_value (self.vc_error_message);
      else
	http (self.vc_error_message);
      return 1;
    }
  declare c any;
  c := self.vc_children;
  i := 0; l := length (c);
  while (i < l)
    {
      declare chil vspx_control;
      chil := c[i];
      if (chil is not null and chil.vc_error_summary (esc_mode, pattern))
        return 1;
      i := i + 1;
    }
  return 0;
}
;

create method vc_xrender () for vspx_control
  {
    return 0;
  }
;

create method vc_render () for vspx_control
{
  declare h any;
  declare inx, len int;
  if (not self.vc_enabled)
    return;
  h := udt_implements_method (self.vc_page, fix_identifier_case (concat ('vc_render_', self.vc_name)));
  if (h)
    {
      call (h) (self.vc_page, self);
      return;
    }

  if (self.vc_xrender ())
    return;

  declare c any;
  c := self.vc_children;
  inx := 0;
  len := length (c);
  while (inx < len)
    {
      declare chil vspx_control;
      chil := c[inx];
      if (chil is not null)
        chil.vc_render ();
      inx := inx + 1;
    }
}
;

create method vc_pre_render (inout stream any, inout n int) for vspx_control
{
  declare h any;
  declare inx, len int;
  -- call vc_view_state
  --declare stream any;
  if (self.vc_have_state)
    {
      --stream := self.vc_page.vc_view_state;
      self.vc_view_state (stream, n);
      --self.vc_page.vc_view_state := stream;
    }

  if (self.vc_page.vc_browser_caps)
    self.vc_set_model ();

  h := udt_implements_method (self.vc_page, fix_identifier_case (concat ('vc_pre_render_', self.vc_name)));
  if (h <> 0)
    call (h) (self.vc_page, self);

  self.vc_invoke_handlers ('before-render');
  -- common handler for fields
  if (udt_instance_of (self, fix_identifier_case ('vspx_field')))
    {
      declare field vspx_field;
      declare _fld any;
      declare i, l int;
      _fld := self;
      field := _fld;
      if (isstring (field.ufl_fmt_fn) and field.vc_error_message is null)
        {
          field.ufl_value := call (field.ufl_fmt_fn) (field.ufl_value);
        }
    }

  inx := 0;
  declare c any;
  c := self.vc_children;
  len := length (c);
  while (inx < len)
    {
      declare chil vspx_control;
      chil := c[inx];
      if (chil is not null)
        chil.vc_pre_render (stream, n);
      inx := inx + 1;
    }
}
;

create method vc_handle_error (in state any, in message any, inout deadl any) for vspx_control
{
  declare h any;
  h := udt_implements_method (self.vc_page, fix_identifier_case (concat ('vc_error_handler_', self.vc_name)));
  if (self is not null and self.vc_name is not null and h <> 0) {
    declare rc int;
    rc := call (h) (self.vc_page, state, message, deadl);
    return rc;
  }
  else {
    if(state = 100 and message is null) message := 'Not Found.';
    if (isinteger (state))
    http_value(sprintf('STATE : %05d  MESSAGE :%s', state, message));
    else
    http_value(sprintf('STATE : %s  MESSAGE :%s', state, message));
  }
  return 0;
}
;

create method vc_data_bind (inout e vspx_event) for vspx_control
{
  declare h any;
  declare inx, len int;
  --dbg_obj_print ('vc_data_bind start: ', self.vc_name, self.vc_enabled);
  -- bind the attributes of control; call inside vc_data_bind_xx
  --h := udt_implements_method (self.vc_page,
  --    fix_identifier_case (concat ('vc_data_bind_attrs_', self.vc_name)));
  --if (h <> 0)
  --  {
  --    call (h) (self.vc_page, self, e);
  --  }

  -- bind the control itself, early hook is there
  h := udt_implements_method (self.vc_page, fix_identifier_case (concat ('vc_data_bind_', self.vc_name)));
  if (h <> 0)
    {
      declare disabled int;
      --dbg_obj_print ('vc_data_bind_x called start: ', self.vc_name);
      disabled := call (h) (self.vc_page, self, e);
      if (disabled = 1)
        return;
    }
  if (not self.vc_enabled)
    return;
  self.vc_invoke_handlers ('before-data-bind');
  -- common handler for fields
  if (udt_instance_of (self, fix_identifier_case ('vspx_field')))
    {
      declare field vspx_field;
      declare _fld any;
      _fld := self;
      field := _fld;
      if (field.ufl_value is null and field.ufl_null_value is not null)
	field.ufl_value := field.ufl_null_value;
      if (isstring (field.ufl_cvt_fn) and field.vc_error_message is null)
        {
          field.ufl_value := call (field.ufl_cvt_fn) (field.ufl_value);
        }
    }
  -- bind the children controls
  inx := 0;
  declare c any;
  c := self.vc_children;
  len := length (c);
  while (inx < len)
    {
      declare chil vspx_control;
      chil := c[inx];
      if (chil is not null)
        {
          --dbg_obj_print ('vc_data_bind called for : ', chil.vc_name);
          chil.vc_data_bind (e);
          --dbg_obj_print ('vc_data_bind finished for : ', chil.vc_name);
        }
      inx := inx + 1;
    }
  if (e.ve_is_post
      and e.ve_button is not null
      and udt_instance_of (e.ve_button, 'vspx_form')
      and e.ve_initiator is null
     )
    {
       declare initiator varchar;
       initiator := get_keyword ('__event_initiator', e.ve_params, '');
       if (initiator <> '' and initiator = self.vc_get_name ())
         {
           e.ve_initiator := self;
         }
    }
  -- after hook is there
  h := udt_implements_method (self.vc_page, fix_identifier_case (concat ('vc_after_data_bind_', self.vc_name)));
  if (h <> 0)
    {
      --dbg_obj_print ('vc_after_data_bind_x called start: ', self.vc_name);
      call (h) (self.vc_page, self, e);
    }
  self.vc_invoke_handlers ('after-data-bind');
}
;

create method vc_set_model () for vspx_control
  {
    return;
  }
;

create method vc_view_state (inout stream any, inout n int) for vspx_control
{
  -- only page have custom vc_view_state method
  return;
}
;

create method vc_set_view_state (inout e vspx_event) for vspx_control
{
  declare h any;
  declare inx, len int;
  -- recursive call is upon vc_init
  h := udt_implements_method (self.vc_page, fix_identifier_case (concat ('vc_set_view_state_', self.vc_name)));
  if (h <> 0)
    call (h) (self.vc_page, self, e);
  self.vc_control_state := 1;
  return;
}
;

create method vc_set_childs_focus(in flag any, inout e vspx_event) for vspx_control
{
  declare inx, len int;
  declare c any;
  inx := 0;
  c := self.vc_children;
  len := length (c);
  while(inx < len) {
    declare child vspx_control;
    child := c[inx];
    if(child is not null) {
      if(not udt_instance_of(child, fix_identifier_case('vspx_form')) and not
         udt_instance_of(child, fix_identifier_case('vspx_button'))) {
        child.vc_focus := flag;
        child.vc_set_childs_focus(flag, e);
      }
    }
    inx := inx + 1;
  }
}
;

create method vc_post (inout e vspx_event) for vspx_control
{
  declare h any;
  declare inx, len int;

  h := udt_implements_method(self.vc_page, fix_identifier_case(concat('vc_post_', self.vc_name)));
  declare c any;
  c := self.vc_children;
  inx := 0;
  len := length(c);
  while(inx < len) {
    declare child vspx_control;
    child := c[inx];
    if(child is not null) {
      child.vc_post(e);
    }
    inx := inx + 1;
  }
  if(h <> 0) {
    call (h) (self.vc_page, self, e);
  }
  if (udt_instance_of (self, fix_identifier_case ('vspx_field')))
    {
      declare field vspx_field;
      declare _fld any;
      _fld := self;
      field := _fld;
      if (field.ufl_value = field.ufl_null_value and field.vc_focus)
	field.ufl_value := null;
    }
}
;

create method vc_user_post (inout e vspx_event) for vspx_control
{
  declare h any;
  declare inx, len int;
  --if (not self.vc_enabled)
  --  return;
  h := udt_implements_method(self.vc_page, fix_identifier_case(concat('vc_user_post_', self.vc_name)));
  declare c any;
  inx := 0;
  c := self.vc_children;
  len := length (c);
  while(inx < len) {
    declare child vspx_control;
    child := c[inx];
    if(child is not null) {
      child.vc_user_post(e);
    }
    inx := inx + 1;
  }
  if(h <> 0) {
    call (h) (self.vc_page, self, e);
  }
  self.vc_invoke_handlers ('on-post');
}
;

create method vc_action (inout e vspx_event) for vspx_control
{
  declare h any;
  declare inx, len int;

  h := udt_implements_method(self.vc_page, fix_identifier_case(concat('vc_action_', self.vc_name)));
  inx := 0;
  declare c any;
  c := self.vc_children;
  len := length(c);
  while(inx < len) {
    declare child vspx_control;
    child := c[inx];
    if(child is not null) {
      child.vc_action(e);
    }
    inx := inx + 1;
  }
  if(h <> 0) {
    call (h) (self.vc_page, self, e);
  }
  -- common handler for fields (using formatting function)
  if (udt_instance_of(self, fix_identifier_case('vspx_field'))) {
    declare field vspx_field;
    declare _fld any;
    _fld := self;
    field := _fld;
    if(isstring(field.ufl_cvt_fn) and field.vc_error_message is null) {
      field.ufl_value := call (field.ufl_cvt_fn) (field.ufl_value);
    }
  }
}
;

create method vc_render () for vspx_select_list
{
  declare inx, len int;
  declare form vspx_form;
  if (not self.vc_enabled)
    return;
  http (sprintf ('<select name="%s"', self.vc_get_name ()));
  vspx_print_html_attrs (self);
  if (self.vsl_multiple)
    {
      http (' multiple="multiple"');
    }
  if (self.ufl_auto_submit or self.vsl_change_script) http (' onchange="doAutoSubmit (this.form, this)"');
  http ('>');

  inx := 0; len := length (self.vsl_items);
  while (inx < len)
    {
      declare sel varchar;
      sel := '';
      if (not self.vsl_multiple)
        {
	  sel := case self.vsl_selected_inx when inx then 'selected="selected"' else '' end;
	}
      else
        {
	  if (isarray(self.vsl_selected_inx) and self.vsl_selected_inx[inx])
	    sel := 'selected="selected"';
	  else
	    sel := '';
	}
      http (sprintf ('<option value="%s" %s>%s</option>', self.vsl_item_values[inx], sel, self.vsl_items[inx]));
      inx := inx + 1;
    }
  http ('</select>');
}
;

create method vc_view_state (inout stream any, inout n int) for vspx_select_list
{
  self.vc_push_in_stream (stream, self.ufl_value, n);
  return;
}
;

create method vc_view_state (inout stream any, inout n int) for vspx_login
{
  --dbg_obj_print ('vc_view_state.vspx_login');
  declare state any;
  state := vector (
            'vl_logout_in_progress', self.vl_logout_in_progress,
            'vl_authenticated', self.vl_authenticated
            );
  self.vc_push_in_stream (stream, state, n);
      return;
}
;



create method vc_render () for vspx_update_field
{
  declare vst any;
  if (not self.vc_enabled)
    return;
  if (self.ufl_failed and self.ufl_error_glyph is not null)
    http (self.ufl_error_glyph);

  http ('<input type="text" name="');
  http (self.vc_get_name ());
  if (self.ufl_value is not null)
    {
      http ('" value="');
      http_value (self.ufl_value);
    }
  else
    {
      vst := self.vc_get_control_state (null);
      if (vst is not null)
        {
          http ('" value="');
          http_value (vst);
        }
      else
       {
          http ('" value="');
          http (self.tf_default);
       }

    }
  http ('"');
  vspx_print_html_attrs (self);
  http (case self.ufl_client_validate when 0 then '' else ' onchange="javascript: vv_validate_' || self.vc_name || '(this)"' end);
  if (self.ufl_auto_submit) http (' onchange="doAutoSubmit (this.form, this)"');
  http (' />');
  if (self.ufl_failed and self.ufl_error_glyph is null)
    http_value (self.ufl_error);
}
;

create method vc_xrender () for vspx_text
  {
    if (not self.vc_page.vc_browser_caps)
      return 0;
    if (self.tf_style = 1 or self.tf_style = 'password')
      {
	http (sprintf ('<xforms:secret ref="/vxf:post/vxf:%s" model="%s" />',
	self.vc_get_name (), self.vc_top_form.vc_get_name ()));
      }
    else if (self.tf_style <> 'hidden' and self.tf_style <> 2)
      {
	http (sprintf ('<xforms:input ref="/vxf:post/vxf:%s" model="%s" />',
	self.vc_get_name (), self.vc_top_form.vc_get_name ()));
      }
    return 1;
  }
;

create method vc_xrender () for vspx_textarea
  {
    if (not self.vc_page.vc_browser_caps)
      return 0;
    http (sprintf ('<xforms:textarea ref="/vxf:post/vxf:%s" model="%s" />',
	self.vc_get_name (), self.vc_top_form.vc_get_name ()));
    return 1;
  }
;

create method vc_xrender () for vspx_select_list
  {
    declare inx, len int;

    if (not self.vc_page.vc_browser_caps)
      return 0;

    http (sprintf ('<xforms:select%s ref="/vxf:post/vxf:%s" model="%s">\n',
      case when not self.vsl_multiple then '1' else '' end,
      self.vc_get_name (), self.vc_top_form.vc_get_name ()));

    inx := 0; len := length (self.vsl_items);
    while (inx < len)
      {
	http ('<xforms:item>\n');
	http (sprintf ('<xforms:label>%s</xforms:label>\n', self.vsl_items[inx]));
	http (sprintf ('<xforms:value>%s</xforms:value>\n', self.vsl_item_values[inx]));
	http ('</xforms:item>\n');
	inx := inx + 1;
      }

    http (sprintf ('</xforms:select%s>\n',
      case when not self.vsl_multiple then '1' else '' end));
    return 1;
  }
;

create method vc_xrender () for vspx_check_box
  {
    if (not self.vc_page.vc_browser_caps)
      return 0;
    http (sprintf ('<xforms:input ref="/vxf:post/vxf:%s" model="%s" />',
	self.vc_get_name (), self.vc_top_form.vc_get_name ()));
    return 1;
  }
;

create method vc_xrender () for vspx_radio_group
  {
    if (not self.vc_page.vc_browser_caps)
      return 0;
    declare inx, len int;
    http (sprintf ('<xforms:select1 ref="/vxf:post/vxf:%s" model="%s" appearance="full">\n',
            self.vc_get_name (), self.vc_top_form.vc_get_name ()));

    inx := 0; len := length (self.vc_children);
    while (inx < len)
      {
	declare chil vspx_control;
	chil := self.vc_children [inx];
	if (chil is not null and udt_instance_of (chil, 'vspx_radio_button'))
	  chil.vc_xrender ();
	inx := inx + 1;
      }

    http ('</xforms:select1>\n');
    return 1;
  }
;

create method vc_xrender () for vspx_radio_button
  {
    if (not self.vc_page.vc_browser_caps)
      return 0;
    http ('<xforms:item>\n');
    http (sprintf ('<xforms:value>%s</xforms:value>\n', coalesce (self.ufl_value, '')));
    http ('</xforms:item>\n');
    return 1;
  }
;

create method vc_xrender () for vspx_button
  {
    if (not self.vc_page.vc_browser_caps)
      return 0;
    http (sprintf ('<xforms:submit submission="%s">\n', self.vc_get_name ()));
    http ('<xforms:label>');
    http_value (self.ufl_value);
    http ('</xforms:label>\n');
    http ('<xforms:action ev:event="DOMActivate">\n');
    http (sprintf ('<xforms:setvalue ref="/vxf:post/vxf:event__target" model="%s">%s</xforms:setvalue>\n',
    	self.vc_top_form.vc_get_name (), self.vc_get_name ()));
    http ('</xforms:action>\n');
    http ('</xforms:submit>\n');
    return 1;
  }
;

create method vc_render () for vspx_text
{
  declare vst any;
  if (not self.vc_enabled)
    return;
  if (self.ufl_failed and self.ufl_error_glyph is not null)
    http (self.ufl_error_glyph);

  http (sprintf ('<input type="%s" name="', (case self.tf_style when 1 then 'password' when 'password' then self.tf_style when 'hidden' then self.tf_style when 2 then 'hidden' when 'file' then 'file' else 'text' end)));
  http (self.vc_get_name ());

  if (self.tf_style <> 'file')
    {
      http ('" value="');
      if (self.ufl_value is not null)
	{
	  http_value (self.ufl_value);
	}
      else
	{
	  vst := self.vc_get_control_state (null);
	  if (vst is not null)
	    {
	      http_value (vst);
	    }
	  else
	   {
	      http (self.tf_default);
	   }
	}
    }
  http ('"');

  if (self.tf_style = 3) {
     http(' readonly="true"');
  }
  vspx_print_html_attrs (self);
  http (case self.ufl_client_validate when 0 then '' else ' onchange="javascript: vv_validate_' || self.vc_name || '(this)"' end);

  if (self.ufl_auto_submit) http (' onchange="doAutoSubmit (this.form, this)"');

  http (' />');
  if (self.ufl_failed and self.ufl_error_glyph is null)
    http_value (self.ufl_error);
}
;

create method vc_render () for vspx_textarea
{
  declare vst any;
  if (not self.vc_enabled)
    return;
  if (self.ufl_failed and self.ufl_error_glyph is not null)
    http (self.ufl_error_glyph);

  http ('<textarea name="');
  http (self.vc_get_name ());
  http ('"');
  vspx_print_html_attrs (self);
  http (case self.ufl_client_validate when 0 then '' else ' onchange="javascript: vv_validate_' || self.vc_name || '(this)"' end);
  if (self.ufl_auto_submit) http (' onchange="doAutoSubmit (this.form, this)"');
  http (' >');

  if (self.ufl_value is not null)
    {
      http_value (self.ufl_value);
    }
  else
    {
      vst := self.vc_get_control_state (null);
      if (vst is not null)
  {
    http_value (vst);
  }
      else
        http (self.tf_default);

    }
  http ('</textarea>');
  if (self.ufl_failed and self.ufl_error_glyph is null)
    http_value (self.ufl_error);
}
;

create method vc_render () for vspx_button
{
  --dbg_obj_print ('vc_render:vspx_button', self.vc_name, self.vc_instance_name);
  if ( not self.vc_enabled)
    return;

  --if (vsp_ua_get_props ('has_css1', self.vc_page.vc_event.ve_lines) = 'False')
  --  goto post_button;

  if (length (self.bt_url) and length (self.bt_l_pars))
    {
      self.bt_url := vspx_uri_add_parameters (self.bt_url, self.bt_l_pars);
      self.bt_l_pars := null;
    }

  if (self.bt_anchor = 1)
    {
      http (sprintf ('<a name="btn_%s"></a>', self.vc_get_name ()));
    }

  if (self.bt_style = 'image')
    {
      declare frm vspx_control;
      declare frm_name varchar;
      frm := self.vc_find_parent_form (self);
      if (frm is not null)
        frm_name := frm.vc_name;
      else
        frm_name := '';
      http ( sprintf ( '<a href="%s" %s><img src="%s" border="0" ',
                       case self.bt_url when '' then 'javascript:void(0)' else self.bt_url end,
                       case when self.bt_url = '' and self.ufl_active > 0
                            then sprintf ( 'onclick="javascript: doPost (\'%s\', \'%s\'); return false"',
                                           frm_name,
                                           self.vc_get_name ()
                            )
                            else '' end,
                       self.ufl_value));
      vspx_print_html_attrs (self);
      http (sprintf (' />%s</a>', self.bt_text));
      return;
    }

  if (self.bt_style = 'url')
    {
      declare frm vspx_control;
      declare frm_name varchar;
      frm := self.vc_find_parent_form (self);
      if (frm is not null)
        frm_name := frm.vc_name;
      else
        frm_name := '';
      http ( sprintf ( '<a href="%s" %s',
                       case self.bt_url when '' then 'javascript:void(0)' else self.bt_url end,
                       case when self.bt_url = '' and self.ufl_active > 0
                            then sprintf ( 'onclick="javascript: doPost (\'%s\', \'%s\'); return false"',
                                           frm_name,
                                           self.vc_get_name ()
                            )
                            else '' end));
      vspx_print_html_attrs (self);
      http (' >');
      http (self.ufl_value);
      http ('</a>');
      return;
    }

post_button:

  http (sprintf ('<input type="%s" name="', case when self.ufl_active > 0 then 'submit' else 'button' end));
  http (self.vc_get_name ());
  if (self.ufl_value is not null)
    {
      http ('" value="');
      http_value (self.ufl_value);
    }
  http ('"');
  vspx_print_html_attrs (self);
  http (' />');
}
;

create method vc_render () for vspx_browse_button
{
  if ( not self.vc_enabled)
    return;

  if (self.bt_style = 'url')
    {
      -- URL style
      http ('<a href="javascript:void(0)"');
      vspx_print_html_attrs (self);
    }
  else if (self.bt_style = 'image')
    {
      -- image style
      http ('<a href="javascript:void(0)" ');
    }
  else
    {
      -- default style : BUTTON
      http ('<input type="button" name="');
      http (self.vc_get_name ());
      if (self.ufl_value is not null)
      {
	http ('" value="');
	http_value (self.ufl_value);
      }
      http ('"');
      vspx_print_html_attrs (self);
    }

  http (' onclick="javascript: ');
  declare pars, fld_pars varchar;
  if (1)
    {
      declare i, l int;
      declare frm vspx_form;
      frm := self.vc_find_parent_form (self);
      i := 0; l := length (self.vcb_fields);
      pars := ''; fld_pars := '&';
      while (i < l)
        {
          declare tfl vspx_text;
          tfl := self.vc_parent.vc_find_control (self.vcb_fields[i]);
          http (sprintf ('window.%s=document.%s[\'%s\']; ',
          self.vcb_fields[i], frm.vc_name, self.vcb_ref_fields[i]));
          pars := concat (pars, self.vcb_fields[i], '=\'+ encodeURIComponent (document.',frm.vc_name, '[\'', self.vcb_ref_fields[i], '\'].value)+\'&');
          fld_pars := concat (fld_pars, 'fld_name=', self.vcb_ref_fields[i], '&');
          i := i + 1;
        }
    }

  if (self.vcb_system = 'dav' or self.vcb_system = 'os')
    {
      declare form vspx_form;
      form := self.vc_find_parent_form (self);
      if (form is not null)
        fld_pars := concat (fld_pars, 'frm_name=', form.vc_name);
      pars := sprintf ('browse_mode=%s&lst_mode=%s&xfer_mode=%s&cur_col=%d&os=%s&flt_pat=%s%s', self.vcb_browser_mode , self.vcb_list_mode, self.vcb_xfer, self.vcb_current, self.vcb_system, self.vcb_filter, fld_pars);
    }

  pars := rtrim (pars, '&');
  if( self.vcb_browser_options <> '' ) pars := concat( pars, '&', self.vcb_browser_options );
  if(self.vcb_params is not null) {
    declare i, l int;
    declare frm vspx_form;
    declare params_string, result_string varchar;
    declare params_stream, result_stream any;
    i := 0;
    l := length(self.vcb_params);
    params_stream := string_output();
    result_stream := string_output();
    frm := self.vc_find_parent_form (self);
    while(i < l) {
      http(sprintf('&%s='' + encodeURIComponent (document.%s.%s.value) + ''', self.vcb_params[i], frm.vc_name, self.vcb_params[i]), params_stream);
      i := i + 1;
    }
    params_string := string_output_string(params_stream);
    http(sprintf('window.open(\\''%s%s\\'', \\''%s_window\\'', \\''%s\\'')',
      vspx_uri_add_parameters (self.vcb_selector, pars),
                 params_string, self.vc_name,  self.vcb_chil_options), result_stream);
    result_string := string_output_string(result_stream);
    http(sprintf('var cmd_str=''%s''; eval(cmd_str); "', result_string));
  }
  else {
    http(sprintf('window.open (\'%s\', \'%s_window\', \'%s\')"',
      vspx_uri_add_parameters (self.vcb_selector, pars), self.vc_name,  self.vcb_chil_options));
  }
  if (self.bt_style = 'url')
    {
      http (sprintf ('>%V</a>', self.ufl_value));
    }
  else if (self.bt_style = 'image')
    {
      http (sprintf ('><img src="%s" border="0" ', self.ufl_value));
      vspx_print_html_attrs (self);
      http (sprintf (' />%s</a>', self.bt_text));
    }
  else
    {
      http (' />');
    }
}
;

create method vc_render () for vspx_return_button
{
  if ( not self.vc_enabled)
    return;
  if (self.bt_style = 'url')
    {
      -- URL style
      http ('<a href="javascript:void(0)"');
      vspx_print_html_attrs (self);
    }
  else if (self.bt_style = 'image')
    {
      -- image style
      http ('<a href="javascript:void(0)"');
    }
  else
    {
      http ('<input type="button" name="');
      http (self.vc_get_name ());
      if (self.ufl_value is not null)
	{
	  http ('" value="');
	  http_value (self.ufl_value);
	}
      http ('"');
      vspx_print_html_attrs (self);
    }
  declare frm vspx_form;
  frm := self.vc_find_parent_form (self);
  http (sprintf (' onclick="javascript: selectRow_%s (\'', self.vc_name));
  if (frm is not null)
    http (frm.vc_name);
  http ('\', ');
  {
    declare i, l integer;
    i := 0; l := length (self.vc_children);
    while (i < l)
      {
        declare chil vspx_field;
  chil := self.vc_children[i];
  if (chil is not null)
    {
      http (sprintf ('\'%V\'', replace(chil.ufl_value,'\'', '\\\'')));
    }
        else
    http ('\'\'');
  if (i <> (l - 1))
    http (',');
        i := i + 1;
      }
  }
  http (')"');
  if (self.bt_style = 'url')
    {
      http (sprintf ('>%V</a>', self.ufl_value));
    }
  else if (self.bt_style = 'image')
    {
      http (sprintf ('><img src="%s" border="0" ', self.ufl_value));
      vspx_print_html_attrs (self);
      http (sprintf (' />%s</a>', self.bt_text));
    }
  else
    {
      http (' />');
    }
}
;

create method vc_render () for vspx_radio_button
{
  if ( not self.vc_enabled)
    return;
  http (sprintf ('<input type="radio" name="%s" value="%s" %s ', case coalesce(self.ufl_group,'') when '' then self.vc_get_name () else self.ufl_group end, cast(self.ufl_value as varchar), case self.ufl_selected when 0 then '' else 'checked="checked"'  end));
  vspx_print_html_attrs (self);
  if (self.ufl_auto_submit) http (' onclick="doAutoSubmit (this.form, this)"');
  http ('/>');
}
;


create method vc_view_state (inout stream any, inout n int) for vspx_data_grid
{
  declare flds any;
  flds :=  vector (serialize(self.dg_last_bookmark), serialize (self.dg_prev_bookmark), self.dg_rows_fetched, self.dg_rowno_edit, self.vc_enabled, self.dg_editable);
  self.vc_push_in_stream (stream, flds, n);
      return;
}
;

create method uf_column_value (in name varchar) for vspx_update_form
{
  declare pos int;
  pos := position (name, self.uf_columns);
  if (pos > 0 and length (self.uf_row) >= pos)
    return self.uf_row[pos-1];
  else
    signal ('22023', sprintf ('The column "%s" does not exist in rowset', name));
}
;

create method vc_view_state (inout stream any, inout n int) for vspx_update_form
{
  if (length (self.uf_keys) > 0)
  {
      self.vc_push_in_stream (stream, self.uf_keys, n);
    }
}
;


create method vc_view_state (inout stream any, inout n int) for vspx_update_field
{
  if (self.vc_page.vc_event.ve_is_post and not self.vc_parent.vc_focus)
    return;
  self.vc_push_in_stream (stream, self.ufl_value, n);
  return;
}
;

create type vspx_node_template under vspx_control
as ( vc_stub any ) temporary self as ref
;

create type vspx_leaf_template under vspx_control
as ( vc_stub any ) temporary self as ref
;

create type vspx_horizontal_template under vspx_control
as ( vc_stub any ) temporary self as ref
;

create type vspx_xsd_stub under vspx_control
as ( vc_stub any ) temporary self as ref
;

create type vspx_xsd_stub_top under vspx_control
as ( vc_stub any ) temporary self as ref
;

create type vspx_xsd_stub_script under vspx_control
as ( vc_stub any ) temporary self as ref
;

--#pragma end control
--#pragma begin dispatcher
-- transformation & store in a external file
create procedure vspx_get_compiler_signature () returns varchar
{
  declare res varchar;
  res := '&proc=2003-12-24 20:31:00.000000';
  if ('1' = registry_get ('__external_vspx_xslt'))
    res := concat ( res,
      '&vspx=',
      cast (file_stat (concat (http_root (), '/vspx/vspx.xsl')) as varchar),
      '&vspx_expand=',
      cast (file_stat (concat (http_root (), '/vspx/vspx_expand.xsl')) as varchar)
      );
  return res;
}
;

create procedure
vspx_make_temp_names (in resource_name varchar, inout vspxm_name varchar, inout sql_name varchar)
returns int
{
  declare is_temp, is_dav int;
  is_temp := 0;
  is_dav := http_map_get ('is_dav');

  if (not is_dav and registry_get ('__no_vspx_temp') <> '1')
    {
      declare tmp_name varchar;
      tmp_name := tmp_file_name ('vspx', 'vspx');
      if (tmp_name is not null)
  {
          is_temp := 1;
          resource_name := tmp_name;
  }
    }

  vspxm_name := resource_name;
  if (vspxm_name like '%.vspx')
    vspxm_name := substring (vspxm_name, 1, length (vspxm_name) - 5);
  vspxm_name := concat (vspxm_name, '.vspx-m');

  sql_name := resource_name;
  if (sql_name like '%.vspx')
    sql_name := substring (sql_name, 1, length (sql_name) - 5);
  sql_name := concat (sql_name, '.vspx-sql');

  return is_temp;
}
;

-- VSPX macro expansion API routine
create function vspx_make_vspxm (
  in resource_name varchar,
  in resource_text varchar,
  in save_vspxm integer,
  in vspxm_name varchar := NULL
) returns any
{
  declare resource_base_uri varchar;
--  declare vspxm_name varchar;
  declare messages any;
  declare expand_ctr integer;
  declare xe, xe_for_xsd, xt any;
  declare xslt_params any;
  declare xslt_add_locations_sheet_name varchar;
  declare xslt_expand_sheet_name varchar;
  declare xslt_pre_xsd_sheet_name varchar;
  declare xslt_pre_sql_sheet_name varchar;
  declare xsd_name varchar;
  declare page_style, xslt_style_uri varchar;
  declare xslt_macro_sheet_name varchar;
  declare xslt_macro_sheet_text varchar;
  declare in_handler integer;
  declare vspx_text_ses any;
  declare old_vspx_text, new_vspx_text varchar;
  declare xe_for_xsd_ses any;
  declare xe_for_xsd_text varchar;
  declare xsd_log varchar;
  xslt_style_uri := null;
  xslt_macro_sheet_name := '';
  in_handler := 0;
  xe := 0;

  if (vspxm_name is null)
    {
       vspxm_name := resource_name;
       if (vspxm_name like '%.vspx')
         vspxm_name := substring (vspxm_name, 1, length (vspxm_name) - 5);
       vspxm_name := concat (vspxm_name, '.vspx-m');
    }

  declare exit handler for sqlstate '*'
    {
      declare old_in_handler integer;
      old_in_handler := in_handler;
      in_handler := 1;
      if (xslt_style_uri is not null)
        xslt_stale (xslt_macro_sheet_name);
      if ((0 = old_in_handler) and (save_vspxm <> 0))
  {
    declare vspxm any;
    vspxm := string_output();
    http_value (string_output_string (messages), null, vspxm);
    http_value (xe, null, vspxm);
    vspx_src_store (vspxm_name, string_output_string (vspxm));
    commit work;
  }
      resignal;
    };
  messages := string_output();
  resource_base_uri := vspx_base_url (resource_name);

  -- here was vspxm_name composition

  http (sprintf('Preparing Virtuoso/PL from VSPX %s (retrieved from %s)\n', resource_name, resource_base_uri), messages);
  if (resource_text is null)
    {
      declare dummy any;
      dummy := 0;
      resource_text := vspx_src_get (resource_name, dummy, 0);
    }
  xe := xtree_doc (resource_text, 256, resource_base_uri);
  xslt_params := vector (
    'vspx_source', resource_name,
    'vspx_source_date', cast (file_stat (concat (http_root (), resource_name)) as varchar),
    'vspx_compile_date', cast (now() as varchar),
    'vspx_compiler_version', vspx_get_compiler_signature() );
  if ('1' = registry_get ('__external_vspx_xslt'))
    {
      xslt_add_locations_sheet_name := 'file://vspx/vspx_add_locations.xsl';
      xslt_expand_sheet_name := 'file://vspx/vspx_expand.xsl';
      xslt_pre_xsd_sheet_name := 'file://vspx/vspx_pre_xsd.xsl';
      xslt_pre_sql_sheet_name := 'file://vspx/vspx_pre_sql.xsl';
      xsd_name := 'file://vspx/vspx.xsd';
      http (sprintf('VSPX compiler will use external stylesheet %s for macro expansion.\n', xslt_expand_sheet_name), messages);
      xml_load_schema_decl (xsd_name, xsd_name, 'UTF-8', 'x-any');
    }
  else
    {
      xslt_add_locations_sheet_name := 'http://local.virt/vspx_add_locations';
      xslt_expand_sheet_name := 'http://local.virt/vspx_expand';
      xslt_pre_xsd_sheet_name := 'http://local.virt/vspx_pre_xsd';
      xslt_pre_sql_sheet_name := 'http://local.virt/vspx_pre_sql';
      xsd_name := 'http://local.virt/vspx.xsd';
    }
  xe := xslt (xslt_add_locations_sheet_name, xe);
  xml_doc_assign_base_uri (xe, resource_base_uri);
  expand_ctr := 0;
  page_style := xpath_eval ('[xmlns:v="http://www.openlinksw.com/vspx/"] //v:page/@style', xe);
  if (page_style is not null)
    {
      http (sprintf('The VSPX contains style URI %s\n', page_style), messages);
      xslt_style_uri := DB.DBA.XML_URI_RESOLVE_LIKE_GET (resource_base_uri, page_style);
      xslt_macro_sheet_name := concat (xslt_style_uri, '-internal-', cast (now() as varchar), ')');
      http (sprintf('The style URI is resolved as %s\n', xslt_style_uri), messages);
      xslt_macro_sheet_text := concat (
  '<?xml version=''1.0''?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"  exclude-result-prefixes="v"
     xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xsl:param name="vspx_log" />
<xsl:output method="xml" omit-xml-declaration="no" indent="yes" />
',
  sprintf('\n<xsl:import href="%V"/>\n<xsl:import href="%V"/>\n',
    xslt_style_uri, xslt_expand_sheet_name),
  '</xsl:stylesheet>' );
      xslt_sheet (xslt_macro_sheet_name, xtree_doc (xslt_macro_sheet_text, 0, xslt_macro_sheet_name));
    }
  else
    {
      xslt_macro_sheet_name := xslt_expand_sheet_name;
    }
  vspx_text_ses := string_output();
  http_value (xe, null, vspx_text_ses);
  old_vspx_text := string_output_string (vspx_text_ses);
expand_again:
  http (sprintf('Applying %s\n', xslt_macro_sheet_name), messages);
  xe := xslt (xslt_macro_sheet_name, xe, xslt_params);
  xml_doc_assign_base_uri (xe, resource_base_uri);
  vspx_text_ses := string_output();
  http_value (xe, null, vspx_text_ses);
  new_vspx_text := string_output_string (vspx_text_ses);
  if (save_vspxm <> 0)
    {
      declare vspxm_ses any;
      vspxm_ses := string_output();
      http_value (string_output_string (messages), null, vspxm_ses);
      http (new_vspx_text, vspxm_ses);
      vspx_src_store (vspxm_name, string_output_string (vspxm_ses));
    }
  if (new_vspx_text = old_vspx_text)
    goto done;
  old_vspx_text := new_vspx_text;
  expand_ctr := expand_ctr + 1;
  if (expand_ctr > 30)
    signal ('22000', sprintf('Too deep recursion in applying style ''%s'' to VSPX page ''%s''', xslt_macro_sheet_name, resource_name), 'VX002');
  goto expand_again;
done:
  xe := xslt (xslt_macro_sheet_name, xe,
    vector_concat (xslt_params,
      vector ('vspx_log', string_output_string (messages)) ) );

  if (registry_get ('vspx_production_mode') <> '1')
    {
      declare dep_files any;
      declare code_files any;
      declare i, l int;

      dep_files := xpath_eval (
        '[xmlns:v="http://www.openlinksw.com/vspx/" ' ||
        'xmlns:vdeps="http://www.openlinksw.com/vspx/deps/"]' ||
        ' //v:hidden/@vdeps:url',
        xe, 0);

      code_files := xpath_eval (
        '[xmlns:v="http://www.openlinksw.com/vspx/" ' ||
        'xmlns:vdeps="http://www.openlinksw.com/vspx/deps/"]' ||
        ' //v:hidden/@vdeps:code-file',
        xe, 0);

      i := 0; l := length (code_files);
      while (i < l)
        {
	  declare code_file varchar;
	  code_file := WS.WS.EXPAND_URL (resource_name, cast (code_files[i] as varchar));
	  code_file := vspx_base_url (code_file);
	  dep_files := vector_concat (coalesce (dep_files, vector ()), vector (code_file));
	  i := i + 1;
	}

      if (xslt_style_uri is not null)
	{
	  dep_files := vector_concat (coalesce (dep_files, vector ()), vector (xslt_style_uri));
	  -- TODO: add the stylesheet includes here
	}
      --dbg_obj_print ('*******dep_files', dep_files);
      registry_set (sprintf ('%s_file_deps', resource_name), serialize (vspx_make_stat_vector (dep_files)));
    }

  if ('1' = registry_get ('__vspx_validate'))
    {

  xe_for_xsd := xslt (xslt_pre_xsd_sheet_name, xe);
  xe_for_xsd_ses := string_output();
  http_value (xe_for_xsd, null, xe_for_xsd_ses);
  xe_for_xsd_text := string_output_string (xe_for_xsd_ses);
  --dbg_obj_print(save_vspxm);
  if (save_vspxm <> 0)
    vspx_src_store (concat(vspxm_name,'-xsd'), xe_for_xsd_text);
  xsd_log := xml_validate_schema (
    xe_for_xsd_text, 0, concat(vspxm_name,'-xsd'), 'LATIN-1', 'x-any',
    'Validation=RIGOROUS Fsa=ERROR FsaBadWs=IGNORE BuildStandalone=ENABLE AttrMissing=ERROR AttrMisformat=ERROR AttrUnknown=ERROR MaxErrors=200',
    'xs:', ':xs', xsd_name );
  if (save_vspxm <> 0)
    vspx_src_store (concat(vspxm_name,'-xsd-log'), xsd_log);
  xml_validate_schema (
    xe_for_xsd_text, 0, concat(vspxm_name,'-xsd'), 'LATIN-1', 'x-any',
    'Validation=RIGOROUS Fsa=ERROR FsaBadWs=IGNORE BuildStandalone=ENABLE AttrMissing=ERROR AttrMisformat=ERROR AttrUnknown=ERROR MaxErrors=200 SignalOnError=ENABLE',
    'xs:', ':xs', xsd_name );

    }

  if (save_vspxm <> 0)
    {
      declare vspxm_ses any;
      declare vspxm_text varchar;
      vspxm_ses := string_output();
      http_value (xe, null, vspxm_ses);
      vspxm_text := string_output_string (vspxm_ses);
      vspx_src_store (concat (vspxm_name, '0'), vspxm_text);
    }

  xe := xslt (xslt_pre_sql_sheet_name, xe);

  if (save_vspxm <> 0)
    {
      declare vspxm_ses any;
      declare vspxm_text varchar;
      vspxm_ses := string_output();
      http_value (xe, null, vspxm_ses);
      vspxm_text := string_output_string (vspxm_ses);
      vspx_src_store (vspxm_name, vspxm_text);
    }
  if (xslt_style_uri is not null)
    xslt_stale (xslt_macro_sheet_name);
  return xe;
}
;


create procedure vspx_make_sql (
  in vspx_dbname varchar,
  in vspx_user varchar,
  in resource_name varchar,
  inout vspxm_name varchar,
  inout sql_name varchar,
  in cls_name varchar
  )
{
  declare resource_base_uri varchar;
--  declare sql_name varchar;
  declare messages any;
  declare xe, xt, dummy any;
  declare xslt_params any;
  declare xslt_main_sheet_name varchar;
  declare subclass_name varchar;
  declare code_files any;
  declare in_handler integer;
  in_handler := 0;
  declare exit handler for sqlstate '*'
    {
      declare old_in_handler integer;
      old_in_handler := in_handler;
      in_handler := 1;
      resignal;
    };
  messages := string_output();
  resource_base_uri := vspx_base_url (resource_name);

  -- here was composition of sql_name

  xe := vspx_make_vspxm (resource_name, null, 1, vspxm_name);

  subclass_name := cast (xpath_eval ('//page[1]/@page-subclass', xe) as varchar);
  if (subclass_name is null)
    subclass_name := '';
  registry_set (concat ('subclass_name_', resource_name), fix_identifier_case (subclass_name));
  code_files := xpath_eval ('[xmlns:v="http://www.openlinksw.com/vspx/" '||
  ' xmlns:vdeps="http://www.openlinksw.com/vspx/deps/"] //v:hidden/@vdeps:code-file', xe, 0);

  xslt_params := vector (
    'vspx_dbname', vspx_dbname,
    'vspx_user', vspx_user,
    'vspx_source', resource_name,
    'vspx_source_date', cast (file_stat (concat (http_root (), resource_name)) as varchar),
    'vspx_compile_date', cast (now() as varchar),
    'vspx_compiler_version', vspx_get_compiler_signature(),
    'vspx_local_class_name', cls_name);
  if ('1' = registry_get ('__external_vspx_xslt'))
    {
      xslt_main_sheet_name := 'file://vspx/vspx.xsl';
      http (sprintf('-- VSPX compiler will use external stylesheet %s for composing SQL\n', xslt_main_sheet_name), messages);
    }
  else
    {
      xslt_main_sheet_name := 'http://local.virt/vspx';
    }
  xt := xslt (xslt_main_sheet_name, xe, xslt_params);
  http ( sprintf ('-- The following SQL is created by applying %s:\n', xslt_main_sheet_name), messages);
  http_value (xt, null, messages);
  vspx_src_store (sql_name, string_output_string (messages));
  return code_files;
}
;

-- load external file & execute it
create procedure vspx_load_sql (
  in vspx_dbname varchar,
  in vspx_user varchar,
  in resource_name varchar,
  inout sql_name varchar)
{
--  declare sql_name varchar;
  declare ses any;
  declare cmd, dbg any;
  declare line varchar;
  declare i, is_drop, curline, sline int;

--  sql_name := resource_name;
--  if (sql_name like '%.vspx')
--    sql_name := substring (sql_name, 1, length (sql_name) - 5);
--  sql_name := concat (sql_name, '.vspx-sql');
  ses := 1;
  vspx_src_get (sql_name, ses, 1);
  commit work;

  __set_user_id (vspx_user);
  set_qualifier (vspx_dbname);
  cmd := null;
  curline := 0;
  while (1)
    {
      -- this is read a long line with CR/LF
      line := ses_read_line (ses, 0, 0, 1);
      if (not isstring (line))
        return;
      if (cmd is null and (line like 'create %' or line like 'drop %' or line like 'grant %'))
	{
          cmd := string_output ();
          dbg := string_output ();
          is_drop := 0;
          if (line like 'drop %')
            is_drop := 1;
          i := 1;
          sline := curline;
	}
      if (rtrim(line, '\r\n ') = ';')
	{
	  declare stmt, stat, msg varchar;
          stmt := string_output_string (cmd);
	  if (not is_drop)
            {
              stmt := concat (sprintf ('#line %d "%s"\n', sline-1, sql_name), stmt);
            }
          stat := '00000'; msg := '';
	  log_enable (0, 1);
          exec (stmt, stat, msg);
          if (stat = '00000')
	    {
              commit work;
	    }
          else
	    {
              rollback work;
	      if (not is_drop)
		{
		  --log_message (sprintf ('VSPX: %s %s',stat, msg));
		  dbg_printf ('%s', string_output_string (dbg));
		}
	      if (not (stmt like 'drop %'))
		signal (stat, concat (msg, '\nwhile executing the following statement:\n', stmt));
	    }
          cmd := null;
          dbg := null;
	}
      if (cmd is not null)
	{
          http (line, cmd);
	  http (sprintf ('%03d ', i), dbg);
          http (line, dbg);
          i := i + 1;
	}
      curline := curline + 1;
    }
}
;

create procedure vspx_src_get (in resource_name varchar, inout ses any, in try_temp int)
{
  declare is_dav int;
  declare ret any;

  is_dav := http_map_get ('is_dav');

  if (not is_dav)
    {
      if (not (try_temp and registry_get ('__no_vspx_temp') <> '1'))
	resource_name := concat (http_root (), resource_name);

      if (not ses)
        ret := file_to_string (resource_name);
      else
        ses := file_to_string_output (resource_name);
    }
  else
    {
      if (not ses)
  select blob_to_string (RES_CONTENT) into ret from WS.WS.SYS_DAV_RES where RES_FULL_PATH = resource_name;
      else
  {
    declare cnt any;
          ses := string_output ();
          select RES_CONTENT into cnt from WS.WS.SYS_DAV_RES where RES_FULL_PATH = resource_name;
          http (cnt, ses);
  }
    }
  return ret;
}
;

create procedure vspx_src_store (in resource_name varchar, inout ses any)
{
  declare is_dav int;

  is_dav := http_map_get ('is_dav');

  if (not is_dav)
    {
      if (registry_get ('__no_vspx_temp') <> '1')
	string_to_file (resource_name, ses, -2);
      else
	string_to_file (concat (http_root (), resource_name), ses, -2);
    }
  else
    {
      declare rc int;
      log_enable (0, 1);
      rc := DAV_RES_UPLOAD_STRSES_INT (resource_name, ses, '', '110100000NN',
        coalesce ((select U_NAME from WS.WS.SYS_DAV_USER where U_ID = connection_get ('DAVUserID'))),
        coalesce ((select G_NAME from WS.WS.SYS_DAV_GROUP where G_ID = connection_get ('DAVGroupID'))),
	null, null, 0);
      --dbg_obj_princ ('vspx_src_store gets id ', rc, ' for ', resource_name);
      if (rc < 0)
	signal ('42000', sprintf ('Can''t store the file ''%s'': DAV error %d', resource_name, rc) , 'DA010');
    }
  return;
}
;

create procedure vspx_base_url (in f varchar)
{
  if (http_map_get ('is_dav'))
    return concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:',f);
  else
    return concat ('file://', f);
}
;

create procedure vsxp_src_stat (in f varchar)
{
  if (http_map_get ('is_dav'))
    {
      declare tim datetime;
      select RES_MOD_TIME into tim from WS.WS.SYS_DAV_RES where RES_FULL_PATH = f;
      return tim;
    }
  else
    return file_stat (concat (http_root (), f));
}
;

create procedure vspx_url_stat (in base_uri varchar)
{
  declare s_url any;
  s_url := WS.WS.PARSE_URI (base_uri);
  if (s_url[0] = 'virt')
    {
      s_url := split_and_decode (base_uri, 0, '\0\0:');
      if (s_url[1] <> '//WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT')
	return 0;
      declare tim datetime;
      select RES_MOD_TIME into tim from WS.WS.SYS_DAV_RES where RES_FULL_PATH = s_url[2];
      return cast (tim as varchar);
    }
  else if (s_url[0] = 'file')
    {
      s_url := split_and_decode (base_uri, 0, '\0\0:');
      return file_stat (concat (http_root (), s_url[1]));
    }
  else
    return 0;
}
;

create procedure vspx_make_stat_vector (in dep_files any)
{
  declare inx integer;
  declare dep_string any;
  inx := 0;
  dep_string := null;
  while (inx < length (dep_files))
    {
      declare f_stat any;
      declare f_name varchar;

      f_name := cast (dep_files[inx] as varchar);
      f_stat := vspx_url_stat (f_name);
      if (isstring (f_stat))
	dep_string := vector_concat (coalesce (dep_string, vector()) , vector (f_name, f_stat));
      inx := inx + 1;
    }
  --dbg_obj_print ('**** stat_vector', dep_string);
  return dep_string;
}
;

create procedure vspx_check_file_deps (in resource_name varchar)
{
  if (registry_get ('vspx_production_mode') <> '1')
    {
      declare dep_vector any;
      declare inx integer;
      dep_vector := registry_get (sprintf ('%s_file_deps', resource_name));

      if (not isstring (dep_vector))
	return 1;

      dep_vector := deserialize (dep_vector);

      if (not isarray (dep_vector))
	return 1;

      inx := 0;
      while (inx < length (dep_vector))
	{
	  declare saved_stat, saved_url, real_stat varchar;

	  saved_url := dep_vector[inx];
	  saved_stat := dep_vector[inx + 1];

	  real_stat := vspx_url_stat (saved_url);

	  if (real_stat <> saved_stat)
	    return 0;

	  inx := inx + 2;
	}
    }
  return 1;
}
;

create function
vspx_get_subclass_name (in resource_name varchar, in class_name varchar) returns varchar
{
  declare subclass_name varchar;
  declare len integer;

  subclass_name := registry_get (concat ('subclass_name_', resource_name));
  if (isstring (subclass_name) and subclass_name <> '')
    {
      return subclass_name;
    }
  return class_name;
}
;

create function
vspx_get_class_name (
in resource_name varchar ) returns varchar
{
  declare class_name varchar;
  declare len integer;

  class_name := fix_identifier_case (resource_name);
  class_name := replace (class_name, '/', '!');
  class_name := replace (class_name, ':', '!');
  class_name := replace (class_name, '.', '!');
  class_name := replace (class_name, '-', '!');
  class_name := replace (class_name, ' ', '!');
  class_name := replace (class_name, '_', '__');
  class_name := replace (class_name, '!', '_');
  len := length (class_name);
  if (len >= 32)
    class_name := concat (md5 (class_name), subseq (class_name, len-31));
  return fix_identifier_case (concat ('page_', class_name));
}
;

create procedure vspx_get_signature (in dbname varchar, in usr varchar, in res varchar)
  {
    declare signature varchar;
    signature := concat (
    '&dbname=', dbname,
    '&user=', usr,
    '&src=', cast (vsxp_src_stat (res) as varchar),
    vspx_get_compiler_signature() );
    return signature;
  }
;

create procedure vspx_load_code (in vspx_dbname varchar, in vspx_user varchar,
		in resource_name varchar, in code_files any)
  {
    declare i, l int;
    declare is_dav int;

    is_dav := http_map_get ('is_dav');
    i := 0; l := length (code_files);
    while (i < l)
      {
	declare url any;
	url := cast (code_files[i] as varchar);
	url := WS.WS.EXPAND_URL (resource_name, url);

	dbg_printf ('Loading: [%s]', url);
	if (not is_dav and registry_get ('__no_vspx_temp') <> '1')
	  url := concat (http_root (), url);
        vspx_load_sql (vspx_dbname, vspx_user, resource_name, url);
	dbg_printf ('Done: [%s]', url);
	i := i + 1;
      }
  }
;

create procedure vspx_report_debug_log (in page vspx_page)
{
  declare sheet_name varchar;
  if ('1' = registry_get ('__external_vspx_xslt'))
    sheet_name := 'file://vspx/vspx_log_format.xsl';
  else
    sheet_name := 'http://local.virt/vspx_log_format';
  http (']]>-' || '->]]></table></div></ins></del><hr>');
  http_value (xslt (sheet_name, page.vc_get_debug_log('xmp'), vector('tgt','http')));
}
;

create procedure vspx_get_user_info (inout vspx_dbname varchar, inout vspx_user varchar)
{
  --vspx_dbname := fix_identifier_case (http_map_get ('vsp_qual'));
  vspx_dbname := fix_identifier_case (dbname());
  --vspx_user := fix_identifier_case (user);
  vspx_user := fix_identifier_case (http_map_get ('vsp_uid'));
}
;

-- VSPX dispatcher procedure, all .vspx goes there
create procedure
vspx_dispatch (in resource_name varchar, inout path any, inout params any, inout lines any, in class_name varchar := null, in compile_only int := 0, in vspx_dbname varchar := NULL, in vspx_user varchar := NULL)
{
  declare signature varchar;
  declare compile, executed, now int;
  declare recompilation_is_allowed int;
  declare page vspx_page;
  declare full_class_name, q_full_class_name varchar;
  declare subclass_name, full_subclass_name, q_full_subclass_name varchar;
  declare h any;
  declare new_signature varchar;
  declare vspxm_name, sql_name varchar;
  declare unlink, deadl int;
  declare res_pos, tmp, vdir, vres, code_files any;

  --vspx_dbname := fix_identifier_case (dbname());
  --vspx_user := fix_identifier_case (user);
  if (vspx_user is null and vspx_dbname is null)
  vspx_get_user_info (vspx_dbname, vspx_user);
  if (class_name is null)
    class_name := vspx_get_class_name (resource_name);
  full_class_name := concat (vspx_dbname, '.', vspx_user, '.', class_name);
  q_full_class_name := concat ('"',vspx_dbname, '"."', vspx_user, '".', class_name);
  -- subclass
  subclass_name := vspx_get_subclass_name (resource_name, class_name);
  full_subclass_name := concat (vspx_dbname, '.', vspx_user, '.', subclass_name);
  q_full_subclass_name := concat ('"',vspx_dbname, '"."', vspx_user, '".', subclass_name);
  signature := vspx_get_signature (vspx_dbname, vspx_user, resource_name);
  -- these are for temporary storage
  unlink := 0; vspxm_name := NULL; sql_name := NULL;

  if ((registry_get (resource_name) = signature) and udt_is_available (full_subclass_name)
    and vspx_check_file_deps (resource_name)) {
    goto run;
  }

  icc_lock_at_commit ('vspx_dispatch', 1);
  commit work;
  log_enable (0);

  if ((registry_get (resource_name) = signature) and udt_is_available (full_subclass_name)
    and vspx_check_file_deps (resource_name)) {
    icc_unlock_now ('vspx_dispatch');
    goto run;
  }

generate:
  {
    --dbg_obj_print ('compiling', resource_name);
    declare stat, msg varchar;
    declare exit handler for sqlstate '*' {
--  dbg_obj_print('\nNested fail in class', class_name, '\nOld signature:', registry_get (resource_name), '\nNew signature:', signature);
      if (udt_is_available (full_subclass_name) and subclass_name <> class_name)
        exec (concat ('drop type ', q_full_subclass_name), stat, msg);
      if (udt_is_available (full_class_name))
        exec (concat ('drop type ', q_full_class_name), stat, msg );
      registry_set (resource_name, '');
      if (unlink) {
        -- silently delete temp files
        file_delete (vspxm_name, 1);
        file_delete (vspxm_name||'0', 1);
        file_delete (sql_name, 1);
      }
      log_enable (1);
      icc_unlock_now ('vspx_dispatch');
      prof_sample ('VSPX compilation', msec_time () - now, 4);
      resignal;
    };
--    dbg_obj_print('\nClass', class_name, '\nOld signature:', registry_get (resource_name), '\nNew signature:', signature);
    registry_set (resource_name, concat (signature, '!'));
    now := msec_time ();
    stat := '00000';
    msg := '';
    unlink := vspx_make_temp_names (resource_name, vspxm_name, sql_name);
    code_files := vspx_make_sql (vspx_dbname, vspx_user, resource_name, vspxm_name, sql_name, class_name);
    -- get sub-class name again, it can be pre-defined
    subclass_name := vspx_get_subclass_name (resource_name, class_name);
    full_subclass_name := concat (vspx_dbname, '.', vspx_user, '.', subclass_name);
    if (subclass_name <> class_name)
      exec (concat ('drop type ', q_full_subclass_name), stat, msg);
    exec (concat ('drop type ', q_full_class_name), stat, msg );

    vspx_load_sql (vspx_dbname, vspx_user, resource_name, sql_name);
    vspx_load_code (vspx_dbname, vspx_user, resource_name, code_files);
    compile := msec_time () - now;
    registry_set (resource_name, signature);
    if (unlink) {
      -- silently delete temp files
      file_delete (vspxm_name, 1);
      file_delete (vspxm_name||'0', 1);
      file_delete (sql_name, 1);
    }
    log_enable (0, 1);
    exec (concat ('grant execute on ', q_full_class_name, ' to "', vspx_user, '"'), stat, msg);
    if (subclass_name <> class_name)
      exec (concat ('grant execute on ', q_full_subclass_name, ' to "', vspx_user, '"'), stat, msg);
    commit work;
    icc_unlock_now ('vspx_dispatch');
    goto run;
  }

run:
  log_enable (1, 1);

  if (compile_only)
    return null;

  now := msec_time ();
  deadl := null;
  __set_user_id (http_map_get ('vsp_uid'));
  set_qualifier (vspx_dbname);
run_again:
  page := __udt_instantiate_class (full_subclass_name, -1);
  page.vc_page := page;
  h := udt_implements_method (page, class_name, 1);
  if (h) {
      declare ss any;
      declare icnt int;
    declare exit handler for sqlstate '*', not found {
      declare rc int;
      --dbg_obj_print( 'Error:', __SQL_STATE, __SQL_MESSAGE );
      rollback work;
      if (page.vc_debug_log_acc is not null)
	page.vc_debug_log ('begin', 'Page error handler', sprintf('Error: ''%s'': %s', __SQL_STATE, __SQL_MESSAGE));
      rc := page.vc_handle_error (__SQL_STATE, __SQL_MESSAGE, deadl);
      if (not rc) {
        prof_sample (resource_name, msec_time () - now, 4);
        if (page.vc_debug_log_acc is not null)
	  {
	    page.vc_debug_log ('fatal', 'Page error handler has returned zero.', null);
	    vspx_report_debug_log (page);
	    return;
	  }
        resignal;
      }
      if (isinteger (deadl) and deadl > 0 and __SQL_STATE = '40001') {
        goto run_again;
      }
    if (page.vc_debug_log_acc is not null)
      {
        page.vc_debug_log ('fatal', 'Page error handler has handled the error.', null);
        vspx_report_debug_log (page);
        return;
      }
      return;
    };
    call (h) (page, path, params, lines);
    page.vc_data_bind (page.vc_event);
    if (page.vc_event.ve_is_post) {
      page.vc_post(page.vc_event);
      page.vc_user_post(page.vc_event);
      page.vc_action(page.vc_event);
    }
    ss := string_output ();
    icnt := 0;
    page.vc_pre_render (ss, icnt);
    page.vc_state_deserialize (ss, icnt);
    page.vc_render ();
    executed :=  msec_time () - now;
  }
  if ('1' = registry_get ('__external_vspx_xslt')) {
    dbg_obj_print (sprintf ('Compiled: %d, Executed: %d', compile, executed));
  }
  if (compile <> 0)
    prof_sample ('VSPX compilation', compile, 1);
  prof_sample (resource_name, executed, 1);
  if (page.vc_debug_log_acc is not null)
    vspx_report_debug_log (page);
  return page;
}
;

-- a wrapper for vsp_auth_verify_pass, as all info is in the auth_vec
create procedure
vspx_verify_pass (in auth_vec any, in passwd varchar)
{
  return vsp_auth_verify_pass (auth_vec,
              get_keyword ('username' , auth_vec, ''),
              get_keyword ('realm', auth_vec, ''),
              get_keyword ('uri', auth_vec, ''),
              get_keyword ('nonce', auth_vec, ''),
              get_keyword ('nc', auth_vec, ''),
              get_keyword ('cnonce', auth_vec, ''),
              get_keyword ('qop', auth_vec, ''),
              passwd);
}
;

--!AWK PUBLIC
create procedure
vspx_get_cookie_vec (in lines any)
{
  declare cookie_vec any;
  declare i,l int;
  declare cookie_str varchar;
  cookie_str := http_request_header (lines, 'Cookie');
  --dbg_obj_print (cookie_str);
  if (not isstring (cookie_str))
    return vector ();
  cookie_vec := split_and_decode (cookie_str, 0, '\0\0;=');
  i := 0; l := length (cookie_vec);
  while (i < l)
    {
      declare kw, var varchar;
      kw := trim (cookie_vec[i]);
      var := cookie_vec[i+1];
      if (var is not null)
        var := trim (var);
      aset (cookie_vec, i, kw);
      aset (cookie_vec, i + 1, var);
      i := i + 2;
    }
  return cookie_vec;
}
;

--!AWK PUBLIC
create procedure
vspx_do_compact (in arr any) returns any
{
  declare i, l int;
  declare ret any;
  if (arr is null or not isarray (arr))
    return arr;
  i := 0; l := length (arr);
  if (mod(l,2))
    return arr;
  ret := vector ();
  while (i < l)
    {
      if (arr[i] is not null and arr[i+1] is not null)
  ret := vector_concat (ret, vector (arr[i], arr[i+1]));
      i := i + 2;
    }
  return ret;
}
;

--#pragma end dispatcher
--#pragma begin meta

--!AWK PUBLIC
create procedure DB.DBA.VSPX_COLUMNS_META (in sql varchar)
{
  declare mtd, res any;
  declare i, l int;
  exec_metadata (sql, null, null, mtd);
  res := string_output ();
  mtd := mtd[0];
  i := 0; l := length (mtd);
  while (i < l)
    {
      declare colname varchar;
      if (isstring (mtd[i][8]))
        colname := mtd[i][8];
      else
        colname := mtd[i][0];
      http (sprintf ('<column name="%s" />\n', colname), res);
      i := i + 1;
    }
  return xml_tree_doc(string_output_string (res));
}
;

grant execute on DB.DBA.VSPX_COLUMNS_META to public
;

--!AWK PUBLIC
create procedure VSPX_COLUMNS_META_TYPES (in col varchar, in tab varchar)
{
  declare mtd, res, sql, ty any;
  declare i, l int;
  sql := 'select ' || col || ' from ' || tab;
  exec_metadata (sql, null, null, mtd);
  mtd := mtd[0];
  i := 0; l := length (mtd);
  if (l > 0 and length (mtd[0]) > 1)
    {
      ty := lower (dv_type_title (mtd[0][1]));
      if (ty like 'long %')
        ty := substring (ty, 6, length (ty));
      res := ty;
      return res;
    }
  else
    return 'varchar';
}
;

grant execute on DB.DBA.VSPX_COLUMNS_META_TYPES to public
;

create procedure VSPX_PK_COLUMNS (in tab varchar)
{
  declare ses, ret any;
  ses := string_output ();
  for select \COLUMN from
   	DB.DBA.SYS_KEYS v1,
	DB.DBA.SYS_KEYS v2,
	DB.DBA.SYS_KEY_PARTS kp,
	DB.DBA.SYS_COLS
	where
	0 = casemode_strcmp (v1.key_table, tab)
	and __any_grants (v1.KEY_TABLE)
	and v1.KEY_IS_MAIN = 1
	and v1.KEY_MIGRATE_TO is NULL
	and v1.KEY_SUPER_ID = v2.KEY_ID
	and kp.KP_KEY_ID = v1.KEY_ID
	and kp.KP_NTH < v1.KEY_DECL_PARTS
	and COL_ID = kp.KP_COL and \COLUMN <> '_IDN'
	order by v1.KEY_TABLE, kp.KP_NTH do
	{
	  http (sprintf ('<column name="%s" />\n', \COLUMN), ses);
	}
   ret := string_output_string (ses);
   if (length (ret) = 0)
     ret := '<void />';
   return xml_tree_doc(ret);
}
;

grant execute on VSPX_PK_COLUMNS to public
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME) VALUES ('http://www.openlinksw.com/vspx/:columns_meta', 'DB.DBA.VSPX_COLUMNS_META')
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME) VALUES ('http://www.openlinksw.com/vspx/:columns_type', 'DB.DBA.VSPX_COLUMNS_META_TYPES')
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME) VALUES ('http://www.openlinksw.com/vspx/:pk_columns', 'DB.DBA.VSPX_PK_COLUMNS')
;

xpf_extension ('http://www.openlinksw.com/vspx/:columns_meta', 'DB.DBA.VSPX_COLUMNS_META', 0)
;

xpf_extension ('http://www.openlinksw.com/vspx/:columns_type', 'DB.DBA.VSPX_COLUMNS_META_TYPES', 0)
;

xpf_extension ('http://www.openlinksw.com/vspx/:pk_columns', 'DB.DBA.VSPX_PK_COLUMNS', 0)
;

--#pragma end meta

--
-- this is to print vspx_control childs tree
-- for debugging purposes only, MUST NOT go in production
-- empty childs i.e NULLs are not printed anyhow
--

--!AWK PUBLIC
create procedure
dbg_vspx_control (in control vspx_control, in tab int default 0)
{
  declare i, l int;
  declare chil vspx_control;
  declare uf vspx_field;
  declare sp, val, und varchar;
  if (control is null or not udt_instance_of (control, fix_identifier_case ('vspx_control')))
    return;
  l := length (control.vc_children);
  if (not tab)
    dbg_obj_print ('=============BEGIN=============');
  if (tab >= 2)
    {
      sp := repeat (' ', tab);
      sp := concat(sp, '+-');
    }
  else
    sp := repeat (' ', tab);

  if (control.vc_inside_form)
    und := '*';
  else
    und := '-';

  uf := null;
  val := 'NONE';
  if (udt_instance_of (control, fix_identifier_case ('vspx_field')))
    {
      declare _ctrl any;
      _ctrl := control;
      uf := _ctrl;
      if (not isstring (uf.ufl_value) and isarray(uf.ufl_value))
        val := sprintf ('vector (l=%d)', length(uf.ufl_value));
      else
        val := cast (uf.ufl_value as varchar);
    }
  dbg_obj_print (substring (sprintf ('%s%s%s (%s) (%s) %s %s [value=%s] %s', sp, und, control.vc_name, udt_instance_of (control), control.vc_instance_name, case control.vc_focus when 1 then 'In focus' else '' end, case control.vc_enabled when 1 then '' else 'DISABLED' end, val, case when uf is not null and uf.ufl_selected then 'SELECTED' else '' end), 1, 120));
  if (l and not (l = 1 and control.vc_children[0] is null))
    dbg_obj_print (sprintf ('%s|', repeat (' ', tab+2)));
  while (i < l)
    {
      chil := control.vc_children[i];
      if (chil is not null)
      dbg_vspx_control (chil, tab + 2);
      i := i + 1;
    }
  if (not tab)
    dbg_obj_print ('=============END=============');
}
;

--!AWK PUBLIC
create procedure
vspx_uri_compose (in res any)
{
  declare _full_path, _elm varchar;
  declare idx integer;

  if (length (res) < 6)
    signal ('.....', 'vspx_uri_compose needs a vector of lenght 6 or greater');

  idx := 0;
  _elm := '';
  _full_path := '';
  while (idx < 6)
    {
      _elm := res[idx];
      if (isstring (_elm) and _elm <> '')
  {
    if (idx = 0)
      _full_path := concat (_elm, ':');
    else if (idx = 1)
      _full_path := concat (_full_path, '//', _elm);
    else if (idx = 2)
      _full_path := concat (_full_path, _elm);
    else if (idx = 3)
      _full_path := concat (_full_path, ';', _elm);
    else if (idx = 4)
      _full_path := concat (_full_path, '?', _elm);
    else if (idx = 5)
      _full_path := concat (_full_path, '#', _elm);
  }
      idx := idx + 1;
    }

  return _full_path;
}
;

--!AWK PUBLIC
create procedure
vspx_uri_add_parameters (in uri varchar, in pars varchar)
{
  declare hinfo any;
  declare par_str varchar;
  uri := cast (uri as varchar);
  hinfo := WS.WS.PARSE_URI (uri);
  par_str := hinfo[4];
  if (par_str <> '' and pars <> '')
    par_str := par_str || '&' || pars;
  else if (pars <> '')
    par_str := pars;
  aset (hinfo, 4, par_str);
  return vspx_uri_compose (hinfo);
}
;


--!AWK PUBLIC
create procedure vspx_xforms_params_parse (inout cnt any)
  {
    declare xt, ret, ss any;
    if (not xslt_is_sheet ('http://local.virt/xforms_params'))
      {
	declare ses any;
	ses := string_output ();
	http ('<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">', ses);
	http ('<xsl:output method="text" omit-xml-declaration="yes" indent="yes" />', ses);
	http ('<xsl:template match="/">', ses);
	http ('<xsl:apply-templates select="post/*" />', ses);
	http ('</xsl:template>', ses);
	http ('<xsl:template match="event__target">&amp;<xsl:value-of select="."/>=<xsl:value-of select="."/></xsl:template>', ses);
	http ('<xsl:template match="*">&amp;<xsl:value-of select="local-name()"/>=<xsl:value-of select="." disable-output-escaping="yes"/></xsl:template>', ses);
	http ('</xsl:stylesheet>', ses);
	xslt_sheet ('http://local.virt/xforms_params', xml_tree_doc (xml_tree (ses)));
      }
    -- in case where content is not www-url-encoded nor multipart nor application/xml
    -- then VSPX page may use 'Content' to parse with special rules
    declare exit handler for sqlstate '*'
      {
        return vector ('Content', cnt);
      };
    xt := xslt ('http://local.virt/xforms_params', xml_tree_doc (xml_tree (cnt)));
    ss := string_output ();
    http_value (xt, null, ss);
    xt := string_output_string (ss);
    ret := split_and_decode (xt, 0, '\0\0&=');
    return ret;
  }
;

--#pragma begin dispatcher, session

insert soft "DB"."DBA"."SYS_SCHEDULED_EVENT" (SE_INTERVAL, SE_LAST_COMPLETED, SE_NAME, SE_SQL, SE_START)
  values (1440, NULL, 'VSPX_SESSION_EXPIRE', 'VSPX_EXPIRE_SESSIONS ()', now())
;


create procedure
VSPX_EXPIRE_SESSIONS ()
{
  delete from VSPX_SESSION where VS_EXPIRY is null;
  delete from VSPX_SESSION where datediff ('minute', VS_EXPIRY, now()) > 120;
  --if (row_count () > 0)
  --  log_message (sprintf ('%d VSPX session entries erased', row_count ()));
}
;

--#pragma end dispatcher, session
create procedure DB.DBA.sys_xpath_localfile_eval(in content any, in expr any) {
  declare retval, result, pos, eval_result integer;
  declare pwd, dav_content any;
  declare xml_tree, xml_entity any;
  -- detect password
  select pwd_magic_calc('dav', U_PASSWORD, 1) into pwd from DB.DBA.SYS_USERS where U_NAME='dav' and U_IS_ROLE=0;
  retval := 0;
  -- check if necessary DAV path exists
  result := cast(DB.DBA.DAV_SEARCH_ID('/DAV/temp/', 'c') as integer);
  if(result < 0) {
    -- create temporary collection in DAV repository if it necessary
    result := cast(DB.DBA.DAV_COL_CREATE('/DAV/temp/', '110110110R', 'dav', 'dav', 'dav', pwd) as integer);
    if(result < 0) {
      signal('XP001', 'DAV Collection /DAV/temp/ can not be created.');
      return;
    }
  }
  -- upload local file content into /DAV/temp/local_file_content
  result := cast(DB.DBA.DAV_RES_UPLOAD('/DAV/temp/temp.xml', content, 'text/html','110110110R','dav','dav','dav',pwd) as INTEGER);
  if(result < 0) {
    signal('XP002', 'DAV Resource /DAV/temp/temp.xml can not be uploaded.');
    return;
  }
  -- read it as string
  select blob_to_string(RES_CONTENT) into dav_content from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/temp/temp.xml';
  -- cut off content before ---BODY and after ---END BODY
  -- find the last occurence of --BODY - sometimes the urlsimu may have 2 bodies (if encountered err reading).
  {
again:
    pos := strstr(dav_content, '---BODY');
    if (pos is not null)
      {
        dav_content := subseq(dav_content, pos + length('---BODY'));
        goto again;
      }
  }

  pos := strstr(dav_content, '\n');
  dav_content := subseq(dav_content, pos + 1);
  pos := strstr(dav_content, '---END BODY');
  dav_content := subseq(dav_content, 0, pos);
  -- create XML tree
  xml_entity := xtree_doc (dav_content, 0);
  -- do xpath evaluation
  eval_result := xpath_eval(expr, xml_entity, 1);
  dbg_obj_print(eval_result);
  -- remove temporary resource
  delete from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/temp/temp.xml';
  -- return necessary value
  result(eval_result);
  return retval;
}
;

create procedure DB.DBA.sys_save_http_history(in vdir any, in vres any)
{
  declare _ext, result, name, content, pwd, cnt any;
  -- do nor record itself
  if (registry_get ('__block_http_history') = http_path ()) 
    {
    return;
  }
  vres := trim (vres);
  -- do not record some registered extensions
  _ext := subseq (vres, strrchr (vres, '.') + 1);
  if (exists (select 1 from WS.WS.HTTP_SES_TRAP_DISABLE where lcase (EXT) = lcase (_ext)))
    return;
  -- record all others
  -- cut off parameters from resource name
  if (length (vres) > 0) 
    {
    declare p any;
      p := strstr (vres, '?');
      if (p) 
	{
      vres := subseq(vres, 0, p);
    }
  }
  name := sprintf ('%06d%s', sequence_next ('sys_http_recording'), vres);
  name := replace (name, '-', '_');
  name := replace (name, ' ', '_');
  name := replace (name, ':', '_');
  name := replace (name, '/', '_');
  name := replace (name, '.', '_');
  name := replace (name, '&', '_');
  -- collect HTTP header block
  content := http_full_request (0);
  if (registry_get ('__save_http_history_on_disk') = '1')
    {
      declare ip varchar;
      declare use_ip int;
      if (registry_get ('__save_http_history_use_ip') = '1')
	use_ip := 1;
      else
        use_ip := 0; 	
      ip := http_client_ip ();
      if (file_stat ('./sys_http_recording') = 0)
	signal ('VSPX9', 'Can not upload resource into sys_http_recording/ directory');
      if (length (name) > 200)
	name := subseq (name, 0, 200);
      if (use_ip and file_stat ('./sys_http_recording/' || ip) = 0)
	sys_mkdir ('./sys_http_recording/' || ip);
      if (use_ip)
	string_to_file ('./sys_http_recording/' || ip || '/' || name, content, -2);
      else
	string_to_file ('./sys_http_recording/' || name, content, -2);
    }
  else
    {
      name := concat ('/DAV/sys_http_recording/', name);
      -- check if necessary DAV path exists
      result := cast (DB.DBA.DAV_SEARCH_ID ('/DAV/sys_http_recording/', 'c') as integer);
      if (result < 0) 
	{
	-- create DAV collection
	  result := cast (DB.DBA.DAV_COL_CREATE_INT ('/DAV/sys_http_recording/', '110100000NN', 'dav', 'dav', 'dav', null, 
	  0, 0, 0, http_dav_uid (), http_admin_gid ()) as integer);
	  if(result < 0) 
	    {
	      signal ('VSPX9', 'Can not create /DAV/sys_http_recording/ directory');
	      return;
	    }
	}
      result := cast (DB.DBA.DAV_RES_UPLOAD_STRSES_INT (name, content,'text/html','110100000NN','dav','dav', 'dav', null, 
	0, now (), now (), null, http_dav_uid (), http_admin_gid (), 0) as integer);
      if (result < 0) 
	{
	  signal ('VSPX9', 'Can not upload resource into /DAV/sys_http_recording/ directory');
	}
    }
}
;

-- helper procedures for index.vspx in blogs
create procedure
cal_icell (inout control vspx_control, in inx int)
{
  return (control.vc_parent as vspx_row_template).te_rowset[inx];
}
;

grant execute on  vspx_event  to public
;

grant execute on  vspx_control  to public
;

grant execute on  vspx_attribute  to public
;

grant execute on  vspx_page  to public
;

grant under on vspx_page to public
;

grant execute on  vspx_row_template  to public
;

grant execute on  vspx_form  to public
;

grant execute on  vspx_tab  to public
;

grant execute on  vspx_template  to public
;

grant execute on  vspx_update_form  to public
;

grant execute on  vspx_login_form  to public
;

grant execute on  vspx_field  to public
;

grant execute on  vspx_column  to public
;

grant execute on  vspx_update_field  to public
;

grant execute on  vspx_isql  to public
;

grant execute on  vspx_text  to public
;

grant execute on  vspx_textarea  to public
;

grant execute on  vspx_label  to public
;

grant execute on  vspx_check_box  to public
;

grant execute on  vspx_radio_button  to public
;

grant execute on  vspx_radio_group  to public
;

grant execute on  vspx_url  to public
;

grant execute on  vspx_button  to public
;

grant execute on  vspx_submit  to public
;

grant execute on  vspx_logout_button  to public
;

grant execute on  vspx_return_button  to public
;

grant execute on  vspx_delete_button  to public
;

grant execute on  vspx_calendar  to public
;

grant execute on  vspx_validator  to public
;

grant execute on  vspx_range_validator  to public
;

grant execute on  vspx_data_set  to public
;

grant execute on  vspx_data_source  to public
;

grant execute on  vspx_data_grid  to public
;

grant execute on  vspx_select_list  to public
;

grant execute on  vspx_data_list  to public
;

grant execute on  vspx_login  to public
;

grant execute on  vspx_browse_button  to public
;

grant execute on  vspx_tree  to public
;

grant execute on  vspx_tree_node  to public
;

grant execute on  vspx_vscx  to public
;

create table VSPX_CUSTOM_CONTROL
	(
	VCC_TAG_NAME varchar not null primary key,
	VCC_CLASS    varchar not null,
	VCC_FUNCTION varchar not null
	)
;

--!AWK PUBLIC
create procedure VSPX_CONTROL_EXISTS (in name varchar)
  {
    --dbg_obj_print ('vcc_exists: ', name);
    if (exists (select 1 from VSPX_CUSTOM_CONTROL
    where VCC_TAG_NAME = name and __proc_exists (VCC_FUNCTION)))
      return 1;
    return null;
  }
;

grant execute on VSPX_CONTROL_EXISTS to public
;

--!AWK PUBLIC
create procedure VSPX_CUSTOM_CLASS_NAME (in name varchar)
  {
    declare class_name varchar;
    select VCC_CLASS into class_name from VSPX_CUSTOM_CONTROL where VCC_TAG_NAME = name;
    return class_name;
  }
;

grant execute on VSPX_CUSTOM_CLASS_NAME to public
;

--!AWK PUBLIC
create procedure VSPX_CLASS_PARSER (in name varchar, in tag any)
  {
    declare fn varchar;
    declare ss any;
    select VCC_FUNCTION into fn from VSPX_CUSTOM_CONTROL where VCC_TAG_NAME = name;
    ss := string_output ();
    call (fn) (tag, ss);
    return string_output_string (ss);
  }
;

grant execute on VSPX_CLASS_PARSER to public
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME) values
	('http://www.openlinksw.com/vspx/:vcc_exists', 'DB.DBA.VSPX_CONTROL_EXISTS')
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME) values
	('http://www.openlinksw.com/vspx/:vcc_instantiate', 'DB.DBA.VSPX_CLASS_PARSER')
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME) values
	('http://www.openlinksw.com/vspx/:vcc_class_name', 'DB.DBA.VSPX_CUSTOM_CLASS_NAME')
;


xpf_extension ('http://www.openlinksw.com/vspx/:vcc_exists', 'DB.DBA.VSPX_CONTROL_EXISTS', 0)
;

xpf_extension ('http://www.openlinksw.com/vspx/:vcc_instantiate', 'DB.DBA.VSPX_CLASS_PARSER', 0)
;

xpf_extension ('http://www.openlinksw.com/vspx/:vcc_class_name', 'DB.DBA.VSPX_CUSTOM_CLASS_NAME', 0)
;


create procedure
VSPX_REGISTER_CONTROL (in tag varchar, in class_name varchar, in func varchar)
  {
    insert replacing VSPX_CUSTOM_CONTROL (VCC_TAG_NAME, VCC_CLASS, VCC_FUNCTION)
    values (tag, class_name, func);
  }
;


--!AWK PUBLIC
create procedure
vspx_sid_generate ()
{
  declare tim, ip, path varchar;
  tim := datestring (now ());
  ip := http_client_ip ();
  if (is_http_ctx ())
    path := http_path ();
  else
    path := '';
  return md5 (concat (tim, ip, path));
}
;


create procedure vspx_label_render (in fmt varchar, in val any)
{
  if (length (fmt))
    http (sprintf (fmt, val));
  else
    http_value (val);
}
;

create procedure vspx_url_render (in fmt varchar, in val any, in url any, in sid any, in realm any, in is_local any)
{
  if (length (sid))
    {
      declare uinfo any;
      uinfo := WS.WS.PARSE_URI (url);
      if (uinfo[0] = '' or is_local = 1)
        url := vspx_uri_add_parameters (url, sprintf ('sid=%U&realm=%U', sid, realm));
    }
  http (sprintf ('<a href="%V">', url));
  if (length (fmt))
    http (sprintf (fmt, val));
  else
    http_value (val);
  http ('</a>');
}
;

create procedure vspx_url_render_ex (in fmt varchar, in val any, in url any, in sid any, in realm any, in is_local any, in attrs any)
{
  declare i, l int;
  if (length (sid))
    {
      declare uinfo any;
      uinfo := WS.WS.PARSE_URI (url);
      if (uinfo[0] = '' or is_local = 1)
        url := vspx_uri_add_parameters (url, sprintf ('sid=%U&realm=%U', sid, realm));
    }
  http (sprintf ('<a href="%V"', url));
  i := 1; l := length (attrs);
  while (i < l)
    {
      if (attrs[i-1] <> '@@hidden@@')
        {
	  http (' ' || attrs[i-1] || '="');
	  http_value (attrs[i]);
	  http ('"');
        }

      i := i + 2;
    }
  http ('>');
  if (length (fmt))
    http (sprintf (fmt, val));
  else
    http_value (val);
  http ('</a>');
}
;

--!AWK PUBLIC
create procedure VSPX_ONE_CONTROL_UP (in expn varchar)
{
  declare idx integer;
  declare hit1, hit2 any;
  expn := concat (' ', expn, ' ');
  idx := 0;
again:
  hit1 := regexp_parse ('([^a-zA-Z0-9_"])(control)([^a-zA-Z0-9_])', expn, idx);
  if (hit1 is NULL)
    return subseq (expn, 1, length (expn) - 1);
  hit2 := regexp_parse ('([^a-zA-Z0-9_"])(control[ \t\r\n]*\.[ \t\r\n]*vc_parent)([^a-zA-Z0-9_])', expn, idx);
  if (hit2 is NULL)
    return '';
  if (aref (hit2, 0) <> aref (hit1, 0))
    return '';
  expn :=
    concat (
      subseq (expn, 0, aref (hit2, 4)),
      'control',
      subseq (expn, aref (hit2, 5)) );
  idx := aref (hit2, 4) + 7;
  goto again;
}
;

grant execute on VSPX_ONE_CONTROL_UP to public
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME) VALUES ('http://www.openlinksw.com/vspx/:one-control-up', 'DB.DBA.VSPX_ONE_CONTROL_UP')
;

xpf_extension ('http://www.openlinksw.com/vspx/:one-control-up', 'DB.DBA.VSPX_ONE_CONTROL_UP', 0)
;

create procedure VSPX_USER_LOGIN (in realm varchar, in uname varchar, in pass varchar, in auth_function varchar)
{
  declare rc int;
  declare sid any;

  sid := null;
  rc := call (auth_function) (uname, pass);
  if (rc)
    {
      sid := md5 (concat (datestring (now ()), client_attr ('client_ip')));
      insert into VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY) values (realm, sid, uname, null, now());
    }
  return sid;
}
;

create procedure VSPX_SESSION_IS_VALID (in realm varchar, in sid varchar)
{
  update VSPX_SESSION set VS_EXPIRY = now () where VS_SID = sid and VS_REALM = realm;
  if (row_count () = 0)
    return 0;
  return 1;
}
;
