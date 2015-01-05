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
USER_CREATE ('FORI', 'fori', vector ('DISABLED', 0));
SET USER GROUP FORI DBA;
USER_SET_QUALIFIER ('FORI' , 'FORI');

drop table FORI.FORI.AUTHORS;
drop table FORI.FORI.MESSAGES;
drop table FORI.FORI.FORUMS;
drop table FORI.FORI.SESSIONS;

VHOST_DEFINE (lpath=>'/forums',
	      ppath=>'/forums/',
	      def_page=>'home.vsp',
	      is_brws=>0,
	      vsp_user=>'FORI',
	      ppr_fn=>'FORI.FORI.SESSION_SAVE',
	      auth_fn=>'FORI.FORI.SESS_RESTORE',
	      ses_vars=>1);

CREATE TABLE FORI.FORI.AUTHORS ( AUTHOR_ID   INTEGER,
                       AUTHOR_NICK VARCHAR(20) NOT NULL,
                       E_MAIL      VARCHAR(50),
                       FIRST_NAME  VARCHAR(100),
                       FATHER_NAME VARCHAR(100),
                       AUTH_PASD   VARCHAR,
                       LAST_LOGIN  DATETIME,
                       PRIMARY KEY (AUTHOR_ID));

CREATE UNIQUE INDEX U_AUTHOR_NICK ON FORI.FORI.AUTHORS (AUTHOR_NICK);

CREATE TABLE FORI.FORI.MESSAGES (MSG_ID INTEGER,
                        ANS_NUM      INTEGER,
                        LAST_VISIT   INTEGER,
                        PARENT_ID    INTEGER,
                        AUTHOR_ID    INTEGER,
                        FORUM_ID     INTEGER,
                        MSG_TEXT     LONG VARCHAR,
                        TIME_CHANGED DATETIME,
                        PRIMARY KEY  (MSG_ID));

CREATE TEXT XML INDEX ON FORI.FORI.MESSAGES(MSG_TEXT) WITH KEY MSG_ID;
CALL DB.DBA.VT_BATCH_UPDATE('FORI.FORI.MESSAGES','ON',1);
CALL FORI.FORI.VT_INDEX_FORI_FORI_MESSAGES(0);


CREATE TABLE FORI.FORI.FORUMS   (FORUM_ID INTEGER,
                        FORUM_DESC  VARCHAR(500),
                        PARENT_ID   INTEGER DEFAULT NULL,
                        PRIMARY KEY (FORUM_ID) );

ALTER TABLE FORI.FORI.MESSAGES ADD FOREIGN KEY (AUTHOR_ID) REFERENCES FORI.FORI.AUTHORS (AUTHOR_ID) ;
ALTER TABLE FORI.FORI.MESSAGES ADD FOREIGN KEY (FORUM_ID) REFERENCES FORI.FORI.FORUMS (FORUM_ID) ;
ALTER TABLE FORI.FORI.MESSAGES ADD FOREIGN KEY (PARENT_ID) REFERENCES FORI.FORI.MESSAGES (MSG_ID) ;
ALTER TABLE FORI.FORI.FORUMS ADD FOREIGN KEY (PARENT_ID) REFERENCES FORI.FORI.FORUMS (FORUM_ID);


CREATE TABLE FORI.FORI.SESSIONS(SID VARCHAR(32) NOT NULL,
                       USER_ID      INTEGER     NOT NULL,
                       LOGIN_TIME   DATETIME    NOT NULL,
                       EXPIRE_TIME  DATETIME    NOT NULL,
                       IP_ADDR      VARCHAR(50),
		       SES_VARS     LONG VARCHAR,
                       PRIMARY KEY  (SID));

sequence_set('seq_msg_id',1,0);
sequence_set('seq_author_id',1,0);
registry_set ('app_forums_xslt_location','/xslt/tutorials/forums');

insert soft SYS_SCHEDULED_EVENT (SE_NAME, SE_INTERVAL, SE_SQL, SE_START)
    values ('FORUMS sessions reaper', 10, 'FORI.FORI.SESS_EXPIRE_OLD ()', now ())
;


INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(1,'Hot themes',NULL);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(7,'Merry Chrustmas',1);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(8,'Family doctor',1);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(9,'Vacations',1);

INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(2,'Computers and Internet',NULL);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(10,'3D',2);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(11,'Linux',2);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(12,'Macintosh',2);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(13,'Internet',2);

INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(3,'Culture and Art',NULL);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(14,'Theatre',3);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(15,'Cinema',3);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(16,'Arts',3);

INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(4,'Science',NULL);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(17,'Math',4);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(18,'Physics',4);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(19,'Opinions',4);

INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(5,'Sport',NULL);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(20,'Football',5);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(21,'Basketball',5);
INSERT INTO FORI.FORI.FORUMS(FORUM_ID, FORUM_DESC, PARENT_ID) VALUES(22,'Formula 1',5);

