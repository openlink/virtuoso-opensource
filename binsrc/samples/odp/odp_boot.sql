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
--  
create user "ODP";

DB.DBA.USER_SET_QUALIFIER ('ODP', 'ODP');

create procedure ODP.ODP.CODE_VERSION () returns varchar
{
  return '0.1.001011A';
}
;

create procedure ODP.ODP.RECREATE_TABLES () returns varchar
{
  DB.DBA.RDF_RECREATE_TABLE ('ODP.ODP.CONFIG', concat(
	'	PARAM		varchar, ',
	'	VALUE		varchar, ',
	'	primary key (PARAM) ' ) );
  DB.DBA.RDF_RECREATE_TABLE ('ODP.ODP.SOURCE', concat(
	'	ID		integer, ',
	'	NAME		varchar, ',
	'	LOADPATH	varchar, ',
	'	VERSION		varchar, ',
	'	REFILL_STATUS	 varchar, ',
	'	REFILL_ERROR	varchar, ',
	'	ERROR_VERSION	varchar, ',
	'	ORIG_DATA	long varchar identified by NAME, ',
	'	primary key (ID) ' ) );
  DB.DBA.RDF_RECREATE_NODEID_TABLE ('ODP.ODP.TOPIC');
  DB.DBA.RDF_RECREATE_NODEID_TABLE ('ODP.ODP.PAGE');
  DB.DBA.RDF_RECREATE_NODEID_TABLE ('ODP.ODP.EDITOR');
  DB.DBA.RDF_RECREATE_NODEID_TABLE ('ODP.ODP.ALIAS');
  DB.DBA.RDF_RECREATE_XPER_TABLE ('ODP.ODP.TOPIC_CONTENT', 1, 'ON', 30);
  DB.DBA.RDF_RECREATE_XPER_TABLE ('ODP.ODP.TOPIC_STRUCTURE', 1, 'ON', 30);
  DB.DBA.RDF_RECREATE_XPER_TABLE ('ODP.ODP.TOPIC_TERM', 1, 'ON', 30);
  DB.DBA.RDF_RECREATE_XPER_TABLE ('ODP.ODP.EDITOR_PROFILE', 1, 'ON', 30);
  DB.DBA.RDF_RECREATE_TABLE ('ODP.ODP.TOPIC_REDIRECT', concat(
	'	NODEID		integer, ',
	'	JUMPTO		integer, ',
	'	primary key (NODEID) ' ) );
  DB.DBA.RDF_RECREATE_TABLE ('ODP.ODP.TOPIC_BRIEFNAME', concat(
	'	NODEID		integer, ',
	'	BRIEFNAME	varchar, ',
	'	primary key (NODEID) ' ) );
  DB.DBA.RDF_RECREATE_TABLE ('ODP.ODP.PAGE_TITLE', concat(
	'	NODEID		integer, ',
	'	TEXT		long varchar, ',
	'	primary key (NODEID) ' ) );
  DB.DBA.RDF_RECREATE_TABLE ('ODP.ODP.PAGE_DESCRIPTION', concat(
	'	NODEID		integer, ',
	'	TEXT		long varchar, ',
	'	primary key (NODEID) ' ) );
  DB.DBA.RDF_RECREATE_TABLE ('ODP.ODP.ALIAS_STRUCTURE', concat(
	'	NODEID		integer, ',
	'	TITLE		varchar, ',
	'	JUMPTO		integer, ',
	'	primary key (NODEID) ' ) );
}
;

create procedure ODP.ODP.RECREATE_INDEXES () returns varchar
{
  DB.DBA.RDF_EXEC_41000_I ('create text xml index on ODP.ODP.TOPIC_BRIEFNAME (BRIEFNAME) with key NODEID');
  DB.DBA.RDF_EXEC_41000_I ('create text index on ODP.ODP.PAGE_TITLE (TEXT) with key NODEID');
  DB.DBA.RDF_EXEC_41000_I ('create text index on ODP.ODP.PAGE_DESCRIPTION (TEXT) with key NODEID');
  DB.DBA.RDF_EXEC_41000_I ('DB.DBA.VT_BATCH_UPDATE(''ODP.ODP.TOPIC_BRIEFNAME'',''ON'',10)');
  DB.DBA.RDF_EXEC_41000_I ('DB.DBA.VT_BATCH_UPDATE(''ODP.ODP.PAGE_TITLE'',''ON'',10)');
  DB.DBA.RDF_EXEC_41000_I ('DB.DBA.VT_BATCH_UPDATE(''ODP.ODP.PAGE_DESCRIPTION'',''ON'',10)');
}
;

create procedure ODP.ODP.RECREATE_SCHEMA () returns varchar
{
  ODP.ODP.RECREATE_TABLES();
  ODP.ODP.RECREATE_INDEXES();
  return 'ODP schema created from scratch';
}
;

create procedure ODP.ODP.CREATE_SCHEMA () returns varchar
{
  if (exists (select KEY_TABLE from DB.DBA.SYS_KEYS where KEY_TABLE = 'ODP.ODP.CONFIG'))
    return 'Existing ODP schema detected';
  return ODP.ODP.RECREATE_SCHEMA ();
}
;

