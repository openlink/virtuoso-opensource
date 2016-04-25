--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

--drop table urilbl_complete_lookup_2;

EXEC_STMT (
'create table
urilbl_complete_lookup_2 (
  ull_label_lang varchar,
  ull_label_ruined varchar,
  ull_iid iri_id_8,
  ull_label varchar,
  primary key (ull_label_ruined, ull_iid))', 0);

EXEC_STMT ('alter index urilbl_complete_lookup_2 on urilbl_complete_lookup_2 partition (ull_label_ruined varchar (6,0hexffff))', 0);

EXEC_STMT (
'create table
urilbl_cpl_log (
  ullog_ts timestamp,
  ullog_msg varchar,
  primary key (ullog_ts, ullog_msg))', 0);

EXEC_STMT ('create table fct_state (fct_sid int primary key, fct_state xmltype)', 0);

EXEC_STMT ('alter index fct_state on fct_state partition (fct_sid int)', 0);

EXEC_STMT ('create table fct_log (
  fl_sid int,
  fl_ts timestamp,
  fl_cli_ip varchar,
  fl_where varchar,
  fl_state xmltype,
  fl_cmd varchar,
  fl_sqlstate varchar,
  fl_sqlmsg varchar,
  fl_parms varchar,
  fl_msec int,
  primary key (fl_sid, fl_ts))', 0);

EXEC_STMT ('alter index fct_log on fct_log partition (fl_sid int)', 0);

EXEC_STMT ('create table fct_stored_qry (
  fsq_id int identity,
  fsq_created timestamp,
  fsq_title varchar,
  fsq_expln varchar,
  fsq_state xmltype,
  fsq_featured int,
  primary key (fsq_id))', 0);

EXEC_STMT ('alter index fct_stored_qry on fct_stored_qry partition (fsq_id int)',0);

EXEC_STMT ('create index fsq_featured_ndx on fct_stored_qry (fsq_featured, fsq_id) partition',0);

sequence_next ('fct_seq');
