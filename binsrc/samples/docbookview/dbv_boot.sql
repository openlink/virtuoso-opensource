create user "DBV";

DB.DBA.USER_SET_QUALIFIER ('DBV', 'DBV');

create procedure DBV.DBV.CODE_VERSION () returns varchar
{
  return '0.1.010316A';
}
;

create procedure DBV.DBV.RECREATE_TABLES () returns varchar
{
  DB.DBA.RDF_RECREATE_TABLE ('DBV.DBV.CONFIG', concat(
	'	PARAM		varchar, ',
	'	VALUE		varchar, ',
	'	primary key (PARAM) ' ) );
  DB.DBA.RDF_RECREATE_TABLE ('DBV.DBV.SOURCE', concat(
	'	ID		varchar, ',
	'	FULLNAME	varchar, ',
	'	PATH		varchar, ',
	'	NAME		varchar, ',
	'	TYPE		varchar, ',
	'	EXT		varchar, ',
	'	GRP		varchar, ',
	'	DTDNAME		varchar, ',
	'	REFILL_STATUS	varchar, ',
	'	REFILL_ERROR	varchar, ',
	'	ORIG_TEXT	long varchar identified by FULLNAME, ',
	'	ORIG_XML	long varchar identified by FULLNAME, ',
	'	HTML		long varchar, ',
	'	primary key (ID) ' ) );
}
;

create procedure DBV.DBV.RECREATE_INDEXES () returns varchar
{
  DB.DBA.RDF_EXEC_41000_I ('create text index on DBV.DBV.SOURCE (ORIG_TEXT) with key ID');
  DB.DBA.RDF_EXEC_41000_I ('DB.DBA.VT_BATCH_UPDATE(''DBV.DBV.SOURCE'',''ON'',10)');
}
;

create procedure DBV.DBV.RECREATE_SCHEMA () returns varchar
{
  DBV.DBV.RECREATE_TABLES();
  DBV.DBV.RECREATE_INDEXES();
  return 'DBV schema created from scratch';
}
;

create procedure DBV.DBV.CREATE_SCHEMA () returns varchar
{
  if (exists (select KEY_TABLE from DB.DBA.SYS_KEYS where KEY_TABLE = 'DBV.DBV.CONFIG'))
    return 'Existing DBV schema detected';
  return DBV.DBV.RECREATE_SCHEMA ();
}
;
