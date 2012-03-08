--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
--set MACRO_SUBSTITUTION off;
--set IGNORE_PARAMS on;

create procedure init_xq_s_4 ()
{
  declare stat, msg any;
  stat := '00000';
  exec ('create table O100_CACHED_PAGES (O_URL varchar primary key, O_CNT LONG VARCHAR, O_TITLE varchar, O_FORUM varchar, O_HOME varchar)', stat, msg);
  if (stat <> '00000')
    rollback work;
  exec ('alter table O100_CACHED_PAGES add O_HOME varchar', stat, msg);
  if (stat <> '00000')
    rollback work;
  exec ('alter table O100_CACHED_PAGES add O_IP varchar', stat, msg);
  if (stat <> '00000')
    rollback work;
  exec ('alter table O100_CACHED_PAGES add O_COUNTRY varchar', stat, msg);
  if (stat <> '00000')
    rollback work;
  exec ('alter table O100_CACHED_PAGES add O_CITY varchar', stat, msg);
  if (stat <> '00000')
    rollback work;
  exec ('alter table O100_CACHED_PAGES add O_LAT float', stat, msg);
  if (stat <> '00000')
    rollback work;
  exec ('alter table O100_CACHED_PAGES add O_LNG float', stat, msg);
  if (stat <> '00000')
    rollback work;
  exec ('create table attendees_sources (name varchar primary key, title varchar, query long varchar)', stat, msg);
  DAV_COL_CREATE_INT ('/DAV/home/tutorial_demo/feeds/', '110100100R', 'tutorial_demo', 'administrators', null, null, 0, 0, 0, null, null);
  DAV_COL_CREATE_INT ('/DAV/home/tutorial_demo/feeds/opml/', '110100100R', 'tutorial_demo', 'administrators', null, null, 0, 0, 0, null, null);
  DAV_COL_CREATE_INT ('/DAV/home/tutorial_demo/feeds/rss/', '110100100R', 'tutorial_demo', 'administrators', null, null, 0, 0, 0, null, null);
  DAV_COL_CREATE_INT ('/DAV/home/tutorial_demo/feeds/foaf/', '110100100R', 'tutorial_demo', 'administrators', null, null, 0, 0, 0, null, null);
  commit work;
};

init_xq_s_4 ();

create procedure
DB.DBA.GET_BLOG_URL (in url varchar)
{
    declare content varchar;
    declare olduri varchar;
    declare hdr any;


    if (url is null)
      signal ('22023', 'Invalid URL string');

    olduri := url;
    again:
    hdr := null;
    commit work;
    dbg_obj_print ('url=', url);
    registry_set ('xq_s_4_stat', url);
    registry_set ('xq_s_4_stat_dt', datestring (now()));
    if (url like 'http://%')
      content := http_get (url, hdr);
    else
      content := http_client_ext (url, null, null, 'GET', null, null, null, null, hdr);
    dbg_obj_print ('done.');

    if (hdr[0] not like 'HTTP/1._ 200 %')
      {
       if (hdr[0] like 'HTTP/1._ 30_ %')
	{
	  url := http_request_header (hdr, 'Location');
	  if (isstring (url))
	    {
	      url := WS.WS.EXPAND_URL (olduri, url);
	      --dbg_obj_print ('loc', url);
	      goto again;
	    }
	}
        signal ('22023', trim(hdr[0], '\r\n'), '22023');
        return NULL;
      }
    url := olduri;
    return content;
};


create procedure getFeed (in url varchar, in cache int)
{
  declare content, hdr, xt, rss, atom, ret, ins, title, home, isfeed any;
  declare arr, arr2 any;

  hdr := null;
  declare exit handler for sqlstate '*' {
    rollback work;
    --dbg_obj_print (__SQL_MESSAGE);
    return '';
  };
  ins := 0; isfeed := 0;
  content := (select O_CNT from O100_CACHED_PAGES where O_URL = url);
  if (content is null and cache)
    return '';
  if (content is null)
    {
      --dbg_obj_print ('URL', url);
      content := DB.DBA.GET_BLOG_URL (url);
      insert replacing O100_CACHED_PAGES (O_URL, O_CNT, O_FORUM) values (url, content, connection_get ('xq_s_4'));
      ins := 1;
    }
  xt := xtree_doc (content, 2, url);
  title := xpath_eval ('/html/head/title/text()', xt, 1);
  home := url;

  -- there is a case where feed can be here

  if (title is null)
    {
      title := xpath_eval ('/rss/channel/title/text()', xt, 1);
      home := xpath_eval ('/rss/channel/link/text()', xt, 1);
      if (title is null)
	{
	  title := xpath_eval ('/feed/title/text()', xt, 1);
	  home := xpath_eval ('/feed/link[@rel="alternate"]/@href', xt, 1);
	}
      if (title is null)
	{
	  title := xpath_eval ('/rdf/channel/title/text()', xt, 1);
	  home := xpath_eval ('/rdf/channel/@about', xt, 1);
	}
      if (title is not null)
	isfeed := 1;
    }

  if (ins)
    {
      update O100_CACHED_PAGES set O_TITLE = title, O_HOME = home where O_URL = url;
      commit work;
    }

  if (isfeed)
    {
      ret := url;
      goto retu;
    }

  --rss := xpath_eval ('/html/head/link[@rel="alternate" and @type="application/rss+xml"]/@href', xt, 1);
  --atom := xpath_eval ('/html/head/link[@rel="alternate" and @type="application/atom+xml"]/@href', xt, 1);
  --ret := WS.WS.EXPAND_URL (url, coalesce (rss, atom, ''));

  arr := xpath_eval ('/html/head/link[@rel="alternate" and @type="application/rss+xml"]/@href', xt, 0);
  arr2 := xpath_eval ('/html/head/link[@rel="alternate" and @type="application/atom+xml"]/@href', xt, 0);
  ret := '';
  if (length(arr) = 1)
    {
      ret := WS.WS.EXPAND_URL (url, arr[0]);
    }
  else if (length(arr2) = 1)
    {
      ret := WS.WS.EXPAND_URL (url, arr2[0]);
    }
  else
    {
      foreach (varchar u in arr) do
	{
	  u := cast (WS.WS.EXPAND_URL (url, u) as varchar);

	  if (u like url||'%' and u <> url)
	    {
	      ret := u;
	      goto retn;
	    }
	}
      foreach (varchar u in arr2) do
	{
	  u := cast (WS.WS.EXPAND_URL (url, u) as varchar);

	  if (u like url||'%' and u <> url)
	    {
	      ret := u;
	      goto retn;
	    }
	}
    }

retn:
  ret := case when ret = url then '' else cast (ret as varchar) end;

retu:

  return ret;
};

create procedure getTitle (in att varchar, in url varchar, in cache int)
{
  getFeed (url, cache);
  return coalesce ((select O_TITLE from O100_CACHED_PAGES where O_URL = url), att);
};

create procedure getHome (in url varchar, in cache int)
{
  getFeed (url, cache);
  return coalesce ((select O_HOME from O100_CACHED_PAGES where O_URL = url), url);
};


create procedure getExpandedUrl (in base varchar, in url varchar)
{
  return WS.WS.EXPAND_URL (base, url);
};

create procedure xq_s_4_get_country (in url varchar, in url2 varchar)
{
  return coalesce (
      (select O_COUNTRY from O100_CACHED_PAGES where O_URL = url),
      (select O_COUNTRY from O100_CACHED_PAGES where O_URL = url2),
      NULL);
};

create procedure xq_s_4_get_city (in url varchar, in url2 varchar)
{
  return coalesce (
      (select O_CITY from O100_CACHED_PAGES where O_URL = url),
      (select O_CITY from O100_CACHED_PAGES where O_URL = url2),
      NULL);
};

create procedure xq_s_4_get_ip (in url varchar, in url2 varchar)
{
  return coalesce (
      (select O_IP from O100_CACHED_PAGES where O_URL = url),
      (select O_IP from O100_CACHED_PAGES where O_URL = url2),
      NULL);
};

create procedure xq_s_4_get_lat (in url varchar, in url2 varchar)
{
  declare ret any;
  ret := (select O_LAT from O100_CACHED_PAGES where O_URL = url);
  if (ret is null)
    ret := (select O_LAT from O100_CACHED_PAGES where O_URL = url2);
  if (ret is not null)
    ret := sprintf ('%.06f', ret);
  return ret;
};

create procedure xq_s_4_get_lng (in url varchar, in url2 varchar)
{
  declare ret any;
  ret := (select O_LNG from O100_CACHED_PAGES where O_URL = url);
  if (ret is null)
    ret := (select O_LNG from O100_CACHED_PAGES where O_URL = url2);
  if (ret is not null)
    ret := sprintf ('%.06f', ret);
  return ret;
};

create procedure xq_s_4_get_blog (in url varchar, in cache int)
{
  declare qry, stat, msg, dta, mdta any;
  dbg_obj_print (url);
  qry := sprintf ('sparql
  	define get:soft "soft" define input:default-graph-uri "%s"
  	prefix foaf: <http://xmlns.com/foaf/0.1/>
  	prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> SELECT ?blog WHERE { ?p rdf:type foaf:Person ; foaf:weblog ?blog }
	limit 1', url);
  stat := '00000';
  exec (qry, stat, msg, vector (), 0, mdta, dta);
  if (stat = '00000' and isarray (dta) and length (dta))
    {
      declare blog any;
      blog := dta[0][0];
      return getFeed (blog, cache);
    }
  return '';
};

grant execute on DB.DBA.getExpandedUrl to public;
grant execute on DB.DBA.getFeed to public;
grant execute on DB.DBA.getTitle to public;
grant execute on DB.DBA.getHome to public;
grant execute on DB.DBA.xq_s_4_get_country to public;
grant execute on DB.DBA.xq_s_4_get_city to public;
grant execute on DB.DBA.xq_s_4_get_ip to public;
grant execute on DB.DBA.xq_s_4_get_lat to public;
grant execute on DB.DBA.xq_s_4_get_lng to public;
grant execute on DB.DBA.xq_s_4_get_blog to public;

xpf_extension ('http://www.openlinksw.com/demo/:getFeed', 'DB.DBA.getFeed');
xpf_extension ('http://www.openlinksw.com/demo/:getTitle', 'DB.DBA.getTitle');
xpf_extension ('http://www.openlinksw.com/demo/:getHome', 'DB.DBA.getHome');
xpf_extension ('http://www.openlinksw.com/demo/:getExpandedUrl', 'DB.DBA.getExpandedUrl');
xpf_extension ('http://www.openlinksw.com/demo/:getBlog', 'DB.DBA.xq_s_4_get_blog');

xpf_extension ('http://www.openlinksw.com/demo/:getCountry', 'DB.DBA.xq_s_4_get_country');
xpf_extension ('http://www.openlinksw.com/demo/:getCity', 'DB.DBA.xq_s_4_get_city');
xpf_extension ('http://www.openlinksw.com/demo/:getIP', 'DB.DBA.xq_s_4_get_ip');
xpf_extension ('http://www.openlinksw.com/demo/:getLat', 'DB.DBA.xq_s_4_get_lat');
xpf_extension ('http://www.openlinksw.com/demo/:getLng', 'DB.DBA.xq_s_4_get_lng');


create procedure GET_OPML_RES (in id any)
{
	-- if you use xtree_doc mode 1 the generated output is not a valid OPML - attributes @xmlUrl and @htmlUrl should NOT be lowercase -  @xmlurl
  return coalesce ((select xtree_doc(RES_CONTENT, 0, '', 'UTF-8') from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/home/tutorial_demo/feeds/opml/'||id||'.opml'), null);
}
;

create procedure GET_FOAF_RES (in id any)
{
	-- if you use xtree_doc mode 1 the generated output is not a valid OPML - attributes @xmlUrl and @htmlUrl should NOT be lowercase -  @xmlurl
  return coalesce ((select xtree_doc(RES_CONTENT, 0, '', 'UTF-8') from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/home/tutorial_demo/feeds/foaf/'||id||'.xml'), null);
}
;

create procedure GET_RSS_RES (in id any)
{
  return coalesce ((select RES_CONTENT from WS.WS.SYS_DAV_RES where
	RES_FULL_PATH = '/DAV/home/tutorial_demo/feeds/rss/'||SYS_ALFANUM_NAME (id)||'.xml'), null);
}
;

create procedure STORE_OPML_RES (in id any, in content any)
{
  DAV_RES_UPLOAD_STRSES_INT ('/DAV/home/tutorial_demo/feeds/opml/'||id||'.opml', content, '', '110100100RM', 'tutorial_demo', 'administrators', 'dav', null, 0);
}
;

create procedure STORE_RSS_RES (in id any, in content any)
{
  DAV_RES_UPLOAD_STRSES_INT ('/DAV/home/tutorial_demo/feeds/rss/'||SYS_ALFANUM_NAME (id)||'.xml', content, '', '110100100RM', 'tutorial_demo', 'administrators', 'dav', null, 0);
}
;

create procedure STORE_FOAF_RES (in id any, in content any)
{
  DAV_RES_UPLOAD_STRSES_INT ('/DAV/home/tutorial_demo/feeds/foaf/'||id||'.xml', content, '', '110100100RM', 'tutorial_demo', 'administrators', 'dav', null, 0);
}
;


insert replacing attendees_sources values
(
  'techcrunch', 'TechCrunch Meetup',

  'declare namespace ns="http://www.openlinksw.com/demo/";
   declare namespace h="http://www.w3.org/1999/xhtml";
  <opml version="1.1"><head><title>TechCrunch Meetup</title></head><body>{
    let $div := document("http://wiki.techcrunch.com/third_meetup", "", 2)//h:div[@class="level1"][preceding-sibling::*[normalize-space(.)="Attendees"]]
    for $row in $div//h:div[@class="li"][h:a[@class="urlextern"]]
    return <outline title="{string($row)}" htmlUrl="{$row/h:a/@href}" xmlUrl="{ns:getFeed ($row/h:a/@href, <CACHE>)}" text="{normalize-space($row)}"/>
    }</body></opml>'
 );

insert replacing attendees_sources values
(
  'blog100', 'Blog 100 Stream',

 'declare namespace ns="http://www.openlinksw.com/demo/";
      <opml version="1.1"><head><title>Blog 100 Stream</title></head><body>{
      for $nod in document("http://news.com.com/html/ne/blogs/CNETNewsBlog100.opml", "", 2)//outline[@url]
	    return <outline title="{$nod/@text}" htmlUrl="{$nod/@url}" xmlUrl="{$nod/@xmlurl}" text="{$nod/@text}"/>
     }</body></opml>'
);

insert replacing attendees_sources values
(
  'osc2003', 'Open Source Convention 2003',

 'declare namespace ns="http://www.openlinksw.com/demo/";
      <opml version="1.1"><head><title>Open Source Convention 2003</title></head><body>{
      for $nod in document("http://conferences.oreillynet.com/pub/w/23/speakers.html", "", 2)//font[@size="3"]
	    return <outline title="{string ($nod)}" htmlUrl="http://conferences.oreillynet.com{$nod//a/@href}" xmlUrl="" text="{string ($nod)}"/>
     }</body></opml>'
);

insert replacing attendees_sources values
(
  'osc2005', 'Open Source Convention 2005',

 'declare namespace ns="http://www.openlinksw.com/demo/";
      <opml version="1.1"><head><title>Open Source Convention 2005</title></head><body>{
      for $nod in document("http://conferences.oreillynet.com/pub/w/38/speakers.html", "", 2)//font[@size="3"]
	    return <outline title="{string ($nod)}" htmlUrl="http://conferences.oreillynet.com{$nod//a/@href}" xmlUrl="" text="{string ($nod)}"/>
     }</body></opml>'
);

insert replacing attendees_sources values
(
  'o100', 'Open Media 100 List',
  'declare namespace ns="http://www.openlinksw.com/demo/";
      <opml version="1.1"><head><title>Open Media 100 List</title></head><body>{
      let $tab := document("http://www.alwayson-network.com/comments.php?id=10852_0_11_0_C", "", 2)//table[caption[contains(., "Open Media 100 List")]]
      for $td in $tab//td[a[@href]]
         for $nod in $td/node()
	    let $att := $nod/preceding-sibling::node()[normalize-space(.)!=""]
            where ($nod[@href] and local-name($nod) = "a")
	      return <outline title="{string($nod)}" htmlUrl="{$nod/@href}" xmlUrl="{ns:getFeed ($nod/@href, <CACHE>)}" text="{normalize-space($att)}"/>
     }</body></opml>'
);

insert replacing attendees_sources values
(
  'gnomedexers', 'Gnomedexers 2005',

  'declare namespace ns="http://www.openlinksw.com/demo/";
      <opml version="1.1"><head><title>Gnomedexers 2005</title></head><body>{
      for $nod in document("http://www.gnomedex.com/holdings/br_2005%20Gnomedexers.opml", "", 2)//outline
	    let $att := $nod/@text
	    return <outline title="{ns:getTitle($att, $nod/@url, <CACHE>)}" htmlUrl="{$nod/@url}" xmlUrl="{ns:getFeed ($nod/@url, <CACHE>)}" text="{normalize-space($att)}"/>
     }</body></opml>'
);

insert replacing attendees_sources values
(
  'web2005', 'Web 2005 speakers',
  'declare namespace ns="http://www.openlinksw.com/demo/";
      	    <opml version="1.1"><head><title>Web 2005 speakers</title></head><body>{
            for $nod in document("http://www.web2con.com/pub/w/40/speakers.html", "", 2)//a[string(.)="Click here"]
	    let $nfo := document (ns:getExpandedUrl ("http://www.web2con.com/pub/w/40/speakers.html", $nod/@href), "", 2)
	    let $url := $nfo//font[@size="-1"]/a/@href
	    return <outline title="{$nfo//font[@size="-1"]/text()}" htmlUrl="{string($url)}"
	      	xmlUrl="{ns:getFeed ($url, <CACHE>)}" text="{string ($nfo//font[@size="3"])}"/>
     }</body></opml>'
);

insert replacing attendees_sources values
(
  'ceo', 'CEO Blogs List',
   'declare namespace ns="http://www.openlinksw.com/demo/";
      	<opml version="1.1"><head><title>CEO Blogs List</title></head><body>{
            for $nod in document ("http://www.thenewpr.com/wiki/pmwiki.php?pagename=Resources.CEOBlogsList", "", 2, "UTF-8")//div[@id="wikitext"]//ul/li/a[@class="urllink"][1]
	    where ($nod/ancestor::ul[preceding-sibling::h2[. = "The list"] and not preceding-sibling::h2[. = "Backlinks"]])
	      return <outline text="{$nod/text()}" htmlUrl="{string($nod/@href)}" title="{ns:getTitle($nod/text(), $nod/@href, <CACHE>)}" xmlUrl="{ns:getFeed ($nod/@href, <CACHE>)}" />
     }</body></opml>'
);

insert replacing attendees_sources values
(
  'nigerian_bloggers', 'Nigerian Bloggers',
  'declare namespace ns="http://www.openlinksw.com/demo/";
      	<opml version="1.1"><head><title>Nigerian Bloggers</title></head><body>{
            for $nod in document ("http://nwr.cowblock.net/index.php?action=list", "", 2, "UTF-8")//table[tr/td/strong[.="All Entries"]]//a[@href]
	      return <outline text="{$nod/text()}" htmlUrl="{string($nod/@href)}" title="{ns:getTitle($nod/text(), $nod/@href, <CACHE>)}" xmlUrl="{ns:getFeed ($nod/@href, <CACHE>)}" />
     }</body></opml>'
);
insert replacing attendees_sources values
(
  'african_blogs', 'African Bloggers',
  'declare namespace ns="http://www.openlinksw.com/demo/";
      	      declare namespace n0="http://www.w3.org/1999/xhtml";
      	<opml version="1.1"><head><title>African Bloggers</title></head><body>{
            for $nod in document ("http://okrasoup.typepad.com/black_looks/2005/05/naija_blogs.html", "", 2, "UTF-8")//n0:div[n0:h2[. = "African Blogs"]]//n0:li/n0:a[@href]
	      return <outline text="{$nod/text()}" htmlUrl="{string($nod/@href)}" title="{ns:getTitle($nod/text(), $nod/@href, <CACHE>)}" xmlUrl="{ns:getFeed ($nod/@href, <CACHE>)}" />
     }</body></opml>'
);
insert replacing attendees_sources values
(
  'blogafrica', 'Blogafrica',
  'declare namespace ns="http://www.openlinksw.com/demo/";
      <opml version="1.1"><head><title>Blogafrica</title></head><body>{
      for $nod in document("http://allafrica.com/afdb/blogs/blogafrica.opml", "", 2, "UTF-8")//outline
	    let $att := $nod/@text
	    return <outline title="{ns:getTitle($att, $nod/@link, <CACHE>)}" htmlUrl="{ns:getHome ($nod/@link, <CACHE>)}" xmlUrl="{ns:getFeed ($nod/@link, <CACHE>)}" text="{normalize-space($att)}"/>
     }</body></opml>'
);


insert replacing attendees_sources values
(
  'vloggercon', 'Vloggercon',
'declare namespace ns="http://www.openlinksw.com/demo/";
declare namespace n0="http://www.w3.org/1999/xhtml";
<opml version="1.1"><head><title>Vloggercon</title></head><body>
{
  for $nod in document ("http://wiki.vloggercon.com/index.php?title=Attendees", "", 2, "UTF-8")//n0:ol[preceding-sibling::n0:a[@name="YES"]]/n0:li
     return <outline text="{$nod/text()}" htmlUrl="{string($nod/n0:a[1][@href and @rel="nofollow"]/@href)}" title="{ns:getTitle($nod/text(), $nod/@href, <CACHE>)}"
          xmlUrl="{ns:getFeed ($nod/n0:a[1][@href and @rel="nofollow"]/@href, <CACHE>)}" />
}
</body></opml>');

insert replacing attendees_sources values
(
  'sem_blogs', 'Semantic Weblogs',
'declare namespace n0="http://www.w3.org/1999/xhtml";
 declare namespace ns="http://www.openlinksw.com/demo/";
<opml version="1.1"><head><title>Semantic Weblogs</title></head><body>{
  for $nod in document("http://journal.dajobe.org/journal/2003/07/semblogs/", "", 2)//n0:ul[1]/n0:li
  let $nfo := $nod/n0:a[1]/@title
  let $html := $nod/n0:a[1]/@href
  let $rss := $nod/n0:a[2]/@href

  return <outline title="{string($nfo)}" htmlUrl="{string($html)}"
  xmlUrl="{ns:getFeed ($rss, <CACHE>)}" text="{string ($nfo)}"/>
}</body></opml>');


insert replacing attendees_sources values
(
  'mapufacture', 'Mapufacture',
'declare namespace ns="http://www.openlinksw.com/demo/";
declare namespace n0="http://www.w3.org/1999/xhtml";
<opml version="1.1"><head><title>Semantic Weblogs</title></head><body>{
  for $nod in document("http://mapufacture.com/georss/feed/list", "", 2)//n0:ul[1]/n0:li[n0:span[@class="FeedTitle"]]
  let $nfo := $nod/n0:span[@class="FeedTitle"]/n0:a
  let $html := $nod/n0:span[@class="FeedTitle"]/n0:a/@href
  let $rss := $nod/n0:span[@class="FeedUrl"]

  return <outline title="{string($nfo)}" htmlUrl="{string($html)}"
  xmlUrl="{ns:getFeed (string($rss), <CACHE>)}" text="{string ($nfo)}"/>
}</body></opml>');


insert replacing attendees_sources values
(
'foafmap', 'foafmap.net',
'declare namespace ns="http://www.openlinksw.com/demo/";
declare namespace rss="http://purl.org/rss/1.0/";
declare namespace rdfs="http://www.w3.org/2000/01/rdf-schema#";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
<opml version="1.1"><head><title>foafmap.net</title></head><body>{
  for $nod in document("http://foafmap.net/rss.php", "", 0)//rss:item
  let $nfo := $nod/rss:title
  let $html := $nod/rss:link
  let $foaf := $nod/rdfs:seeAlso/@rdf:resource

  return <outline title="{string($nfo)}" htmlUrl="{string($html)}"
    xmlUrl="{ns:getBlog(string($foaf), <CACHE>)}" text="{string ($nfo)}"/>
}</body></opml>');

insert replacing attendees_sources values
(
'technologyvoices', 'Meet The Bloggers',
'declare namespace ns="http://www.openlinksw.com/demo/";
declare namespace rss="http://purl.org/rss/1.0/";
declare namespace rdfs="http://www.w3.org/2000/01/rdf-schema#";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace x="http://www.w3.org/1999/xhtml";
<opml version="1.1"><head><title>Meet The Bloggers</title></head><body>{
  for $nod in document("http://www.technologyvoices.com/bloggers", "", 2)//x:div[@id = "newblogs"]/x:div[@class="picture"]
  let $nfo := $nod/following-sibling::x:dl/x:dd[1]
  let $html := $nod/x:a/@href


  return <outline title="{string($nfo)}" htmlUrl="http://www.technologyvoices.com/{string($html)}"
  xmlUrl="" text="{string ($nfo)}"/>
}</body></opml>');



insert replacing attendees_sources values
(
'technorati_pop', 'Technorati, Most popular',
'declare namespace ns="http://www.openlinksw.com/demo/";
declare namespace rss="http://purl.org/rss/1.0/";
declare namespace rdfs="http://www.w3.org/2000/01/rdf-schema#";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace x="http://www.w3.org/1999/xhtml";
<opml version="1.1"><head><title></title></head><body>{
  for $nod in document("http://www.technorati.com/pop/blogs/", "", 2)//x:ol[@class="whatsup latest"]/x:li
  let $nfo := $nod//x:h3
  let $html := $nod//x:a[@class = "url"]/@href
  return <outline title="{string($nfo)}" htmlUrl="{string($html)}"
  xmlUrl="{ns:getFeed ($html, <CACHE>)}" text="{string ($nfo)}"/>
}</body></opml>');

insert replacing attendees_sources values
(
'technorati_fav', 'Technorati, Most Favorited',
'declare namespace ns="http://www.openlinksw.com/demo/";
declare namespace rss="http://purl.org/rss/1.0/";
declare namespace rdfs="http://www.w3.org/2000/01/rdf-schema#";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace x="http://www.w3.org/1999/xhtml";
<opml version="1.1"><head><title></title></head><body>{
  for $nod in document("http://www.technorati.com/pop/blogs/?faves=1", "", 2)//x:ol[@class="whatsup latest"]/x:li
  let $nfo := $nod//x:h3
  let $html := $nod//x:a[@class = "url"]/@href
  return <outline title="{string($nfo)}" htmlUrl="{string($html)}"
  xmlUrl="{ns:getFeed ($html, <CACHE>)}" text="{string ($nfo)}"/>
}</body></opml>');

insert replacing attendees_sources values
(
'planetrdf', 'Planet RDF',
'declare namespace ns="http://www.openlinksw.com/demo/";
declare namespace rss="http://purl.org/rss/1.0/";
declare namespace rdfs="http://www.w3.org/2000/01/rdf-schema#";
declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
declare namespace x="http://www.w3.org/1999/xhtml";
<opml version="1.1"><head><title>Planet RDF</title></head><body>{
  for $nod in document("http://planetrdf.com/", "", 2)//x:h2[. = "Bloggers"]/following-sibling::x:ul/x:li
  let $nfo := $nod/x:a[1]
  let $html := $nod/x:a[1]/@href
  let $rss := $nod/x:a[2]/@href
  return <outline title="{string($nfo)}" htmlUrl="{string($html)}"
  xmlUrl="{ns:getFeed ($rss, <CACHE>)}" text="{string ($nfo)}"/>
}</body></opml>');

create procedure gen_opml (in attendee_list varchar, in cache int := 1)
{
  declare src any;
  declare xt, xp, res, q, t any;

  commit work;
  declare exit handler for sqlstate '*'
    {
      rollback work;
      return xtree_doc ('<opml/>');
    };

  if (cache)
    {
      res := GET_OPML_RES (attendee_list);
      if (res is not null)
        return res;
    }
  connection_set ('xq_s_4', attendee_list);

  xt := xtree_doc ('<dummy/>');

  q := (select blob_to_string (query) from attendees_sources where name = attendee_list);
  q := replace (q, '<CACHE>', cast (cache as varchar));

  xp := xquery_eval (q, xt);

  STORE_OPML_RES (attendee_list, serialize_to_UTF8_xml (xp));

  return (xp);
};

create procedure xq_s_4_get_location (in url varchar)
{
  declare ret, ip, cnt, hf any;

  hf := WS.WS.PARSE_URI (url);
  ip := tcpip_gethostbyname (hf[1]);
  cnt := http_get ('http://api.hostip.info/get_html.php?ip='||ip||'&position=true');
  ret := sprintf_inverse (cnt, 'Country:%s\nCity:%s\nLatitude:%s\nLongitude:%s', 0);
  return vector_concat (vector (ip), ret);
};

create trigger O100_CACHED_PAGES_I after insert on O100_CACHED_PAGES referencing new as N
{
  declare info any;
  declare lat, lng any;

  declare exit handler for sqlstate '*'
    {
      return;
    };

 info := xq_s_4_get_location (N.O_URL);

 lat := trim(info[3]);
 lng := trim(info[4]);

 if (length (lat))
   lat := atof (lat);
 else
   lat := null;

 if (length (lng))
   lng := atof (lng);
 else
   lng := null;

 update O100_CACHED_PAGES set O_IP = info[0], O_COUNTRY = trim(info[1]), O_CITY = trim (info[2]), O_LAT = lat, O_LNG = lng
     where O_URL = N.O_URL;

};

create procedure gen_foaf (in cache int := 1)
{
  declare src any;
  declare xt, xp, res any;

  if (cache)
    {
      res := GET_FOAF_RES ('foaf');
      if (res is not null)
        return res;
    }

  xt := xtree_doc ('<dummy/>');
  xp := xquery_eval (
    sprintf ('declare namespace ns="http://www.openlinksw.com/demo/";
      	      declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
      	      declare namespace rdfs="http://www.w3.org/2000/01/rdf-schema#";
      	      declare namespace foaf="http://xmlns.com/foaf/0.1/";
      	      <rdf:RDF>{
               for $doc in collection ("http://local.virt/DAV/home/tutorial_demo/feeds/opml/")//opml
	       return
  	      <foaf:Group>
                <foaf:name>{ string ($doc/head/title) }</foaf:name>{
      for $nod in $doc//outline
	    let $att := $nod/@text
	    return <foaf:member>
	             <foaf:Person>
		        <foaf:name>{ normalize-space($att) }</foaf:name>
			<foaf:homepage rdf:resource="{$nod/@htmlUrl}"/>
			<rdfs:seeAlso rdf:resource="{$nod/@xmlUrl}"/>
  		     </foaf:Person>
	           </foaf:member>

     }</foaf:Group>
    }</rdf:RDF>
     '),
    xt
  );

  STORE_FOAF_RES ('foaf', serialize_to_UTF8_xml (xp));

  return (xp);
}
;

create procedure gen_foaf_one (in which varchar, in cache int := 1)
{
  declare src any;
  declare xt, xp, res any;

  declare exit handler for sqlstate '*'
    {
      rollback work;
      return xtree_doc ('<rdf:RDF rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"/>');
    };

  if (cache)
    {
      res := GET_FOAF_RES (which||'_foaf');
      if (res is not null)
        return res;
    }

  xt := xtree_doc ('<dummy/>');
  xp := xquery_eval (
    sprintf ('declare namespace ns="http://www.openlinksw.com/demo/";
      	      declare namespace rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#";
      	      declare namespace rdfs="http://www.w3.org/2000/01/rdf-schema#";
      	      declare namespace foaf="http://xmlns.com/foaf/0.1/";
	      declare namespace geo="http://www.w3.org/2003/01/geo/wgs84_pos#";
	      declare namespace vcard="http://www.w3.org/2001/vcard-rdf/3.0#";
      	      <rdf:RDF>{
               for $doc in document ("http://local.virt/DAV/home/tutorial_demo/feeds/opml/%s.opml")//opml
	       return
  	      <foaf:Group>
                <foaf:name>{ string ($doc/head/title) }</foaf:name>{
      for $nod in $doc//outline
	    let $att := $nod/@text
	    let $url := replace ($nod/@htmlUrl, "}", "")
	    return <foaf:member>
	             <foaf:Person rdf:about="{$url}#{ urlify (normalize-space($att)) }">
		        <foaf:name>{ normalize-space($att) }</foaf:name>
			<foaf:homepage rdf:resource="{$url}"/>
			<rdfs:seeAlso rdf:resource="{$nod/@xmlUrl}"/>
			<foaf:based_near>
			  <geo:Point geo:lat="{ns:getLat($url, $nod/@xmlUrl)}" geo:long="{ns:getLng($url, $nod/@xmlUrl)}" />
			</foaf:based_near>
			<vcard:ADR rdf:parseType="Resource">
			  <vcard:Country>{ns:getCountry($url, $nod/@xmlUrl)}</vcard:Country>
			  <vcard:Locality>{ns:getCity($url, $nod/@xmlUrl)}</vcard:Locality>
			</vcard:ADR>
  		     </foaf:Person>
	           </foaf:member>

     }</foaf:Group>
    }</rdf:RDF>
     ', which),
    xt
  );

  STORE_FOAF_RES (which||'_foaf', serialize_to_UTF8_xml (xp));

  return (xp);
}
;

create user "xq_s_4";

VHOST_REMOVE (lpath=>'/xq_s_4');

VHOST_DEFINE (lpath=>'/xq_s_4', ppath=>'/SOAP/', soap_user=>'xq_s_4',
    soap_opts => vector (
      'Namespace','http://temp.org/', 'SchemaNS', 'http://temp.org/','MethodInSoapAction','yes',
      'ServiceName', 'MyXMLService', 'elementFormDefault', 'qualified', 'Use', 'literal'
      )
    )
;


create procedure "GetAttendees" (in EventURI varchar, in ResultFormat int) returns xmltype
{
  declare x xmltype;
  declare xd any;
  declare page, ht varchar;

  -- some operations needs a dba privileges
  set_user_id ('dba');
  set http_charset='utf-8';

  EventURI := trim (EventURI);
  if (EventURI = 'http://www.alwayson-network.com/comments.php?id=10852_0_11_0_C')
    {
      if (ResultFormat = 2)
	{
	  xd := gen_foaf_one ('o100');
	}
      else if (ResultFormat = 3 or ResultFormat = 1)
	{
	  xd := gen_opml ('o100');
	}
      page := 'o100';
    }
  else if (EventURI = 'http://www.gnomedex.com/holdings/br_2005%%20Gnomedexers.opml')
    {
      if (ResultFormat = 2)
	{
	  xd := gen_foaf_one ('gnomedexers');
	}
      else if (ResultFormat = 3 or ResultFormat = 1)
	{
	  xd := gen_opml ('gnomedexers');
	}
      page := 'gnomedexers';
    }
  else if (EventURI = 'http://www.web2con.com/pub/w/40/speakers.html')
    {
      if (ResultFormat = 2)
	{
	  xd := gen_foaf_one ('web2005');
	}
      else if (ResultFormat = 3 or ResultFormat = 1)
	{
	  xd := gen_opml ('web2005');
	}
      page := 'web2005';
    }
  else if (EventURI = 'http://www.thenewpr.com/wiki/pmwiki.php/Resources/CEOBlogsList' or EventURI = 'http://www.thenewpr.com/wiki/pmwiki.php?pagename=Resources.CEOBlogsList')
    {
      if (ResultFormat = 2)
	{
	  xd := gen_foaf_one ('ceo');
	}
      else if (ResultFormat = 3 or ResultFormat = 1)
	{
	  xd := gen_opml ('ceo');
	}
      page := 'ceo';
    }
  else if (EventURI = 'http://nwr.cowblock.net/index.php?action=list')
    {
      if (ResultFormat = 2)
	{
	  xd := gen_foaf_one ('nigerian');
	}
      else if (ResultFormat = 3 or ResultFormat = 1)
	{
	  xd := gen_opml ('nigerian_bloggers');
	}
      page := 'nigerian_bloggers';
    }
  else if (EventURI = 'http://okrasoup.typepad.com/black_looks/2005/05/naija_blogs.html')
    {
      if (ResultFormat = 2)
	{
	  xd := gen_foaf_one ('african');
	}
      else if (ResultFormat = 3 or ResultFormat = 1)
	{
	  xd := gen_opml ('african_blogs');
	}
      page := 'african_blogs';
    }
  else if (EventURI = 'http://allafrica.com/afdb/blogs/blogafrica.opml')
    {
      if (ResultFormat = 2)
	{
	  xd := gen_foaf_one ('blogafrica');
	}
      else if (ResultFormat = 3 or ResultFormat = 1)
	{
	  xd := gen_opml ('blogafrica');
	}
      page := 'blogafrica';
    }
  else
    {
      signal ('22023', 'No such URL in the Database');
    }

  if (ResultFormat not in (1,2,3))
    signal ('22023', 'Wrong ResultFormat, must be 1, 2 or 3');

  xml_tree_doc_encoding (xd, 'UTF-8');
  x := new xmltype (xd);
  if (ResultFormat = 1)
    {
      x.xt_ent := xslt (TUTORIAL_XSL_DIR () || '/tutorial/xml/xq_s_4/xq_s_4svc.xsl', x.xt_ent,
      vector ('base', 'http://'|| HTTP_GET_HOST () || '/tutorial/xml/xq_s_4/'||page||'.vsp'));
    }
  return x;
}
;

grant execute on "GetAttendees" to "xq_s_4";

--inital loading

create procedure init_xq_s_4_feeds ()
{
  connection_set ('HTTP_CLI_TIMEOUT', 5);
  commit work;
  dbg_obj_print ('init_feeds', is_http_ctx ());
  if (is_http_ctx ())
    {
      declare arr, cnt any;
      arr := http_pending_req ();
      cnt := 0;
      foreach (any l in arr) do
	{
	  if (l[1] = '/tutorial/xml/xq_s_4/xq_s_4.vsp')
	    cnt := cnt + 1;
	}
      dbg_obj_print ('cnt=',cnt);
      http_request_status ('HTTP/1.1 302 Found');
      http_header ('Location: xq_s_4.vsp\r\n');
      if (cnt <= 1)
	{
	  http_flush ();
        }
      else
	{
	  return;
	}
    }

  declare ex, src any;
  declare i, l, dedl int;

  ex := vector ('o100', 'vloggercon', 'gnomedexers', 'web2005', 'ceo', 'nigerian_bloggers', 'african_blogs', 'blogafrica', 'techcrunch', 'blog100', 'osc2003', 'osc2005', 'sem_blogs', 'mapufacture', 'foafmap', 'technologyvoices', 'technorati_pop', 'technorati_fav', 'planetrdf');

  --ex := vector ('planetrdf');

  commit work;
  dedl := 5;
  l := length (ex);
  i := 0;

  declare exit handler for sqlstate '40001' {
    rollback work;
    dedl := dedl - 1;
    if (dedl > 0)
      goto again;
    registry_set ('xq_s_4_stat', 'error');
    resignal;
  };

  again:;
  while (i < l)
    {
      src := ex[i];
      gen_opml (src, 0);
      gen_foaf_one (src, 0);
      commit work;
      i := i + 1;
    }
  if (l > 0)
  gen_foaf (0);
  registry_set ('xq_s_4_stat', 'done');
};

commit work;
dbg_obj_print ('before init_feeds');
init_xq_s_4_feeds ();

