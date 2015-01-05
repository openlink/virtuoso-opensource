--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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

drop table sec_log;
drop table REPORT;
drop table NEED_TO_KNOW;


create table sec_log (sl_user varchar, sl_logged_in datetime,
		      sl_logged_out datetime, primary key (sl_user, sl_logged_in));
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': creating security log table STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';


CREATE TABLE REPORT (R_AUTHOR VARCHAR, R_ID INTEGER IDENTITY, R_CLASS INTEGER, R_TEXT LONG VARCHAR,
		     PRIMARY KEY (R_ID));
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': creating REPORT table STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

CREATE TABLE NEED_TO_KNOW (NK_CLASS INTEGER, NK_USER INTEGER,
			   PRIMARY KEY (NK_CLASS, NK_USER));
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': creating NEED_TO_KNOW table STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

create user U;
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': creating USER U STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

create user MANAGER;
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': creating USER MANAGER STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

create user NOGO;
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': creating USER NOGO STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

create user OUTSIDER;
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': creating USER OUTSIDER STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

grant select on REPORT to U, MANAGER, OUTSIDER;
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': grant select on REPORT to U, MANAGER and OUTSIDER STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

delete from sec_log;
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': cleaning up the sec_log table STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

delete from REPORT;
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': cleaning up the REPORT table STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

delete from NEED_TO_KNOW;
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': cleaning up the NEED_TO_KNOW table STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

insert into NEED_TO_KNOW (NK_CLASS, NK_USER)
    values (1, (select U_ID from SYS_USERS where U_NAME = 'MANAGER'));
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': enable MANAGER to see Reports class 1 STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

insert into NEED_TO_KNOW (NK_CLASS, NK_USER)
    values (2, (select U_ID from SYS_USERS where U_NAME = 'MANAGER'));
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': enable MANAGER to see Reports class 2 STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

insert into NEED_TO_KNOW (NK_CLASS, NK_USER)
    values (2, (select U_ID from SYS_USERS where U_NAME = 'U'));
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': enable U to see Reports class 2 STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

insert into NEED_TO_KNOW (NK_CLASS, NK_USER)
    values (3, (select U_ID from SYS_USERS where U_NAME = 'MANAGER'));
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': enable MANAGER to see Reports class 3 STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

insert into NEED_TO_KNOW (NK_CLASS, NK_USER)
    values (3, (select U_ID from SYS_USERS where U_NAME = 'U'));
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': enable U to see Reports class 3 STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

insert into NEED_TO_KNOW (NK_CLASS, NK_USER)
    values (3, (select U_ID from SYS_USERS where U_NAME = 'OUTSIDER'));
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': enable OUTSIDER to see Reports class 3 STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

insert into REPORT (R_AUTHOR, R_CLASS, R_TEXT) values ('MANAGER', 1, 'sensitive');
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': create Report class 1 STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

insert into REPORT (R_AUTHOR, R_CLASS, R_TEXT) values ('U', 2, 'vital');
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': create Report class 2 STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

insert into REPORT (R_AUTHOR, R_CLASS, R_TEXT) values ('OUTSIDER', 3, 'advertising');
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': create Report class 3 STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';


create procedure DB.DBA.DBEV_PREPARE (inout tree any)
{
	declare uid integer;
  uid := (select U_ID from SYS_USERS where U_NAME = user);
  need_to_know (uid, tree);
  dbg_obj_print ('compiled by ', user, ': ', tree);
}
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': create prepare hook STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';



create procedure DBEV_CONNECT ()
{
  dbg_obj_print (user, ' connected');
  if (user = 'NOGO')
    signal ('EAUTH', '	External authorization failed');
  insert into sec_log (sl_user, sl_logged_in) values (user, curdatetime ());
  connection_set ('login_time', curdatetime ());
}
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': create connect hook STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';




create procedure DB.DBA.DBEV_DISCONNECT ()
{
  declare ctime datetime;
  dbg_obj_print (user, ' disconnected');
  ctime := connection_get ('login_time');
  update sec_log set sl_logged_out = now () where
    sl_user = user and sl_logged_in = ctime;
  if (row_count () = 0)
    signal ('ELOGO', 'Logout by user with no login record. This occurs when DBEV_CONNECT denied permission');
}
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': create disconnect hook STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';


create procedure DB.DBA.DBEV_STARTUP ()
{
  dbg_obj_print (' server started ');
}
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': create startup hook STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';


create procedure DB.DBA.DBEV_SHUTDOWN ()
{
  dbg_obj_print (' server shut down.');
  update sec_log set sl_logged_out = now () where sl_logged_out is null;
}
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
ECHO BOTH ': create shutdown hook STATE=' $STATE ' MESSAGE=' $MESSAGE '\n';

