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

load bmk-a-wa.sql;
load bmk-a-table.sql;
load bmk-a-code.sql;

-- End --------------------------------------------------------------------
echoln "Job finished on " $YYYYMMDD " at " $HHMMSS;
echoln "-------------------------------------------";
echoln "Check file 'errors.out' in current directory";
echoln "for possible errors during installation.";
echoln "";
