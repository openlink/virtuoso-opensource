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
-------------------------------------------------------------------------------
--
OMAIL.WA.exec_no_error (
 'create table OMAIL.WA.MESSAGES (
    DOMAIN_ID        INTEGER         NOT NULL,
    USER_ID          INTEGER         NOT NULL,
    MSG_ID           INTEGER         NOT NULL,
    FOLDER_ID        INTEGER         NOT NULL,
    PARENT_ID        INTEGER,
    FREETEXT_ID      INTEGER         NOT NULL,
    SRV_MSG_ID       VARCHAR(100),
    UNIQ_MSG_ID      VARCHAR(100),
    MSG_SOURCE       INTEGER,
    REF_ID           VARCHAR(1000),
    MSTATUS          INTEGER         NOT NULL,
    ATTACHED         INTEGER         NOT NULL,
    ADDRESS          LONG VARCHAR,
    RCV_DATE         DATETIME        NOT NULL,
    SND_DATE         DATETIME        NOT NULL,
    MHEADER          LONG VARCHAR,
    DSIZE            INTEGER         NOT NULL,
    PRIORITY         INTEGER         NOT NULL,
    SUBJECT          VARCHAR(255),
    ADDRES_INFO      VARCHAR(255)    NOT NULL,
    M_CONTENT        LONG VARCHAR,
    M_OPTIONS        LONG VARCHAR,
    M_RFC_ID         VARCHAR,
    M_RFC_HEADER     LONG VARCHAR,
    M_RFC_REFERENCES VARCHAR,

    PRIMARY KEY (DOMAIN_ID,USER_ID,MSG_ID)
  )'
)
;

OMAIL.WA.exec_no_error (
  'update DB.DBA.SYS_COLS set COL_PREC=1000 where "TABLE" = \'OMAIL.WA.MESSAGES\' and "COLUMN" = \'REF_ID\''
)
;

OMAIL.WA.exec_no_error (
  'alter table OMAIL.WA.MESSAGES add M_CONTENT LONG VARCHAR', 'C', 'OMAIL.WA.MESSAGES', 'M_CONTENT'
)
;

OMAIL.WA.exec_no_error (
  'alter table OMAIL.WA.MESSAGES add M_OPTIONS LONG VARCHAR', 'C', 'OMAIL.WA.MESSAGES', 'M_OPTIONS'
)
;

OMAIL.WA.exec_no_error (
  'alter table OMAIL.WA.MESSAGES add M_RFC_ID VARCHAR', 'C', 'OMAIL.WA.MESSAGES', 'M_RFC_ID'
)
;

OMAIL.WA.exec_no_error (
  'alter table OMAIL.WA.MESSAGES add M_RFC_HEADER LONG VARCHAR', 'C', 'OMAIL.WA.MESSAGES', 'M_RFC_HEADER'
)
;

OMAIL.WA.exec_no_error (
  'alter table OMAIL.WA.MESSAGES add M_RFC_REFERENCES VARCHAR', 'C', 'OMAIL.WA.MESSAGES', 'M_RFC_REFERENCES'
)
;

-------------------------------------------------------------------------------
--
OMAIL.WA.exec_no_error (
 'create table OMAIL.WA.MSG_PARTS (
    DOMAIN_ID   INTEGER         NOT NULL,
    USER_ID     INTEGER         NOT NULL,
    MSG_ID      INTEGER         NOT NULL,
    PART_ID     INTEGER         NOT NULL,
    FREETEXT_ID INTEGER         NOT NULL,
    TYPE_ID     INTEGER         NOT NULL,
    CONTENT_ID  VARCHAR(100),
    FNAME       VARCHAR(100),
    TDATA       LONG VARCHAR,
    BDATA       LONG VARBINARY,
    DSIZE       INTEGER         NOT NULL,
    PDEFAULT    INTEGER         NOT NULL,
    APARAMS     VARCHAR(1000),
    TAGS        VARCHAR(255),

    PRIMARY KEY (DOMAIN_ID,MSG_ID,USER_ID,PART_ID)
  )'
)
;

OMAIL.WA.exec_no_error (
  'alter table OMAIL.WA.MSG_PARTS add TAGS varchar(255)', 'C', 'OMAIL.WA.MSG_PARTS', 'TAGS'
)
;

-------------------------------------------------------------------------------
--
OMAIL.WA.exec_no_error (
 'create table OMAIL.WA.FOLDERS (
    DOMAIN_ID   integer         not null,
    USER_ID     integer         not null,
    FOLDER_ID   integer         not null,
    PARENT_ID   integer         default 0,
    SYSTEM_FLAG char(1)         default ''N'',
    SMART_FLAG  char(1)         default ''N'',
    SEQ_NO      integer,
    NAME        varchar         not null,
    PATH        varchar,
    DATA        long varchar,
    F_TYPE      varchar,
    F_SOURCE    integer,

    PRIMARY KEY (DOMAIN_ID,USER_ID,FOLDER_ID)
  )'
)
;

OMAIL.WA.exec_no_error (
  'alter table OMAIL.WA.FOLDERS add SYSTEM_FLAG char(1) default ''N''', 'C', 'OMAIL.WA.FOLDERS', 'SYSTEM_FLAG'
)
;

OMAIL.WA.exec_no_error (
  'alter table OMAIL.WA.FOLDERS add SMART_FLAG char(1) default ''N''', 'C', 'OMAIL.WA.FOLDERS', 'SMART_FLAG'
)
;

OMAIL.WA.exec_no_error (
  'alter table OMAIL.WA.FOLDERS add SEQ_NO integer', 'C', 'OMAIL.WA.FOLDERS', 'SEQ_NO'
)
;

OMAIL.WA.exec_no_error (
  'alter table OMAIL.WA.FOLDERS add PATH varchar', 'C', 'OMAIL.WA.FOLDERS', 'PATH'
)
;

OMAIL.WA.exec_no_error (
  'alter table OMAIL.WA.FOLDERS add DATA long varchar', 'C', 'OMAIL.WA.FOLDERS', 'DATA'
)
;

OMAIL.WA.exec_no_error (
  'alter table OMAIL.WA.FOLDERS add F_TYPE varchar', 'C', 'OMAIL.WA.FOLDERS', 'F_TYPE'
)
;

OMAIL.WA.exec_no_error (
  'alter table OMAIL.WA.FOLDERS add F_SOURCE integer', 'C', 'OMAIL.WA.FOLDERS', 'F_SOURCE'
)
;

OMAIL.WA.exec_no_error (
  'CREATE UNIQUE INDEX FOLDERS_NAME_ID ON OMAIL.WA.FOLDERS (DOMAIN_ID, USER_ID, PARENT_ID, NAME)'
)
;

OMAIL.WA.exec_no_error('
  create trigger FOLDERS_AI after insert on OMAIL.WA.FOLDERS referencing new as N {
    OMAIL.WA.folder_trigger (N.DOMAIN_ID, N.USER_ID, N.FOLDER_ID, N.PARENT_ID, N.NAME, N.F_TYPE);
  }
');

OMAIL.WA.exec_no_error('
  create trigger FOLDERS_AU after update on OMAIL.WA.FOLDERS referencing old as O, new as N {
    OMAIL.WA.folder_trigger (N.DOMAIN_ID, N.USER_ID, N.FOLDER_ID, N.PARENT_ID, N.NAME, N.F_TYPE);
  }
');

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_trigger (
  in _domain_id integer,
  in _user_id integer,
  in _folder_id integer,
  in _parent_id integer,
  in _name varchar,
  in _type varchar)
{
  declare _path varchar;

  _path := coalesce((select PATH from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and FOLDER_ID = _parent_id), '') || '/' || _name;

  set triggers off;
  update OMAIL.WA.FOLDERS
     set PATH = _path
   where DOMAIN_ID = _domain_id
     and USER_ID = _user_id
     and FOLDER_ID = _folder_id;
  OMAIL.WA.folder_paths (_domain_id, _user_id, _folder_id, _path);
  set triggers on;

  if (DB.DBA.is_empty_or_null (_type))
  {
    declare _type varchar;

    _type := '';
    if (ucase (_name) like 'INBOX%')
      _type := 'INBOX';

    if (ucase (_name) like 'TRASH%')
      _type := 'TRASH';

    if (ucase (_name) like 'SENT%')
      _type := 'SENT';

    if (ucase (_name) like 'DRAFT%')
      _type := 'DRAFT';

    if (ucase (_name) like 'SPAM%')
      _type := 'SPAM';

    if (_type <> '')
    {
      set triggers off;
      update OMAIL.WA.FOLDERS
         set SYSTEM_FLAG = 'S',
             F_TYPE = _type
       where DOMAIN_ID = _domain_id
         and USER_ID = _user_id
         and FOLDER_ID = _folder_id;
      set triggers on;
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.folder_paths (
  in _domain_id integer,
  in _user_id integer,
  in _parent_id integer,
  in _path varchar)
{
  declare _folder_id integer;

  for (select NAME, FOLDER_ID from OMAIL.WA.FOLDERS where DOMAIN_ID = _domain_id and USER_ID = _user_id and PARENT_ID = _parent_id) do
  {
    _folder_id := FOLDER_ID;
    update OMAIL.WA.FOLDERS
       set PATH = _path || '/' || NAME
     where DOMAIN_ID = _domain_id
       and USER_ID = _user_id
       and FOLDER_ID = _folder_id;
    OMAIL.WA.folder_paths (_domain_id, _user_id, _folder_id, _path || '/' || NAME);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.mail_folder_type ()
{
  if (registry_get ('mail_folder_type') = '1')
    return;

  update OMAIL.WA.FOLDERS set F_TYPE = 'INBOX' where FOLDER_ID = 100;
  update OMAIL.WA.FOLDERS set F_TYPE = 'TRASH' where FOLDER_ID = 110;
  update OMAIL.WA.FOLDERS set F_TYPE = 'SENT'  where FOLDER_ID = 120;
  update OMAIL.WA.FOLDERS set F_TYPE = 'DRAFT' where FOLDER_ID = 130;
  update OMAIL.WA.FOLDERS set F_TYPE = 'SPAM'  where FOLDER_ID = 125;

  registry_set ('mail_folder_type', '1');
}
;

OMAIL.WA.mail_folder_type ()
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.mail_folder_path ()
{
  if (registry_get ('mail_folder_path') = '1')
    return;

  for (select distinct DOMAIN_ID, USER_ID from OMAIL.WA.FOLDERS where PARENT_ID = 0) do
  {
    OMAIL.WA.folder_paths(DOMAIN_ID, USER_ID, 0, '');
  }

  registry_set ('mail_folder_path', '1');
}
;

OMAIL.WA.mail_folder_path ()
;

-------------------------------------------------------------------------------
--
OMAIL.WA.exec_no_error (
 'create table OMAIL.WA.EXTERNAL_ACCOUNT (
    EA_ID             integer      identity,
    EA_DOMAIN_ID      integer      not null,
    EA_USER_ID        integer      not null,
    EA_NAME           varchar      not null,
    EA_TYPE           varchar      default \'pop3\',
    EA_HOST           varchar      not null,
    EA_PORT           integer      not null,
    EA_CONNECT_TYPE   varchar      default \'none\',
    EA_USER           varchar      not null,
    EA_PASSWORD       varchar      not null,
    EA_MCOPY          integer      not null,
    EA_FOLDER_ID      integer      default 100,
    EA_CHECK_INTERVAL integer      not null,
    EA_CHECK_DATE     datetime,
    EA_CHECK_ERROR    integer,

    PRIMARY KEY (EA_ID)
  )'
)
;

OMAIL.WA.exec_no_error (
  'CREATE UNIQUE INDEX EXTERNAL_ACCOUNT_NAME_ID ON OMAIL.WA.EXTERNAL_ACCOUNT (EA_DOMAIN_ID, EA_USER_ID, EA_NAME)'
)
;

create procedure OMAIL.WA.upgrade ()
{
  if (registry_get ('omail_accounts_upgrade') = '1')
    return;

  OMAIL.WA.exec_no_error (
   'insert into OMAIL.WA.EXTERNAL_ACCOUNT(
      EA_DOMAIN_ID,
      EA_USER_ID,
      EA_NAME,
      EA_HOST,
      EA_PORT,
      EA_CONNECT_TYPE,
      EA_USER,
      EA_PASSWORD,
      EA_MCOPY,
      EA_FOLDER_ID,
      EA_CHECK_INTERVAL,
      EA_CHECK_DATE,
      EA_CHECK_ERROR)
    select
      DOMAIN_ID,
      USER_ID,
      ACC_NAME,
      POP_SERVER,
      POP_PORT,
      POP_TYPE,
      USER_NAME,
      USER_PASS,
      MCOPY,
      FOLDER_ID,
      CH_INTERVAL,
      LAST_CHECK,
      CH_ERROR
    from OMAIL.WA.EXTERNAL_POP_ACC
    '
  );

  registry_set ('omail_accounts_upgrade', '1');
}
;
OMAIL.WA.upgrade ();

-------------------------------------------------------------------------------
--
OMAIL.WA.exec_no_error (
  'create table OMAIL.WA.MIME_HANDLERS(
    ID      INTEGER     NOT NULL,
    TYPE_ID INTEGER     NOT NULL,
    MOD_ID  INTEGER     NOT NULL,
    PNAME   VARCHAR(50) NOT NULL,

    PRIMARY KEY(ID)
  )'
)
;

-------------------------------------------------------------------------------
--
OMAIL.WA.exec_no_error (
  'create table OMAIL.WA.SETTINGS(
    DOMAIN_ID   INTEGER      NOT NULL,
    USER_ID     INTEGER      NOT NULL,
    SNAME       VARCHAR(50)  NOT NULL,
    SVALUES     LONG VARCHAR,

    PRIMARY KEY(DOMAIN_ID,USER_ID,SNAME)
  )'
)
;

-------------------------------------------------------------------------------
--
OMAIL.WA.exec_no_error (
  'create table OMAIL.WA.SHARES (
    SHARE_ID    INTEGER         NOT NULL,
    APP_ID      VARCHAR(50)     NOT NULL,
    USER_ID     INTEGER         NOT NULL,
    OBJ_ID      INTEGER,
    OBJ_TYPE    CHAR(2)         NOT NULL,
    GRANTED_UID INTEGER,
    G_TYPE      CHAR(2)         NOT NULL,

    PRIMARY KEY (SHARE_ID)
  )'
)
;

-------------------------------------------------------------------------------
--
OMAIL.WA.exec_no_error (
  'create table OMAIL.WA.CONVERSATION (
    C_ID integer identity,
    C_DOMAIN_ID integer not null,
    C_USER_ID integer not null,
    C_ADDRESS varchar not null,
    C_ADDRESSES long varchar not null,
    C_DESCRIPTION varchar not null,
    C_TS datetime,
    C_RFC_ID varchar,
    C_RFC_HEADER long varchar,
    C_RFC_REFERENCES varchar,

    PRIMARY KEY (C_ID)
  )'
)
;

-------------------------------------------------------------------------------
--
OMAIL.WA.exec_no_error (
  'create table OMAIL.WA.FILTERS (
    F_ID integer identity,
    F_DOMAIN_ID integer not null,
    F_NAME varchar not null,
    F_MODE integer default 1,
    F_ACTIVE integer default 1,
    F_CRITERIA long varchar,
    F_ACTIONS long varchar,

    PRIMARY KEY (F_ID)
  )'
)
;

OMAIL.WA.exec_no_error (
  'ALTER TABLE OMAIL.WA.MESSAGES         ADD FOREIGN KEY (DOMAIN_ID,USER_ID,FOLDER_ID) REFERENCES OMAIL.WA.FOLDERS     (DOMAIN_ID,USER_ID,FOLDER_ID)'
)
;

OMAIL.WA.exec_no_error (
  'ALTER TABLE OMAIL.WA.MESSAGES         ADD FOREIGN KEY (DOMAIN_ID,USER_ID,PARENT_ID) REFERENCES OMAIL.WA.MESSAGES    (DOMAIN_ID,USER_ID,MSG_ID)'
)
;

OMAIL.WA.exec_no_error (
  'ALTER TABLE OMAIL.WA.MSG_PARTS        ADD FOREIGN KEY (DOMAIN_ID,USER_ID,MSG_ID)    REFERENCES OMAIL.WA.MESSAGES    (DOMAIN_ID,USER_ID,MSG_ID)'
)
;

OMAIL.WA.exec_no_error (
  'ALTER TABLE OMAIL.WA.MSG_PARTS        ADD FOREIGN KEY (TYPE_ID)                     REFERENCES OMAIL.WA.RES_MIME_TYPES  (ID)'
)
;

OMAIL.WA.exec_no_error (
  'ALTER TABLE OMAIL.WA.FOLDERS          ADD FOREIGN KEY (DOMAIN_ID,USER_ID,PARENT_ID) REFERENCES OMAIL.WA.FOLDERS     (DOMAIN_ID,USER_ID,FOLDER_ID)'
)
;

OMAIL.WA.exec_no_error (
  'ALTER TABLE OMAIL.WA.EXTERNAL_POP_ACC ADD FOREIGN KEY (DOMAIN_ID,USER_ID,FOLDER_ID) REFERENCES OMAIL.WA.FOLDERS     (DOMAIN_ID,USER_ID,FOLDER_ID)'
)
;

OMAIL.WA.exec_no_error (
  'ALTER TABLE OMAIL.WA.MIME_HANDLERS    ADD FOREIGN KEY (TYPE_ID)                     REFERENCES OMAIL.WA.RES_MIME_TYPES  (ID)'
)
;

OMAIL.WA.exec_no_error (
  'sequence_set (\'OMAIL.WA.omail_seq_eml_msg_id\',%d,0)', 'S', 'OMAIL.WA.MESSAGES', 'MSG_ID'
)
;

OMAIL.WA.exec_no_error (
  'sequence_set (\'OMAIL.WA.omail_seq_eml_freetext_id\',%d,0)', 'S', 'OMAIL.WA.MESSAGES', 'FREETEXT_ID'
)
;

OMAIL.WA.exec_no_error (
  'sequence_set (\'OMAIL.WA.omail_seq_eml_folder_id\',%d,0)', 'S', 'OMAIL.WA.FOLDERS', 'FOLDER_ID'
)
;

OMAIL.WA.exec_no_error (
  'sequence_set (\'OMAIL.WA.omail_seq_eml_external_acc_id\',%d,0)', 'S', 'OMAIL.WA.EXTERNAL_POP_ACC', 'ACC_ID'
)
;

-- CREATE TRIGGERS -------------------------------------------------------------

OMAIL.WA.exec_no_error (
  'CREATE TRIGGER EML_MESSAGES_A_I after insert on OMAIL.WA.MESSAGES referencing new as N
   {
     if (N.DOMAIN_ID = 1)
       OMAIL.WA.dashboard_update(N.DOMAIN_ID, N.USER_ID, N.MSG_ID, N.SUBJECT, N.RCV_DATE, OMAIL.WA.omail_address2str(\'from\', N.ADDRESS, 3), OMAIL.WA.omail_address2str(\'from\', N.ADDRESS, 2));
   }'
)
;

OMAIL.WA.exec_no_error (
  'CREATE TRIGGER EML_MESSAGES_A_U after update on OMAIL.WA.MESSAGES referencing new as N
   {
     if (N.DOMAIN_ID = 1)
       OMAIL.WA.dashboard_update(N.DOMAIN_ID, N.USER_ID, N.MSG_ID, N.SUBJECT, N.RCV_DATE, OMAIL.WA.omail_address2str(\'from\', N.ADDRESS, 3), OMAIL.WA.omail_address2str(\'from\', N.ADDRESS, 2));
     OMAIL.WA.dsize_update(N.DOMAIN_ID, N.USER_ID, N.MSG_ID);
   }'
)
;

OMAIL.WA.exec_no_error (
  'CREATE TRIGGER EML_MESSAGES_B_D before delete on OMAIL.WA.MESSAGES referencing old as O
   {
     DELETE FROM OMAIL.WA.MESSAGES WHERE DOMAIN_ID = O.DOMAIN_ID AND USER_ID = O.USER_ID AND PARENT_ID = O.MSG_ID;
   }'
)
;

OMAIL.WA.exec_no_error (
  'CREATE TRIGGER EML_MESSAGES_A_D after delete on OMAIL.WA.MESSAGES referencing old as O
   {
     if (O.DOMAIN_ID = 1)
       OMAIL.WA.dashboard_delete(O.DOMAIN_ID, O.USER_ID, O.MSG_ID);
     if (O.DOMAIN_ID <> 1)
     {
       declare _name, _group any;

       _name := OMAIL.WA.domain_nntp_name (O.DOMAIN_ID);
       _group := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = _name);
       if (isnull(_group))
         return;
       delete from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = O.M_RFC_ID and NM_GROUP = _group;
       DB.DBA.ns_up_num (_group);
     }
   }'
)
;

OMAIL.WA.exec_no_error (
  'CREATE TRIGGER EML_MSG_PARTS_A_I after insert on OMAIL.WA.MSG_PARTS referencing new as N
   {
     OMAIL.WA.dsize_update(N.DOMAIN_ID, N.USER_ID, N.MSG_ID);
     if ((N.DOMAIN_ID <> 1) and (N.PART_ID = 1))
     {
       declare id integer;
       declare msg_id, msg_references, msg_subject, msg_address, rfc_id, rfc_header, rfc_references varchar;
       declare ts datetime;
       declare nInstance any;

       nInstance := OMAIL.WA.domain_nntp_name(N.DOMAIN_ID);
       select SRV_MSG_ID, REF_ID, M_RFC_ID, M_RFC_HEADER, M_RFC_REFERENCES, SUBJECT, RCV_DATE, ADDRESS
         into msg_id, msg_references, rfc_id, rfc_header, rfc_references, msg_subject, ts, msg_address
         from OMAIL.WA.MESSAGES
        where DOMAIN_ID = N.DOMAIN_ID
          and USER_ID   = N.USER_ID
          and MSG_ID    = N.MSG_ID;

       if (is_empty_or_null (rfc_id))
       {
         rfc_id := msg_id;
         if (is_empty_or_null(rfc_id))
         rfc_id := OMAIL.WA.make_rfc_id (N.MSG_ID);
       }

       if (is_empty_or_null (rfc_references))
       {
         rfc_references := msg_references;
         if (is_empty_or_null (rfc_references))
         {
           declare addresses varchar;

           addresses := OMAIL.WA.str2vector (OMAIL.WA.omail_address2str (''to'', msg_address, 2));
           foreach (any address in addresses) do
           {
           rfc_references := (select C_RFC_ID from OMAIL.WA.CONVERSATION where C_ADDRESS = trim(address));
             if (not is_empty_or_null (rfc_references))
             goto _exit;
         }
         }
       _exit:;
       }

       if (is_empty_or_null (rfc_header))
         rfc_header := OMAIL.WA.make_post_rfc_header (rfc_id, rfc_references, nInstance, msg_subject, ts, nInstance);

       set triggers off;
       update OMAIL.WA.MESSAGES
          set M_RFC_ID = rfc_id,
     	        M_RFC_HEADER = rfc_header,
     	        M_RFC_REFERENCES = rfc_references
        where DOMAIN_ID = N.DOMAIN_ID
          and USER_ID   = N.USER_ID
          and MSG_ID    = N.MSG_ID;
       set triggers on;
     }
   }'
)
;

OMAIL.WA.exec_no_error (
  'CREATE TRIGGER EML_MSG_PARTS_NEWS_A_I after insert on OMAIL.WA.MSG_PARTS order 30 referencing new as N
   {
     if ((N.DOMAIN_ID <> 1) and (N.PART_ID = 1))
     {
       declare grp, ngnext integer;
       declare rfc_id, nInstance any;

       declare exit handler for not found { return;};

       nInstance := OMAIL.WA.domain_nntp_name(N.DOMAIN_ID);
       select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nInstance;
       if (ngnext < 1)
         ngnext := 1;
       rfc_id := (select M_RFC_ID from OMAIL.WA.MESSAGES where DOMAIN_ID = N.DOMAIN_ID and USER_ID = N.USER_ID and MSG_ID = N.MSG_ID);

       insert into DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP)
         values (rfc_id, grp, ngnext);

       set triggers off;
       update DB.DBA.NEWS_GROUPS
          set NG_NEXT_NUM = ngnext + 1
        where NG_NAME = nInstance;
       DB.DBA.ns_up_num (grp);
       set triggers on;
     }
   }
')
;

OMAIL.WA.exec_no_error (
  'CREATE TRIGGER EML_MSG_PARTS_A_U after update on OMAIL.WA.MSG_PARTS referencing new as N
   {
     OMAIL.WA.dsize_update(N.DOMAIN_ID, N.USER_ID, N.MSG_ID);
   }'
)
;

OMAIL.WA.exec_no_error (
  'CREATE TRIGGER EML_MSG_PARTS_A_D after delete on OMAIL.WA.MSG_PARTS referencing old as O
   {
     OMAIL.WA.dsize_update(O.DOMAIN_ID, O.USER_ID, O.MSG_ID);
   }'
)
;

OMAIL.WA.exec_no_error ('
  create trigger CONVERSATION_B_I before insert on OMAIL.WA.CONVERSATION referencing new as N
  {
    N.C_ADDRESS := sprintf(\'conversation-%d%s\', N.C_ID, N.C_ADDRESS);
    connection_set(\'conversation_address\', N.C_ADDRESS);
  }
')
;

OMAIL.WA.exec_no_error ('
  create trigger CONVERSATION_I after insert on OMAIL.WA.CONVERSATION referencing new as N
  {
    declare id integer;
    declare rfc_id, rfc_header, rfc_references varchar;
    declare nInstance any;

    nInstance := OMAIL.WA.domain_nntp_name(N.C_DOMAIN_ID);
    id := N.C_ID;

    rfc_id := N.C_RFC_ID;
    if (isnull(rfc_id))
      rfc_id := OMAIL.WA.make_rfc_id (N.C_ID);
    rfc_references := \'\';
    rfc_header := N.C_RFC_HEADER;
    if (isnull(rfc_header))
      rfc_header := OMAIL.WA.make_post_rfc_header (rfc_id, rfc_references, nInstance, N.C_DESCRIPTION, N.C_TS, nInstance);

    set triggers off;
    update OMAIL.WA.CONVERSATION
       set C_RFC_ID = rfc_id,
  	       C_RFC_HEADER = rfc_header,
  	       C_RFC_REFERENCES = rfc_references
     where C_ID = id;
    set triggers on;
  }
')
;

OMAIL.WA.exec_no_error ('
  create trigger CONVERSATION_NEWS_I after insert on OMAIL.WA.CONVERSATION order 30 referencing new as N
  {
    declare _name, _key_id, _group, _num_group any;

    --declare exit handler for not found { return;};

    _name := OMAIL.WA.domain_nntp_name(N.C_DOMAIN_ID);
    select NG_GROUP, NG_NEXT_NUM into _group, _num_group from DB.DBA.NEWS_GROUPS where NG_NAME = _name;
    select C_RFC_ID into _key_id from OMAIL.WA.CONVERSATION where C_ID = N.C_ID;

    if (_num_group < 1)
      _num_group := 1;

    -- this should be after all columns in the corresponding object row are set eq. rfc_id rfc_header etc.
    insert into DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP) values (_key_id, _group, _num_group);

    set triggers off;
    update DB.DBA.NEWS_GROUPS set NG_NEXT_NUM = _num_group + 1 where NG_NAME = _name;
    DB.DBA.ns_up_num (_group);
    set triggers on;
  }
')
;

OMAIL.WA.exec_no_error ('
  create trigger CONVERSATION_NEWS_D after delete on OMAIL.WA.CONVERSATION referencing old as O
  {
    declare _name, _group any;

    _name := OMAIL.WA.domain_nntp_name(O.C_DOMAIN_ID);
    _group := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = _name);
    if (isnull(_group))
      return;
    delete from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = O.C_RFC_ID and NM_GROUP = _group;
    DB.DBA.ns_up_num (_group);
  }
')
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.dsize_update (in _domain_id integer, in _user_id integer, in _msg_id integer)
{
  declare _dsize integer;

  _dsize := coalesce((select sum(DSIZE) from OMAIL.WA.MSG_PARTS where DOMAIN_ID = _domain_id and USER_ID = _user_id and MSG_ID = _msg_id), 0);
  set triggers off;
  update OMAIL.WA.MESSAGES
     set DSIZE = _dsize
   where DOMAIN_ID = _domain_id
     and USER_ID   = _user_id
     and MSG_ID    = _msg_id;
  set triggers on;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.MESSAGES_ADDRESS_HOOK (inout vtb any, inout d_id any, in mode any)
{
  declare S, _user_id, _folder_id, _address, _options any;

  select USER_ID, FOLDER_ID, ADDRESS, M_OPTIONS into _user_id, _folder_id, _address, _options from OMAIL.WA.MESSAGES where FREETEXT_ID = d_id;

  S := '';
  if (not isnull(_address))
    S := S || _address;
  if (not isnull(_options))
    S := S || _options;
  if (S <> '')
    vt_batch_feed (vtb, S, mode, 1);
  if (not isnull(_folder_id))
    vt_batch_feed (vtb, sprintf ('^F%d', _folder_id), mode);
  if (not isnull(_user_id))
    vt_batch_feed (vtb, sprintf ('^UID%d', _user_id), mode);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.drop_index ()
{
  if (registry_get ('mail_index_version') = '2')
    return;

    OMAIL.WA.exec_no_error('drop table OMAIL.WA.MESSAGES_ADDRESS_WORDS');
}
;

OMAIL.WA.drop_index ()
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.MESSAGES_ADDRESS_INDEX_HOOK (inout vtb any, inout d_id any)
{
  return OMAIL.WA.MESSAGES_ADDRESS_HOOK (vtb, d_id, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.MESSAGES_ADDRESS_UNINDEX_HOOK (inout vtb any, inout d_id any)
{
  return OMAIL.WA.MESSAGES_ADDRESS_HOOK (vtb, d_id, 1);
}
;

OMAIL.WA.exec_no_error(
  'create text xml index on OMAIL.WA.MESSAGES (ADDRESS) with key FREETEXT_ID not insert CLUSTERED WITH (FOLDER_ID) using function language \'x-ViDoc\''
)
;
-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.MSG_PARTS_TDATA_HOOK (inout vtb any, inout d_id any, in mode any)
{
  declare _user_id, _tdata, _tags, _part_id any;

  select USER_ID, TDATA, TAGS, PART_ID into _user_id, _tdata, _tags, _part_id from OMAIL.WA.MSG_PARTS where FREETEXT_ID = d_id;

  if (_part_id <> 1)
    return 1;

  if (not isnull(_user_id))
    vt_batch_feed (vtb, sprintf ('^UID%d', _user_id), mode);

  if (not is_empty_or_null(_tdata))
    vt_batch_feed (vtb, _tdata, mode);

  if (not is_empty_or_null(_tags))
  {
    _tags := split_and_decode (_tags, 0, '\0\0,');
    foreach (any tag in _tags) do
    {
      tag := concat('^T', trim(tag));
      tag := replace (tag, ' ', '_');
      vt_batch_feed (vtb, tag, mode);
    }
  }
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.drop_index()
{
  if (registry_get ('mail_index_version') = '2')
    return;

    OMAIL.WA.exec_no_error ('drop table OMAIL.WA.MSG_PARTS_TDATA_WORDS');
}
;

OMAIL.WA.drop_index()
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.MSG_PARTS_TDATA_index_hook (inout vtb any, inout d_id any)
{
  return OMAIL.WA.MSG_PARTS_TDATA_HOOK (vtb, d_id, 0);
    }
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.MSG_PARTS_TDATA_unindex_hook (inout vtb any, inout d_id any)
{
  return OMAIL.WA.MSG_PARTS_TDATA_HOOK (vtb, d_id, 1);
  }
;

OMAIL.WA.exec_no_error(
  'create text index on OMAIL.WA.MSG_PARTS(TDATA) with key FREETEXT_ID not insert CLUSTERED WITH (TAGS) using function language \'x-ViDoc\''
)
;

-------------------------------------------------------------------------------
--
registry_set ('mail_index_version', '2')
;

-------------------------------------------------------------------------------
--
OMAIL.WA.exec_no_error ('
  delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = \'WebMail External POP3 Scheduler\'
')
;

OMAIL.WA.exec_no_error ('
  insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
    values(\'WebMail External Account Scheduler\', now(), \'OMAIL.WA.external_account_schedule ()\', 10)
')
;

-------------------------------------------------------------------------------
--
OMAIL.WA.exec_no_error ('
  insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
    values(\'WebMail Spam Clean Scheduler\', now(), \'OMAIL.WA.spam_clean_schedule ()\', 60)
')
;

