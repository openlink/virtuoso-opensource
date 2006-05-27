------------------------------------------------------------------------------
-- bmk-d.sql
-- script for cleaning wa instalation.
-- Copyright (C) 2004 OpenLink Software
------------------------------------------------------------------------------

-- Scheduler
BMK.WA.exec_no_error('DELETE FROM DB.DBA.SYS_SCHEDULED_EVENT WHERE SE_NAME = \'BM tags aggregator\'');

-- Triggers
BMK.WA.exec_no_error('DROP TDRIGGER WA_MEMBER_AU_BMK');

-- Tables
BMK.WA.exec_no_error('DROP VIEW  BMK.DBA.TAGS_STATISTICS');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.SETTINGS');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.TAGS');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.BOOKMARK_DATA');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.BOOKMARK_DOMAIN');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.SFOLDER');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.FOLDER');
BMK.WA.exec_no_error('DROP TABLE BMK.WA.BOOKMARK');

-- Types
BMK.WA.exec_no_error('delete from WA_TYPES where WAT_NAME = \'bookmark\'');
BMK.WA.exec_no_error('drop type wa_bookmark');

-- Procedures
create procedure BMK.WA.drop_procedures()
{
  for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like 'BMK.WA.%') do {
    if (P_NAME not in ('BMK.WA.exec_no_error', 'BMK.WA.drop_procedures'))
      BMK.WA.exec_no_error(sprintf('drop procedure %s', P_NAME));
  }
}
;

-- dropping procedures for BMK
BMK.WA.drop_procedures();

BMK.WA.exec_no_error('DROP procedure BMK.WA.drop_procedures');
BMK.WA.exec_no_error('DROP procedure BMK.WA.exec_no_error');
