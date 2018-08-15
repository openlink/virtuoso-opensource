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


create procedure nntpf_exec_no_error(in expr varchar) {
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;


nntpf_exec_no_error ('create table NNTPFE_USERRSSFEEDS (
	FEURF_ID	varchar primary key not NULL,
	FEURF_USERID	integer references SYS_USERS (U_ID) on delete cascade,
	FEURF_PARAM	any,
	FEURF_DESCR	varchar,	-- user-supplied desc of the feed
	FEURF_URL	varchar		-- URL to the feed (search results or group)
)')
;

nntpf_exec_no_error ('create table NNFE_THR (
	FTHR_GROUP		integer,
	FTHR_MESS_ID		varchar,
	FTHR_DATE		datetime,
	FTHR_TOP		integer,
	FTHR_REFER		varchar,
	FTHR_SUBJ		varchar,
	FTHR_UID		integer,
	FTHR_MESS_DETAILS	any,
	FTHR_TOPIC_ID		varchar,
	FTHR_FROM		varchar,
	primary key (FTHR_MESS_ID, FTHR_GROUP)
)')
;

wa_add_col('DB.DBA.NNFE_THR', 'FTHR_TOPIC_ID', 'varchar');
wa_add_col('DB.DBA.NNFE_THR', 'FTHR_FROM', 'varchar');

nntpf_exec_no_error (
'create table NNTPF_SUBS
       (
	 NS_USER int,		 -- U_ID
         NS_MAIL varchar,	 -- email address
	 NS_GROUP int, 		 -- NG_GROUP
         NS_THREAD_ID varchar,   -- NM_ID
         NS_TYPE int,		 -- flag digest or not
	 NS_TS datetime,	 -- last batch
	 NS_DIGEST int default 1, -- next digest number
	 NS_SUB_TS timestamp,
         primary key (NS_USER, NS_GROUP, NS_THREAD_ID, NS_MAIL)
       )')
;

nntpf_exec_no_error ('create index IN_FTHR_UID on NNFE_THR (FTHR_UID)')
;

nntpf_exec_no_error ('create index IN_FTHR_SUBJ on NNFE_THR (FTHR_SUBJ)')
;

nntpf_exec_no_error ('create index NNFE_THR_DATE_IDX on NNFE_THR (FTHR_GROUP, FTHR_TOP, FTHR_DATE)')
;

-- the external links
nntpf_exec_no_error ('create table NNTPF_MSG_LINKS (NML_MSG_ID varchar, NML_URL varchar, primary key (NML_MSG_ID, NML_URL))')
;
-- procedure view nntpf_group_list_v UPDATED
nntpf_exec_no_error ('drop view nntpf_group_list_v')
;
nntpf_exec_no_error ('create procedure view nntpf_group_list_v as nntpf_group_list (_group, _fordate, _len)
	(_date datetime, _from varchar, _subj varchar, _nm_id varchar)')
;

nntpf_exec_no_error ('create procedure view nntpf_search_result_v as nntpf_search_result (_str)
	(_date varchar, _from varchar, _subj varchar, _nm_id varchar, _grp_list varchar)')
;

--VHOST_REMOVE (lpath=>'/nntpf');

--VHOST_DEFINE (lpath=>'/nntpf', ppath=>'/nntpf/', def_page=>'nntpf_main.vspx', vsp_user => 'dba');
