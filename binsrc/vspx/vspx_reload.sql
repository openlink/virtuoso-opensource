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
drop type vspx_calendar;
drop type vspx_data_source;
drop type vspx_row_template;
drop type vspx_tab;
drop type vspx_template;
drop type vspx_update_form;
drop type vspx_login_form;
drop type vspx_update_field;
drop type vspx_dsedit_form;
drop type vspx_isql;
drop type vspx_textarea;
drop type vspx_text;
drop type vspx_label;
drop type vspx_check_box;
drop type vspx_radio_button;
drop type vspx_radio_group;
drop type vspx_url;
drop type vspx_submit;
drop type vspx_logout_button;
drop type vspx_return_button;
drop type vspx_delete_button;
drop type vspx_range_validator;
drop type vspx_validator;
drop type vspx_data_set;
drop type vspx_data_grid;
drop type vspx_data_list;
drop type vspx_select_list;
drop type vspx_login;
drop type vspx_browse_button;
drop type vspx_tree;
drop type vspx_tree_node;
drop type vspx_button;
drop type vspx_column;
drop type vspx_field;
drop type vspx_form;
drop type vspx_event;
drop type vspx_page;
drop type vspx_control;
drop type vspx_attribute;
drop procedure vspx_print_html_attrs;
drop procedure vspx_get_compiler_signature;
drop procedure vspx_make_temp_names;
drop function vspx_make_vspxm;
drop procedure vspx_make_sql;
drop procedure vspx_load_sql;
drop procedure vspx_src_get;
drop procedure vspx_src_store;
drop procedure vspx_base_url;
drop procedure vsxp_src_stat;
drop function vspx_get_class_name;
drop procedure vspx_dispatch;
drop procedure vspx_verify_pass;
drop procedure vspx_get_cookie_vec;
drop procedure vspx_do_compact;
drop procedure VSPX_COLUMNS_META;
drop procedure VSPX_COLUMNS_META_TYPES;
drop procedure dbg_vspx_control;
drop procedure VSPX_EXPIRE_SESSIONS;
drop table VSPX_SESSION;
load vspx.sql;
