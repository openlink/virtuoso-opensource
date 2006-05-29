-- ------------------------------------------------------------------------
-- install.sql
-- Main instalation script.
-- Copyright (C) 2004 OpenLink Software
-- ------------------------------------------------------------------------

-- Start of instalation ---------------------------------------------------
echoln "";
echoln "Job started on " $YYYYMMDD " at " $HHMMSS;
echoln "-------------------------------------------";
echoln "";

load exec_no_error.sql;
load tables.sql;
load procedures.sql;
load wa_install.sql;

DB.DBA.community_install();

-- End --------------------------------------------------------------------
echoln "Job finished on " $YYYYMMDD " at " $HHMMSS;
echoln "-------------------------------------------";
echoln "Check file 'errors.out' in current directory";
echoln "for possible errors during installation.";
echoln "";
