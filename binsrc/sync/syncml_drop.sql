--
--  $Id$
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

-- Tables
syncml_exec_no_error ('drop table DB.DBA.SYNC_SESSION');
syncml_exec_no_error ('drop table DB.DBA.SYNC_RPLOG');
syncml_exec_no_error ('drop table DB.DBA.SYNC_COLS_TYPES');
syncml_exec_no_error ('drop table DB.DBA.SYNC_ANCHORS');
syncml_exec_no_error ('drop table DB.DBA.SYNC_MAPS');
syncml_exec_no_error ('drop table DB.DBA.SYNC_DEVICES');

-- Triggers
syncml_exec_no_error ('drop trigger WS.WS.SRLOG_SYS_DAV_RES_I');
syncml_exec_no_error ('drop trigger WS.WS.SRLOG_SYS_DAV_RES_D');
syncml_exec_no_error ('drop trigger WS.WS.SRLOG_SYS_DAV_RES_U');

-- Types
syncml_exec_no_error ('drop type DB.DBA.sync_batch');
syncml_exec_no_error ('drop type DB.DBA.sync_cmd');

-- Procedures
syncml_exec_no_error ('drop procedure DB.DBA.sync_handle_request');
syncml_exec_no_error ('drop procedure DB.DBA.SYNCML');
syncml_exec_no_error ('drop procedure DB.DBA.sync_define_xsl');
syncml_exec_no_error ('drop procedure DB.DBA.sync_define_xml_to_pl');
syncml_exec_no_error ('drop procedure DB.DBA.sync_date_nokia');
syncml_exec_no_error ('drop procedure DB.DBA.sync_create_col');
syncml_exec_no_error ('drop procedure DB.DBA.sync_datastore_vcard_12');
syncml_exec_no_error ('drop procedure DB.DBA.sync_datastore_vcard_11');
syncml_exec_no_error ('drop procedure DB.DBA.sync_datastore_vcalendar_11');
syncml_exec_no_error ('drop procedure DB.DBA.sync_datastore_vcalendar_12');
syncml_exec_no_error ('drop procedure DB.DBA.sync_datastore_vcard_11_test');
syncml_exec_no_error ('drop procedure DB.DBA.sync_xml_to_node');
syncml_exec_no_error ('drop procedure DB.DBA.SYNC_GET_AUTH_TYPE');
syncml_exec_no_error ('drop procedure DB.DBA.SYNC_MAKE_DAV_DIR');
syncml_exec_no_error ('drop procedure DB.DBA.sync_parse_in_data_get_prop');
syncml_exec_no_error ('drop procedure DB.DBA.sync_pars_mult');
syncml_exec_no_error ('drop procedure DB.DBA.sync_pars_vcard_int');
syncml_exec_no_error ('drop procedure DB.DBA.sync_parse_in_data');
syncml_exec_no_error ('drop procedure DB.DBA.sync_parse_in_data_get_long');
syncml_exec_no_error ('drop procedure DB.DBA.sync_parse_in_data_note');
syncml_exec_no_error ('drop procedure DB.DBA.sync_recode');
syncml_exec_no_error ('drop procedure DB.DBA.sync_pars_ical_int');
syncml_exec_no_error ('drop procedure DB.DBA.sync_pars_mult_cal');
syncml_exec_no_error ('drop procedure DB.DBA.yac_syncml_detect');
syncml_exec_no_error ('drop procedure DB.DBA.yac_syncml_type');
syncml_exec_no_error ('drop procedure DB.DBA.yac_syncml_version');
syncml_exec_no_error ('drop procedure DB.DBA.yac_syncml_version_get');
syncml_exec_no_error ('drop procedure DB.DBA.yac_syncml_type_get');
syncml_exec_no_error ('drop procedure DB.DBA.yac_syncml_update_type');
