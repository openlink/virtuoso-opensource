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

-- ------------------------------------------------------------------------
-- install.sql
-- Main installation script.
-- ------------------------------------------------------------------------

-- Start of installation ---------------------------------------------------
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
