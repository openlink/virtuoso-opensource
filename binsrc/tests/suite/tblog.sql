--
--  $Id: tblog.sql,v 1.9.10.1 2013/01/02 16:14:59 source Exp $
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
echo BOTH "STARTED: XML-RPC tests\n";
CONNECT;

--set echo on;

SET ARGV[0] 0;
SET ARGV[1] 0;

--vhost_remove (lpath=>'/RPC2');

vhost_remove (lpath=>'/xmlStorageSystem');


--vhost_define (lpath=>'/RPC2', ppath=>'/SOAP/', soap_user=>'dba', soap_opts=>vector ('XML-RPC', 'yes'));
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": /RPC2 endpoint added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--grant execute on  "blogger.newPost" to DBA;
--grant execute on  "blogger.editPost" to DBA;
--grant execute on  "blogger.deletePost" to DBA;
--grant execute on  "blogger.getPost" to DBA;
--grant execute on  "blogger.getRecentPosts" to DBA;
--grant execute on  "blogger.getUsersBlogs" to DBA;
--grant execute on  "blogger.getTemplate" to DBA;
grant execute on  "blogger.setTemplate" to DBA;
--grant execute on  "blogger.getUserInfo" to DBA;

vhost_define (lpath=>'/xmlStorageSystem', ppath=>'/SOAP/', soap_user=>'dba');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": /xmlStorageSystem endpoint added : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from BLOG..SYS_BLOGS;

sequence_set ('blogger.postid', 0, 0);

delete user "xss@example.domain";

DAV_DELETE ('/DAV/xss@example.domain/', 0, 'dav', 'dav');

create procedure blog_check (in xtr any, in what varchar)
{
  declare xt any;
  declare res varchar;
  dbg_obj_print ('xtr  = ', xtr);
  dbg_obj_print ('what = ', what);
  xt := xml_cut (xml_tree_doc (xtr));
  res := cast (xpath_eval ('//'||what||'/text()', xt, 1) as varchar);
  dbg_obj_print ('res = ', res);
  result_names (res);
  res := replace (res, '$U{HTTPPORT}', '');
  result (res);
}
;

--BLOG_CREATE_DEFAULT_SITE ('/DAV/dav/blog/', http_dav_uid (), 'dav', 'dav');
--BLOG..BLOG_CREATE_DEFAULT_SITE ('/DAV/home/dav/dav-blog-0/', http_dav_uid (), 'dav', 'dav');
--USER_SET_OPTION ('dav', 'HOME', '/DAV/dav/');

DROP TABLE DB.DBA.REAL_POSTS;
CREATE TABLE DB.DBA.REAL_POSTS(MD5 VARCHAR(4080) NOT NULL,LINK VARCHAR(4080),TITLE LONG VARCHAR,DESCR LONG VARCHAR,RDATE TIMESTAMP,PRIMARY KEY(MD5));
-- SELECT * FROM DB.DBA.REAL_POSTS
-- Table DB.DBA.REAL_POSTS has more than one blob column.
-- The column DESCR of type LONG VARCHAR might not get properly inserted.
FOREACH BLOB INSERT INTO DB.DBA.REAL_POSTS(MD5,LINK,TITLE,DESCR,RDATE) VALUES('0010dcd67b2ac100926b9da57f7c9812','http://www.nhfordean.com/deanspace/?q=node/view/2124',?,?,NULL);
Democracy for America\c
BLOB
Gov. Dean has formed a new organization, <a href="http://www.democracyforamerica.com/">Democracy For America</a>, to build on the grassroots support for his pre\c
sidential campaign. DFA will recruit and help finance progressive candidates for office at all levels, raise funds for Congressional candidates, build relations\c
hips with other progressive organizations and initiatives, and harness the power of the Internet to support the new organization and further its goals.<br />
<br />
Democracy for New Hampshire has been created to pursue these goals on a regional level. The <a href="http://www.democracyfornewhampshire.com/">DFNH Web site</a\c
> is now operational. See you there!\c
END
FOREACH BLOB INSERT INTO DB.DBA.REAL_POSTS(MD5,LINK,TITLE,DESCR,RDATE) VALUES('001e00e915edc51943aa31cb7d56d721','http://www.vila-real.com/node/4144',?,?,NULL);
Neu\c
BLOB
<p>Si teniu ocasió,\240aguaiteu per la finestra. Està nevant a Vila-real.</p>
END
FOREACH BLOB INSERT INTO DB.DBA.REAL_POSTS(MD5,LINK,TITLE,DESCR,RDATE) VALUES('002b67a637846b27fa66195d907864ac','http://www.nrojr.gov/',?,?,NULL);
NRO jr.\c
BLOB
The National Reconnaissance Office\47s website for kids. Because it\47s never to soon to learn that you\47re always being watched...from space.\c
END
FOREACH BLOB INSERT INTO DB.DBA.REAL_POSTS(MD5,LINK,TITLE,DESCR,RDATE) VALUES('003287eab8fd717025281e674a2b6578','http://www.danesparza.us/node/50',?,?,NULL);
Iraqis realize they have a country to own\c
BLOB
<p>This is some really exciting stuff &#8212; Iraqis are starting to realize that the <span class="caps">U.S. </span>is encouraging them to care about their own\c
 country.  </p>
<blockquote><p>
From <a title="My Way News" href="http://apnews.myway.com/article/20050301/D88IBJF00.html">My Way News</a></p>
<p><span class="caps">BAGHDAD,</span> Iraq (AP) - More than 2,000 people demonstrated Tuesday at the site of a car bombing south of Baghdad that killed 125 peo\c
ple, chanting &#8220;No to terrorism!&#8221;</p>\c
END

create procedure init (in _begin int, in users int)
{

  declare uid int;

  for (declare x any, x := _begin; x <= users ; x := x + 1)
    {
       declare name varchar;
       declare _inst wa_blog2;
       declare _id, _start any;

       _start := now ();
       name := sprintf ('user_%i', x);

       uid := DB.DBA.USER_CREATE (name, name,
	    vector ('E-MAIL', sprintf ('user_%i@openlinksw.com', x),
		    'FULL_NAME', sprintf ('User_%i User_%i', x, x),
		    'HOME', '/DAV/home/' || name || '/',
		    'DAV_ENABLE' , 1,
		    'SQL_ENABLE', 1));
       DAV_MAKE_DIR ('/DAV/home/' || name || '/', uid, null, '110100100R');
       USER_SET_OPTION (name, 'SEC_QUESTION', 'aaaaaaa bbbbbb');
       USER_SET_OPTION (name, 'SEC_ANSWER', 'ccccccc');
       USER_SET_OPTION (name, 'FIRST_NAME', name);
       USER_SET_OPTION (name, 'LAST_NAME', name);

       commit work;

       _inst := new wa_blog2();
       _inst.wa_name := name || '''s BLOG [1]';

       _id := _inst.wa_new_inst(name);

       commit work;

       if (mod (x, 250) = 0)
	{
	 delay (10);
         exec ('checkpoint');
	 delay (10);
	}

    }
        exec ('checkpoint');
}
;



create procedure create_single_user ()
{

  declare uid int;

       declare name varchar;
       declare _inst wa_blog2;
       declare _id, _start any;

       _start := now ();
       name := uuid ();

       uid := DB.DBA.USER_CREATE (name, 'pass',
	    vector ('E-MAIL', sprintf ('user_%s@openlinksw.com', name),
		    'FULL_NAME', sprintf ('User_%s User_%s', name, name),
		    'HOME', '/DAV/home/' || name || '/',
		    'DAV_ENABLE' , 1,
		    'SQL_ENABLE', 1));
       DAV_MAKE_DIR ('/DAV/home/' || name || '/', uid, null, '110100100R');
       USER_SET_OPTION (name, 'SEC_QUESTION', 'aaaaaaa bbbbbb');
       USER_SET_OPTION (name, 'SEC_ANSWER', 'ccccccc');
       USER_SET_OPTION (name, 'FIRST_NAME', name);
       USER_SET_OPTION (name, 'LAST_NAME', name);

       commit work;

       _inst := new wa_blog2();
       _inst.wa_name := name || '''s BLOG [1]';

       _id := _inst.wa_new_inst(name);

       commit work;

       exec ('checkpoint');
}
;


create procedure user_post (in user_name any)
{
                declare msg vspx_textarea;
                declare id, blogid, user_id varchar;
                declare dummy any;
                declare res DB.DBA."MTWeblogPost";

		user_name := sprintf ('user_%i', user_name);

		blogid := user_name || '-blog-0';

	        select U_ID into user_id from sys_users where U_NAME = user_name;

                dummy := null;
                msg := repeat ('This is a post !!!', rand (25) + 1);
                if(msg <> '')
                {
                    declare dat datetime;
                    dat := now ();
                    id := cast (sequence_next ('blogger.postid') as varchar);
                    res := BLOG.DBA.BLOG_MESSAGE_OR_META_DATA (dummy, user_id, dummy, id, dat);
                    res.title := 'Title !!!';
                    res.dateCreated := dat;
                    res.postid := id;
                    insert into BLOG.DBA.SYS_BLOGS(B_APPKEY, B_POST_ID, B_BLOG_ID, B_TS, B_CONTENT, B_USER_ID, B_META, B_STATE)
                    values('appKey', id, blogid, dat, msg, user_id, res, 2);

                  declare categs, cur_cat varchar;
                  categs := '';
                  {
                    declare ix any;
                    declare cat varchar;
                    ix := 0;
		    cat := sprintf ('%i', rand (100));
                    {
                      if (cat <> '')
                      {
                        cur_cat := '';
                        whenever not found goto endcat;
                        select MTC_NAME into cur_cat from BLOG.DBA.MTYPE_CATEGORIES where MTC_ID=atoi(cat) and MTC_BLOG_ID=blogid;
                        endcat:;
                        if (cur_cat <> '' and cur_cat is not null)
                          categs := concat(categs, cur_cat, '%20');
                        insert into BLOG.DBA.MTYPE_BLOG_CATEGORY (MTB_CID, MTB_POST_ID, MTB_BLOG_ID) values (atoi(cat), id, blogid);
                      }
                    }
                  }
                  categs := trim(categs);
                  categs := replace(categs, '&', '%26');
                  categs := replace(categs, ' ', '%20');
                  {
                    declare username, dpassword, res1, error_msg, urlstr, cur_time, aaa, descr varchar;
                    declare hdr any;
                    declare tag_count, i integer;
                    whenever not found goto enddel;
                    select BI_DEL_USER, BI_DEL_PASS into username, dpassword from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID=blogid;
                    if (username = '' or username is null)
                      goto enddel;
                    cur_time := sprintf('%d-%02d-%02dT%02d:%02d:%02dZ', year(now()), month(now()), dayofmonth(now()), hour(now()), minute(now()), second(now()) );
                    urlstr := replace(urlstr, '&', '%26');
                    descr := 'Description . . .';
                    descr := replace(descr, '&', '%26');
                    descr := replace(descr, ' ', '%20');
                    aaa := sprintf('http://del.icio.us/api/posts/add?url=%s&description=%s&extended=%s&tags=%s&dt=%s', urlstr, descr, '', categs, cur_time);
                    res1 := http_get(aaa, hdr, 'POST', sprintf ('Content-Type: text/xml\r\nAuthorization: Basic %s', encode_base64 (concat(username, ':', dpassword))));
                  }
                  enddel:;
                  declare tbu any;
                  tbu := vector ();
                }
                else
                {
                  return 0;
                }
                return 1;
}
;

create procedure go_post (in len int)
{
  declare _all_u int;

  select count (*) into _all_u from sys_users;

  for (declare xx any, xx := 1; xx <= len ; xx := xx + 1)
    {
	declare _user integer;
	_user := rand (5260) + 1;
	_user := rand (100) + 1;
	user_post (_user);

        commit work;
        delay (1);

        if (mod (xx, 100) = 0)
	  {
	    create_single_user ();
            exec ('checkpoint');
	  }
    }
}
;


create procedure go_browse (in len int)
{

  for (declare x any, x := 1; x <= len ; x := x + 1)
    {
	declare _user integer;
	declare _url integer;
        declare _start any;

        _start := now ();
	commit work;
	_user := rand (5) + 1;
	_user := rand (5250) + 1;
	_user := rand (99) + 1;
	_url := sprintf ('http://zdravko:6666/weblog/user_%i/user_%i-blog-0/index.vspx', _user, _user);
    }
}
;


create procedure go_attach (in len int)
{

  for (declare x any, x := 1; x <= len ; x := x + 1)
    {
	declare _url integer;
	_url := sprintf ('BLOG..BLOG2_BLOG_ATTACH (''user_%i-blog-0'', ''user_%i-blog-0'')', x, x + 1);
	exec (_url);
	commit work;
	_url := sprintf ('BLOG..BLOG2_BLOG_ATTACH (''user_%i-blog-0'', ''user_%i-blog-0'')', x, x + 2);
	exec (_url);
	commit work;
	_url := sprintf ('BLOG..BLOG2_BLOG_ATTACH (''user_%i-blog-0'', ''user_%i-blog-0'')', x, x + 3);
	exec (_url);
	commit work;
	_url := sprintf ('BLOG..BLOG2_BLOG_ATTACH (''user_%i-blog-0'', ''user_%i-blog-0'')', x, x + 4);
	exec (_url);
	commit work;
	_url := sprintf ('BLOG..BLOG2_BLOG_ATTACH (''user_%i-blog-0'', ''user_%i-blog-0'')', x, x + 5);
	exec (_url);
	commit work;
    }
}
;
create procedure urlsimu_file (in len int)
{

  declare _all any;

  _all := 'zdravko 6666\n';

  for (declare x any, x := 1; x <= len ; x := x + 1)
    {
	declare _user integer;
	declare _url integer;
        declare _start any;

        _start := now ();
	commit work;
	_user := x;
-- 1 GET /weblog/user_311/user_311-blog-0/index.vspx HTTP/1.1
	_url := sprintf ('1 GET /weblog/user_%i/user_%i-blog-0/index.vspx HTTP/1.1', _user, _user);
	_all := _all || '\n' || _url;
    }

  _all := _all || '\n';
  string_to_file ('urls', _all, -2);
}
;

create procedure go_browse_100 ()
{

  for (declare x any, x := 1; x <= 101 ; x := x + 1)
    {
	declare _user integer;
	declare _url integer;
        declare _start any;

        _start := now ();
	commit work;

	_user := 33;
	delay (1);
	_url := sprintf ('http://zdravko:6666/weblog/user_%i/user_%i-blog-0/index.vspx', _user, _user);
    }
}
;


create procedure go_browse_rss (in len int)
{

  for (declare x any, x := 1; x <= len ; x := x + 1)
    {
	declare _user integer;
	declare _url integer;
        declare _start any;

        _start := now ();
	commit work;
	_user := rand (5) + 1;
	_user := rand (5250) + 1;
	_user := rand (100) + 1;
	_user := x;
--	delay (1);
	_url := sprintf ('http://zdravko:6666/weblog/user_%i/user_%i-blog-0/gems/rss.xml', _user, _user);
	_url := sprintf ('http://zdravko:6666/weblog/user_%i/user_%i-blog-0/gems/index.rdf', _user, _user);
	_url := sprintf ('http://zdravko:6666/weblog/user_%i/user_%i-blog-0/gems/atom.xml', _user, _user);
    }
}
;

-- select string_to_file ('art.xml', http_get ('http://www.weblogs.com/rssUpdates/changes.xml'), -2);

-- BLOG_FEED_AGREGATOR

--drop table REAL_POSTS
;

create procedure user_post_2 (in user_name any, in msg_text varchar, in in_date datetime, in in_title varchar)
{
                declare msg vspx_textarea;
                declare id, blogid, user_id varchar;
                declare dummy any;
                declare res BLOG.DBA."MTWeblogPost";

		user_name := sprintf ('user_%i', user_name);

		blogid := user_name || '-blog-0';

	        select U_ID into user_id from sys_users where U_NAME = user_name;

                dummy := null;
                msg := msg_text;
                if(msg <> '')
                {
                    declare dat datetime;
                    dat := in_date;
                    id := cast (sequence_next ('blogger.postid') as varchar);
                    res := BLOG.DBA.BLOG_MESSAGE_OR_META_DATA (dummy, user_id, dummy, id, dat);
                    res.title := in_title;
                    res.dateCreated := dat;
                    res.postid := id;
                    insert into BLOG.DBA.SYS_BLOGS(B_APPKEY, B_POST_ID, B_BLOG_ID, B_TS, B_CONTENT, B_USER_ID, B_META, B_STATE)
                    values('appKey', id, blogid, dat, msg, user_id, res, 2);

                  declare categs, cur_cat varchar;
                  categs := '';
                  {
                    declare ix any;
                    declare cat varchar;
                    ix := 0;
		    cat := sprintf ('%i', rand (100));
                    {
                      if (cat <> '')
                      {
                        cur_cat := '';
                        whenever not found goto endcat;
                        select MTC_NAME into cur_cat from BLOG.DBA.MTYPE_CATEGORIES where MTC_ID=atoi(cat) and MTC_BLOG_ID=blogid;
                        endcat:;
                        if (cur_cat <> '' and cur_cat is not null)
                          categs := concat(categs, cur_cat, '%20');
                        insert into BLOG.DBA.MTYPE_BLOG_CATEGORY (MTB_CID, MTB_POST_ID, MTB_BLOG_ID) values (atoi(cat), id, blogid);
                      }
                    }
                  }
                  categs := trim(categs);
                  categs := replace(categs, '&', '%26');
                  categs := replace(categs, ' ', '%20');
                  {
                    declare username, dpassword, res1, error_msg, urlstr, cur_time, aaa, descr varchar;
                    declare hdr any;
                    declare tag_count, i integer;
                    whenever not found goto enddel;
                    select BI_DEL_USER, BI_DEL_PASS into username, dpassword from BLOG.DBA.SYS_BLOG_INFO where BI_BLOG_ID=blogid;
                    if (username = '' or username is null)
                      goto enddel;
                    cur_time := sprintf('%d-%02d-%02dT%02d:%02d:%02dZ', year(now()), month(now()), dayofmonth(now()), hour(now()), minute(now()), second(now()) );
                    urlstr := replace(urlstr, '&', '%26');
                    descr := 'Description . . .';
                    descr := replace(descr, '&', '%26');
                    descr := replace(descr, ' ', '%20');
                    aaa := sprintf('http://del.icio.us/api/posts/add?url=%s&description=%s&extended=%s&tags=%s&dt=%s', urlstr, descr, '', categs, cur_time);
                    res1 := http_get(aaa, hdr, 'POST', sprintf ('Content-Type: text/xml\r\nAuthorization: Basic %s', encode_base64 (concat(username, ':', dpassword))));
                  }
                  enddel:;
                  declare tbu any;
                  tbu := vector ();
                }
                else
                {
                  return 0;
                }
                return 1;
}
;


create procedure go_post_2 ()
{
  declare _all_u, zz int;

  select count (*) into _all_u from sys_users;
  zz := 0;
  for (select TITLE, DESCR from REAL_POSTS) do
    {
	declare _user, _date_d integer;
	declare my_date datetime;
	_user := rand (10) + 1;
	_date_d :=  (-1) * rand (50) + 1;
	my_date := dateadd ('day', _date_d, now());
	user_post_2 (_user, DESCR, my_date, TITLE);

        commit work;
	zz := zz + 1;
        if (mod (zz, 500) = 0)
	  {
            exec ('checkpoint');
	  }
    }
}
;

create procedure real_post ()
{
  declare name, _all any;

  _all := xml_tree_doc (file_to_string ('art.xml'));

  name := xpath_eval ('/weblogUpdates/weblog/@url', _all, 0);

  declare exit handler for sqlstate '*'
     {
	rollback work;
	goto znext;
     };

  for (declare x any, x := 1; x <= length (name) ; x := x + 1)
    {
	declare mess any;
	declare _md5, _link, _tit, _desc any;
	mess := http_get (cast (name[x] as varchar));
	mess := xml_tree_doc (mess);
	_desc := xpath_eval ('//description', mess, 0);
	_tit := xpath_eval ('//title', mess, 0);
	_link := xpath_eval ('//link', mess, 0);

  	for (declare xx any, xx := 1; xx < length (_tit) ; xx := xx + 1)
	  {
		declare __link, __tit, __desc any;
		__link := cast (_link[xx - 1] as varchar);
		__tit := cast (_tit[xx - 1] as varchar);
		__desc := cast (_desc[xx - 1] as varchar);
		_md5 := MD5 (__desc || __tit || __link);
		insert soft REAL_POSTS (MD5, LINK, TITLE, DESCR) values (_md5, __link, __tit, __desc);
		commit work;
	  }
znext:;
    }
}
;


go_post_2 ();

checkpoint;

-- blog API tests
blog_check (XMLRPC_CALL ('http://localhost:$U{HTTPPORT}/RPC2', 'blogger.getUsersBlogs',
	vector ('appKey', 'dav', 'dav')), 'url');
ECHO BOTH $IF $EQU $LAST[1] "http://localhost:/weblog/dav/dav-blog-0/" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Default home page " $LAST[1] "\n";

blog_check (XMLRPC_CALL ('http://localhost:$U{HTTPPORT}/RPC2', 'blogger.setTemplate',
	vector ('appKey', 'dav-blog-0', 'dav', 'dav', '<template>', 'main')), 'Param1');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Template saved : result " $LAST[1] "\n";


blog_check (XMLRPC_CALL ('http://localhost:$U{HTTPPORT}/RPC2', 'blogger.getTemplate',
	vector ('appKey', 'dav-blog-0', 'dav', 'dav', 'main')), 'Param1');
ECHO BOTH $IF $EQU $LAST[1] '<template>' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Template retrieved " $LAST[1] "\n";

select blog.blogger.new_Post ('http://localhost:$U{HTTPPORT}/RPC2',
		BLOG.DBA."blogRequest" ('appKey', 'dav-blog-0', '', 'dav', 'dav'), 'this is a test');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": New message posted ID: " $LAST[1] "\n";

select blog.blogger.new_Post ('http://localhost:$U{HTTPPORT}/RPC2',
		BLOG.DBA."blogRequest" ('appKey', 'dav-blog-0', '', 'dav', 'dav'), 'this is a second test');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": New message posted ID: " $LAST[1] "\n";

select blog.blogger.edit_Post ('http://localhost:$U{HTTPPORT}/RPC2',
		BLOG.DBA."blogRequest" ('appKey', '', '1', 'dav', 'dav'), '>>> this is a test');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Message ID=1 edited : " $LAST[1] "\n";

select B_CONTENT from BLOG..SYS_BLOGS where B_POST_ID = '1';
ECHO BOTH $IF $EQU $LAST[1] '&gt;&gt;&gt; this is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Message ID=1 edited : " $LAST[1] "\n";

select blog.blogger.delete_Post ('http://localhost:$U{HTTPPORT}/RPC2',
		BLOG.DBA."blogRequest" ('appKey', '', '2', 'dav', 'dav'));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Message ID=2 deleted : " $LAST[1] "\n";

select blog.blogger.get_Post ('http://localhost:$U{HTTPPORT}/RPC2',
		BLOG.DBA."blogRequest" ('appKey', '', '1', 'dav', 'dav'));
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Message ID=1 retrieved : " $LAST[1] "\n";

select length (blog.blogger.get_Recent_Posts ('http://localhost:$U{HTTPPORT}/RPC2',
		BLOG.DBA."blogRequest" ('appKey', 'dav-blog-0', '', 'dav', 'dav'), 10));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last (max 10) message(s) retrieved #: " $LAST[1] "\n";

-- xSS tests

create procedure xss_check (in xt any, in what varchar := 'flError')
{
  declare xp any;
  declare msg any;
  result_names (xp);
  xp := cast (xpath_eval ('//'||what||'/text()', xt, 1) as varchar);
  msg := xpath_eval ('//message/text()', xt, 1);
  if (atoi(xp) = 1 and what = 'flError')
    signal ('XSS00', cast (msg as varchar));
  xp := replace (xp, '$U{HTTPPORT}', '');
  result (xp);
}
;

xss_check (xml_tree_doc (
            SOAP_CLIENT (
			url=>'http://localhost:$U{HTTPPORT}/xmlStorageSystem',
			operation=>'registerUser',
			parameters=>vector ('email','xss@example.domain',
					    'name', 'Blog User',
					    'password', 'secret',
					    'clientPort', 8080,
					    'userAgent', '' , 'serialNumber', ''))
		  ));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": registerUser xss@example.domain : flError: " $LAST[1] "\n";


xss_check (xml_tree_doc (
            SOAP_CLIENT (
			url=>'http://localhost:$U{HTTPPORT}/xmlStorageSystem',
			operation=>'registerUser',
			parameters=>vector ('email','xss@example.domain',
					    'name', 'Blog User',
					    'password', 'secret',
					    'clientPort', 8080,
					    'userAgent', '' , 'serialNumber', ''))
		  ));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": double registration : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


xss_check (xml_tree_doc (
	SOAP_CLIENT (
		url=>'http://localhost:$U{HTTPPORT}/xmlStorageSystem',
		operation=>'getServerCapabilities',
		parameters=>vector ('email','xss@example.domain',
				    'password', md5('secret')))
		));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": getServerCapabilities : flError: " $LAST[1] "\n";

xss_check (xml_tree_doc (
	SOAP_CLIENT (
		url=>'http://localhost:$U{HTTPPORT}/xmlStorageSystem',
		operation=>'getServerCapabilities',
		parameters=>vector ('email','xss@example.domain',
				    'password', md5('badsecret')))
		));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Bad authentication : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

xss_check (xml_tree_doc (
	SOAP_CLIENT (
		url=>'http://localhost:$U{HTTPPORT}/xmlStorageSystem',
		operation=>'getServerCapabilities',
		parameters=>vector ('email','xss@example.domain',
				    'password', md5('secret')))
		), 'yourUpstreamFolderUrl');
ECHO BOTH $IF $EQU $LAST[1] 'http://localhost:/DAV/xss@example.domain/blog/' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": getServerCapabilities : yourUpstreamFolderUrl " $LAST[1] "\n";

xss_check (xml_tree_doc (
		SOAP_CLIENT (url=>'http://localhost:$U{HTTPPORT}/xmlStorageSystem',
		operation=>'saveMultipleFiles',
		parameters=>vector ('email','xss@example.domain', 'password', md5 ('secret'),
		'relativepathList', vector('test.txt', 'sub/test.txt'), 'fileTextList', vector ('this is a test', 'second')))
		));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": saveMultipleFiles : flError: " $LAST[1] "\n";

select blob_to_string(RES_CONTENT) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/xss@example.domain/blog/test.txt';
ECHO BOTH $IF $EQU $LAST[1] 'this is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": saveMultipleFiles test.txt (check) : " $LAST[1] "\n";

select blob_to_string(RES_CONTENT) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/xss@example.domain/blog/sub/test.txt';
ECHO BOTH $IF $EQU $LAST[1] 'second' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": saveMultipleFiles sub/test.txt (check) : " $LAST[1] "\n";


xss_check (xml_tree_doc (
		SOAP_CLIENT (url=>'http://localhost:$U{HTTPPORT}/xmlStorageSystem',
		operation=>'deleteMultipleFiles',
		parameters=>vector ('email','xss@example.domain', 'password', md5('secret'),
		'relativepathList', vector ('test.txt')))
		));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deleteMultipleFiles : flError: " $LAST[1] "\n";

select count(*) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/xss@example.domain/blog/test.txt';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deleteMultipleFiles (test.txt removed from WebDAV) : " $LAST[1] "\n";

select count(*) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/xss@example.domain/blog/sub/test.txt';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deleteMultipleFiles sub/test1 (exists) : " $LAST[1] "\n";

xss_check (xml_tree_doc (
		SOAP_CLIENT (url=>'http://localhost:$U{HTTPPORT}/xmlStorageSystem',
		operation=>'mailPasswordToUser',
		parameters=>vector ('email','xss@example.domain'))
		));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": mailPasswordToUser prohibited : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

xss_check (xml_tree_doc (
		SOAP_CLIENT (url=>'http://localhost:$U{HTTPPORT}/xmlStorageSystem',
		operation=>'ping',
		parameters=>vector ('email','xss@example.domain', 'password', md5('secret'),
		'status', 0, 'clientPort', 0, 'userinfo', ''))
		));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ping : flError: " $LAST[1] "\n";


-- metaweb log tests
ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: XML-RPC tests\n";
