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

load create_tables.sql;
load procedures/exec_no_error.sql;
load procedures/types.sql;
load procedures/common.sql;
load procedures/procedures.sql;
load procedures/images.sql;
load procedures/dav_api.sql;
load procedures/comments.sql;
load photo-wa-install.sql;


PHOTO.WA.photo_install();

-- End --------------------------------------------------------------------
echoln "Job finished on " $YYYYMMDD " at " $HHMMSS;
echoln "-------------------------------------------";
echoln "Check file 'errors.out' in current directory";
echoln "for possible errors during installation.";
echoln "";
