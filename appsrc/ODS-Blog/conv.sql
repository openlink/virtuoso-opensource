--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

use DB;

-- clear NNTP view (remove old declaration)
create procedure DB.DBA.NNTP_NEWS_MSG_INIT ()
{
  declare v, n any;
  declare x any;

  x := registry_get ('__NNTP_NEWS_MSG_BLOG');
  if (isstring (x))
    return;

  declare exit handler for sqlstate '*' { return;};

  select coalesce (V_TEXT, blob_to_string (V_EXT)) into v from SYS_VIEWS where V_NAME = 'DB.DBA.NEWS_MSG';
  n := replace(v, '\r', ' ');
  n := replace(n, '\n', ' ');
  x := regexp_substr('(union all.*select.*\'BLOG\'.*B_POST_ID)', n, 0);
  if (isnull(x))
    return;
  n := trim(replace(n, x, ''));
  n := replace(n, 'create view', '\ncreate view');

  declare state, message any;
  exec ('drop view DB.DBA.NEWS_MSG', state, message);
  state := '00000';
  exec (n, state, message);
  if (state <> '00000')
    exec (v, state, message);
};
DB.DBA.NNTP_NEWS_MSG_INIT ();

-- update NNTP view
DB.DBA.NNTP_NEWS_MSG_ADD(
'BLOG',
'select
  \'BLOG\',
  B_RFC_ID,
  null, -- NM_REF
  0, -- NM_READ
  B_USER_ID,
  B_TS,
  0, -- NM_STAT
  null, -- NM_TRY_POST
  0, -- NM_DELETED
  BLOG..MAKE_POST_RFC_MSG (B_RFC_HEADER, B_CONTENT, 1), -- NM_HEAD
  BLOG..MAKE_POST_RFC_MSG (B_RFC_HEADER, B_CONTENT),
  B_CONTENT_ID
	from BLOG.DBA.SYS_BLOGS

union all

select
  \'BLOG\',
  BM_RFC_ID,
  coalesce (BM_RFC_REFERENCES, B_RFC_ID),
  0, -- NM_READ
  null,
  BM_TS,
  0, -- NM_STAT
  null, -- NM_TRY_POST
  0, -- NM_DELETED
  BLOG..MAKE_POST_RFC_MSG (BM_RFC_HEADER, BM_COMMENT, 1), -- NM_HEAD
  BLOG..MAKE_POST_RFC_MSG (BM_RFC_HEADER, BM_COMMENT),
  BM_ID
from BLOG..BLOG_COMMENTS, BLOG..SYS_BLOGS where BM_BLOG_ID = B_BLOG_ID and BM_POST_ID = B_POST_ID'
);

-- to call inside updatable view triggers, no blog etc. added yet
create procedure DB.DBA.BLOG_NEWS_MSG_I
    (
    inout N_NM_ID any,
    inout N_NM_REF any,
    inout N_NM_READ any,
    inout N_NM_OWN any,
    inout N_NM_REC_DATE any,
    inout N_NM_STAT any,
    inout N_NM_TRY_POST any,
    inout N_NM_DELETED any,
    inout N_NM_HEAD any,
    inout N_NM_BODY any
    )
{
  declare bid, id, uid any;
  declare author, name, mail, addr, tree, head, ctype, content, rfc_header, subject, subject1, cset any;

  uid := connection_get ('nntp_uid');

--  dbg_obj_print ('N_NM_REF', N_NM_REF);

  if (N_NM_REF is null and uid is null)
    signal ('CONVA', 'The post cannot be done via news client, this requires authentication.');


  tree := deserialize (N_NM_HEAD);
  head := tree [0];
  ctype := get_keyword_ucase ('Content-Type', head, 'text/plain');
  cset  := upper (get_keyword_ucase ('charset', head));
  author :=  get_keyword_ucase ('From', head, 'nobody@unknown');
  subject :=  get_keyword_ucase ('Subject', head);

  if (subject is not null)
     BLOG..decode_nntp_subj (subject);

  --dbg_obj_print (N_NM_BODY);

  if (ctype like 'text/%')
    {
      declare st, en int;
      declare last any;

      st := tree[1][0];
      en := tree[1][1];

      if (en > st + 5)
	{
	  last := subseq (N_NM_BODY, en - 4, en);
	  --dbg_printf ('[%0x %0x %0x %0x]', last[0], last[1], last[2], last[3]);
	  if (last = '\r\n.\r')
	    en := en - 4;
	}
      content := subseq (N_NM_BODY, st, en);
      if (cset is not null and cset <> 'UTF-8')
	{
	  declare exit handler for sqlstate '2C000'
	    {
	      goto next1;
	    };
	  content := charset_recode (content, cset, 'UTF-8');
	}
      next1:;
      if (ctype = 'text/plain')
	content := '<pre>' || ns_make_index_content (content, 1) || '</pre>';
    }
  else if (ctype like 'multipart/%')
    {
      declare res, best_cnt any;
      --dbg_obj_print ('start parse');
      declare exit handler for sqlstate '*'
      {
	signal ('CONVX', __SQL_MESSAGE);
      };
      BLOG2_MOBLOG_PROCESS_PARTS(tree, N_NM_BODY, vector ('text/%'), res, 1);

      best_cnt := null;
      content := null;
      foreach (any elm in res) do
	{
	  if (elm[1] = 'text/html' and (content is null or best_cnt = 'text/plain'))
	    {
	      --dbg_obj_print (elm[3], elm[4], elm[5]);
	      best_cnt := 'text/html';
	      content := elm[2];
	      if (elm[4] = 'quoted-printable')
		{
		  content := uudecode (content, 12);
		}
	      else if (elm[4] = 'base64')
		{
		  content := decode_base64 (content);
		}
	      cset := elm[5];
	    }
	  else if (best_cnt is null and elm[1] = 'text/plain')
	    {
	      content := elm[2];
	      best_cnt := 'text/plain';
	      cset := elm[5];
	    }
	  --dbg_obj_print (elm[1]);
	  if (elm[1] not like 'text/%')
	    signal ('CONVX', sprintf ('The post contains parts of type [%s] which is prohibited.', elm[1]));
	}
      if (length (cset) and cset <> 'UTF-8')
	{
	  declare exit handler for sqlstate '2C000'
	    {
	      goto next2;
	    };
	  content := charset_recode (content, cset, 'UTF-8');
	}
      next2:;
      --dbg_obj_print ('end parse', content);
    }
  else
    signal ('CONVX', sprintf ('The content type [%s] is not supported', ctype));

  rfc_header := '';

  for (declare i int, i := 0; i < length (head); i := i + 2)
     {
--       dbg_printf ('[%s]=[%s]', head[i], head[i + 1]);
       if (lower (head[i]) <> 'content-type' and lower (head[i]) <> 'mime-version' and lower (head[i]) <> 'boundary'
	   and lower (head[i]) <> 'subject')
	 rfc_header := rfc_header || head[i] ||': ' || head[i + 1]||'\r\n';
     }

  rfc_header := BLOG..BLOG_MAKE_MAIL_SUBJECT (subject) || rfc_header || 'Content-Type: text/html; charset=UTF-8\r\n\r\n';

  -- !!! check subject !!!

  if (N_NM_REF is not null) -- comments
    {
      declare refs, post_allowed, p_refs, p_id, p_bm_id any;
      declare rlen int;
--      dbg_printf ('N_NM_REF=[%s]', N_NM_REF);
      declare exit handler for not found
	{
	  signal ('CONV1', 'No such article.');
	};

      p_refs := N_NM_REF;
      p_bm_id := null;
      refs := split_and_decode (N_NM_REF, 0, '\0\0 ');

--      dbg_obj_print (refs);

      rlen := length (refs);
      if (rlen)
	{
	  N_NM_REF := refs[0];
	  p_id := refs [rlen - 1];
	}

      select B_POST_ID, B_BLOG_ID, B_TITLE, BI_COMMENTS into id, bid, subject1, post_allowed from BLOG..SYS_BLOGS,
	     BLOG..SYS_BLOG_INFO where B_RFC_ID = N_NM_REF and BI_BLOG_ID = B_BLOG_ID;

      if (rlen)
	{
	  declare exit handler for not found;
	  --dbg_printf ('p_id=[%s] bid=[%s] id=[%s]', p_id, bid, id);
	  select BM_ID into p_bm_id from BLOG..BLOG_COMMENTS where BM_BLOG_ID = bid and BM_POST_ID = id and BM_RFC_ID = p_id;
	  --dbg_printf ('p_bm_id=[%d]', p_bm_id);
	}

      if (post_allowed = 0)
	signal ('CONV2', '440 Posting not allowed.');

      if (subject is null)
	subject := 'Re: '|| subject1;

      BLOG..SPLIT_MAIL_ADDR (author, name, mail);

      insert into BLOG..BLOG_COMMENTS (BM_BLOG_ID, BM_POST_ID, BM_COMMENT, BM_NAME, BM_E_MAIL,
				       BM_HOME_PAGE, BM_ADDRESS, BM_TS, BM_RFC_ID, BM_RFC_HEADER, BM_TITLE,
				       BM_REF_ID, BM_RFC_REFERENCES)
	  values (bid, id, content, name, mail, '', client_attr ('client_ip'), N_NM_REC_DATE, N_NM_ID, rfc_header, subject,
	      			       p_bm_id, p_refs);
    }
  else -- post,  user is authorized
    {
      declare rc, u_id int;
      declare meta BLOG.DBA."MTWeblogPost";
      declare bids any;
      declare i integer;


--      bid :=  get_keyword_ucase ('Newsgroups', head);
      bids:= split_and_decode (get_keyword_ucase ('Newsgroups', head,''), 0, '\0\0,');
      for(i:=0;i<length(bids);i:=i+1)
      {
        if(locate('-blog-',bids[i]))
        {
          bid :=bids[i];
      rc := DB.DBA.BLOG2_GET_USER_ACCESS (bid, uid);

      if (rc <> 1 and rc <> 2)
	signal ('CONV1', 'The authenticated user have no permissions to write topic in this group.');

      id := cast (sequence_next ('blogger.postid') as varchar);
      u_id := (select U_ID from SYS_USERS where U_NAME = uid);

      meta := new BLOG.DBA."MTWeblogPost" ();
      meta.title := subject;
      meta.dateCreated := N_NM_REC_DATE;
      meta.postid := id;
      meta.userid := u_id;
      meta.author := author;
      meta.mt_allow_pings := 0;
      meta.mt_allow_comments := 0;

      insert into BLOG..SYS_BLOGS (B_APPKEY, B_POST_ID, B_BLOG_ID, B_TS, B_CONTENT, B_USER_ID, B_META, B_STATE,
	  B_RFC_ID, B_RFC_HEADER, B_TITLE)
	  values ('NNTP', id, bid, N_NM_REC_DATE, content, u_id, meta, 2, N_NM_ID, rfc_header, subject);
        }
      }
    }
};

create procedure DB.DBA.BLOG_NEWS_MSG_U
    (
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
    inout N_NM_BODY any
    )
{
  return;
};

create procedure DB.DBA.BLOG_NEWS_MSG_D (inout O_NM_ID any)
{
  signal ('CONV3', 'Delete of a blog comment is not allowed');
};



use BLOG;

-- This should depend of creation flags
create trigger SYS_BLOG_INFO_NEWS_I after insert on SYS_BLOG_INFO referencing new as N
{
   if (N.BI_SHOW_AS_NEWS = 0)
     return;
   insert into DB.DBA.NEWS_GROUPS (
	      NG_NEXT_NUM, NG_NAME, NG_DESC, NG_SERVER, NG_POST, NG_UP_TIME, NG_CREAT, NG_UP_INT,
	      NG_PASS, NG_UP_MESS, NG_NUM, NG_FIRST, NG_LAST, NG_LAST_OUT, NG_CLEAR_INT, NG_TYPE)
   values (0, N.BI_BLOG_ID, N.BI_TITLE, null, N.BI_COMMENTS, now(), now(), 30, 0, 0, 0, 0, 0, 0, 120, 'BLOG');
}
;

create trigger SYS_BLOG_INFO_NEWS_U after update on SYS_BLOG_INFO referencing old as O, new as N
{
   if (N.BI_SHOW_AS_NEWS = 0 and O.BI_SHOW_AS_NEWS = 0)
     return;
   else if (O.BI_SHOW_AS_NEWS = 1 and N.BI_SHOW_AS_NEWS = 0)
     {
       declare grp int;
       grp := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = O.BI_BLOG_ID);
       delete from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = grp;
       delete from DB.DBA.NEWS_GROUPS where NG_NAME = O.BI_BLOG_ID;
       return;
     }
   else if (O.BI_SHOW_AS_NEWS = 0 and N.BI_SHOW_AS_NEWS = 1)
     {
       declare gid, nexti int;
       insert into DB.DBA.NEWS_GROUPS (
	      NG_NEXT_NUM, NG_NAME, NG_DESC, NG_SERVER, NG_POST, NG_UP_TIME, NG_CREAT, NG_UP_INT,
	      NG_PASS, NG_UP_MESS, NG_NUM, NG_FIRST, NG_LAST, NG_LAST_OUT, NG_CLEAR_INT, NG_TYPE)
       values (0, N.BI_BLOG_ID, N.BI_TITLE, null, N.BI_COMMENTS, now(), now(), 30, 0, 0, 0, 0, 0, 0, 120, 'BLOG');
       gid := identity_value ();
     }
   else /* N.BI_SHOW_AS_NEWS = 1 and O.BI_SHOW_AS_NEWS = 1 */
     {
        update DB.DBA.NEWS_GROUPS set
	  NG_POST = N.BI_COMMENTS, NG_NAME = N.BI_BLOG_ID, NG_DESC = N.BI_TITLE
	  where NG_NAME = O.BI_BLOG_ID;
     }
}
;

create trigger SYS_BLOG_INFO_NEWS_D after delete on SYS_BLOG_INFO
{
  declare grp int;
  declare exit handler for not found
    {
      return;
    };
  select NG_GROUP into grp from DB..NEWS_GROUPS where NG_NAME = BI_BLOG_ID;
  delete from DB.DBA.NEWS_GROUPS where NG_NAME = BI_BLOG_ID;
  delete from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = grp;
}
;

create procedure MAKE_POST_RFC_MSG (inout head varchar, inout body varchar, in tree int := 0)
{
  declare ses any;
  ses := string_output ();
--  dbg_printf ('tag_head=[%d], tag_body=[%d]', __tag(head), __tag (body));
  http (head, ses);
  http (body, ses);
  http ('\r\n.\r\n', ses);
  ses := string_output_string (ses);
  if (tree)
    ses := serialize (mime_tree (ses));
  return ses;
};


-- XXX: should have policy for blog author mail, probably

create trigger SYS_BLOGS_NEWS_I after insert on SYS_BLOGS order 30 referencing new as N
{
  declare grp, ngnext int;
  declare mid, rfc, head, title, author any;

  declare exit handler for not found
    {
      return;
    };

  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = N.B_BLOG_ID;

  select B_RFC_ID into mid from SYS_BLOGS where B_BLOG_ID = N.B_BLOG_ID and B_POST_ID = N.B_POST_ID;

  if (ngnext < 1)
    ngnext := 1;

  -- this should be after all columns in the corresponding object row are set eq. rfc_id rfc_header etc.
  insert into DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP) values (mid, grp, ngnext);

  set triggers off;
  update DB.DBA.NEWS_GROUPS set NG_NEXT_NUM = ngnext + 1 where NG_NAME = N.B_BLOG_ID;
  DB.DBA.ns_up_num (grp);
  set triggers on;
};

-- XXX : maybe we should handle update ?!

create trigger SYS_BLOGS_NEWS_D after delete on SYS_BLOGS referencing old as O
{
  declare grp int;
  grp := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = O.B_BLOG_ID);
  if (grp is null)
    return;
  delete from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = O.B_RFC_ID and NM_GROUP = grp;
  DB.DBA.ns_up_num (grp);
};


create trigger BLOG_COMMENTS_NEWS_I after insert on BLOG_COMMENTS order 30 referencing new as N
{
  declare grp, ngnext int;
  declare mid, bid any;

  declare exit handler for not found
    {
      return;
    };

  select BM_RFC_ID, B_BLOG_ID into mid, bid from SYS_BLOGS, BLOG_COMMENTS where
      B_POST_ID = N.BM_POST_ID and
      BM_BLOG_ID = B_BLOG_ID and BM_POST_ID = B_POST_ID
      and BM_ID = N.BM_ID;


  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = bid;

  if (ngnext < 1)
    ngnext := 1;

  -- this should be after all columns in the corresponding object row are set eq. rfc_id rfc_header etc.
  insert into DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP) values (mid, grp, ngnext);

  set triggers off;
  update DB.DBA.NEWS_GROUPS set NG_NEXT_NUM = ngnext + 1 where NG_NAME = bid;
  DB.DBA.ns_up_num (grp);
  set triggers on;

};


create trigger BLOG_COMMENTS_NEWS_D after delete on BLOG_COMMENTS referencing old as O
{
  declare grp int;
  grp := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = O.BM_BLOG_ID);
  if (grp is null)
    return;
  delete from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = O.BM_RFC_ID and NM_GROUP = grp;
  DB.DBA.ns_up_num (grp);
};



create procedure BLOG_FILL_NEWS_GROUP (in bid varchar)
{
  declare grp, ngnext int;
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = bid;
  if (ngnext < 1)
    ngnext := 1;
  for select B_RFC_ID as mid from SYS_BLOGS where B_BLOG_ID = bid
    union all
      select BM_RFC_ID as mid from BLOG_COMMENTS where BM_BLOG_ID = bid
    do
      {
	insert soft DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP) values (mid, grp, ngnext);
	ngnext := ngnext + 1;
      }
  set triggers off;
  update DB.DBA.NEWS_GROUPS set NG_NEXT_NUM = ngnext + 1 where NG_NAME = bid;
  DB.DBA.ns_up_num (grp);
  set triggers on;
}
;
