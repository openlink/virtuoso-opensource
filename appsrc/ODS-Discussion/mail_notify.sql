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

create procedure nntpf_encode_subject (in txt any)
{
  declare enc any;
  txt := wa_wide_to_utf8 (txt);
  txt := trim (txt);
  enc :=  encode_base64 (txt);
  enc := replace (enc, '\r\n', '');
  txt := concat ('=?UTF-8?B?', enc, '?=');
  return txt;
};

create procedure nntpf_transform_message (in sender varchar, in recv varchar, in grp varchar, in subj varchar, in dat varchar,
    in _repl varchar, inout _body any, inout head any, inout ses any)
{
  declare hdr, h any;
  declare body varchar;

  string_output_flush (ses);
  http (sprintf ('Sender: %s\r\n', sender), ses);
  http (sprintf ('To: %s\r\n', recv), ses);
  http (sprintf ('Reply-To: %s\r\n', _repl), ses);

  hdr := deserialize (head);
  h := hdr[0];

  for (declare i int, i := 0; i < length (h); i := i + 2)
     {
       declare kwd varchar;
       kwd := lower (h[i]);
       if (kwd not in ('to', 'reply-to', 'newsgroups', 'charset'))
	 {
	   http (h[i]||': ', ses);

	   if (kwd <> 'subject')
	     http (h[i+1], ses);
	   else
	     {
	       declare orig varchar;
	       orig := h[i+1];
               nntpf_decode_subj (orig);
	       if (lower (orig) like 're:%')
		 {
		   orig := substring (orig, 4, length (orig));
		   orig := 'Re: [' || grp || '] ' || nntpf_encode_subject (orig);
		 }
	       else
		 {
		   orig := '[' || grp || '] ' || nntpf_encode_subject (orig);
		 }
	       http (orig, ses);
	     }

	   if (kwd = 'content-type')
	     {
	       declare enc any;
	       enc := get_keyword_ucase ('charset', h);
	       if (enc is not null)
		 http (sprintf ('; charset=%s', enc), ses);
	     }
	   http ('\r\n', ses);
	 }
     }

  http ('\r\n', ses);

  body := subseq (_body, hdr[1][0], hdr[1][1]);

  http (body, ses);

};


create procedure nntpf_send_message (in mail_server varchar, in sender varchar, in recv varchar, inout mail_messages any)
{
  declare body varchar;
  declare continue handler for sqlstate '*' { dbg_obj_print ('An error during smtp_send');  };

  body := string_output_string (mail_messages);
  string_output_flush (mail_messages);

--  dbg_obj_print (body);

  commit work;
--  dbg_obj_print ('sending...');
  smtp_send (mail_server, sender, recv, body);
--  dbg_obj_print ('done...');
};


create procedure NNTPF_MAIL_NOTIFICATIONS ()
{
  declare mail_server, mail_messages, ses, dat, sender, _repl, _domain any;
  declare inx int;

  if ((select WS_USE_DEFAULT_SMTP from WA_SETTINGS) = 1)
    {
      mail_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
    }
  else
    {
      mail_server := (select WS_SMTP from WA_SETTINGS);
    }

  _domain := (select top 1 WS_DEFAULT_MAIL_DOMAIN from WA_SETTINGS);
  if (not length (_domain))
    _domain := sys_stat ('st_host_name');

  dat := sprintf ('Date: %s\r\n', date_rfc1123 (now ()));
  sender := (select top 1 U_E_MAIL from DB.DBA.SYS_USERS where U_NAME = 'dav');
  mail_messages := string_output ();
  ses := string_output ();

  for select NS_MAIL as _ns_mail, NS_GROUP as _ns_group, NS_THREAD_ID as _ns_thread_id, NS_TYPE as _ns_type, NS_DIGEST as _ns_digest, NS_TS as _ns_ts, NG_TYPE as _ng_type, NG_NAME as _ng_name from NNTPF_SUBS, NEWS_GROUPS
    where NS_GROUP = NG_GROUP and NS_TS < now () do
    {
      inx := 0;
      _repl := _ng_name || '@' || _domain;
       if (_ns_type = 1)
	 {
	   http (dat, ses);
	   http (sprintf ('Sender: %s\r\n', sender), ses);
	   http (sprintf ('To: %s\r\n', _ns_mail), ses);
	   --http (sprintf ('Reply-To: %s\r\n', _repl), ses);
	   http (sprintf ('Subject: [%s] Digest #%d\r\n', _ng_name, _NS_DIGEST), ses);
	   http (sprintf ('Content-Type: text/plain\r\n\r\n'), ses);
	 }
       for select FTHR_MESS_ID, FTHR_REFER, FTHR_SUBJ, FTHR_DATE, FTHR_MESS_DETAILS, FTHR_TOPIC_ID from NNFE_THR where
	  FTHR_GROUP = _ns_group and FTHR_DATE > _ns_ts do
	  {
	      declare dummy any;

	      if (_ns_thread_id = '' or FTHR_TOPIC_ID = _ns_thread_id)
	        {
	          declare body, head any;
	          select NM_BODY, NM_HEAD into body, head from NEWS_MSG where
	      	  NM_ID = FTHR_MESS_ID and NM_TYPE = _ng_type;
	          if (_ns_type = 0) -- individual mails
	            {
		      nntpf_transform_message (sender, _ns_mail, _ng_name, FTHR_SUBJ, dat, _repl, body, head, mail_messages);
	              nntpf_send_message (mail_server, sender, _ns_mail, mail_messages);
	            }
		  else
		    {
		      declare _from any;
		      _from := deserialize (FTHR_MESS_DETAILS);
		      _from := _from [0];

		      inx := inx + 1;
		      http (sprintf ('Message #%d\r\n', inx), mail_messages);
		      http (sprintf ('   Subject: %s\r\n', FTHR_SUBJ), mail_messages);
		      http (sprintf ('   From: %s\r\n', _from), mail_messages);
		      http (sprintf ('   Date: %s\r\n', date_rfc1123 (FTHR_DATE)), mail_messages);
		      http ('---------------------------\r\n\r\n', mail_messages);
		    }
	        }
	  }
       if (_ns_type = 1 and inx > 0)
         {
	   http (sprintf ('There are %d messages in this issue.\r\nTopics in this digest: \r\n\r\n', inx), ses);
	   http (string_output_string (mail_messages), ses);
	   nntpf_send_message (mail_server, sender, _ns_mail, ses);
         }
       string_output_flush (ses);
       string_output_flush (mail_messages);
       -- enable the bellow
       update NNTPF_SUBS set NS_TS = now (), NS_DIGEST = _ns_digest + 1 where
         NS_MAIL = _ns_mail and NS_GROUP = _ns_group and NS_THREAD_ID = _ns_thread_id;
    }
};

-- !!! check various flags etc.
create procedure NNTPF_MAIL_VALIDATE (in gname varchar)
{
  declare grp any;
  declare exit handler for not found
    {
      return 0;
    };
  select NG_GROUP into grp from NEWS_GROUPS where NG_NAME = gname;
  if (ns_rest (grp, 1) = 0)
    return 0;
  result ('__news_group:' || gname);
  return 1;
};

create procedure NNTPF_NEW_MAIL (in gname varchar, in _msg any)
{
  declare gid, tree, head, _start, _end, ses any;

  if (gname not like '__news_group:%')
    return 0;

  gname := substring (gname, 14, length (gname));

  declare exit handler for not found
    {
      return 0;
    };
  select NG_GROUP into gid from NEWS_GROUPS where NG_NAME = gname;

  -- XXX: insert the message into the news group
  tree := mime_tree (_msg);
  head := tree[0];
  _start := tree[1][0];
  _end :=   tree[1][1];

  ses := string_output ();

  http (sprintf ('Newsgroups: %s\r\n', gname), ses);

  --for (declare int i; i := 0; i < length (head); i := i + 2)
  --  {
  --    http (sprintf ('%s: %s\r\n', head[i], head[i+1]), ses);
  --  }

  --http ('\r\n', ses);
  --http (subseq (_msg, _start, _end), ses);

  http (_msg, ses);

  _msg := string_output_string (ses);

--  dbg_obj_print (gname, _msg);

  -- XXX: put handler here
  ns_post (_msg);

  return 1;
};

--nntpf_mail_notifications ();

insert soft DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
		values ('Send the NNTP subscriptions', now(), 'NNTPF_MAIL_NOTIFICATIONS ()', 1440)
;
