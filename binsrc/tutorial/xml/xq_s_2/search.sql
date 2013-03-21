--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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
--DAV_COL_CREATE ('/DAV/blogs/', '110100000', 'dav',   'dav',  'dav', 'dav');
--DAV_COL_CREATE ('/DAV/blogs/local/', '110100000', 'dav',   'dav',  'dav', 'dav');
--DAV_COL_CREATE ('/DAV/blogs/subscribed/', '110100000', 'dav',   'dav',  'dav', 'dav');
--set MACRO_SUBSTITUTION off;
--set IGNORE_PARAMS on;

create procedure exec_no_error(in expr varchar) {
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

create function DB.DBA.RSS_DATE_PARSER (in strg varchar)
{
  declare m integer;
  declare res varchar;
  if (strg is null)
    return null;
  strg := cast (strg as varchar);
  res := sprintf ('%s-%s-%s',
    subseq (strg, 12, 16),
    get_keyword (subseq (strg, 8, 11), vector ('Jan', '01', 'Feb', '02', 'Mar', '03', 'Apr', '04', 'May', '05', 'Jun', '06', 'Jul', '07', 'Aug', '08', 'Sep', '09', 'Oct', '10', 'Nov', '11', 'Dec', '12')),
    subseq (strg, 5, 7) );
  return cast (res as date);
}
;

grant execute on DB.DBA.RSS_DATE_PARSER to public
;


xpf_extension ('http://www.openlinksw.com/rss/:date-parser', fix_identifier_case ('DB.DBA.RSS_DATE_PARSER'), 0)
;

create function DB.DBA.RSS_DATETIME_PARSER (in strg varchar)
{
  declare m integer;
  declare res varchar;
  if (strg is null)
    return null;
  strg := cast (strg as varchar);
  res := sprintf ('%s-%s-%s %s',
    subseq (strg, 12, 16),
    get_keyword (subseq (strg, 8, 11), vector ('Jan', '01', 'Feb', '02', 'Mar', '03', 'Apr', '04', 'May', '05', 'Jun', '06', 'Jul', '07', 'Aug', '08', 'Sep', '09', 'Oct', '10', 'Nov', '11', 'Dec', '12')),
    subseq (strg, 5, 7),
    subseq (strg, 17, 25) );
  return cast (res as datetime);
}
;

grant execute on DB.DBA.RSS_DATETIME_PARSER to public
;

xpf_extension ('http://www.openlinksw.com/rss/:datetime-parser', fix_identifier_case ('DB.DBA.RSS_DATETIME_PARSER'), 0)
;

create function DB.DBA.XPF_FN_DATEDIFF (in unit varchar, in t1 datetime, in t2 datetime)
{
  if (t1 is null or t2 is null)
    return null;
  return datediff (unit, t1, t2);
}
;

grant execute on DB.DBA.XPF_FN_DATEDIFF to public
;

xpf_extension ('http://www.w3.org/2004/07/xpath-functions:datediff', fix_identifier_case ('DB.DBA.XPF_FN_DATEDIFF'), 0)
;

create function DB.DBA.XPF_FN_DATEADD (in unit varchar, in n integer, in dt datetime)
{
  if (n is null or dt is null)
    return null;
  return dateadd (unit, n, dt);
}
;

grant execute on DB.DBA.XPF_FN_DATEADD to public
;

xpf_extension ('http://www.w3.org/2004/07/xpath-functions:dateadd', fix_identifier_case ('DB.DBA.XPF_FN_DATEADD'), 0)
;



create procedure XQ..xtree_document (in _doc varchar)
{
	if (_doc is null)
		return xtree_doc ('<stub/>');
	return xtree_doc (_doc, 2);
}
;
create procedure XQ..RssDate (in _date datetime)
{
	declare _date_str varchar;
	_date_str := replace (cast (_date as varchar), '-', '/');
	return subseq (_date_str, 0, 19);
}
;


exec_no_error ('drop table XQ..CACHED_RESOURCES');

create table XQ..CACHED_RESOURCES (
	id int identity,
	descr varchar not null,
	text varchar not null,
	type int default 0, -- 0: XPath, 1: XQuery
	primary key (id))
;

create procedure XQ..GET_RESOURCES (in _type int:=0, in _is_select int:=1, in _default_opt varchar:=null)
{
	declare _res varchar;
	if (_is_select = 1) {
	 _res := '<option value=""> --- choose your ' || case when _type < XQ..COLLECTIONS_ID () then 'query' else 'collection' end || ' --- </option>';
	 for select text as _q, descr as _d from XQ..CACHED_RESOURCES where type = _type order by id do {
	 	if ((_default_opt is not null) and (_default_opt = _q))
		  _res := _res || '<option value="' || _q || '" selected="1">' || _d || '</option>';
		else
		  _res := _res || '<option value="' || _q || '">' || _d || '</option>';
	 }
 	} else {
	 _res := '"--- choose your ' || case when _type < XQ..COLLECTIONS_ID () then 'query' else 'collection' end || ' ---", ""';
	 for select text as _q, descr as _d from XQ..CACHED_RESOURCES where type = _type order by id do {
		_res := _res || ',"' || _d || '","' || _q || '"';

	 }
	}

	return _res;
}
;

create procedure ins (in _d varchar, in _q varchar, in _type int:=0)
{
	declare _text varchar;
	_text := _d;
	if (_type = 0)
	  {
	    if (substring (_text, 1, 12) = '//*[contains')
	      {
		_text :=  '<table> { \\n' ||
'	for \\044d in fn:collection (\'===XXX===\', ., 1, 2) //description' || substring (_text, 4, length (_text)) ||  ' \\n' ||
'	let \\044link :=  \\044d/ancestor::item/link/string() \\n' ||
'	let \\044title := \\044d/ancestor::item/title/string() \\n' ||
'	return  \\n' ||
'		<tr> \\n' ||
'		  <td valign=\'top\'> \\n' ||
'			<a href=\'{\\044link}\'><b>{\\044title}</b></a> \\n' ||
'		  </td> \\n' ||
'		  <td> \\n' ||
'			{\\044d} \\n' ||
'		  </td> \\n' ||
'		</tr> \\n' ||
'	} </table>';
	      }
	    else
	      {
		_text :=  '<table> { \\n' ||
'	for \\044d in fn:collection (\'===XXX===\', ., 1, 2) //description \\n' ||
'       for \\044h in document-literal (\\044d, \'\', 2)'|| _text ||  '\\n' ||
'	let \\044link :=  \\044d/ancestor::item/link/string() \\n' ||
'	let \\044title := \\044d/ancestor::item/title/string() \\n' ||
'	return  \\n' ||
'		<tr> \\n' ||
'		  <td valign=\'top\'> \\n' ||
'			<a href=\'{\\044link}\'><b>{\\044title}</b></a> \\n' ||
'		  </td> \\n' ||
'		  <td> \\n' ||
'			{\\044h} \\n' ||
'		  </td> \\n' ||
'		</tr> \\n' ||
'	} </table>';
	      }
	   }

	insert into XQ..CACHED_RESOURCES (descr, text, type) values (_q, _text, _type);
}
;

ins('//a/@href[contains(.,\'.mp3\') or contains(.,\'.wav\') or contains(.,\'.mov\') or contains(.,\'.ram\') or contains(.,\'.swf\') or contains(., \'wmv\') or contains(., \'.wma\')]/ancestor::a','audio and video clips');
-- ins('//a[contains(@href, \'demo.com\') or contains(ancestor::content, \'DEMO\') or contains(ancestor::content, \'Demo@15\')]/ancestor::content','items about the DEMO conference');
-- ins('//content[contains(., \'REST\')]/ancestor::item/title','items mentioning \'REST\'');
ins('//*[contains(., \'XML\')]/ancestor::item/title','items mentioning \'XML\'');
ins('//*[contains(., \'SOAP\')]/ancestor::item/title','items mentioning \'SOAP\'');
-- ins('//item/title[matches(., \'REST|[Ww]eb [Ss]ervices|WS\-[\*I]|SOA|[Ss]ervice[s]*[\- ][Oo]riented\')]','items with titles matching REST, Web Services, SOAP, WS-*, SOA, or service-oriented');
ins('//pre[code and contains(., \'www.w3.org/1999/XSL/Transform\')]','XSL-T code fragments');
-- ins('//a[contains(./@href, \'infoworld.com\') and contains(ancestor::item/date, \'2005/02\')]','links, in February items, to infoworld.com');
ins('//*[count(.//p)>30]','articles of more than 30 paragraphs');
ins('//a[contains(./@href, \'infoworld.com\') and contains(ancestor::content, \'Linux\')]','links to infoworld.com in items that mention \'Linux\'');
ins('//item//a[ ( matches(ancestor::item/title,\'Linux|Windows\') and matches(ancestor::item/title,\'[Ss]ecurity\') ) or ( matches(., \'Linux|Windows\') and matches(., \'[Ss]ecurity\') ) ]','titles or links where \'Linux\' or \'Microsoft\' appear in conjunction with \'security\'');
ins('//*[contains (., \'Linux\') and contains (., \'Mac\')]','items that mention \'Linux\' and \'Mac\'');
-- ins('//a/@href[contains(., \'amazon.com\') and matches(., \'/\d%7b9,9%7d[\dX]\')]/ancestor::a','links to books on amazon.com');
-- ins('//a[contains(./@href, \'amazon.com\') and contains(./img/@src, \'amazon.com\')]','images linked to amazon.com');
ins('//*[contains(., \'ODBC\')]','whole items containing \'ODBC\'');
ins('//item[contains(link, \'msdn.com\')]//a[not contains (@href, \'msdn.com\')]','external links from msdn.com bloggers');
--ins('//a[contains(./@href,\'amazon.com\') and matches(@href, \'\d%7b9,9%7d[\dX]\') and contains(. , \'America\')]','links to Amazon books, with \'America\' in the text of the link ');
ins('//table[count(.//tr)>3 or count(.//td)>3]','tabular data');
ins('//title[contains(., \'Dynamic\')]','titles containing \'Dynamic\'');
ins('//a[contains(@rel, \'tag\')]','links using rel=\'tag\'');
--ins('//a[contains(@rel, \'nofollow\')]','links using rel=\'nofollow\'');
ins('//img[contains(@src, \'flickr.com\')]','images from flickr');
ins('//img[contains(@src, \'.png\')]','png images');
ins('//img','all images');
ins('//a','all links');
ins('<ul> { for \044title in fn:collection (\'===XXX===\', ., 1, 2)//title return <li> { \044title/text() }  </li> } </ul>','All titles', 2);
ins('<ul> { for \044img in fn:collection (\'===XXX===\', ., 1, 2)//*[(local-name () = \'img\') and contains(@src, \'.png\')] return <li> <img src=\'{\044img/@src}\'/> </li> } </ul>','png images', 2);
ins('<ul> { for \044img in fn:collection (\'===XXX===\', ., 1, 2)//*[local-name () = \'img\'] return <li> <img src=\'{\044img/@src}\'/> </li> } </ul>','All images', 2);
ins('<ul> { for \044tag in distinct-values (fn:collection (\'===XXX===\', ., 1, 2)//*/local-name()) return <li> { \044tag } </li> } </ul>', 'All tag names', 2);
ins('<ul> { for \044a in fn:collection (\'===XXX===\', ., 1, 2)//*[local-name() = \'a\'] return <li> <a href=\'{\044a/@href}\'> { \044a/text() } </a> </li> } </ul>', 'All links', 2);


ins('declare namespace virtrss=\'http://www.openlinksw.com/rss/\';\\n<last-hour-counts>{\\n  let $rss-col := \'http://www.nytimes.com/services/xml/rss/nyt/Books.xml\'\\n  for $channel in document($rss-col)/rss/channel\\n  let $doc-uri := document-get-uri ($channel)\\n  let $items := $channel/*[self::image|self::item]\\n  let $channel-pubdate := virtrss:datetime-parser ($channel/pubDate/text())\\n  let $fresh-count :=\\n    count (\\n      $items[pubDate][\\n        fn:datediff (\'minute\',\\n   virtrss:datetime-parser (pubDate/text()),\\n          $channel-pubdate\\n    ) < 60] )\\n  return\\n    <rss-feed title=\'{$channel/title}\' uri=\'{$doc-uri}\'\\n      pubDate=\'{string ($channel-pubdate)}\'\\n      allItemsCount=\'{count ($items)}\'\\n      freshItemsCount=\'{$fresh-count}\'></rss-feed>\\n  }</last-hour-counts>', 'Last Hour Counts of New York Times Books', 1);
ins('declare namespace virtrss=\'http://www.openlinksw.com/rss/\';\\n<today-activity>\\n{\\nlet $rss-col := \'http://www.nytimes.com/services/xml/rss/nyt/Business.xml\'\\nlet $snapshot_begin := fn:dateadd (\'day\', -10, fn:current-dateTime())\\nlet $recent_items := document($rss-col)/rss/channel/*[self::image|self::item][pubDate][virtrss:datetime-parser (pubDate/text()) > $snapshot_begin]\\nlet $authors := distinct (for $a in $recent_items/author return string($a))\\nreturn\\n  for $author in $authors\\n  return\\n    <items author=\'{$author}\'/>\\n  }</today-activity>', 'Today Activity for New York Times Business', 1);
ins('declare namespace virtrss=\'http://www.openlinksw.com/rss/\';\\n<politics>{\\nlet $snapshot_begin := fn:dateadd (\'day\', -10, fn:current-dateTime())\\nlet $political_items := document(\'http://rss.cnn.com/rss/cnn_allpolitics.rss/\')/rss/channel/*[self::image|self::item][pubDate][contains (link, \'politics\') or contains (../link, \'politics\')]\\nreturn\\n  for $item in $political_items\\n  order by string ($item/author), virtrss:datetime-parser ($item/pubDate) descending\\n  return $item\\n  }</politics>', 'Politics on CNN', 1);
ins ('for $pn in fn:distinct-values(\\n      fn:doc(\'http://news.com.com/2547-1_3-0-20.xml\')/rss/channel/item/category)\\n      let $i := fn:doc(\'http://news.com.com/2547-1_3-0-20.xml\')/rss/channel/item/category[. = $pn]\\n      where fn:count($i) >= 3\\n      order by $pn\\n      return\\n         <article>\\n	       {$pn}\\n         </article>', 'Popular Categories', 1);

-- collections
create procedure XQ..COLLECTIONS_ID () { return 10; };

--ins ('http://local.virt/DAV/blogs/subscribed/', 'Subscribed blogs collection', XQ..COLLECTIONS_ID ());
--ins ('http://local.virt/DAV/blogs/local/', 'Local blogs collection', XQ..COLLECTIONS_ID ());
ins ('{Own}', 'Home collection', XQ..COLLECTIONS_ID ());
ins ('http://local.virt/DAV/feeds/', 'Local feeds collection', XQ..COLLECTIONS_ID ());
-- ins ('http://local.virt/DAV/VAD/tutorial/xml/ms_a_1/', 'XSD example collection', XQ..COLLECTIONS_ID ());
ins ('{Empty}', 'External document', XQ..COLLECTIONS_ID ());

create procedure XQ..SET_HOME_COLLECTION_REFS ()
{
--  for select COL_NAME from WS.WS.SYS_DAV_COL where COL_PARENT = DAV_SEARCH_ID ('/DAV/home/', 'C') do
--    {
--	 ins ('http://local.virt/DAV/home/' || COL_NAME || '/MyItems/Content Syndication (like RSS and Atom)/title/', 'CatFilter collection of ' || COL_NAME, XQ..COLLECTIONS_ID ());
--   }
  ;
};

XQ..SET_HOME_COLLECTION_REFS();


create procedure XQ..GET_SCRIPT (in _collection_id int:=0, in _collection_id2 int:=2)
{
	return '<script>
var collections = new Array ();
collections [0] = [' || XQ..GET_RESOURCES (_collection_id, 0) || '];
collections [1] = [' || XQ..GET_RESOURCES (_collection_id2, 0) || '];
collections [2] = [' || XQ..GET_RESOURCES (1, 0) || '];
            function transform(collection, query) {
  	        var str;
		str = query;
		if (collection[0] == \'/\')
		  collection = \'http://local.virt\' + collection;
		if (collection == \'\')
		  collection = \'http://local.virt/DAV/feeds/\';
		str = str.replace (/===XXX===/g, collection);
	   	document.queryList.q.value = str;
		if (document.queryList.coll.value == \'\')
		  {
		    if (document.queryList.collopt.selectedIndex == 0)
	  		document.queryList.coll.value = \'http://local.virt/DAV/feeds/\';
		    else
	  		document.queryList.coll.value = document.queryList.collopt.value;
		  }
            }
	function updateCollection (array, sel, target)
	{
		var i, aidx;
		aidx = 0;
		if (sel == 3)
		  aidx = 2;
		if (sel > 3)
		  aidx = 1;
		target.length = 0;
		for (i = 0; i < array[aidx].length/2; i++)
			target.options[i] = new Option (array[aidx][2*i], array[aidx][2*i+1]);
	}
	function transform2(query, sel) {
		updateCollection (collections, sel, document.queryList.qopt);
  		document.queryList.coll.value = query;
        }
	function init() {
	  if (document.queryList.coll.value  == \'{Empty}\')
	    {
	      document.queryList.enc.checked = false;
	      document.queryList.enc.style.visibility = \'hidden\';
	    }
	  else
	      document.queryList.enc.style.visibility = \'visible\';

        }
	    </script>
   <noscript><p><b>Javascript must be enabled to use this form.</b></p></noscript>';
};
