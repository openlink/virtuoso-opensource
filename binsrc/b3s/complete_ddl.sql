--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2009 OpenLink Software
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

drop table urilbl_complete_lookup_2;

create table
urilbl_complete_lookup_2 (
  ull_label_lang varchar,
  ull_label_ruined varchar,
  ull_iid iri_id_8,
  ull_label varchar,
  primary key (ull_label_ruined, ull_iid));

alter index urilbl_complete_lookup_2 on urilbl_complete_lookup_2 partition (ull_label_ruined varchar (6,0hexffff));

create table 
urilbl_cpl_log (
  ullog_ts timestamp,
  ullog_msg varchar,
  primary key (ullog_ts, ullog_msg));

