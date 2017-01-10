--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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
-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.discussion_check ()
{
  if (isnull (VAD_CHECK_VERSION ('Discussion')))
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.conversation_enable(
  in domain_id integer)
{
  return coalesce ((select coalesce (NNTP, 0) from PHOTO.WA.SYS_INFO where GALLERY_ID = domain_id), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.make_rfc_id (
  in item_id integer,
  in comment_id integer := null)
{
  declare hashed, host any;

  hashed := md5 (uuid ());
  host := sys_stat ('st_host_name');
  if (isnull (comment_id))
    return sprintf ('<%d.%s@%s>', item_id, hashed, host);
  return sprintf ('<%d.%d.%s@%s>', item_id, comment_id, hashed, host);
}
;

-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.make_mail_subject (
  in txt any,
  in id varchar := null)
{
  declare enc any;

  enc := encode_base64 (PHOTO.WA.wide2utf (txt));
  enc := replace (enc, '\r\n', '');
  txt := concat ('Subject: =?UTF-8?B?', enc, '?=\r\n');
  if (not isnull (id))
    txt := concat (txt, 'X-Virt-NewsID: ', uuid (), ';', id, '\r\n');
  return txt;
}
;

-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.make_post_rfc_header (
  in mid varchar,
  in refs varchar,
  in gid varchar,
  in title varchar,
  in rec datetime,
  in author_mail varchar)
{
  declare ses any;

  ses := string_output ();
  http (PHOTO.WA.make_mail_subject (title), ses);
  http (sprintf ('Date: %s\r\n', DB.DBA.date_rfc1123 (rec)), ses);
  http (sprintf ('Message-Id: %s\r\n', mid), ses);
  if (not isnull (refs))
    http (sprintf ('References: %s\r\n', refs), ses);
  http (sprintf ('From: %s\r\n', author_mail), ses);
  http ('Content-Type: text/html; charset=UTF-8\r\n', ses);
  http (sprintf ('Newsgroups: %s\r\n\r\n', gid), ses);
  ses := string_output_string (ses);
  return ses;
}
;

-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.make_post_rfc_msg (
  inout head varchar,
  inout body varchar,
  in tree int := 0)
{
  declare ses any;

  ses := string_output ();
  http (head, ses);
  http (body, ses);
  http ('\r\n.\r\n', ses);
  ses := string_output_string (ses);
  if (tree)
    ses := serialize (mime_tree (ses));
  return ses;
}
;

-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.nntp_update (
  in instance_id integer,
  in oInstance varchar,
  in nInstance varchar,
  in oConversation integer := null,
  in nConversation integer := null)
{
  if (PHOTO.WA.discussion_check () = 0)
    return;

  declare nntpGroup integer;
  declare nDescription varchar;

  if (isnull (oInstance))
    oInstance := PHOTO.WA.domain_nntp_name (instance_id);

  if (isnull (nInstance))
    nInstance := PHOTO.WA.domain_nntp_name (instance_id);

  nDescription := PHOTO.WA.domain_description (instance_id);

  if (isnull (nConversation))
  {
    update DB.DBA.NEWS_GROUPS
      set NG_POST = 1,
          NG_NAME = nInstance,
          NG_DESC = nDescription
    where NG_NAME = oInstance;
    return;
  }

  if (oConversation = 1 and nConversation = 0)
  {
    nntpGroup := (select NG_GROUP from DB.DBA.NEWS_GROUPS where NG_NAME = oInstance);
    delete from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = nntpGroup;
    delete from DB.DBA.NEWS_GROUPS where NG_NAME = oInstance;
  }
  else if (oConversation = 0 and nConversation = 1)
  {
    declare exit handler for sqlstate '*' { return; };

    insert into DB.DBA.NEWS_GROUPS (NG_NEXT_NUM, NG_NAME, NG_DESC, NG_SERVER, NG_POST, NG_UP_TIME, NG_CREAT, NG_UP_INT, NG_PASS, NG_UP_MESS, NG_NUM, NG_FIRST, NG_LAST, NG_LAST_OUT, NG_CLEAR_INT, NG_TYPE)
      values (0, nInstance, nDescription, null, 1, now(), now(), 30, 0, 0, 0, 0, 0, 0, 120, 'GALLERY');
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.nntp_fill (
  in domain_id integer)
{
  if (PHOTO.WA.discussion_check () = 0)
    return;

  declare exit handler for SQLSTATE '*', not found {
    return;
  };

  declare grp, ngnext integer;
  declare nntpName varchar;

  for (select distinct RES_ID as _res_id from PHOTO.WA.COMMENTS where GALLERY_ID = domain_id) do
  {
    if (not exists (select 1 from PHOTO.WA.COMMENTS where GALLERY_ID = domain_id and RES_ID = _res_id and PARENT_ID is null and TEXT = PHOTO.WA.get_image_caption (_res_id)))
    {
      PHOTO.WA.root_comment (domain_id, _res_id);
    }
  }
  nntpName := PHOTO.WA.domain_nntp_name (domain_id);
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nntpName;
  if (ngnext < 1)
    ngnext := 1;

  for (select RFC_ID as rfc_id from PHOTO.WA.COMMENTS where GALLERY_ID = domain_id) do
  {
    insert soft DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP) values (rfc_id, grp, ngnext);
    ngnext := ngnext + 1;
  }

  set triggers off;
  update DB.DBA.NEWS_GROUPS set NG_NEXT_NUM = ngnext + 1 where NG_NAME = nntpName;
  DB.DBA.ns_up_num (grp);
  set triggers on;
}
;

-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.nntp_decode_subject (
  inout str varchar)
{
  declare match varchar;
  declare inx int;

  inx := 50;

  str := replace (str, '\t', '');

  match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
  while (match is not null and inx > 0) {
    declare enc, ty, dat, tmp, cp, dec any;

    cp := match;
    tmp := regexp_match ('^=\\?[^\\?]+\\?[A-Z]\\?', match);

    match := substring (match, length (tmp)+1, length (match) - length (tmp) - 2);

    enc := regexp_match ('=\\?[^\\?]+\\?', tmp);

    tmp := replace (tmp, enc, '');

    enc := trim (enc, '?=');
    ty := trim (tmp, '?');

    if (ty = 'B') {
      dec := decode_base64 (match);
    } else if (ty = 'Q') {
      dec := uudecode (match, 12);
    } else {
      dec := '';
    }
    declare exit handler for sqlstate '2C000' { return;};
    dec := charset_recode (dec, enc, 'UTF-8');

    str := replace (str, cp, dec);

    match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
    inx := inx - 1;
  }
}
;


-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.nntp_process_parts (
  in parts any,
  inout body varchar,
  inout amime any,
  out result any,
  in any_part int)
{
  declare name1, mime1, name, mime, enc, content, charset varchar;
  declare i, i1, l1, is_allowed int;
  declare part any;

  if (not isarray (result))
    result := vector ();

  if (not isarray (parts) or not isarray (parts[0]))
    return 0;

  part := parts[0];

  name1 := get_keyword_ucase ('filename', part, '');
  if (name1 = '')
    name1 := get_keyword_ucase ('name', part, '');

  mime1 := get_keyword_ucase ('Content-Type', part, '');
  charset := get_keyword_ucase ('charset', part, '');

  if (mime1 = 'application/octet-stream' and name1 <> '')
    mime1 := http_mime_type (name1);

  is_allowed := 0;
  i1 := 0;
  l1 := length (amime);
  while (i1 < l1)
  {
    declare elm any;
    elm := trim(amime[i1]);
    if (mime1 like elm)
    {
      is_allowed := 1;
      i1 := l1;
    }
    i1 := i1 + 1;
  }

  declare _cnt_disp any;
  _cnt_disp := get_keyword_ucase('Content-Disposition', part, '');

  if (is_allowed and (any_part or (name1 <> '' and _cnt_disp in ('attachment', 'inline')))) {
    name := name1;
    mime := mime1;
    enc := get_keyword_ucase ('Content-Transfer-Encoding', part, '');
    content := subseq (body, parts[1][0], parts[1][1]);
    if (enc = 'base64')
      content := decode_base64 (content);
    result := vector_concat (result, vector (vector (name, mime, content, _cnt_disp, enc, charset)));
    return 1;
  }

  -- process the parts
  if (isarray (parts[2]))
    for (i := 0; i < length (parts[2]); i := i + 1)
      PHOTO.WA.nntp_process_parts (parts[2][i], body, amime, result, any_part);

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.domain_nntp_name (
  in domain_id integer)
{
  return PHOTO.WA.domain_nntp_name2 (PHOTO.WA.domain_name (domain_id), PHOTO.WA.domain_owner_name (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.domain_nntp_name2 (
  in domain_name varchar,
  in owner_name varchar)
{
  return sprintf ('ods.photos.%s.%U', owner_name, PHOTO.WA.string2nntp (domain_name));
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.string2nntp (
  in S varchar)
{
  S := replace (S, '.', '_');
  S := replace (S, '@', '_');
  return sprintf ('%U', S);
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.domain_name (
  in domain_id integer)
{
  return coalesce((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'GALLERY Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.domain_owner_name (
  in domain_id integer)
{
  return (select U_NAME from WS.WS.SYS_DAV_USER where U_ID = PHOTO.WA.domain_owner_id (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.domain_owner_id (
  in domain_id integer)
{
  return (select A.WAM_USER from WA_MEMBER A, WA_INSTANCE B where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.domain_description (
  in domain_id integer)
{
  return coalesce((select coalesce(WAI_DESCRIPTION, WAI_NAME) from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'GALLERY Instance');
}
;

-------------------------------------------------------------------------------
--
-- NNTP views & triggers
--
-------------------------------------------------------------------------------
--
DB.DBA.NNTP_NEWS_MSG_ADD (
'GALLERY',
'select
   \'GALLERY\',
   RFC_ID,
   RFC_REFERENCES,
   0,    -- NM_READ
   null,
   MODIFY_DATE,
   0,    -- NM_STAT
   null, -- NM_TRY_POST
   0,    -- NM_DELETED
   PHOTO.WA.make_post_rfc_msg (RFC_HEADER, TEXT, 1), -- NM_HEAD
   PHOTO.WA.make_post_rfc_msg (RFC_HEADER, TEXT),
   COMMENT_ID
 from PHOTO.WA.COMMENTS'
)
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.nntp_rfc_update (
  in _comment_id integer,
  in _parent_id integer,
  in _gallery_id integer,
  in _modify_date datetime,
  in _user_id integer,
  in _res_id integer,
  in _rfc_id varchar,
  in _rfc_header varchar,
  in _rfc_references varchar)
{
  declare _rfc_title, _author_mail, nInstance varchar;

  declare exit handler for not found
  {
    return;
  };
  nInstance := PHOTO.WA.domain_nntp_name (_gallery_id);
  if (isnull (_rfc_id))
  {
    _rfc_id := PHOTO.WA.make_rfc_id (_res_id, _comment_id);
  }
  _rfc_references := '';
  if (_parent_id)
  {
    for (select RFC_ID, RFC_REFERENCES from PHOTO.WA.COMMENTS where COMMENT_ID = _parent_id) do
    {
      _rfc_references := RFC_ID;
      if (not isnull (RFC_REFERENCES))
      {
        _rfc_references := RFC_REFERENCES || ' ' || _rfc_references;
      }
    }
  }
  --if (isnull (_rfc_header))
  --{
    _rfc_title  := PHOTO.WA.get_image_name (_res_id);
    if (_user_id < 0)
    {
      _author_mail := 'Anonymous';
    } else {
      _author_mail := (select U_E_MAIL from DB.DBA.SYS_USERS where U_ID = _user_id);
      if (is_empty_or_null (trim (_author_mail)))
      {
        _author_mail := PHOTO.WA.user_fullName (_user_id);
      }
    }
    if (not isnull (_parent_id))
    {
      _rfc_title := 'Re: ' || _rfc_title;
    }
    _rfc_header := PHOTO.WA.make_post_rfc_header (_rfc_id, _rfc_references, nInstance, _rfc_title, _modify_date, _author_mail);
  --}

  set triggers off;
  update PHOTO.WA.COMMENTS
     set RFC_ID = _rfc_id,
         RFC_HEADER = _rfc_header,
         RFC_REFERENCES = _rfc_references
   where COMMENT_ID = _comment_id;
  set triggers on;
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.nntp_discussion_update (
  in _comment_id integer,
  in _gallery_id integer)
{
  declare grp, ngnext integer;
  declare rfc_id, nInstance any;

  declare exit handler for not found
  {
    return;
  };
  rfc_id := (select RFC_ID from PHOTO.WA.COMMENTS where COMMENT_ID = _comment_id);
  if (not exists (select 1 from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = rfc_id))
  {
    nInstance := PHOTO.WA.domain_nntp_name (_gallery_id);
    select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nInstance;
    if (ngnext < 1)
      ngnext := 1;
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
;

-------------------------------------------------------------------------------
--
create trigger PHOTO_COMMENTS_I after insert on PHOTO.WA.COMMENTS referencing new as N
{
  PHOTO.WA.nntp_rfc_update (
    N.COMMENT_ID,
    N.PARENT_ID,
    N.GALLERY_ID,
    N.MODIFY_DATE,
    N.USER_ID,
    N.RES_ID,
    N.RFC_ID,
    N.RFC_HEADER,
    N.RFC_REFERENCES);
}
;

-------------------------------------------------------------------------------
--
create trigger PHOTO_COMMENTS_NEWS_I after insert on PHOTO.WA.COMMENTS order 30 referencing new as N
{
  if (PHOTO.WA.discussion_check () = 0)
    return;

  PHOTO.WA.nntp_discussion_update (N.COMMENT_ID, N.GALLERY_ID);
}
;

-------------------------------------------------------------------------------
--
create trigger PHOTO_COMMENTS_U after update on PHOTO.WA.COMMENTS referencing new as N
{
  PHOTO.WA.nntp_rfc_update (
    N.COMMENT_ID,
    N.PARENT_ID,
    N.GALLERY_ID,
    N.MODIFY_DATE,
    N.USER_ID,
    N.RES_ID,
    N.RFC_ID,
    N.RFC_HEADER,
    N.RFC_REFERENCES);
}
;

-------------------------------------------------------------------------------
--
create trigger PHOTO_COMMENTS_NEWS_U after update on PHOTO.WA.COMMENTS order 30 referencing new as N
{
  if (PHOTO.WA.discussion_check () = 0)
    return;

  PHOTO.WA.nntp_discussion_update (N.COMMENT_ID, N.GALLERY_ID);
}
;

-------------------------------------------------------------------------------
--
create trigger PHOTO_COMMENTS_D after delete on PHOTO.WA.COMMENTS referencing old as O
{
  set triggers off;
  update PHOTO.WA.COMMENTS
     set PARENT_ID = O.PARENT_ID
   where PARENT_ID = O.COMMENT_ID;
  set triggers on;
}
;

-------------------------------------------------------------------------------
--
create trigger PHOTO_COMMENTS_NEWS_D after delete on PHOTO.WA.COMMENTS order 30 referencing old as O
{
  if (PHOTO.WA.discussion_check () = 0)
    return;

  declare grp integer;
  declare oInstance any;

  oInstance := PHOTO.WA.domain_nntp_name (O.GALLERY_ID);
  grp := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = oInstance);
  if (not isnull (grp))
  {
    delete from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = O.RFC_ID and NM_GROUP = grp;
    DB.DBA.ns_up_num (grp);
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.GALLERY_NEWS_MSG_I (
  inout N_NM_ID any,
  inout N_NM_REF any,
  inout N_NM_READ any,
  inout N_NM_OWN any,
  inout N_NM_REC_DATE any,
  inout N_NM_STAT any,
  inout N_NM_TRY_POST any,
  inout N_NM_DELETED any,
  inout N_NM_HEAD any,
  inout N_NM_BODY any)
{
  declare uid any;
  declare author, name, mail, tree, head, contentType, content, subject, title, cset any;
  declare rfc_id, rfc_header, rfc_references, refs any;

  uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = connection_get ('nntp_uid'));
  if (isnull (N_NM_REF) and isnull (uid))
    signal ('CONVA', 'The post cannot be done via news client, this requires authentication.');

  tree := deserialize (N_NM_HEAD);
  head := tree [0];
  contentType := get_keyword_ucase ('Content-Type', head, 'text/plain');
  cset  := upper (get_keyword_ucase ('charset', head));
  author :=  get_keyword_ucase ('From', head, 'nobody@unknown');
  subject :=  get_keyword_ucase ('Subject', head);

  if (not isnull (subject))
    PHOTO.WA.nntp_decode_subject (subject);

  if (contentType like 'text/%')
  {
    declare st, en int;
    declare last any;

    st := tree[1][0];
    en := tree[1][1];

    if (en > st + 5) {
      last := subseq (N_NM_BODY, en - 4, en);
      if (last = '\r\n.\r')
        en := en - 4;
    }
    content := subseq (N_NM_BODY, st, en);
    if (cset is not null and cset <> 'UTF-8')
    {
      declare exit handler for sqlstate '2C000' { goto next_1;};
      content := charset_recode (content, cset, 'UTF-8');
    }
  next_1:;
    if (contentType = 'text/plain')
      content := '<pre>' || content || '</pre>';
  }
  else if (contentType like 'multipart/%')
  {
    declare res, best_cnt any;

    declare exit handler for sqlstate '*' {  signal ('CONVX', __SQL_MESSAGE);};

    PHOTO.WA.nntp_process_parts (tree, N_NM_BODY, vector ('text/%'), res, 1);

    best_cnt := null;
    content := null;
    foreach (any elm in res) do
    {
      if (elm[1] = 'text/html' and (content is null or best_cnt = 'text/plain'))
      {
        best_cnt := 'text/html';
        content := elm[2];
        if (elm[4] = 'quoted-printable')
        {
          content := uudecode (content, 12);
        } else if (elm[4] = 'base64') {
          content := decode_base64 (content);
        }
        cset := elm[5];
      } else if (best_cnt is null and elm[1] = 'text/plain') {
        content := elm[2];
        best_cnt := 'text/plain';
        cset := elm[5];
      }
      if (elm[1] not like 'text/%')
        signal ('CONVX', sprintf ('The post contains parts of type [%s] which is prohibited.', elm[1]));
    }
    if (length (cset) and cset <> 'UTF-8')
    {
      declare exit handler for sqlstate '2C000' { goto next_2;};
      content := charset_recode (content, cset, 'UTF-8');
    }
  next_2:;
  } else
    signal ('CONVX', sprintf ('The content type [%s] is not supported', contentType));

  rfc_header := '';
  for (declare i int, i := 0; i < length (head); i := i + 2)
  {
    if (lower (head[i]) <> 'content-type' and lower (head[i]) <> 'mime-version' and lower (head[i]) <> 'boundary'  and lower (head[i]) <> 'subject')
      rfc_header := rfc_header || head[i] ||': ' || head[i + 1]||'\r\n';
  }
  rfc_header := PHOTO.WA.make_mail_subject (subject) || rfc_header || 'Content-Type: text/html; charset=UTF-8\r\n\r\n';

  rfc_references := N_NM_REF;
  if (not isnull (N_NM_REF))
  {
    declare _comment_id, _parent_id, _gallery_id, _res_id integer;

    declare exit handler for not found { signal ('CONV1', 'No such article.');};

    refs := split_and_decode (N_NM_REF, 0, '\0\0 ');
    if (length (refs))
      N_NM_REF := refs[length (refs) - 1];

    select COMMENT_ID, RES_ID, GALLERY_ID
      into _parent_id, _res_id, _gallery_id
      from PHOTO.WA.COMMENTS
     where RFC_ID = N_NM_REF;

    _comment_id := sequence_next('PHOTO.WA.comments');
    insert into PHOTO.WA.COMMENTS (COMMENT_ID, PARENT_ID, GALLERY_ID, RES_ID, CREATE_DATE, MODIFY_DATE, USER_ID, TEXT, RFC_ID, RFC_HEADER, RFC_REFERENCES)
      values (_comment_id, _parent_id, _gallery_id, _res_id, N_NM_REC_DATE, N_NM_REC_DATE, uid, content, N_NM_ID, rfc_header, rfc_references);
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.GALLERY_NEWS_MSG_U (
  inout O_NM_ID any,
  inout N_NM_ID any,
  inout N_NM_REF any,
  inout N_NM_READ any,
  inout N_NM_OWN any,
  inout N_NM_REC_DATE any,
  inout N_NM_STAT any,
  inout N_NM_TRY_POST any,
  inout N_NM_DELETED any,
  inout N_NM_HEAD any,
  inout N_NM_BODY any)
{
  return;
}
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.GALLERY_NEWS_MSG_D (
  inout O_NM_ID any)
{
  signal ('CONV3', 'Delete of a GALLERY comment is not allowed');
}
;
