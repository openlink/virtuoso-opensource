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

load omail-wa-install.sql;

load res/res-create-tables.sql;

load res/res-create-code.sql;
load res/res-create-code-data.sql;

load utl/utl-create-code.sql;

load eml/eml-create-tables.sql;
load eml/eml-create-code.sql;

OMAIL.WA.omail_install();

-- End --------------------------------------------------------------------
echoln "Job finished on " $YYYYMMDD " at " $HHMMSS;
echoln "-------------------------------------------";
echoln "Check file 'errors.out' in current directory";
echoln "for possible errors during installation.";
echoln "";
