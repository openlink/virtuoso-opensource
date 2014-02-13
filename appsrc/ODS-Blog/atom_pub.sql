--
--  $Id$
--
--  Atom publishing protocol support.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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

USE "BLOG"
;


create procedure atom_authenticate (inout req "blogRequest")
  {
  declare _u_name, _u_password varchar;
  declare _u_id integer;
  declare auth any;
  declare _user varchar;
  declare lines, line any;

  lines := http_request_header ();
  line := http_request_header (lines, 'X-WSSE');
  auth := db.dba.vsp_auth_vec (lines);

  if (isstring (line))
    {
      declare uid, pwd, nonce, crt, npwd any;
      line := 'X-WSSE: ' || replace (line, ',', '');

      _user := http_request_header (vector(line), 'X-WSSE', 'Username');
      pwd := http_request_header (vector(line), 'X-WSSE', 'PasswordDigest');
      nonce := http_request_header (vector(line), 'X-WSSE', 'Nonce');
      crt := http_request_header (vector(line), 'X-WSSE', 'Created');
      whenever not found goto wronguser;

      select U_NAME, U_PWD, U_ID
  into _u_name, _u_password, _u_id from WS.WS.SYS_DAV_USER
  where U_NAME = _user and U_ACCOUNT_DISABLED = 0 with (prefetch 1);
      _u_password := pwd_magic_calc (_u_name, _u_password, 1);
      npwd := sha1_digest (concat (decode_base64(nonce), crt, _u_password));
      if (npwd = pwd)
        {
    commit work;
    req.user_name := _u_name;
    req.passwd := _u_password;
    req.auth_userid := _u_id;
    declare exit handler for sqlstate '*' {
      goto wronguser;
    };
    "blogger_auth" (req);
          return 1;
        }
      wronguser:;
      http_request_status ('HTTP/1.1 401 Unauthorized');
      http_header ('WWW-Authenticate: WSSE realm="Atom", profile="UsernameToken"\r\n');
      return 0;
    }
  else if (0 = auth)
    {
      wronga:;
      http_body_read ();
      db.dba.vsp_auth_get ('Atom', http_map_get ('domain'), md5 (datestring(now())), md5 ('opaakki'), 'false', lines, 1);
      http_request_status ('HTTP/1.1 401 Unauthorized');
      return 0;
    }

  _user := get_keyword ('username', auth);

  if (_user = '' or isnull (_user))
    {
      goto wronga;
    }

  whenever not found goto wronga;

  select U_NAME, U_PWD, U_ID
    into _u_name, _u_password, _u_id from WS.WS.SYS_DAV_USER
    where U_NAME = _user and U_ACCOUNT_DISABLED = 0 with (prefetch 1);

  if (_u_password is null)
    goto wronga;

  if (db.dba.vsp_auth_verify_pass (auth, _u_name,
          coalesce(get_keyword ('realm', auth), ''),
          coalesce(get_keyword ('uri', auth), ''),
          coalesce(get_keyword ('nonce', auth), ''),
          coalesce(get_keyword ('nc', auth),''),
          coalesce(get_keyword ('cnonce', auth), ''),
          coalesce(get_keyword ('qop', auth), ''),
          _u_password))
    {
      commit work;
      req.user_name := _u_name;
      req.passwd := pwd_magic_calc (_u_name, _u_password, 1);
      declare exit handler for sqlstate '*' {
        goto wronga;
      };
      "blogger_auth" (req);
      return 1;
    }
   goto wronga;
  }
;


create procedure atom_new_entry (inout struct "MTWeblogPost", inout req "blogRequest")
  {
    declare postId, cnt varchar;
    postId := cast (sequence_next ('blogger.postid') as varchar);
    struct.postid := postId;
    cnt := struct.description;
    struct.description := null;

    if (length (trim (cnt)) = 0)
      signal ('22023', 'Empty posts are not allowed');

    insert into SYS_BLOGS (B_APPKEY, B_BLOG_ID, B_CONTENT, B_POST_ID, B_USER_ID, B_TS, B_META, B_STATE, B_TITLE)
    values (req.appkey, req.blogid, cnt, struct.postId, req.auth_userid, struct.dateCreated, struct, 2,
	struct.title);
    return postId;
  }
;

create procedure atom_new_comment (inout blogid varchar, inout struct "MTWeblogPost", inout req "blogRequest")
  {
    insert into BLOG_COMMENTS
    (BM_BLOG_ID, BM_POST_ID, BM_COMMENT, BM_NAME, BM_E_MAIL, BM_HOME_PAGE, BM_ADDRESS, BM_TS)
    values
    (blogid, struct.postId, struct.description, struct.author, '', '', http_client_ip (), now ());
    return identity_value ();
  }
;

create procedure atom_edit_entry (inout struct "MTWeblogPost", inout req "blogRequest", in ver int)
  {
    declare cnt varchar;
    cnt := struct.description;
    struct.description := null;
    if (length (trim (cnt)) = 0)
      signal ('22023', 'Empty posts are not allowed');
    update SYS_BLOGS set B_CONTENT = cnt, B_META = struct, B_VER = ver where B_POST_ID = req.postId;
    return row_count ();
  }
;

create procedure atom_serialize_entry (inout req "blogRequest")
  {
    declare userid, content, dt, home any;
    declare res "MTWeblogPost";
    declare ss, _res any;

    ss := string_output ();
    whenever not found goto nf;
    select B_META, B_USER_ID, B_CONTENT, B_TS, BI_HOME into _res, userid, content, dt, home
    from SYS_BLOGS, SYS_BLOG_INFO
    where B_POST_ID = req.postId and BI_BLOG_ID = B_BLOG_ID;
    if (_res is null)
      {
  res := new "MTWeblogPost" ();
  res.postid := req.postId;
  res.title := BLOG_MAKE_TITLE (content);
      }
    else
      res := _res;
    res.author := (select U_NAME from "DB"."DBA"."SYS_USERS" where U_ID = userid);
    res.userid := res.author;
    res.dateCreated := dt;
    res.description := blob_to_string (content);

    atom_serialize (res, ss, home, req.postid, req.blogid);

    return string_output_string (ss);
    nf:
    signal ('22023', 'Cannot find a post with Id = ' || req.postId);
  }
;

create procedure atom_serialize (inout res "MTWeblogPost", inout ss any,
    in bloghome varchar := null, in postid varchar := null, in blogid varchar := null, in new_post int := 0)
  {
    if (res.mt_excerpt is null)
      res.mt_excerpt := '';
    if (res.mt_text_more is null)
      res.mt_text_more := '';
    if (res.dateCreated is null)
      res.dateCreated := now ();

    http (sprintf ('<?xml version="1.0" encoding="%s" ?>\n', 'utf-8'),ss);
    http ('<entry xmlns="http://www.w3.org/2005/Atom">\n',ss);
    if (postid is not null)
      http (sprintf ('<id>http://%s/%s</id>\n', BLOG_GET_HOST (), postid),ss);
    http (sprintf ('<title type="text">%V</title>\n', blog_wide2utf (res.title)),ss);
    http (sprintf ('<updated>%s</updated>\n', soap_print_box(dt_set_tz (res.dateCreated, 0), '', 0)),ss);
    -- XXX: add version
    if (postid is not null and bloghome is not null)
      {
        declare permalink varchar;
	permalink := sprintf ('http://%s%s?id=%s', BLOG_GET_HOST (), bloghome, postid);
        http (sprintf ('<link rel="alternate" type="text/html" href="%s"/>\n', permalink),ss);
        http (sprintf ('<link rel="edit" href="http://%s/%s" />\n', BLOG.DBA.GET_HTTP_URL (), postid),ss);
      }
    http ('<content type="html"><![CDATA[', ss);
    http (blog_wide2utf (res.description), ss);
    http (']]></content>\n',ss);
    http ('</entry>',ss);
  }
;

create procedure atom_delete_entry (inout req "blogRequest", in ver int)
  {
    declare over int;
    declare rc int;
    declare cr cursor for select B_VER from SYS_BLOGS where B_POST_ID = req.postid and B_BLOG_ID = req.blogid;

    declare exit handler for not found
      {
	return 0;
      };

    open cr (prefetch 1, exclusive);
    fetch cr into over;

    if (ver <> over)
      signal ('BLOGV', 'Specified version number doesn\'t match resource\'s latest version number.');

    delete from SYS_BLOGS where B_POST_ID = req.postid and B_BLOG_ID = req.blogid;
    close cr;
    return 1;
  }
;

create procedure atom_parse_entry (inout xt any)
  {
    declare post MTWeblogPost;
    declare ss any;
    declare tims datetime;

    ss := string_output ();
    post := new MTWeblogPost ();
    post.dateCreated := now ();

    post.title :=   blog_wide2utf (xpath_eval ('string (/entry/title)', xt));
    post.mt_excerpt :=  blog_wide2utf (xpath_eval ('string (/entry/subtitle)', xt, 1));
    post.mt_text_more := blog_wide2utf (xpath_eval ('string (/entry/summary)', xt, 1));
    post.author :=  blog_wide2utf (xpath_eval ('string (/entry/author/name)', xt, 1));
    tims := cast(xpath_eval ('/entry/issued/text()', xt, 1) as varchar);
    if (tims is not null)
      post.dateCreated := cast (tims as datetime);
    if (xpath_eval ('/entry/content[@type="text" or @type="html" or @mode="escaped"]', xt, 1) is not null)
      {
	post.description := blog_wide2utf (xpath_eval ('string (/entry/content)', xt));
      }
    else
      {
	post.description := xpath_eval ('/entry/content/*', xt, 1);
	http_value (post.description, null, ss);
	post.description := string_output_string (ss);
      }

    return post;
  }
;

--
-- ATOM API
--

create procedure
atom_req_headers (in req "blogRequest", in what int := 0)
  {
    declare b any;
    if (req.user_name is not null)
      {
  b := encode_base64 (req.user_name||':'||req.passwd);
	return sprintf ('%s: application/atom+xml\r\nAuthorization: Basic %s', case when what = 0 then 'Content-Type' else 'Accept' end, b);
      }
    else
      {
	return sprintf ('%s: application/atom+xml', case when what = 0 then 'Content-Type' else 'Accept' end);
      }
  }
;

create procedure atom_parse_search (in xt any)
  {
    declare arr, res any;
    declare tit, url varchar;
    declare i, l int;
    arr := xpath_eval ('/feed/entry', xt, 0);
    l := length (arr); i := 0;
    res := make_array (l, 'any');
    while (i < l)
      {
	  tit := cast (xpath_eval ('string (title)', xml_cut (arr[i]), 1) as varchar);
	  url := cast (xpath_eval ('link[@rel="edit"]/@href', xml_cut (arr[i]), 1) as varchar);
	  res[i] :=  vector (tit, url);
	  i := i + 1;
      }
    return res;
  }
;

create procedure
atom.new_Post (in uri varchar, in req "blogRequest")
  {
    declare postid, resp, h, edit_url varchar;
    declare ss, _struct any;
    ss := string_output ();
    if (req.struct is null)
      {
      declare stru "MTWeblogPost";
      stru := new "MTWeblogPost" ();
      stru.description := '';
      req.struct := stru;
      }
    _struct := req.struct;
    atom_serialize (_struct, ss, null, null, null, 1);
    ss := string_output_string (ss);
    resp := http_get (uri, h, 'POST', atom_req_headers (req), ss);
    if (h[0] not like 'HTTP/1._ 2% %')
      signal ('22023', trim (h[0], '\r\n '));
    edit_url := http_request_header (h, 'Location');
    if (not isstring (edit_url))
      {
        declare xt any;
	xt := xtree_doc (resp);
	edit_url := cast (xpath_eval ('/entry/link[@rel="edit"]/@href', xt) as varchar);
      }
    return edit_url;
  }
;

create procedure
atom.edit_Post (in uri varchar, in req "blogRequest")
  {
    declare ss, resp, h, _struct any;
    ss := string_output ();
    if (req.struct is null)
      {
  declare stru "MTWeblogPost";
  stru := new "MTWeblogPost" ();
  stru.description := '';
        req.struct := stru;
      }
    _struct := req.struct;
    atom_serialize (_struct, ss, null, null, null, 1);
    ss := string_output_string (ss);
    resp := http_get (uri, h, 'PUT', atom_req_headers (req), ss);
    if (h[0] not like 'HTTP/1._ 2% %')
      signal ('22023', trim (h[0], '\r\n '));
    return 1;
  }
;

create procedure
atom.get_Post (in uri varchar, in req "blogRequest")
  {
    declare post, xt, resp, h any;
    resp := http_get (uri, h, 'GET', atom_req_headers (req, 1));
    if (h[0] not like 'HTTP/1._ 2% %')
      signal ('22023', trim (h[0], '\r\n '));
    xt := xml_tree_doc (resp);
    post := atom_parse_entry (xt);
    return post;
  }
;

create procedure
atom.delete_Post (in uri varchar, in req "blogRequest")
  {
    declare resp, h any;
    resp := http_get (uri, h, 'DELETE', atom_req_headers (req, 1));
    if (h[0] not like 'HTTP/1._ 2% %')
      signal ('22023', trim (h[0], '\r\n '));
    return 1;
  }
;

create procedure
atom.get_RecentPosts (in uri varchar, in req "blogRequest", in num int)
  {
    declare res, resp, h any;
    uri := uri || '?max-results=' || cast (num as varchar);
    resp := http_get (uri, h, 'GET', atom_req_headers (req, 1));
    if (h[0] not like 'HTTP/1._ 2% %')
      signal ('22023', trim (h[0], '\r\n '));
    res := atom_parse_search (xml_tree_doc (resp));
    return res;
  }
;



