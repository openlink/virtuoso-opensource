--
--
--  $Id$
--
--  RDF Mappings
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
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

-- remove wrong cartridge patterns
delete from DB.DBA.SYS_RDF_MAPPERS where RM_PATTERN = '(text/html)|(application/atom.xml)|(text/xml)|(application/xml)|(application/rss.xml)' and RM_TYPE = 'MIME';
delete from DB.DBA.SYS_RDF_MAPPERS where RM_PATTERN = '(text/html)|(application/atom.xml)|(text/xml)|(application/xml)|(application/rss.xml)|(application/rdf.xml)' and RM_TYPE = 'MIME';
delete from DB.DBA.SYS_RDF_MAPPERS where RM_PATTERN = '.+\.svg\$';
delete from DB.DBA.SYS_RDF_MAPPERS where RM_PATTERN = '.+\.od[ts]\$';
delete from DB.DBA.SYS_RDF_MAPPERS where RM_PATTERN = '.+\.ics\$';
delete from DB.DBA.SYS_RDF_MAPPERS where RM_PATTERN = '.+\\.ics\x24';

-- insertion of cartridges

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('http://.*oreilly.com/catalog/.*',
    'URL', 'DB.DBA.RDF_LOAD_OREILLY', null, 'Oreilly');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('http://books.google.com/.*',
    'URL', 'DB.DBA.RDF_LOAD_GOOGLE_BOOK', null, 'Google Book');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('http://.*etsy.com/.*',
    'URL', 'DB.DBA.RDF_LOAD_ETSY', null, 'Etsy');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('(http://.*download.com/.*)|'||
    '(http://download.cnet.com/.*)|'||
    '(http://shopper.cnet.com/.*)|'||
    '(http://reviews.cnet.com/.*)',
    'URL', 'DB.DBA.RDF_LOAD_CNET', null, 'CNET');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('http://www.wine.com/.*',
    'URL', 'DB.DBA.RDF_LOAD_WINE', null, 'Wine');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('http://www.evri.com/.*',
    'URL', 'DB.DBA.RDF_LOAD_EVRI', null, 'Evri');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('http://.*tumblr.com/.*',
    'URL', 'DB.DBA.RDF_LOAD_TUMBLR', null, 'Tumblr');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('(http://.*yelp.com/.*)',
    'URL', 'DB.DBA.RDF_LOAD_YELP', null, 'Yelp');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('http://www.google.com/base/feeds/snippets.*', 
	'URL', 'DB.DBA.RDF_LOAD_GOOGLEBASE', null, 'Google Base');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('(http://spreadsheets.google.com/.*)|'||
    '(https://spreadsheets.google.com/.*)',
    'URL', 'DB.DBA.RDF_LOAD_GOOGLE_SPREADSHEET', null, 'Google (Spreadsheets)');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('(http://docs.google.com/.*)|'||
    '(https://docs.google.com/.*)',
    'URL', 'DB.DBA.RDF_LOAD_GOOGLE_DOCUMENT', null, 'Google (Documents)');

--insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION, RM_ENABLED)
--	values ('.*', 'HTTP', 'DB.DBA.RDF_LOAD_HTTP_SESSION', null, 'HTTP in RDF', 0);
delete from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_HTTP_SESSION';

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('.*', 'URL', 'DB.DBA.RDF_LOAD_FACEBOOK_OPENGRAPH_SELECTION', null, 'Facebook Open Graph');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION, RM_OPTIONS)
	values ('(text/html)|(text/xml)|(application/xml)|(application/rdf.xml)',
	'MIME', 'DB.DBA.RDF_LOAD_HTML_RESPONSE', null, 'xHTML', vector ('add-html-meta', 'yes', 'get-feeds', 'no'));

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION, RM_OPTIONS)
	values ('(application/atom.xml)|(text/xml)|(application/xml)|(application/rss.xml)',
	'MIME', 'DB.DBA.RDF_LOAD_FEED_RESPONSE', null, 'Feeds', null);

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('(http://farm[0-9]*.static.flickr.com/.*)|'||
			'(http://www.flickr.com/photos/.*)',
    'URL', 'DB.DBA.RDF_LOAD_FLICKR_IMG', null, 'Flickr Images');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('(http://www.ustream.tv/channel/.*)|'||
    '(http://www.ustream.tv/user/.*)|'||
    '(http://www.ustream.tv/recorded/.*)',
    'URL', 'DB.DBA.RDF_LOAD_USTREAM', null, 'Ustream');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('http://.*openstreetmap.org/.*',
    'URL', 'DB.DBA.RDF_LOAD_OPENSTREETMAP', null, 'OpenStreetMap');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('http://.*bestbuy.com/.*',
	'URL', 'DB.DBA.RDF_LOAD_BESTBUY', null, 'BestBuy articles');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://.*amazon.[^/]+/gp/product/.*)|'||
	'(http://.*amazon.[^/]+/o/ASIN/.*)|'||
	'(http://.*amazon.[^/]+/[^/]+/dp/[^/]+(/.*)?)|'||
	'(http://.*amazon.[^/]+/[^/]+/product-reviews/.*)|'||
	'(http://.*amazon.[^/]+/exec/obidos/ASIN/.*)|' ||
        '(http://.*amazon.[^/]+/s\?.*)|' ||
        '(http://.*amazon.[^/]+/gp/registry/wishlist/.*)|' ||
        '(http://.*amazon.[^/]+/exec/obidos/tg/detail/-/[^/]+/.*)',
	'URL', 'DB.DBA.RDF_LOAD_AMAZON_ARTICLE', null, 'Amazon articles');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://.*youtube.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_YOUTUBE', null, 'YouTube');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://.*vimeo.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_VIMEO', null, 'Vimeo');
	
insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://delicious.com/.*)|(http://feeds.delicious.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_DELICIOUS', null, 'Delicious');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://picasaweb.google.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_PICASA', null, 'Picasa');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://.*geonames.org/.*)',
	'URL', 'DB.DBA.RDF_LOAD_GEONAMES', null, 'Geonames');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://.*last.fm/.*)|'||
	'(http://.*lastfm.*/.*)',
	'URL', 'DB.DBA.RDF_LOAD_LASTFM', null, 'LastFM');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://.*meetup.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_MEETUP', null, 'Meetup');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://.*discogs.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_DISCOGS', null, 'Discogs');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://.*disqus.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_DISQUS', null, 'Disqus');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://www.radiopop.co.uk/users/.*)',
	'URL', 'DB.DBA.RDF_LOAD_RADIOPOP', null, 'Radio Pop');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://www.idiomag.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_IDIOMAG', null, 'Idio Your Magazine');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://www.rhapsody.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_RHAPSODY', null, 'Rhapsody');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('http://.*tesco.com/.*',
	'URL', 'DB.DBA.RDF_LOAD_TESCO', null, 'Tesco');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION, RM_OPTIONS)
	values ('(http://.*slideshare.net/.*)',
	'URL', 'DB.DBA.RDF_LOAD_SLIDESHARE', null, 'Slideshare', vector ('SharedSecret', ''));

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://.*slidesix.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_SLIDESIX', null, 'Slidesix');
        
insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://.*revyu.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_REVYU', null, 'Revyu');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://bugs.*)|'||
	'(http://.*/show_bug.cgi\\?id.*)|'||
	'(http://.*bugzilla.*)|'||
	'(https://bugzilla.*)|'||
	'(https://.*bugzilla.*)',
	'URL', 'DB.DBA.RDF_LOAD_BUGZILLA', null, 'Bugzillas');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://digg.com/.*)|(http://services.digg.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_DIGG', null, 'Digg');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://isbndb.com/.*)|'||
	'(https://isbndb.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_ISBN', null, 'ISBN');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://www.librarything.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_LIBRARYTHING', null, 'LibraryThing');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://www.theyworkforyou.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_TWFY', null, 'TWFY');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://.*getsatisfaction.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_GETSATISFATION', null, 'GetSatisfaction');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://twitter.com/.*)|' ||
	'(http://search.twitter.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_TWITTER', null, 'Twitter');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://.*salesforce.com/.*)|'||
	'(https://.*salesforce.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_SALESFORCE', null, 'SalesForce');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://friendfeed.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_FRIENDFEED', null, 'FriendFeed');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(www.zillow.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_ZILLOW', null, 'Zillow');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://socialgraph.apis.google.com/lookup\\?.*)|'||
	'(http://socialgraph.apis.google.com/otherme\\?.*)',
	'URL', 'DB.DBA.RDF_LOAD_SOCIALGRAPH', null, 'SocialGraph');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('http://openlibrary.org/b/.*',
	'URL', 'DB.DBA.RDF_LOAD_OPENLIBRARY', null, 'OpenLibrary');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('.+\\.svg\x24', 'URL', 'DB.DBA.RDF_LOAD_SVG', null, 'SVG');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('.+\\.csv\x24', 'URL', 'DB.DBA.RDF_LOAD_CSV', null, 'CSV');
        
insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(http://cgi.sandbox.ebay.com/.*)|(http://cgi.ebay.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_EBAY_ARTICLE', null, 'eBay articles');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('.+\\.od[ts]\x24', 'URL', 'DB.DBA.RDF_LOAD_OO_DOCUMENT', null, 'OO Documents');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(.+\\.docx\x24)|(.+\\.xlsx\x24)', 'URL', 'DB.DBA.RDF_LOAD_MS_DOCUMENT', null, 'Microsoft Documents');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('.+\\.fod[tsg]\x24', 'URL', 'DB.DBA.RDF_LOAD_OO_DOCUMENT2', null, 'OpenOffice Documents');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('http://local.yahooapis.com/MapsService/V1/trafficData.*',
	'URL', 'DB.DBA.RDF_LOAD_YAHOO_TRAFFIC_DATA', null, 'Yahoo Traffic Data');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(.+\\.ics\x24)|(.+\\.ics\?.*)', 'URL', 'DB.DBA.RDF_LOAD_ICAL', null, 'iCalendar');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('(text/calendar)', 'MIME', 'DB.DBA.RDF_LOAD_WEBCAL', null, 'WebCal');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION, RM_OPTIONS)
	values ('http[s]*://.*.facebook.com/.*',
	'URL', 'DB.DBA.RDF_LOAD_FACEBOOK_OPENGRAPH', null, 'FaceBook', vector ('secret', '', 'session', ''));

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION, RM_OPTIONS)
	values ('http[s]*://.*.facebook.com/.*',
	'URL', 'DB.DBA.RDF_LOAD_FQL', null, 'FaceBook', vector ('secret', '', 'session', ''));

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION, RM_OPTIONS)
	values ('http://www.freebase.com/view/.*',
	'URL', 'DB.DBA.RDF_LOAD_MQL', null, 'Freebase', vector ());

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION, RM_ENABLED)
	values ('.*', 'MIME', 'DB.DBA.RDF_LOAD_DAV_META', null, 'WebDAV Metadata', 1);

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('http://.*.wikipedia.org.*',
	'URL', 'DB.DBA.RDF_LOAD_WIKIPEDIA_ARTICLE', null, 'Wikipedia');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('http://finance.yahoo.com/q\\?s=.*',
	'URL', 'DB.DBA.RDF_LOAD_YAHOO_STOCK_DATA', null, 'Yahoo Finance');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
	values ('http://musicbrainz.org/([^/]*)/([^/]*)',
	'URL', 'DB.DBA.RDF_LOAD_MBZ', null, 'Musicbrainz');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION, RM_OPTIONS)
	values ('(http://api.crunchbase.com/v/1/.*)|(http://www.crunchbase.com/.*)|(http://crunchbase.com/.*)',
	'URL', 'DB.DBA.RDF_LOAD_CRUNCHBASE', null, 'CrunchBase', null);

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION, RM_OPTIONS)
	values ('.+\\.pptx\x24', 'URL', 'DB.DBA.RDF_LOAD_PPTX_DOCUMENT', null, 'Powerpoint documents', null);

update DB.DBA.SYS_RDF_MAPPERS set RM_ENABLED = 1 where RM_ENABLED is null;

-- pattern upgrades
update DB.DBA.SYS_RDF_MAPPERS set RM_PATTERN = '(http://api.crunchbase.com/v/1/.*)|(http://www.crunchbase.com/.*)|(http://crunchbase.com/.*)'
	where RM_HOOK = 'DB.DBA.RDF_LOAD_CRUNCHBASE';

update DB.DBA.SYS_RDF_MAPPERS set RM_PATTERN =
    '(http://.*download.com/.*)|'||
    '(http://download.cnet.com/.*)|'||
    '(http://shopper.cnet.com/.*)|'||
    '(http://reviews.cnet.com/.*)'
    where RM_HOOK = 'DB.DBA.RDF_LOAD_CNET';

update DB.DBA.SYS_RDF_MAPPERS set RM_PATTERN = '(http://cgi.sandbox.ebay.com/.*)|(http://cgi.ebay.com/.*)'
    where RM_HOOK = 'DB.DBA.RDF_LOAD_EBAY_ARTICLE';

update DB.DBA.SYS_RDF_MAPPERS set RM_PATTERN =
	'(http://.*amazon.[^/]+/gp/product/.*)|'||
	'(http://.*amazon.[^/]+/o/ASIN/.*)|'||
	'(http://.*amazon.[^/]+/[^/]+/dp/[^/]+(/.*)?)|'||
	'(http://.*amazon.[^/]+/dp/[^/]+(/.*)?)|'||
	'(http://.*amazon.[^/]+/[^/]+/product-reviews/.*)|'||
	'(http://.*amazon.[^/]+/s\?.*)|'||
	'(http://.*amazon.[^/]+/exec/obidos/ASIN/.*)|' ||
        '(http://.*amazon.[^/]+/gp/registry/wishlist/.*)|' ||
	'(http://.*amazon.[^/]+/exec/obidos/tg/detail/-/[^/]+/.*)'
	where RM_HOOK = 'DB.DBA.RDF_LOAD_AMAZON_ARTICLE';

update DB.DBA.SYS_RDF_MAPPERS 
	set RM_PATTERN = 'http://.*delicious.com/.*'
	where RM_HOOK = 'DB.DBA.RDF_LOAD_DELICIOUS';

-- migration from old servers
create procedure DB.DBA.RM_MAPPERS_UPGRADE ()
{
  declare pk any;
  pk := DB.DBA.REPL_PK_COLS ('DB.DBA.SYS_RDF_MAPPERS');
  if (length (pk) = 2 and pk[0][0] = 'RM_TYPE' and pk[1][0] = 'RM_PATTERN')
    {
      declare skip_up int;
      skip_up := 0;
      for select RM_HOOK from DB.DBA.SYS_RDF_MAPPERS group by 1 having count(*) > 1 do
	{
	  if (skip_up = 0)
	    log_message ('The DB.DBA.SYS_RDF_MAPPERS cannot be upgraded');
	  log_message (sprintf ('The %s cartridge is defined multiple times, remove duplicate', RM_HOOK));
	  skip_up := skip_up + 1;
	}
      if (skip_up = 0)
	{
	  exec ('alter table DB.DBA.SYS_RDF_MAPPERS modify primary key (RM_HOOK)');
	  log_message ('The DB.DBA.SYS_RDF_MAPPERS have been upgraded');
	}
    }
  return;
}
;

DB.DBA.RM_MAPPERS_UPGRADE ()
;

create procedure RM_UPGRADE_TBL (in tbl varchar, in col varchar, in coltype varchar)
{
  if (exists( select top 1 1 from DB.DBA.SYS_COLS where upper("TABLE") = upper(tbl) and upper("COLUMN") = upper(col)))
    return;
  exec (sprintf ('alter table %s add column %s %s', tbl, col, coltype));
}
;

DB.DBA.EXEC_STMT(
'create table DB.DBA.RDF_META_CARTRIDGES (
  	MC_ID integer identity,
	MC_SEQ integer identity,
	MC_HOOK varchar,
	MC_TYPE varchar default \'URL\',
	MC_PATTERN varchar not null,
	MC_KEY varchar,
	MC_OPTIONS any,
	MC_DESC long varchar,
	MC_ENABLED int not null default 1,
	MC_API_TYPE integer default 0,
	primary key (MC_HOOK)
)
alter index RDF_META_CARTRIDGES on DB.DBA.RDF_META_CARTRIDGES partition cluster replicated', 0)
;

RM_UPGRADE_TBL ('DB.DBA.RDF_META_CARTRIDGES', 'MC_API_TYPE', 'integer default 0');

DB.DBA.EXEC_STMT(
'create table DB.DBA.RDF_CARTRIDGES_LOOKUPS (
	CL_URI IRI_ID_8,
	CL_STAT int,
	CL_TS timestamp,
	primary key (CL_URI))', 0
)
;

DB.DBA.EXEC_STMT(
'create table DB.DBA.RDF_META_CARTRIDGES_LOG (
	ML_SESSION varchar,		-- session id
	ML_ID integer identity,		-- an unique number
	ML_TS timestamp,		-- ts
	ML_PROC varchar,
	ML_KEYWORDS long varchar,	-- text predicates
	ML_REQUEST long varchar,	-- web service url and parameters
	ML_RESPONSE_HEAD long varchar,	-- response headers
	ML_RESPONSE long varchar,	-- response body
	ML_RESULT long varchar,		-- transformation to rdf
	primary key (ML_SESSION, ML_ID)
)
alter index RDF_META_CARTRIDGES_LOG on DB.DBA.RDF_META_CARTRIDGES_LOG partition cluster replicated', 0)
;

create procedure RM_LOG_REQUEST (in url varchar, in kwd varchar, in proc varchar)
{
  declare sid, pname any;
  sid := connection_get ('__rdf_sponge_sid');
  if (registry_get ('__rdf_sponge_debug') <> '1')
    return;
  if (sid is null)
    return;
  pname := rtrim (proc, '2');
  pname := rtrim (pname, '_REST');
  insert into DB.DBA.RDF_META_CARTRIDGES_LOG (ML_KEYWORDS, ML_REQUEST, ML_SESSION, ML_PROC) values (kwd, url, sid, pname);
  connection_set ('__rdf_sponge_idn', identity_value ());
}
;

create procedure RM_LOG_RESPONSE (in resp varchar, in hdr any)
{
  declare sid, idn, hdr_str any;
  sid := connection_get ('__rdf_sponge_sid');
  idn := connection_get ('__rdf_sponge_idn');
  if (sid is null or idn is null)
    return;
  hdr_str := '';
  foreach (varchar l in hdr) do
    hdr_str := hdr_str || l;
  update DB.DBA.RDF_META_CARTRIDGES_LOG set ML_RESPONSE = resp, ML_RESPONSE_HEAD = hdr_str where ML_SESSION = sid and ML_ID = idn;
}
;

create procedure RM_LOG_RESULT (in res any)
{
  declare sid, idn any;
  sid := connection_get ('__rdf_sponge_sid');
  idn := connection_get ('__rdf_sponge_idn');
  if (sid is null or idn is null)
    return;
  update DB.DBA.RDF_META_CARTRIDGES_LOG set ML_RESULT = res where ML_SESSION = sid and ML_ID = idn;
}
;


create procedure RM_LOG_CLEAR ()
{
  declare sid any;
  sid := connection_get ('__rdf_sponge_sid');
  if (sid is null)
    return;
  delete from DB.DBA.RDF_META_CARTRIDGES_LOG where ML_SESSION = sid;
}
;

create procedure DB.DBA.MIGRATE_CALAIS ()
{
  insert into DB.DBA.RDF_META_CARTRIDGES (MC_HOOK, MC_TYPE, MC_PATTERN, MC_KEY, MC_OPTIONS, MC_DESC, MC_ENABLED)
      select RM_HOOK, RM_TYPE, RM_PATTERN, RM_KEY, RM_OPTIONS, RM_DESCRIPTION, RM_ENABLED from DB.DBA.SYS_RDF_MAPPERS
      where RM_HOOK = 'DB.DBA.RDF_LOAD_CALAIS';
  delete from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_CALAIS';
}
;

DB.DBA.MIGRATE_CALAIS ();

create procedure DB.DBA.RM_MAPPERS_SET_ORDER ()
{
   declare inx int;
   declare top_arr, arr, http, html, feed, calais, fb_og, num any;

   if (exists (select RM_PID, count(*) from DB.DBA.SYS_RDF_MAPPERS group by RM_PID having count(*) > 1))
     {
       num := (select count(*) from DB.DBA.SYS_RDF_MAPPERS);
       inx := 1;
       for select RM_HOOK as hook from DB.DBA.SYS_RDF_MAPPERS do
	 {
	   update DB.DBA.SYS_RDF_MAPPERS set RM_PID = inx where RM_HOOK = hook;
	   inx := inx + 1;
	 }
     }

   --http := (select RM_PID from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_HTTP_SESSION');
   html := (select RM_PID from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_HTML_RESPONSE');
   feed := (select RM_PID from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_FEED_RESPONSE');
   fb_og := (select RM_PID from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_FACEBOOK_OPENGRAPH_SELECTION');
--   calais := (select RM_PID from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_CALAIS');
   top_arr := vector (html, feed, fb_og);

   arr := (select DB.DBA.VECTOR_AGG (RM_PID) from DB.DBA.SYS_RDF_MAPPERS  where 0 = position (RM_PID, top_arr) order by RM_ID);
   inx := 1;
   arr := vector_concat (top_arr, arr);
   foreach (int pid in arr) do
     {
       update DB.DBA.SYS_RDF_MAPPERS set RM_ID = inx where RM_PID = pid;
       inx := inx + 1;
     }
   DB.DBA.SET_IDENTITY_COLUMN ('DB.DBA.SYS_RDF_MAPPERS', 'RM_PID', inx);
   DB.DBA.SET_IDENTITY_COLUMN ('DB.DBA.SYS_RDF_MAPPERS', 'RM_ID', inx);
   update DB.DBA.SYS_RDF_MAPPERS set RM_ID = 10000 + inx where RM_HOOK = 'DB.DBA.RDF_LOAD_DAV_META';
}
;

RM_MAPPERS_SET_ORDER ();

-- /* to insert cartridge after another */
create procedure RM_MAPPERS_SET_CONSEQ (in proc_1 varchar, in proc_2 varchar)
{
   declare inx int;
   declare top_arr, arr, http, html, feed, calais, pid_1, pid_2, do_update any;

   pid_1 := (select RM_PID from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = proc_1);
   pid_2 := (select RM_PID from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = proc_2);
   top_arr := (select DB.DBA.VECTOR_AGG (RM_PID) from DB.DBA.SYS_RDF_MAPPERS
   	where RM_HOOK in ('DB.DBA.RDF_LOAD_HTTP_SESSION','DB.DBA.RDF_LOAD_HTML_RESPONSE','DB.DBA.RDF_LOAD_FEED_RESPONSE')
	order by RM_ID);
   arr := (select DB.DBA.VECTOR_AGG (RM_PID) from DB.DBA.SYS_RDF_MAPPERS  where 0 = position (RM_PID, top_arr) and RM_HOOK <> proc_2 order by RM_ID);
   inx := 0;
   do_update := 0;
   arr := vector_concat (top_arr, arr);
   foreach (int pid in arr) do
     {
       if (pid = pid_1)
	 {
	   inx := inx + 1;
           update DB.DBA.SYS_RDF_MAPPERS set RM_ID = inx where RM_PID = pid_2;
	   do_update := 1;
	 }
       else if (do_update)
	 {
           update DB.DBA.SYS_RDF_MAPPERS set RM_ID = inx where RM_PID = pid;
	 }
       inx := inx + 1;
     }
   DB.DBA.SET_IDENTITY_COLUMN ('DB.DBA.SYS_RDF_MAPPERS', 'RM_PID', inx);
   update DB.DBA.SYS_RDF_MAPPERS set RM_ID = 10000 + inx where RM_HOOK = 'DB.DBA.RDF_LOAD_DAV_META';
}
;

EXEC_STMT(
'create table DB.DBA.OAI_SERVERS (
    OS_ID     integer identity,
    OS_SERVER     varchar,
    OS_URN_PATTERN varchar,
    OS_ENABLED    int default 0,
    primary key (OS_ID, OS_SERVER)
)
alter index OAI_SERVERS on DB.DBA.OAI_SERVERS partition cluster replicated', 0)
;

DB.DBA.EXEC_STMT('CREATE TABLE DB.DBA.RDF_CARTRIDGES_COUNTRIES(RCC_CODE VARCHAR NOT NULL,RCC_NAME VARCHAR,PRIMARY KEY(RCC_CODE))', 0);

--
-- The GRDDL filters
-- This keeps all microformat filters
-- Every of these is called inside XHTML mapper
--
EXEC_STMT(
'create table DB.DBA.SYS_GRDDL_MAPPING (
    GM_NAME varchar,
    GM_PROFILE varchar,
    GM_XSLT varchar,
    GM_FLAG integer default 0,
    primary key (GM_NAME)
)
alter index SYS_GRDDL_MAPPING on DB.DBA.SYS_GRDDL_MAPPING partition cluster replicated
create index SYS_GRDDL_MAPPING_PROFILE on DB.DBA.SYS_GRDDL_MAPPING (GM_PROFILE) partition cluster replicated', 0)
;

RM_UPGRADE_TBL ('DB.DBA.SYS_GRDDL_MAPPING', 'GM_FLAG', 'integer default 0');

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('eRDF', 'http://purl.org/NET/erdf/profile', registry_get ('_rdf_mappers_path_') || 'xslt/main/erdf2rdfxml.xsl')
;

--insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
--    values ('RDFa', '', registry_get ('_rdf_mappers_path_') || 'xslt/main/rdfa2rdfxml.xsl')
--;
delete from DB.DBA.SYS_GRDDL_MAPPING where GM_NAME = 'RDFa'
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('AB Meta', 'http://abmeta.org/#spec', registry_get ('_rdf_mappers_path_') || 'xslt/main/abmeta2rdfxml.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT, GM_FLAG)
    values ('Microsoft XML Spreadsheet 2003', 'urn:schemas-microsoft-com:office:spreadsheet', registry_get ('_rdf_mappers_path_') || 'xslt/main/ms_spreadsheet2rdf.xsl', 1)
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT, GM_FLAG)
    values ('Word 2003 XML Document', 'http://schemas.microsoft.com/office/word/2003/wordml', registry_get ('_rdf_mappers_path_') || 'xslt/main/ms_document2rdf.xsl', 1)
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('hCard', 'http://www.w3.org/2006/03/hcard', registry_get ('_rdf_mappers_path_') || 'xslt/main/hcard2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('hProduct', 'http://microformats.org/wiki/hproduct', registry_get ('_rdf_mappers_path_') || 'xslt/main/hproduct2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('hAudio', 'http://purl.org/weborganics/mo-haudio', registry_get ('_rdf_mappers_path_') || 'xslt/main/haudio2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('hCalendar', 'http://dannyayers.com/microformats/hcalendar-profile', registry_get ('_rdf_mappers_path_') || 'xslt/main/hcal2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('Slidy', 'http://www.w3.org/Talks/Tools/Slidy', registry_get ('_rdf_mappers_path_') || 'xslt/main/slidy2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('hReview', 'http://dannyayers.com/micromodels/profiles/hreview', registry_get ('_rdf_mappers_path_') || 'xslt/main/hreview2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('hNews', 'http://microformats.org/wiki/hnews', registry_get ('_rdf_mappers_path_') || 'xslt/main/hnews2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('hListing', 'http://dannyayers.com/micromodels/profiles/hlisting', registry_get ('_rdf_mappers_path_') || 'xslt/main/hlisting2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('relLicense', '', registry_get ('_rdf_mappers_path_') || 'xslt/main/cc2rdf.xsl')
;

-- specific case, so we put the GM_FLAG
insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT, GM_FLAG)
    values ('XBRL', '', registry_get ('_rdf_mappers_path_') || 'xslt/main/xbrl2rdf.xsl', 1)
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('HR-XML', '', registry_get ('_rdf_mappers_path_') || 'xslt/main/hrxml2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('hResume', 'http://dannyayers.com/micromodels/profiles/hresume', registry_get ('_rdf_mappers_path_') || 'xslt/main/hresume2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('Dublin Core', '', registry_get ('_rdf_mappers_path_') || 'xslt/main/dc2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('geoURL', '', registry_get ('_rdf_mappers_path_') || 'xslt/main/geo2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('Google Base', '', registry_get ('_rdf_mappers_path_') || 'xslt/main/google2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('Ning Metadata', '', registry_get ('_rdf_mappers_path_') || 'xslt/main/ning2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('XFN Profile', 'http://gmpg.org/xfn/11', registry_get ('_rdf_mappers_path_') || 'xslt/main/xfn2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('XFN Profile2', 'http://gmpg.org/xfn/1', registry_get ('_rdf_mappers_path_') || 'xslt/main/xfn2rdf.xsl')
;


insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('HTML5 Microdata', 'http://dev.w3.org/html5/md', registry_get ('_rdf_mappers_path_') || 'xslt/main/html5md2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('xFolk', '', registry_get ('_rdf_mappers_path_') || 'xslt/main/xfolk2rdf.xsl')
;

create procedure DB.DBA.RM_XLAT_CONCAT (in x any, in y any)
{
  if (not isstring (x))
    return x;
  if (registry_get ('__rdf_cartridges_original_doc_uri__') = '1')
    return x;
  return DB.DBA.RDF_PROXY_ENTITY_IRI(x);
  --return DB.DBA.RDF_SPONGE_PROXY_IRI (x);
}
;

EXEC_STMT ('grant execute on DB.DBA.RM_XLAT_CONCAT to "SPARQL_SPONGE"', 0);

create procedure DB.DBA.RM_RDF_SPONGE_ERROR (in pname varchar, in graph_iri varchar, in dest varchar, in sql_message varchar)
{
  declare gr, errs_iri, err_iri, nam any;
  if (0 = length (sql_message) or pname is null)
    return;
  if (coalesce (connection_get ('__rdf_sponge_debug'), 0) <> 1)
    return;
  pname := cast (pname as varchar);
  gr := coalesce (dest, graph_iri);
  nam := lower (name_part (pname, 2));
  err_iri := gr ||'#'||nam;
  errs_iri := gr||'#errors';
  DB.DBA.RDF_QUAD_URI (gr, RM_SPONGE_DOC_IRI (gr), 'http://www.openlinksw.com/schema/attribution#hasErrors', errs_iri);
  DB.DBA.RDF_QUAD_URI (gr, errs_iri, 'http://www.openlinksw.com/schema/attribution#hasError', err_iri);
  DB.DBA.RDF_QUAD_URI_L (gr, err_iri, 'http://www.openlinksw.com/schema/attribution#errorText', sql_message);
  return;
}
;

-- helper procedures
create procedure DB.DBA.RM_RDF_LOAD_RDFXML (in strg varchar, in base varchar, in graph varchar, in doc_iri_flag int := 1)
{
  declare nss, ses any;
  nss := xmlnss_get (xtree_doc (strg));
  ses := string_output ();
  http ('@prefix opl: <http://www.openlinksw.com/schema/attribution#> .\n', ses);
  http ('@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n', ses);
  http ('@prefix ore: <http://www.openarchives.org/ore/terms/> .\n', ses);
  for (declare i, l int, i := 0, l := length (nss); i < l; i := i + 2)
    {
      http (sprintf ('<%s> a opl:DataSource .\n', nss[i+1]), ses);
      http (sprintf ('<%s> opl:isDescribedUsing <%s> .\n', case when doc_iri_flag then RDF_SPONGE_PROXY_IRI (graph) else graph end, nss[i+1]), ses);
      http (sprintf ('<%s> opl:hasNamespacePrefix "%s" .\n', nss[i+1], nss[i]), ses);
    }
  DB.DBA.RDF_LOAD_RDFXML (strg, base, graph);
  -- INFO: may be this should be done when primaryTopic is set
  DB.DBA.TTLP (ses, base, graph);
}
;

create procedure DB.DBA.RM_ADD_PRV (in proc varchar, in base varchar, in graph varchar, in service_url varchar)
{
  declare ses, iri, h any;

  if (registry_get ('__rdf_cartridges_original_doc_uri__') = '1')
    return;
  if (not isstring (service_url))
    service_url := base;
  h := rfc1808_parse_uri (service_url);
  h [3] := ''; h [4] := ''; h [5] := '';
  service_url := DB.DBA.vspx_uri_compose (h);
  proc := cast (proc as varchar);
  ses := string_output ();
  iri := lower (name_part (proc, 2));
  http('<rdf:RDF xmlns:rdfg="http://www.w3.org/2004/03/trix/rdfg-1/" xmlns:spo="http://www.openlinksw.com/schemas/sponger/" xmlns:xsd="http://www.w3.org/2001/XMLSchema#" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:doap="http://usefulinc.com/ns/doap#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:prv="http://purl.org/net/provenance/ns#" xmlns:prvTypes="http://purl.org/net/provenance/types#">', ses);
  http('    <prv:DataCreation rdf:ID="DataCreation">', ses);
  http(sprintf ('	<prv:usedData rdf:resource="#%V"/>', iri), ses);
  http('    </prv:DataCreation>', ses);
  http(sprintf ('    <prv:DataItem rdf:ID="%V">', iri), ses);
  http('	<rdf:type rdf:resource="http://purl.org/net/provenance/types#QueryResult" />', ses);
  http('	<rdf:type rdf:resource="http://www.w3.org/2004/03/trix/rdfg-1/Graph" />', ses);
  http('	<prv:retrievedBy>', ses);
  http('	    <prv:DataAccess>', ses);
  http('		<prv:performedAt rdf:datatype="http://www.w3.org/2001/XMLSchema#dateTime">', ses);
  http(sprintf ('		    %s', date_iso8601 (now())), ses);
  http('		</prv:performedAt>', ses);
  http('		<prv:performedBy rdf:resource="#spongerInstance" />', ses);
  http(sprintf ('		<prv:accessedService rdf:resource="%V" />', service_url), ses);
  http('	    </prv:DataAccess>', ses);
  http('	</prv:retrievedBy>', ses);
  http('    </prv:DataItem>', ses);
  http('</rdf:RDF>', ses);
  DB.DBA.RDF_LOAD_RDFXML (ses, DB.DBA.RDF_SPONGE_PROXY_IRI (base), graph);
}
;

create procedure DB.DBA.RM_UMBEL_GET (in strg varchar)
{
  declare data, meta any;
  declare ses, cont, xt, xd, arr any;
  declare exit handler for sqlstate '*'
    {
      return xtree_doc ('<error/>');
    };
  commit work;
  cont := http_client (url=>'http://umbel.zitgist.com/ws/scones/index.php',
  		       http_method=>'POST',
    		       body=>sprintf ('text=%U', strg),
    	               http_headers=>'Accept: text/xml',
		       proxy=>connection_get ('sparql-get:proxy'),
		       timeout=>10);
  xt := xtree_doc (cont);
  return xt;
}
;

create procedure DB.DBA.XSLT_REGEXP_MATCH (in pattern varchar, in val varchar)
{
  return regexp_match (pattern, val);
}
;

create procedure DB.DBA.XSLT_SPLIT_AND_DECODE (in val varchar, in md int, in pattern varchar)
{
  declare x, ses any;

  declare exit handler for sqlstate '*'
    {
      return xtree_doc ('<results/>');
    };

  x := split_and_decode (val, md, '\0\0'||pattern);
  ses := string_output ();
  http ('<results>', ses);
  foreach (any elm in x) do
    {
      if (length (elm))
        http (sprintf ('<result><![CDATA[%s]]></result>', elm), ses);
    }
  http ('</results>', ses);
  return xtree_doc (string_output_string (ses));
}
;

create procedure DB.DBA.XSLT_UNIX2ISO_DATE (in val int)
{
  if (val is null)
    return null;
  return  date_iso8601 (dt_set_tz (dateadd ('second', val, dt_set_tz (stringdate ('1970-01-01'), 0)), 0));
}
;

create procedure DB.DBA.XSLT_STRING2ISO_DATE2 (in val varchar)
{
  declare ret, tmp any;
  if (val is null)
    return null;
  ret := stringdate(val);
  ret := date_iso8601 (ret);
  if (ret is not null)
	return ret;
  return null;
}
;


create procedure DB.DBA.XSLT_STRING2ISO_DATE (in val varchar)
{
  declare ret, tmp any;
  if (val is null)
    return null;
  tmp := sprintf_inverse (val, '%s %s %s %s %s %s', 0);
  if (length(tmp) > 5)
  {
	ret := http_string_date(sprintf('%s, %s %s %s %s %s', tmp[0], tmp[2], tmp[1], tmp[5], tmp[3], tmp[4]));
	ret := dt_set_tz (ret, 0);
    ret := date_iso8601 (ret);
    if (ret is not null)
		return ret;
  }
  return null;
}
;

create procedure DB.DBA.XSLT_HTTP_STRING_DATE (in val varchar)
{
  declare ret, tmp any;
  if (val is null)
    return null;
  declare exit handler for sqlstate '*'
    {
      return val;
    };
  tmp := sprintf_inverse (val, '%s, %s %s %s %s %s', 0);
  if (length(tmp) > 5)
    {
      ret := http_string_date (val);
      ret := dt_set_tz (ret, 0);
      ret := date_iso8601 (ret);
      if (ret is not null)
	return ret;
    }
  -- Wed Dec 10 21:24:54 EST 2008
  if (regexp_match ('[[:upper:]][[:lower:]]{2} [[:upper:]][[:lower:]]{2} [0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [[:upper:]]{2,} [0-9]{4,}', val)
      is not null)
    {
      tmp := sprintf_inverse (val, '%s %s %s %s %s %s', 0);
      if (tmp is not null and length (tmp) > 5)
	{
	  declare tz int;
	  tz := -1 * RM_GET_TZ (tmp[4]);
	  ret := http_string_date (sprintf ('%s, %s %s %s %s GMT', tmp[0], tmp[2], tmp[1], tmp[5], tmp[3]));
	  if (tz is not null)
	    ret := dt_set_tz (ret, tz);
	  else
	  ret := dt_set_tz (ret, 0);
	  ret := date_iso8601 (ret);
	  if (ret is not null)
	    return ret;
	}
    }
  tmp := sprintf_inverse (val, '%s %s %s', 0);
  if (length (tmp) > 2)
    {
      declare dt, tz any;
      dt := stringdate (tmp[0] || ' ' || tmp[1]);
      tz := -1 * RM_GET_TZ (tmp[2]);
      if (tz is not null)
	dt := dt_set_tz (dt, tz);
      else
	dt := dt_set_tz (dt, 0);
      ret := date_iso8601 (dt);
      if (ret is not null)
	return ret;
    }
  tmp := sprintf_inverse (val, '%s %s', 0);
  if (length (tmp) > 1)
    {
      declare dt any;
      dt := stringdate (val);
      dt := dt_set_tz (dt, 0);
      ret := date_iso8601 (dt);
      if (ret is not null)
	return ret;
    }
  return val;
}
;

create procedure DB.DBA.XSLT_REPLACE1 (in val varchar)
{
  val := replace (val, '(', '%28');
  val := replace (val, ')', '%29');
	return replace (val, '\'', '%27');
}
;

create procedure DB.DBA.XSLT_SHA1_HEX (in val varchar)
{
  return tree_sha1 (val, 1);
}
;

create procedure DB.DBA.XSLT_STR2DATE (in val varchar)
{
  declare ret any;
  ret := null;
  if (val like '[A-Za-z]* [0-9]*')
    {
      declare dt, pos, tmp, v any;
      v := trim (val, '+');
      pos := strchr (v, ' ');
      tmp := subseq (v, 0, pos);
      dt := trim(tmp);
      tmp := trim (subseq (v, pos));
      dt := 'Wee, ' || tmp || ' ' || dt || sprintf (' %d 00:00:00 GMT', year (now ()));
      ret := http_string_date (dt, null, null);
    }
  else
    ret := http_string_date (val, null, null);
  if (ret is not null)
    {
      ret := dt_set_tz (ret, 0);
      ret := date_iso8601 (ret);
    }
  return coalesce (ret, val);
}
;

create procedure DB.DBA.RDF_SPONGE_DOC_IRI (in url varchar, in dest varchar := null)
{
  declare res varchar;
  res := coalesce (url, dest);
  return res;
}
;


--
-- # this returns document IRI, non-proxy one
--
create procedure DB.DBA.RM_SPONGE_DOC_IRI (in url varchar, in frag varchar := 'this')
{
  declare hf, uri any;
  hf := rfc1808_parse_uri (url);
  if (hf[5] = '')
    hf[5] := frag;
  uri := vspx_uri_compose (hf);
  return uri;
}
;

create procedure DB.DBA.RDF_SPONGE_IRI_SCH ()
{
  if (is_https_ctx ())
    return 'https';
  return 'http';
}
;

--
-- # this is used to make proxy IRI of the document
--
create procedure DB.DBA.RDF_SPONGE_PROXY_IRI (in uri varchar := '', in login varchar := '', in frag varchar := 'this')
{
  declare cname any;
  declare ret any;
  declare url_sch varchar;
  declare ua any;

  cname := DB.DBA.RDF_PROXY_GET_HTTP_HOST ();

  if (frag = 'this' or frag = '#this') -- comment out to do old behaviour
    frag := '';

  if (length (frag) and frag[0] <> '#'[0])
    frag := '#' || sprintf ('%U', frag);
  if (strchr (uri, '#') is not null)
    frag := '';

  ua := rfc1808_parse_uri (uri);
  url_sch := ua[0];
  ua [0] := '';
  uri := vspx_uri_compose (ua);
  uri := ltrim (uri, '/');

  if (length (login))
    ret := sprintf ('%s://%s/about/rdf/%s/%U/%s%s', RDF_SPONGE_IRI_SCH (), cname, url_sch, login, uri, frag);
  else
    ret := sprintf ('%s://%s/about/id/%s/%s%s', RDF_SPONGE_IRI_SCH (), cname, url_sch, uri, frag);
  return ret;
}
;

create function DB.DBA.RDF_PROXY_GET_HTTP_HOST ()
{
  declare default_host, cname varchar;
  if (is_http_ctx ())
    default_host := http_request_header(http_request_header (), 'Host', null, null);
  else if (connection_get ('__http_host') is not null)
    default_host := connection_get ('__http_host');
  else
    default_host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  if (default_host is not null)
    cname := default_host;
  else
  {
    cname := sys_stat ('st_host_name');
    if (server_http_port () <> '80')
        cname := cname ||':'|| server_http_port ();
  }
  return cname;
}
;

--
-- # this one is used to make proxy IRI for primary topic (entity)
--
create procedure DB.DBA.RDF_PROXY_ENTITY_IRI (in uri varchar := '', in login varchar := '', in frag varchar := 'this')
{
  declare cname any;
  declare ret any;
  declare url_sch varchar;
  declare ua any;

  cname := DB.DBA.RDF_PROXY_GET_HTTP_HOST ();

  if (frag = 'this' or frag = '#this') -- comment out to do old behaviour
    frag := '';

  if (length (frag) and frag[0] <> '#'[0])
    {
      frag := '#' || sprintf ('%U', frag);
    }
  if (strchr (uri, '#') is not null)
    frag := '';

  ua := rfc1808_parse_uri (uri);
  url_sch := ua[0];
  ua [0] := '';
  uri := vspx_uri_compose (ua);
  uri := ltrim (uri, '/');

  ret := sprintf ('%s://%s/about/id/entity/%s/%s%s', RDF_SPONGE_IRI_SCH (), cname, url_sch, uri, frag);
  return ret;
}
;

create procedure DB.DBA.XSLT_ESCAPE (in body any) returns varchar
{
  declare str_out any;
  declare s, s2 varchar;
  s2 := serialize_to_UTF8_xml (body);
  str_out := string_output();
  http_value(s2, null, str_out);
  s := string_output_string(str_out);
  return s;
}
;

create procedure MOAT_APPLY (in ap_uid any, in phrase varchar)
{
  declare ap_set_ids any;
  declare res_out, script_out, match_list any;
  declare m_apc, m_aps, m_app, m_apa, m_apa_w, m_aph any;
  declare apa_w_ctr, apa_w_count integer;
  declare app_ctr, app_count integer;
  declare prev_end, prev_apa_id, prev_idx integer;
  declare done any;

  ap_set_ids := (select vector (APS_ID) from DB.DBA.SYS_ANN_PHRASE_SET where
  	APS_OWNER_UID = ap_uid and APS_NAME = sprintf ('Hyperlinking-%d', ap_uid));

  if (not length (ap_set_ids))
    return null;

  match_list := ap_build_match_list (ap_set_ids, phrase, 'x-any', 1, 0);
  m_apc   := aref_set_0 (match_list, 0);
  m_aps   := aref_set_0 (match_list, 1);
  m_app   := aref_set_0 (match_list, 2);
  m_apa   := aref_set_0 (match_list, 3);
  m_apa_w := aref_set_0 (match_list, 4);
  m_aph   := aref_set_0 (match_list, 5);

  apa_w_count := length (m_apa_w);
  app_count := length (m_app);
  if (0 = app_count)
    return null;
  for (apa_w_ctr := 0; apa_w_ctr < apa_w_count; apa_w_ctr := apa_w_ctr + 1)
    {
      declare apa_idx integer;
      declare apa any;
      apa_idx := m_apa_w [apa_w_ctr];
      apa := aref_set_0 (m_apa, apa_idx);

      if (6 = length (apa))
        {
          declare this_apa_id integer;
          declare arr, dta any;
	  if (position (prev_apa_id, apa[5]))
	    this_apa_id := prev_apa_id;
	  else
	    this_apa_id := apa[5][0];
	  arr := m_app[this_apa_id];
	  dta := arr [3];
	  return dta;
	}
    }
  return null;
}
;

create procedure DB.DBA.RDF_SPONGE_GET_COUNTRY_NAME (in code varchar)
{
  return (select RCC_NAME from DB.DBA.RDF_CARTRIDGES_COUNTRIES where RCC_CODE = code);
}
;

create procedure DB.DBA.RDF_SPONGE_DBP_IRI (in base varchar, in word varchar)
{
  declare res, xp, xt, url varchar;
  declare uri varchar;
  declare st int;
  declare dbp_iri any;

  declare exit handler for sqlstate '*' {
    return base || '#' || word;
  };

  uri := MOAT_APPLY (http_dav_uid (), word);
  if (uri is not null)
    {
      return uri;
    }

  if (word[0] >= 'a'[0] and word[0] <= 'z'[0])
    word[0] := word[0] - 32;
  word := replace (word, ' ', '_');
  url := sprintf ('http://dbpedia.org/resource/%U', word);
  dbp_iri := iri_to_id (url);
  st := (select CL_STAT from RDF_CARTRIDGES_LOOKUPS where CL_URI = dbp_iri);
  if (st = 1)
    return url;
  else if (st = 0)
    return base || '#' || word;

  uri := sprintf ('ask from <http://dbpedia.org> where { <%s> ?y ?z }', url);
  res := http_client (url=>sprintf ('http://dbpedia.org/sparql?query=%U&format=xml', uri), timeout=>30, proxy=>connection_get ('sparql-get:proxy'));
  xt := xtree_doc (res);
  xp := cast (xpath_eval('/sparql/boolean/text()', xt) as varchar);
  if (xp = 'true')
    {
      insert soft DB.DBA.RDF_CARTRIDGES_LOOKUPS (CL_URI, CL_STAT) values (dbp_iri, 1);
      return url;
    }
  insert soft DB.DBA.RDF_CARTRIDGES_LOOKUPS (CL_URI, CL_STAT) values (dbp_iri, 0);
  return base || '#' || word;
}
;

create procedure DB.DBA.RM_SAMEAS_IRI (in u varchar)
{
  return RDF_SPONGE_PROXY_IRI (u);
  --if (strchr (u, '#') is null)
  --  return u || '#this';
  --return u;
}
;

create procedure DB.DBA.RDF_MQL_RESOLVE_IMAGE (in name varchar)
{
  declare qr, url, cnt, tree, xt, hdr any;
  declare exit handler for sqlstate '*'
    {
      return '';
    };

  qr := sprintf ('{"ROOT":{"query":{"name":"%s", "type":"/common/image", "id":{}}}}', name);
  url := sprintf ('http://www.freebase.com/api/service/mqlread?queries=%U', qr);
  cnt := http_client_ext (url, headers=>hdr, proxy=>connection_get ('sparql-get:proxy'));
  tree := json_parse (cnt);
  tree := get_keyword ('ROOT', tree);
  tree := get_keyword ('result', tree);
  tree := get_keyword ('id', tree);
  tree := get_keyword ('value', tree);
  return 'http://www.freebase.com/api/trans/image_thumb'||tree;
}
;

create procedure DB.DBA.GET_XBRL_ONTOLOGY_DOMAIN(in elem varchar) returns varchar
{
    declare cur, domain varchar;
    cur := 'http://www.openlinksw.com/schemas/xbrl/' || elem;
    domain := (sparql select ?domain from <http://www.openlinksw.com/schemas/RDF_Mapper_Ontology/1.0/> where {`iri(?:cur)` rdfs:domain ?domain . } );
    if (domain is not null and domain <> '')
		return domain;
    return 'http://www.openlinksw.com/schemas/xbrl/item';
}
;

create procedure DB.DBA.GET_XBRL_ONTOLOGY_VALUE_NAME(in elem varchar) returns varchar
{
  declare cur, range, value, ret varchar;
  declare pos int;
  declare dict any;

  dict := connection_get ('xbrl-value-name');
  if (dict is null)
    {
      dict := dict_new (10);
      connection_set ('xbrl-value-name', dict);
    }
  cur := 'http://www.openlinksw.com/schemas/xbrl/' || elem;
  ret := dict_get (dict, cur);
  if (ret is not null)
    {
      return ret;
    }
  ret := 'value';
  value := (sparql select ?s from <http://www.openlinksw.com/schemas/RDF_Mapper_Ontology/1.0/>
  	where {`iri(?:cur)` rdfs:range ?range . ?s rdfs:domain ?range } );
  if (value is not null and value <> '')
    {
      pos := strrchr(value, '/');
      if (pos is null or pos = 0)
	ret := value;
      else
        {
          value := subseq(value, pos+1);
          ret := value;
	}
    }
  dict_put (dict, cur, ret);
  return ret;
}
;

create procedure DB.DBA.GET_XBRL_ONTOLOGY_VALUE_DATATYPE(in elem varchar) returns varchar
{
    declare cur, range, value, ret varchar;
    declare pos int;
    declare dict any;

    dict := connection_get ('xbrl-data-type');
    if (dict is null)
      {
	dict := dict_new (10);
	connection_set ('xbrl-data-type', dict);
      }

    cur := 'http://www.openlinksw.com/schemas/xbrl/' || elem;
    ret := dict_get (dict, cur);
    if (ret is not null)
      {
        return ret;
      }
    range := (sparql select ?range from <http://www.openlinksw.com/schemas/RDF_Mapper_Ontology/1.0/> where {`iri(?:cur)` rdfs:range ?range . } );
    ret := 'http://www.w3.org/2001/XMLSchema#string';
    if (range is not null and range <> '')
      {
	value := (sparql select ?range from <http://www.openlinksw.com/schemas/RDF_Mapper_Ontology/1.0/> where {?s rdfs:domain `iri(?:range)` . ?s rdfs:range ?range .});
	if (value is not null and value <> '')
	  {
	    ret := value;
	  }
	else
	  {
	    if (length(range) > 8)
	      {
		if (right(range, 8) = 'ItemType')
		  {
		    value := subseq(range, 0, length(range) - 8);
		    pos := strchr(value, '#');
		    if (pos > 0)
		      {
			value := subseq(value, pos + 1);
			if (value = 'textBlock')
			  ret := 'http://www.w3.org/2001/XMLSchema#string';
			else if (value = 'monetary')
			  ret := 'http://www.w3.org/2001/XMLSchema#decimal';
			else if (value = 'shares')
			  ret := 'http://www.w3.org/2001/XMLSchema#decimal';
			else if (value = 'pure')
			  ret := 'http://www.w3.org/2001/XMLSchema#decimal';
			else if (value = 'fraction')
			  ret := 'http://www.w3.org/2001/XMLSchema#integer';
			else if (value = 'domain')
			  ret := 'http://www.w3.org/2001/XMLSchema#string';
			else if (value = 'percent')
			  ret := 'http://www.w3.org/2001/XMLSchema#decimal';
			else if (value = 'perShare')
			  ret := 'http://www.w3.org/2001/XMLSchema#decimal';
			else
			  ret := concat('http://www.w3.org/2001/XMLSchema#', value);
		      }
		  }
	      }
	  }
      }
    dict_put (dict, cur, ret);
    return ret;
}
;

create procedure DB.DBA.GET_XBRL_CANONICAL_NAME(in elem varchar) returns varchar
{
    declare cur varchar;
    if (elem = 'schemaRef')
		return null;
    cur := 'http://www.openlinksw.com/schemas/xbrl/' || elem;
    if (exists (sparql ask from <http://www.openlinksw.com/schemas/RDF_Mapper_Ontology/1.0/> {`iri(?:cur)` a rdf:Property } ) )
    {
        return elem;
    }
    return null;
}
;

create procedure DB.DBA.GET_HTML5MD_LOCALNAME(in elem varchar) returns varchar
{
    declare pos1, pos2 integer;
    pos1 := strrchr(elem, '/');
    pos2 := strrchr(elem, '#');
    if (pos2 > 0)
        return subseq(elem, pos2+1);    
    if (pos1 > 0)
        return subseq(elem, pos1+1);    
}
;

create procedure DB.DBA.GET_HTML5MD_NAMESPACE(in elem varchar) returns varchar
{
    declare pos1, pos2 integer;
    pos1 := strrchr(elem, '/');
    pos2 := strrchr(elem, '#');
    if (pos2 > 0)
        return subseq(elem, 0, pos2+1);    
    if (pos1 > 0)
        return subseq(elem, 0, pos1+1);    
}
;

create procedure DB.DBA.GET_XBRL_CANONICAL_LABEL_NAME(in elem varchar) returns varchar
{
    declare cur, result varchar;
    declare i integer;
    cur := DB.DBA.GET_XBRL_CANONICAL_NAME(elem);
    cur := replace(cur, '_', ' ');
    if (cur is not null)
    {
       result := chr(cur[0]);
       for (i := 1; i < length(cur); i := i+1)
       {
           if  (chr(cur[i]) = upper(chr(cur[i])))
           {
               if (chr(cur[i - 1]) = upper(chr(cur[i - 1])) or chr(cur[i - 1]) = ' ')
                   result := concat(result, chr(cur[i]));
               else
               {
                   result := concat(result, ' ');
                   result := concat(result, chr(cur[i]));
               }
           }
           else
               result := concat(result, chr(cur[i]));
       }
        return result;
    }
    else
        return null;
}
;

EXEC_STMT('create table DB.DBA.XBRL_CIK_CACHE (XC_CIK varchar primary key, XC_NAME varchar not null, XC_URL varchar, XC_TS timestamp)', 0);
RM_UPGRADE_TBL ('DB.DBA.XBRL_CIK_CACHE', 'XC_URL', 'varchar');

create procedure DB.DBA.GET_XBRL_NAME_BY_CIK (in cik varchar)
{
  declare url, nam, ret, cnt, xt, xp varchar;
  declare exit handler for sqlstate '*'
    {
      return '';
    };
  whenever not found goto retr;
  set isolation='comitted';
  select XC_URL into ret from DB.DBA.XBRL_CIK_CACHE where XC_CIK = cik;
  if (ret is null)
    {
      delete from XBRL_CIK_CACHE where XC_CIK = cik;
      goto retr;
    }
  return ret;
  retr:
  url := sprintf ('http://www.rdfabout.com/sparql?query=%U',
  	sprintf ('select ?url ?name '||
	' where { <http://www.rdfabout.com/rdf/usgov/sec/id/cik%s> <http://www.w3.org/2002/07/owl#sameAs> ?url ; '||
	' <http://xmlns.com/foaf/0.1/name> ?name . }', cik));
  cnt := http_client (url, proxy=>connection_get ('sparql-get:proxy'));
  xt := xtree_doc (cnt);
  url := cast (xpath_eval ('string (//binding[@name="url"]/uri)', xt) as varchar);
  nam := cast (xpath_eval ('string (//binding[@name="name"]/literal)', xt) as varchar);
  if (not length (url))
    return '';
  insert into DB.DBA.XBRL_CIK_CACHE (XC_CIK, XC_NAME, XC_URL) values (cik, nam, url);
  return url;
}
;

create procedure DB.DBA.GET_XBRL_CANONICAL_DATATYPE(in elem varchar) returns varchar
{
    declare cur, datatype varchar;
    cur := 'http://www.openlinksw.com/schemas/xbrl/' || elem;
    datatype := (sparql prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> select ?range from <http://www.openlinksw.com/schemas/RDF_Mapper_Ontology/1.0/> {`iri(?:cur)` a rdf:Property; rdfs:range ?range } );
    datatype := subseq(datatype, strrchr(datatype, '#') + 1);
    datatype := subseq(datatype, 0, strstr(datatype, 'ItemType'));
    if (datatype = 'monetary' or datatype = 'perShare' or datatype = 'shares' or datatype = 'pure' or datatype = 'percent')
        datatype := 'decimal';
    else if (datatype is NULL or datatype = '' or datatype = 'domain' or datatype = 'textBlock' or datatype = 'fractionItemType')
		datatype := 'string';
    return datatype;
};

create procedure RDF_SPONGE_URI_HASH (in u varchar)
{
  if (u is null)
    return '';
  return tridgell32 (u, 1);
}
;

grant execute on DB.DBA.RDF_MQL_RESOLVE_IMAGE to public;
grant execute on DB.DBA.RM_UMBEL_GET to public;
grant execute on DB.DBA.XSLT_REGEXP_MATCH to public;
grant execute on DB.DBA.XSLT_SPLIT_AND_DECODE to public;
grant execute on DB.DBA.XSLT_UNIX2ISO_DATE to public;
grant execute on DB.DBA.XSLT_SHA1_HEX to public;
grant execute on DB.DBA.XSLT_REPLACE1 to public;
grant execute on DB.DBA.XSLT_STR2DATE to public;
grant execute on DB.DBA.XSLT_HTTP_STRING_DATE to public;
grant execute on DB.DBA.XSLT_STRING2ISO_DATE to public;
grant execute on DB.DBA.XSLT_STRING2ISO_DATE2 to public;
grant execute on DB.DBA.RDF_SPONGE_PROXY_IRI to public;
grant execute on DB.DBA.RDF_PROXY_ENTITY_IRI to public;
grant execute on DB.DBA.RM_SPONGE_DOC_IRI to public;
grant execute on DB.DBA.RDF_SPONGE_DBP_IRI to public;
grant execute on DB.DBA.RM_SAMEAS_IRI to public;
grant execute on DB.DBA.XSLT_ESCAPE to public;
grant execute on DB.DBA.GET_XBRL_ONTOLOGY_DOMAIN to public;
grant execute on DB.DBA.GET_XBRL_ONTOLOGY_VALUE_NAME to public;
grant execute on DB.DBA.GET_XBRL_ONTOLOGY_VALUE_DATATYPE to public;
grant execute on DB.DBA.GET_XBRL_CANONICAL_NAME to public;
grant execute on DB.DBA.GET_HTML5MD_LOCALNAME to public;
grant execute on DB.DBA.GET_HTML5MD_NAMESPACE to public;
grant execute on DB.DBA.GET_XBRL_CANONICAL_LABEL_NAME to public;
grant execute on DB.DBA.GET_XBRL_NAME_BY_CIK to public;
grant execute on DB.DBA.GET_XBRL_CANONICAL_DATATYPE to public;
grant execute on DB.DBA.RDF_SPONGE_URI_HASH to public;
grant execute on DB.DBA.RDF_SPONGE_GET_COUNTRY_NAME to public;

xpf_extension_remove ('http://www.openlinksw.com/virtuoso/xslt:getNameByCIK');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:xbrl_canonical_datatype', fix_identifier_case ('DB.DBA.GET_XBRL_CANONICAL_DATATYPE'));
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:getIRIbyCIK', fix_identifier_case ('DB.DBA.GET_XBRL_NAME_BY_CIK'));
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:xbrl_canonical_label_name', fix_identifier_case ('DB.DBA.GET_XBRL_CANONICAL_LABEL_NAME'));
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:xbrl_canonical_name', fix_identifier_case ('DB.DBA.GET_XBRL_CANONICAL_NAME'));
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:xbrl_canonical_value_datatype', fix_identifier_case ('DB.DBA.GET_XBRL_ONTOLOGY_VALUE_DATATYPE'));
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:xbrl_canonical_value_name', fix_identifier_case ('DB.DBA.GET_XBRL_ONTOLOGY_VALUE_NAME'));
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:xbrl_ontology_domain', fix_identifier_case ('DB.DBA.GET_XBRL_ONTOLOGY_DOMAIN'));
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:regexp-match', 'DB.DBA.XSLT_REGEXP_MATCH');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:split-and-decode', 'DB.DBA.XSLT_SPLIT_AND_DECODE');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:html5md_localname', 'DB.DBA.GET_HTML5MD_LOCALNAME');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:html5md_namespace', 'DB.DBA.GET_HTML5MD_NAMESPACE');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:unix2iso-date', 'DB.DBA.XSLT_UNIX2ISO_DATE');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:sha1_hex', 'DB.DBA.XSLT_SHA1_HEX');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:replace1', 'DB.DBA.XSLT_REPLACE1');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:str2date', 'DB.DBA.XSLT_STR2DATE');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:escape', 'DB.DBA.XSLT_ESCAPE');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:string2date', 'DB.DBA.XSLT_STRING2ISO_DATE');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:string2date2', 'DB.DBA.XSLT_STRING2ISO_DATE2');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:proxyIRI', 'DB.DBA.RDF_PROXY_ENTITY_IRI');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:docproxyIRI', 'DB.DBA.RDF_SPONGE_PROXY_IRI');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:dbpIRI', 'DB.DBA.RDF_SPONGE_DBP_IRI');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:getCountryName', 'DB.DBA.RDF_SPONGE_GET_COUNTRY_NAME');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:umbelGet', 'DB.DBA.RM_UMBEL_GET');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:mql-image-by-name', fix_identifier_case ('DB.DBA.RDF_MQL_RESOLVE_IMAGE'));
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:sasIRI', 'DB.DBA.RM_SAMEAS_IRI');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:docIRI', 'DB.DBA.RM_SPONGE_DOC_IRI');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:http_string_date', 'DB.DBA.XSLT_HTTP_STRING_DATE');
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:uri_hash', 'DB.DBA.RDF_SPONGE_URI_HASH');

create procedure DB.DBA.RDF_MAPPER_XSLT (in xslt varchar, inout xt any, in params any := null)
{
  set_user_id ('dba');
  if (params is null)
    return xslt (xslt, xt);
  else
    return xslt (xslt, xt, params);
};

create procedure DB.DBA.RDF_APERTURE_INIT ()
{
  if (__proc_exists ('java_vm_attach', 2) is null)
    {
      delete from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_BIN_DOCUMENT';
      return;
    }
  set_qualifier ('APERTURE');
  if (not udt_is_available ('APERTURE.DBA.MetaExtractor'))
  {
    declare exit handler for sqlstate '*'
    {
       set_qualifier ('DB');
       return;
    };
    DB.DBA.import_jar (NULL, 'MetaExtractor', 1);
  }
  exec (
'create procedure DB.DBA.RDF_LOAD_BIN_DOCUMENT (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, tmp, fn any;
--  if (graph_iri like \'%.odt\' or graph_iri like \'%.ods\')
--    return 0;
  tmp := null;
  declare exit handler for sqlstate \'*\'
    {
      if (length (tmp))
        file_delete (tmp, 1);
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  tmp := tmp_file_name (\'rdfm\', \'bin\');
  fn := tmp;
  string_to_file (tmp, _ret_body, -2);
  xd := APERTURE.DBA."MetaExtractor"().getMetaFromFile (fn, 5);
  xd := charset_recode(xd, \'_WIDE_\', \'UTF-8\');
  file_delete (tmp, 1);
  if (xd is null)
    return 0;
  xd := replace (xd, \'file:\'||tmp, new_origin_uri);
  xd := replace (xd, \'urn:uuid:\', new_origin_uri||\'/\');
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), \'urn:org.semanticdesktop.aperture\');
  return 1;
}');

  insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('application/.*',
    'MIME', 'DB.DBA.RDF_LOAD_BIN_DOCUMENT', null, 'Binary Files');
  update DB.DBA.SYS_RDF_MAPPERS set RM_ID = 1000 where RM_HOOK = 'DB.DBA.RDF_LOAD_BIN_DOCUMENT';
  set_qualifier ('DB');
}
;

RDF_APERTURE_INIT ()
;

-- cartridges

create procedure FB_SIG (in params any, in secret any)
{
  declare arr, pars, str any;
  arr := split_and_decode (params, 0, '\0\0&=');
  pars := vector ();
  for (declare i int, i := 0; i < length (arr); i := i + 2)
     {
       declare tmp any;
       tmp := split_and_decode (arr[i+1]);
       tmp := tmp[0];
       pars := vector_concat (pars, vector (arr[i]||'='||tmp));
     }
  pars := __vector_sort (pars);
  str := '';
  foreach (any elm in pars) do
    {
      str := str || elm;
    }
  str := str || secret;
  return md5 (str);
};

create procedure  DB.DBA.MQL_TREE_TO_XML_REC (in tree any, in tag varchar, inout ses any)
{
  if (not isarray (tree) or isstring (tree))
    {
      if (tree is not null and tree <> '')
	{
	  http_value (tree, tag, ses);
	}
    }
  else if (length (tree) > 1 and __tag (tree[0]) = 255)
    {
      http (sprintf ('<%U>', tag), ses);
      for (declare i,l int, i := 2, l := length (tree); i < l; i := i + 2)
         {
	   DB.DBA.MQL_TREE_TO_XML_REC (tree[i+1], tree[i], ses);
	 }
      http (sprintf ('</%U>', tag), ses);
    }
  else if (length (tree) > 0)
    {
      for (declare i,l int, i := 0, l := length (tree); i < l; i := i + 1)
         {
	   DB.DBA.MQL_TREE_TO_XML_REC (tree[i], tag, ses);
	 }
    }
}
;

create procedure  DB.DBA.MQL_TREE_TO_XML (in tree any)
{
  declare ses any;
  ses := string_output ();
  DB.DBA.MQL_TREE_TO_XML_REC (tree, 'results', ses);
  ses := string_output_string (ses);
  ses := xtree_doc (ses);
  return ses;
}
;

create procedure  DB.DBA.SOCIAL_TREE_TO_XML_REC	(in	tree any, in tag varchar, inout	ses	any)
{
 	tag := trim(tag, '\"');
	if (not isarray (tree) or	isstring (tree))
	{
                if (isstring (tree))
                    tree := trim(tree, '\"');
		if (left(tag,	7) = 'http://')
			tag	:= 'Site';
		http_value (tree, tag, ses);
	}
	else if (length (tree) > 1 and __tag (tree[0]) = 255)
	{
		if (left(tag,	7) = 'http://' or left(tag,	6) = 'ttp://' or left(tag, 7) = 'mailto:' or left(tag, 4) = 'sgn:')
		{
			http ('<Document>\n', ses);
			http_value (tag, 'about', ses);
		}
		else
		{
                    http (sprintf ('<%U>\n', tag), ses);
                }
		for (declare i,l int,	i := 2,	l := length	(tree);	i <	l; i :=	i +	2)
		{
			DB.DBA.SOCIAL_TREE_TO_XML_REC (tree[i+1], tree[i], ses);
		}
		if (left(tag,	7) = 'http://' or left(tag,	6) = 'ttp://' or left(tag, 7) = 'mailto:' or left(tag, 4) = 'sgn:')
			http ('</Document>\n',	ses);
		else
                {
			http (sprintf ('</%U>\n', tag),	ses);
                }
	}
	else if (length (tree) > 0)
	{
		for (declare i,l int,	i := 0,	l := length	(tree);	i <	l; i :=	i +	1)
		{
			DB.DBA.SOCIAL_TREE_TO_XML_REC (tree[i], tag,	ses);
		}
	}
}
;

create procedure  DB.DBA.SOCIAL_TREE_TO_XML (in tree any)
{
  declare ses any;
  ses := string_output ();
  DB.DBA.SOCIAL_TREE_TO_XML_REC (tree, 'results', ses);
  ses := string_output_string (ses);
  ses := xtree_doc (ses);
  return ses;
}
;

create procedure DB.DBA.RDF_LOAD_SALESFORCE(in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare hdr any;
	declare tree, xt, xd any;
	declare res, tmp, what_, name_, username_, password_, where_, file, id, type, sessionId, serverURL, fieldList, sObjectType varchar;
	hdr := null;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
    username_ := get_keyword ('username', opts);
	password_ := get_keyword ('password', opts); -- password = password+secret
	if (new_origin_uri like 'https://%.salesforce.com/%' or new_origin_uri like 'http://%.salesforce.com/%')
	{
		id := '';
		tmp := sprintf_inverse (new_origin_uri, 'https://%s.salesforce.com/%s', 0);
		if (length(tmp) > 1)
		id := trim (tmp[1], '/');
		if (id is null or id = '')
		{
			tmp := sprintf_inverse (new_origin_uri, 'http://%s.salesforce.com/%s', 0);
			if (length(tmp) > 1)
				id := trim (tmp[1], '/');
			else
				return 0;
		if (id is null)
			{
			return 0;
			}
		}
		res := xml_tree_doc(SOAP_CLIENT (
				url=>'https://www.salesforce.com/services/Soap/c/14.0',
				operation=>'login',
				parameters=>vector ('username', username_,
							'password', password_),
				target_namespace=>'urn:enterprise.soap.sforce.com',
				style=>21));
		sessionId := cast(xpath_eval('//sessionId/text()' , res ) as varchar);
		serverURL := cast(xpath_eval('//serverUrl/text()' , res ) as varchar);
		type := left(id, 3);
		if (type = '001')
		{
			fieldList := 'AccountNumber,
				AnnualRevenue,
				BillingCity,
				BillingCountry,
				BillingPostalCode,
				BillingState,
				BillingStreet,
				Description,
				Fax,
				Industry,
				LastActivityDate,
				Name,
				NumberOfEmployees,
				Ownership,
				Phone,
				Rating,
				ShippingCity,
				ShippingCountry,
				ShippingPostalCode,
				ShippingState,
				ShippingStreet,
				Sic,
				Site,
				TickerSymbol,
				Type,
				Website';
			sObjectType := 'Account';
		}
		else if (type = '701')
		{
			fieldList := 'ActualCost,
				AmountAllOpportunities,
				AmountWonOpportunities,
				BudgetedCost,
				Description,
				EndDate,
				ExpectedResponse,
				ExpectedRevenue,
				LastActivityDate,
				Name,
				NumberOfContacts,
				NumberOfConvertedLeads,
				NumberOfLeads,
				NumberOfOpportunities,
				NumberOfResponses,
				NumberOfWonOpportunities,
				NumberSent,
				StartDate,
				Status,
				Type';
			sObjectType := 'Campaign';
		}
		else if (type = '00Q')
		{
			fieldList := 'AnnualRevenue,
				City,
				Company,
				ConvertedDate,
				Country,
				Description,
				Email,
				EmailBouncedDate,
				EmailBouncedReason,
				Fax,
				FirstName,
				Industry,
				LastActivityDate,
				LastName,
				LeadSource,
				MobilePhone,
				Name,
				NumberOfEmployees,
				Phone,
				PostalCode,
				Rating,
				Salutation,
				State,
				Status,
				Street,
				Title,
				Website';
			sObjectType := 'Lead';
		}
		else if (type = '003')
		{
			fieldList := 'AssistantName,
				AssistantPhone,
				Birthdate,
				Department,
				Description,
				Email,
				EmailBouncedDate,
				EmailBouncedReason,
				Fax,
				FirstName,
				HomePhone,
				LastActivityDate,
				LastCURequestDate,
				LastCUUpdateDate,
				LastName,
				LeadSource,
				MailingCity,
				MailingState,
				MailingCountry,
				MailingPostalCode,
				MailingStreet,
				MobilePhone,
				Name,
				OtherCity,
				OtherCountry,
				OtherPostalCode,
				OtherState,
				OtherPhone,
				OtherStreet,
				Phone,
				Salutation,
				Title';
			sObjectType := 'Contact';
		}
		else if (type = '006')
		{
			fieldList := 'Amount,
				CloseDate,
				Description,
				ExpectedRevenue,
				Fiscal,
				FiscalQuarter,
				FiscalYear,
				ForecastCategory,
				ForecastCategoryName,
				LastActivityDate,
				LeadSource,
				Name,
				NextStep,
				Probability,
				StageName,
				TotalOpportunityQuantity,
				Type';
			sObjectType := 'Opportunity';
		}
		else if (type = '800')
		{
			fieldList := 'AssistantName,
				AssistantPhone,
				Birthdate,
				Department,
				Description,
				Email,
				EmailBouncedDate,
				EmailBouncedReason,
				Fax,
				FirstName,
				HomePhone,
				LastActivityDate,
				LastCURequestDate,
				LastCUUpdateDate,
				LastName,
				LeadSource,
				MailingCity,
				MailingState,
				MailingCountry,
				MailingPostalCode,
				MailingStreet,
				MobilePhone,
				Name,
				OtherCity,
				OtherCountry,
				OtherPostalCode,
				OtherState,
				OtherPhone,
				OtherStreet,
				Phone,
				Salutation,
				Title';
			sObjectType := 'Contact';
		}
		else if (type = '500')
		{
			fieldList := 'CaseNumber,
				ClosedDate,
				Description,
				Origin,
				Priority,
				Reason,
				Status,
				Subject,
				SuppliedCompany,
				SuppliedEmail,
				SuppliedName,
				SuppliedPhone,
				Type';
			sObjectType := 'Case';
		}
		else if (type = '501')
		{
			fieldList := 'SolutionName,
				SolutionNote,
				SolutionNumber,
				Status,
				TimesUsed';
			sObjectType := 'Solution';
		}
		else if (type = '01t')
		{
			fieldList := 'Description,
				Family,
				Name,
				ProductCode';
			sObjectType := 'Product2';
		}
		else if (type = '015')
		{
			fieldList := 'Body,
				BodyLength,
				ContentType,
				Description,
				DeveloperName,
				Keywords,
				Name,
				Type,
				URL';
			sObjectType := 'Document';
		}
		else
			return 0;
	}
	else
		return 0;
	xd := xml_tree_doc (SOAP_CLIENT (
		url=>serverUrl,
		operation=>'retrieve',
		headers=>vector (
			vector ('SessionHeader', '__XML__', 0),
			xtree_doc (concat (
				'<urn:SessionHeader xmlns:urn="urn:enterprise.soap.sforce.com">
					<urn:sessionId xmlns:urn="urn:enterprise.soap.sforce.com">',
						sessionId,
					'</urn:sessionId>
				</urn:SessionHeader>'))),
		parameters=>vector (
			'fieldList', fieldList,
			'sObjectType', sObjectType,
			'ids', id),
		target_namespace=>'urn:enterprise.soap.sforce.com',
		style=>21));
	delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/sf2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (new_origin_uri)));
	xd := serialize_to_UTF8_xml (xt);
        delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), 'https://www.salesforce.com/services/Soap/c/14.0');
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_TWITTER2(in url varchar, in id varchar, in new_origin_uri varchar,  in dest varchar, in graph_iri varchar, in username_ varchar, in password_ varchar, in what_ varchar, inout opts any) returns integer
{
	declare xt, xd any;
	declare tmp, test1, test2, test3 varchar;
	tmp := http_client (url, username_, password_, 'GET', proxy=>get_keyword_ucase ('get:proxy', opts));
	if (length(tmp) < 300)
		return 0;
	xd := xtree_doc (tmp);
	test1 := cast(xpath_eval('//user', xd) as varchar);
	test2 := cast(xpath_eval('//status', xd) as varchar);
	test3 := cast(xpath_eval('//feed', xd) as varchar);
	if (not (length(test1) or length(test2) or length(test3)))
		return 0;
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/twitter2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (new_origin_uri), 'id', id, 'what', what_));
	xd := serialize_to_UTF8_xml (xt);
        delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_TWITTER(in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xt, xd any;
	declare url, tmp varchar;
	declare id, post, username_, password_, what_ varchar;
	declare pos, page, res_count integer;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	what_ := '';
    username_ := get_keyword ('username', opts);
    password_ := get_keyword ('password', opts);
	res_count := atoi(get_keyword ('result_count', opts));
	if (res_count is null or res_count < 0 or res_count = 0)
		res_count := 5;

	if (new_origin_uri like 'http://search.twitter.com/search/thread/%')
	{
		url := concat(new_origin_uri, '.atom');
		delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
		what_ := 'thread2';
		DB.DBA.RDF_LOAD_TWITTER2(url, id, new_origin_uri, dest, graph_iri, username_, password_, what_, opts);
		return 1;
	}
	else if (new_origin_uri like 'http://search.twitter.com/search?q=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://search.twitter.com/search?q=%s', 0);
		post := trim(tmp[0], '/');
		if (post is null)
			return 0;
		url := sprintf('http://search.twitter.com/search.atom?q=%s', post);
		delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
		what_ := 'thread1';
		DB.DBA.RDF_LOAD_TWITTER2(url, id, new_origin_uri, dest, graph_iri, username_, password_, what_, opts);
		return 1;
	}
	else if (new_origin_uri like 'http://twitter.com/%/status/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://twitter.com/%s/status/%s', 0);
		id := tmp[0];
		post := trim(tmp[1], '/');
		if (id is null or post is null)
			return 0;

		delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);

		what_ := 'thread2';
		url := sprintf('http://search.twitter.com/search/thread/%s.atom', post);
		DB.DBA.RDF_LOAD_TWITTER2(url, id, new_origin_uri, dest, graph_iri, username_, password_, what_, opts);

		what_ := 'status';
		url := sprintf('http://twitter.com/statuses/show/%s.xml', post);
		DB.DBA.RDF_LOAD_TWITTER2(url, id, new_origin_uri, dest, graph_iri, username_, password_, what_, opts);

		return 1;
	}
	else if (new_origin_uri like 'http://twitter.com/%/statuses/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://twitter.com/%s/statuses/%s', 0);
		id := tmp[0];
		post := trim(tmp[1], '/');
		if (id is null or post is null)
			return 0;

		delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);

		what_ := 'thread2';
		url := sprintf('http://search.twitter.com/search/thread/%s.atom', post);
		DB.DBA.RDF_LOAD_TWITTER2(url, id, new_origin_uri, dest, graph_iri, username_, password_, what_, opts);

		what_ := 'status';
		url := sprintf('http://twitter.com/statuses/show/%s.xml', post);
		DB.DBA.RDF_LOAD_TWITTER2(url, id, new_origin_uri, dest, graph_iri, username_, password_, what_, opts);


		return 1;
	}
	else if (new_origin_uri like 'http://twitter.com/%/friends')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://twitter.com/%s/friends', 0);
		id := tmp[0];
		if (id is null)
		  return 0;
		goto friends_and_followers;
	}
	else if (new_origin_uri like 'http://twitter.com/%/followers')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://twitter.com/%s/followers', 0);
		id := tmp[0];
		if (id is null)
			return 0;
		goto friends_and_followers;
	}
	else if (new_origin_uri like 'http://twitter.com/%/favourites')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://twitter.com/%s/favourites', 0);
		id := tmp[0];
		if (id is null)
			return 0;
		goto friends_and_followers;
	}
	else if (new_origin_uri like 'http://twitter.com/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://twitter.com/%s', 0);
		id := trim(tmp[0], '/');
		if (id is null)
			return 0;
		pos := strchr(id, '/');
		if (pos is not null)
		{
			id := left(id, pos);
		}
		goto friends_and_followers;
	}
	else
		return 0;

	friends_and_followers: ;
	delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	page := 1;
	while (page > 0 and page < res_count)
	{
		url := sprintf('http://twitter.com/statuses/user_timeline.xml?id=%s&page=%d', id, page);
		if (DB.DBA.RDF_LOAD_TWITTER2(url, id, new_origin_uri, dest, graph_iri, username_, password_, what_, opts) = 0)
			goto statuses_out;
		page := page + 1;
	}
	statuses_out: ;

	page := 1;
	while (page > 0 and page < res_count)
	{
		what_ := 'friends';
		url := sprintf('http://twitter.com/statuses/friends.xml?id=%s&page=%d', id, page);
		if (DB.DBA.RDF_LOAD_TWITTER2(url, id, new_origin_uri, dest, graph_iri, username_, password_, what_, opts) = 0)
			goto friends_out;
		page := page + 1;
	}
	friends_out: ;

	page := 1;
	while (page > 0 and page < res_count)
	{
		url := sprintf('http://twitter.com/favorites.xml?id=%s&page=%d', id, page);
		if (DB.DBA.RDF_LOAD_TWITTER2(url, id, new_origin_uri, dest, graph_iri, username_, password_, what_, opts) = 0)
			goto favorites_out;
		page := page + 1;
	}
	favorites_out: ;

	page := 1;
	while (page > 0 and page < res_count)
	{
		what_ := 'followers';
		url := sprintf('http://twitter.com/statuses/followers.xml?id=%s&page=%d', id, page);
		if (DB.DBA.RDF_LOAD_TWITTER2(url, id, new_origin_uri, dest, graph_iri, username_, password_, what_, opts) = 0)
			goto followers_out;
		page := page + 1;
	}
	followers_out: ;

	what_ := 'user';
	url := sprintf('http://twitter.com/users/show/%s.xml', id);
	DB.DBA.RDF_LOAD_TWITTER2(url, id, new_origin_uri, dest, graph_iri, username_, password_, what_, opts);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_GETSATISFATION(in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare qr, path, hdr any;
	declare tree, xt, xd, types, is_search any;
	declare base, cnt, url, suffix, tmp, url_, what varchar;
	declare url_vec any;
	declare cur, len integer;
	declare what_, name_, where_, file, base_uri varchar;

	hdr := null;
	base_uri := new_origin_uri;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	if (new_origin_uri like 'http://getsatisfaction.com/%')
	{
		new_origin_uri := concat(new_origin_uri, '/');
		tmp := sprintf_inverse (new_origin_uri, 'http://getsatisfaction.com/%s', 0);
		url_ := trim (tmp[0], '/');
		if (url_ is null)
			return 0;
		url_vec := vector();
		len := length(url_);
		while (len > 0)
		{
			cur := strchr(url_, '/');
			if (cur is null or cur = 0)
			{
				what_ := url_;
				url_ := '';
			}
			else
			{
				what_ := subseq(url_, 0, cur);
				url_ := right(url_, len - cur);
				url_ := trim(url_ , '/');
			}
			len := length(url_);
			url_vec := vector_concat(url_vec, vector(what_));
		}
		len := length(url_vec);
		if (len > 0)
		{
			if (url_vec[0] <> 'people')
			{
				url := 'http://api.getsatisfaction.com/companies/';
				url := concat(url, url_vec[0]);
				if (len > 1)
				{
					if (url_vec[1] = 'overheard')
					{
						url := concat(url, '.json');
						what_ := 'company';
					}
					else
					{
						url := concat(url, '/', url_vec[1]);
						if (len > 2)
						{
							if (url_vec[1] = 'topics')
							{
								url := concat(url, '/', url_vec[2]);
								what_ := 'topics';
							}
							else if (url_vec[1] = 'products')
							{
								url := concat(url, '/', url_vec[2], '.json');
								what_ := 'product';
							}
							else
								return 0; -- TODO: add for people if exists
						}
						else
						{
							what_ := url_vec[1];
							url := concat(url, '.json');
						}
					}
				}
				else
				{
					what_ := 'topics';
					url := concat(url, '/topics');
				}
			}
			else
			{
				url := 'http://api.getsatisfaction.com/people/';
				url := concat(url, url_vec[1]);
				if (len > 2)
				{
					if (url_vec[2] = 'uses')
					{
						url := concat(url, '/companies.json');
						what_ := 'companies';
					}
					else
					{
						url := concat(url, '/products.json');
						what_ := 'products2';
					}
				}
				else
				{
					url := concat(url, '.json');
					what_ := 'people2';
				}
			}
		}
	}
	else
		return 0;
	tmp := http_client(url, proxy=>get_keyword_ucase ('get:proxy', opts));
	delete from DB.DBA.RDF_QUAD where g =  iri_to_id(base_uri);
	if (what_ = 'topics')
	{
		xd := xtree_doc (tmp);
		xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/atomdoc2rdf.xsl', xd,
			vector ('baseUri', RDF_SPONGE_DOC_IRI (base_uri), 'what', what_));
	}
	else
	{
		tree := json_parse (tmp);
		xt := DB.DBA.MQL_TREE_TO_XML (tree);
		xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/getsatisfaction2rdf.xsl', xt,
			vector ('baseUri', RDF_SPONGE_DOC_IRI (base_uri), 'what', what_));
	}
	xd := serialize_to_UTF8_xml (xt);
        delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, base_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_GOOGLEBASE (in graph_iri varchar, in new_origin_uri varchar, in dest varchar, inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, xt any;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
      return 0;
    };
  xd := xtree_doc (_ret_body);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/googlebase2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_CRUNCHBASE(in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare qr, path, hdr any;
  declare tree, xt, xd, types, is_search any;
  declare base, cnt, url, suffix varchar;

  hdr := null;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };

  is_search := 0;
  if (new_origin_uri like 'http://www.crunchbase.com/search?query=%')
    {
      url := 'http://api.crunchbase.com/v/1/search.js?query=' || subseq (new_origin_uri, 39);
      cnt := http_client_ext (url, 
      		headers=>hdr,
      		proxy=>get_keyword_ucase ('get:proxy', opts));
      base := 'http://www.crunchbase.com/';
      suffix := '';
      is_search := 1;
    }
  else if (new_origin_uri like 'http://www.crunchbase.com/%')
    {
      url := 'http://api.crunchbase.com/v/1/' || subseq (new_origin_uri, 26) || '.js';
      cnt := http_client_ext (url, 
      		headers=>hdr,
      		proxy=>get_keyword_ucase ('get:proxy', opts));
      base := 'http://www.crunchbase.com/';
      suffix := '';
    }
  else if (new_origin_uri like 'http://crunchbase.com/%')
    {
      url := 'http://api.crunchbase.com/v/1/' || subseq (new_origin_uri, 22) || '.js';
      cnt := http_client_ext (url, 
      		headers=>hdr,
      		proxy=>get_keyword_ucase ('get:proxy', opts));
      base := 'http://www.crunchbase.com/';
      suffix := '';
    }
  else
    {
      cnt := _ret_body;
      base := 'http://api.crunchbase.com/v/1/';
      url := base;
      suffix := '.js';
    }
  if (hdr is not null and hdr[0] not like 'HTTP/1._ 200 %')
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, hdr[0]);
      return 0;
    }
  if (new_origin_uri like 'http://api.crunchbase.com/v/1/search.js?query=%')
    is_search := 1;
  tree := json_parse (cnt);
  if (is_search)
    tree := get_keyword ('results', tree);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
  xt := DB.DBA.MQL_TREE_TO_XML (tree);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/crunchbase2rdf.xsl', xt,
	  vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'base', base, 'suffix', suffix));
  xd := serialize_to_UTF8_xml (xt);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
  return 1;
}
;

create procedure DB.DBA.RDF_MQL_GET_WIKI_URI (in kwd any)
{
  declare url, hdr any;
  declare olduri any;
  declare redirects, i, l int;

  hdr := null;
  redirects := 15;
  i := 0; l := length (kwd);
  for (; i < l; i := i+1)
  {
    if (i = 0 and kwd[i] > 96 and kwd[i] < 123)
      kwd[i] := kwd[i] - 32;
    else if (i > 0 and kwd[i-1] = '_'[0] and kwd[i] > 96 and kwd[i] < 123)
      kwd[i] := kwd[i] - 32;
  }
  url := 'http://wikipedia.org/wiki/'||kwd;

  again:
  olduri := url;
  if (redirects <= 0)
    return '';

  http_client_ext (url=>url, headers=>hdr, http_method=>'HEAD', proxy=>connection_get ('sparql-get:proxy'));
  redirects := redirects - 1;

  if (hdr[0] not like 'HTTP/1._ 200 %')
    {
      if (hdr[0] like 'HTTP/1._ 30_ %')
	{
	  url := http_request_header (hdr, 'Location');
	  if (isstring (url))
	    {
	      url := WS.WS.EXPAND_URL (olduri, url);
	      goto again;
	    }
	}
      return '';
    }
  return url;
}
;

create procedure DB.DBA.RM_ACCEPT ()
{
  return 'User-Agent: OpenLink Virtuoso RDF crawler\r\n'
  || 'Accept: application/rdf+xml; q=1.0,'
  || ' text/rdf+n3; q=0.9, application/rdf+turtle; q=0.7,'
  || ' application/x-turtle; q=0.6, application/turtle; q=0.5,'
  || ' application/xml; q=0.2, */*; q=0.1';
}
;

create procedure DB.DBA.RM_FREEBASE_DOC_LINK (in graph varchar, in doc varchar, in iri varchar, in sa varchar)
{
  declare ses, data, meta, state, message any;
  ses := string_output ();
  http ('@prefix foaf: <http://xmlns.com/foaf/0.1/> .\n', ses);
  http ('@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n', ses);
  http ('@prefix owl: <http://www.w3.org/2002/07/owl#> .\n', ses);
  -- we classify source as document and set primary topic
  http (sprintf ('<%s> a foaf:Document .\n', doc), ses);
  --http (sprintf ('<%s> foaf:primaryTopic <%s> .\n', doc, iri), ses);
  http (sprintf ('<%s> foaf:primaryTopic <%s> .\n', sa, iri), ses);
  state := '00000';
  -- if object is a person we also classify him as foaf:Person
  exec (sprintf ('sparql ask from <%s> where { <%s> a <http://rdf.freebase.com/ns/people.person> }', graph, iri),
     state, message, vector (), 0, meta, data);
  if (state = '00000' and length (data) > 0 and data[0][0] = 1)
    http (sprintf ('<%s> a foaf:Person .\n', iri), ses);
  TTLP (ses, doc, graph);
  return;
}
;

-- /* Freebase cartridge */
create procedure DB.DBA.RDF_LOAD_MQL (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare qr, path, hdr any;
  declare tree, xt, xd, types any;
  declare k, url, sa, lang, new_url, cnt, mime varchar;
  declare have_rdf, ord int;

  hdr := null;
  sa := '';
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };

  path := split_and_decode (new_origin_uri, 0, '%\0/');
  if (length (path) < 2)
    return 0;

  k := path [length(path) - 1];
  lang := path [length(path) - 2];
  have_rdf := 0;
  new_url := sprintf ('http://rdf.freebase.com/ns/%U/%U', lang, k);
  cnt := DB.DBA.RDF_HTTP_URL_GET (new_url, '', hdr, 'GET', RM_ACCEPT (), proxy=>get_keyword_ucase ('get:proxy', opts));
  -- /* check return mime type */
  mime := http_request_header (hdr, 'Content-Type', null, null);
  if (mime = 'application/rdf+xml')
    {
      sa := DB.DBA.RDF_MQL_GET_WIKI_URI (k);
      delete from DB.DBA.RDF_QUAD where g =  iri_to_id (coalesce (dest, graph_iri));
      -- cb-- As was
      --DB.DBA.RM_RDF_LOAD_RDFXML (cnt, new_origin_uri, coalesce (dest, graph_iri));

      -- cb++
      xt := xtree_doc(cnt);
      xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/mqlrdf2oplrdf.xsl', xt,
      	vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'wpUri', sa, 'ptIRI', sprintf ('http://rdf.freebase.com/ns/%U.%U', lang, k)));
      sa := '';
      xd := serialize_to_UTF8_xml (xt);
      DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
      -- ++cb

      DB.DBA.RM_FREEBASE_DOC_LINK (coalesce (dest, graph_iri), new_origin_uri, sprintf ('http://rdf.freebase.com/ns/%U.%U', lang, k), sa);
      DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), new_url);
      have_rdf := 1;
      goto done;
    }
  if (path [length(path) - 2] = 'guid')
    k := sprintf ('"id":"/guid/%s"', k);
  else
  {
    if (k like '#%')
        k := sprintf ('"id":"%s"', k);
    else
      {
	sa := DB.DBA.RDF_MQL_GET_WIKI_URI (k);
        k := sprintf ('"key":"%s"', k);
      }
  }
  qr := sprintf ('{"ROOT":{"query":[{%s, "type":[]}]}}', k);
  url := sprintf ('http://www.freebase.com/api/service/mqlread?queries=%U', qr);
  cnt := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
  tree := json_parse (cnt);
  xt := get_keyword ('ROOT', tree);
  if (not isarray (xt))
    return 0;
  xt := get_keyword ('result', xt);
  types := vector ();
  foreach (any tp in xt) do
    {
      declare tmp any;
      tmp := get_keyword ('type', tp);
      types := vector_concat (types, tmp);
    }
  --types := get_keyword ('type', xt);
  delete from DB.DBA.RDF_QUAD where g = iri_to_id (coalesce (dest, graph_iri));
  foreach (any tp in types) do
    {
      qr := sprintf ('{"ROOT":{"query":{%s, "type":"%s", "*":[]}}}', k, tp);
      url := sprintf ('http://www.freebase.com/api/service/mqlread?queries=%U', qr);
      cnt := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
      tree := json_parse (cnt);
      xt := get_keyword ('ROOT', tree);
      xt := DB.DBA.MQL_TREE_TO_XML (tree);
      xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/mql2rdf.xsl', xt,
      	vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'wpUri', sa));
      sa := '';
      xd := serialize_to_UTF8_xml (xt);
      delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
      DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
      DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
      have_rdf := 1;
    }
done:;
  -- /* see if other cartridges can process it, e.g. NYT */
  ord := (select RM_ID from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = upper (current_proc_name ()));
  if (exists (select 1 from DB.DBA.SYS_RDF_MAPPERS where RM_ID > ord and RM_TYPE = 'URL' and RM_ENABLED = 1 and
	regexp_match (RM_PATTERN, new_origin_uri) is not null))
    return 0;
  return 1;
}
;

create procedure FQL_CALL (in q varchar, in api_key varchar, in ses_id varchar, in secret varchar, inout opts any)
{
  declare url, pars, sig, ret varchar;
  url := 'http://api.facebook.com/restserver.php?';
  pars := 'method=facebook.fql.query&api_key='||api_key||'&v=1.0&session_key='||ses_id||'&call_id='|| cast (msec_time () as varchar) ||
   '&query=' || sprintf ('%U', q) ;
  sig := DB.DBA.FB_SIG (pars, secret);
  url := url || pars || '&sig=' || sig;
  ret := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
  return ret;
}
;

create procedure DB.DBA.RDF_LOAD_FQL (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare api_key, ses_id, secret varchar;
  declare ret, tmp, karr, xt, xd any;
  declare url, sig, pars, q, own, pid, aid, acc varchar;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };

  if (isarray (opts) = 0 or mod (length(opts), 2) <> 0)
    {
      return 0;
    }

  acc := get_keyword ('get:login', opts);
  api_key := null;
  if (acc is not null)
    {
      tmp := null;
      if (__proc_exists ('DB.DBA.WA_USER_GET_SVC_KEY') is not null)
	tmp := DB.DBA.WA_USER_GET_SVC_KEY (acc, 'FBKey');
      if (tmp is null)
	tmp := DB.DBA.USER_GET_OPTION (acc, 'FBKey');
      if (tmp is not null)
	{
	  tmp := replace (tmp, '\r', '\n');
	  tmp := replace (tmp, '\n\n', '\n');
	  tmp := rtrim (tmp, '\n');
	  tmp := split_and_decode (tmp, 0, '\0\0\n=');
	  api_key := get_keyword ('key', tmp);
	  secret := get_keyword ('secret', tmp);
	  ses_id := get_keyword ('session', tmp);
	}
    }
  if (0 = length (api_key))
    {
      api_key := _key;
      secret := get_keyword ('secret', opts);
      ses_id := get_keyword ('session', opts);
    }
  if (not length (api_key) or not length (secret) or not length (ses_id))
    return 0;

  own := ''; pid := '';
  if (acc is null)
    acc := '';

  tmp := sprintf_inverse (graph_iri, 'http://%s.facebook.com/album.php?aid=%s&l=%s&id=%s', 0);
  if (length (tmp) = 4)
    {
      own := tmp[3];
      aid := tmp[1];
    }
  else
    {
      tmp := sprintf_inverse (graph_iri, 'http://%s.facebook.com/album.php?aid=%s&id=%s', 0);
      if (length (tmp) <> 3)
	goto try_profile;
      own := tmp[2];
      aid := tmp[1];
    }

  q := sprintf ('SELECT pid, aid, owner, src_small, src_big, src, link, caption, created FROM photo '||
  'WHERE aid in (select aid from album where owner = %s and strpos (link, "aid=%s&") > 0)', own, aid);
  ret := DB.DBA.FQL_CALL (q, api_key, ses_id, secret, opts);
  xt := xtree_doc (ret);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/fql2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'login', acc));
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  q := sprintf ('SELECT aid, cover_pid, owner, name, created, modified, description, location, size, link FROM album '||
  'WHERE owner = %s and strpos (link, "aid=%s&") > 0', own, aid);
  ret := DB.DBA.FQL_CALL (q, api_key, ses_id, secret, opts);
  xt := xtree_doc (ret);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/fql2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'login', acc));
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  goto end_sp;

try_profile:
  tmp := sprintf_inverse (graph_iri, 'http://%s.facebook.com/%s/%s/%s', 0);
  if (length (tmp) <> 4)
    {
      tmp := sprintf_inverse (graph_iri, 'http://%s.facebook.com/profile.php?id=%s', 0);
      if (length (tmp) <> 1)
	return 0;
      own := tmp[1];
    }
  else
    own := tmp[3];
  q :=  sprintf ('SELECT uid, first_name, last_name, name, pic_small, pic_big, pic_square, pic, affiliations, profile_update_time, timezone, religion, birthday, sex, hometown_location, meeting_sex, meeting_for, relationship_status, significant_other_id, political, current_location, activities, interests, is_app_user, music, tv, movies, books, quotes, about_me, hs_info, education_history, work_history, notes_count, wall_count, status, has_added_app FROM user WHERE uid = %s', own);
  ret := DB.DBA.FQL_CALL (q, api_key, ses_id, secret, opts);
  xt := xtree_doc (ret);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/fql2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'login', acc));
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));

  q := sprintf ('SELECT aid, cover_pid, owner, name, created, modified, description, location, size, link FROM album '||
  'WHERE owner = %s', own);
  ret := DB.DBA.FQL_CALL (q, api_key, ses_id, secret, opts);
  xt := xtree_doc (ret);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/fql2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'login', acc));
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  q := sprintf ('select eid, name, tagline, nid, pic_small, pic_big, pic, host, description, event_type, event_subtype, '||
  ' start_time, end_time, creator, update_time, location, venue from event where eid in '||
  '(SELECT eid FROM event_member where uid = %s)', own);
  ret := DB.DBA.FQL_CALL (q, api_key, ses_id, secret, opts);
  xt := xtree_doc (ret);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/fql2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'login', acc));
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  q := sprintf ('SELECT uid, first_name, last_name, name, pic_small, pic_big, pic_square, pic, profile_update_time, timezone, religion, birthday, sex, current_location FROM user WHERE uid IN (select uid2 from friend where uid1 = %s)', own);
  ret := DB.DBA.FQL_CALL (q, api_key, ses_id, secret, opts);
  xt := xtree_doc (ret);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/fql2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'login', acc));
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  goto end_sp;
end_sp:
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), 'http://api.facebook.com/restserver.php');
  return 1;
};

create procedure DB.DBA.RDF_LOAD_FACEBOOK_OPENGRAPH_SELECTION (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
    declare qr, path any;
    declare tree, xt, xd, types, hdr any;
    declare k, cnt, url, tmp, mime varchar;
    declare pos, ord, ret integer;
    declare exit handler for sqlstate '*'
    {
        DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
        return 0;
    };
    url := concat('http://graph.facebook.com/?ids=', new_origin_uri);
    cnt := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
  	if (hdr[0] not like 'HTTP/1._ 200 %')
    {
        signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
        return 0;
    }
    tree := json_parse (cnt);
    if (tree is null)
        return 0;
    declare ses any;
    ses := string_output ();
    DB.DBA.SOCIAL_TREE_TO_XML_REC (tree, 'results', ses);
    ses := string_output_string (ses);
    xt := xtree_doc (ses, 2);
    xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/fb_ogs2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
    xd := serialize_to_UTF8_xml (xt);
    DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), 'http://graph.facebook.com/');
    mime := get_keyword ('content-type', opts);
    ord := (select RM_ID from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_FACEBOOK_OPENGRAPH_SELECTION');
    ret := 1;
    for select RM_PATTERN, RM_TYPE, RM_HOOK from DB.DBA.SYS_RDF_MAPPERS
      where RM_ID > ord and RM_TYPE in ('URL', 'MIME') and RM_ENABLED = 1 order by RM_ID do
	{
	  if (RM_TYPE = 'URL' and regexp_match (RM_PATTERN, new_origin_uri) is not null)
	    ret := 0;
          else if (RM_TYPE = 'MIME' and mime is not null and RM_HOOK <> 'DB.DBA.RDF_LOAD_DAV_META' and regexp_match (RM_PATTERN, mime) is not null)
            ret := 0;
	}
    return ret;
}
;

create procedure DB.DBA.RDF_LOAD_FACEBOOK_OPENGRAPH (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
    declare qr, path any;
    declare tree, xt, xd, types any;
    declare id, cnt, url, tmp, access_token, client_id, client_secret, code varchar;
    declare pos integer;
    declare exit handler for sqlstate '*'
    {
        DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
        return 0;
    };
    
    if (new_origin_uri like 'http://www.facebook.com/profile.php?id=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.facebook.com/profile.php?id=%s', 0);
        id := rtrim(tmp[0], '&/');
        pos := strchr(id, '&');
        if (pos > 0)
			id := left(id, pos);
		if (id is null)
			return 0;
	}
    else if (new_origin_uri like 'http://www.facebook.com/album.php?aid=%&id=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.facebook.com/album.php?aid=%s&id=%s', 0);
        id := rtrim(tmp[1], '&/');
        pos := strchr(id, '?');
        if (pos > 0)
			id := left(id, pos);
		if (id is null)
			return 0;
	}
    else if (new_origin_uri like 'http://www.facebook.com/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.facebook.com/%s', 0);
        id := rtrim(tmp[0], '&/');
        pos := strchr(id, '?');
        if (pos > 0)
			id := left(id, pos);
		if (id is null)
			return 0;
	}
    else
        return 0;
    url := sprintf ('https://graph.facebook.com/%s', id);
    cnt := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
    tree := json_parse (cnt);
    xt := DB.DBA.SOCIAL_TREE_TO_XML (tree);
    xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/fb_og2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
    xd := serialize_to_UTF8_xml (xt);
    DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
    return 0;
}
;

create procedure DB.DBA.RDF_LOAD_ZILLOW (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
    declare xd, xt, url, url2, tmp, api_key, full_address, address, citystatezip, zpid, hdr any;
    declare api_ret varchar;
	declare iAve, iDr, iLn, iPl, iRd, iSt, iUnit, iWay, cAddrFlds, iFld, sSearch any;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	api_key := _key;
	if (not isstring (api_key))
		return 0;

	if (new_origin_uri like 'http://www.zillow.com/homedetails/%/%')
		tmp := sprintf_inverse (new_origin_uri, 'http://www.zillow.com/homedetails/%s/%s', 0);
	else if (new_origin_uri like 'http://www.zillow.com/trk/ClkTrk.htm?link=\%2Fhomedetails\%2F%\%2F%')
		tmp := sprintf_inverse (new_origin_uri, 'http://www.zillow.com/trk/ClkTrk.htm?link=%%2Fhomedetails%%2F%s%%2F%s', 0);
    else
        return 0;

	zpid := subseq (tmp[1], 0, strstr(tmp[1], '_zpid'));
	full_address := replace(tmp[0], '-', '+');
	if (full_address is null)
		return 0;

	-- Not all addresses consist of 6 fields.
	-- A typical address might take the form:
	--   http://www.zillow.com/homedetails/500-Starview-Dr-Danville-CA-94526/18431449_zpid/
	-- Atypical examples are:
	--   http://www.zillow.com/homedetails/8354-11th-Ave-NW-UNIT-3-Seattle-WA-98117/2135796276_zpid/
	--   http://www.zillow.com/homedetails/6900-SE-33rd-St-Mercer-Island-WA-98040/49130677_zpid/
	cAddrFlds := 0;
	iFld := 0;
	sSearch := full_address;
	iFld := strchr (sSearch, '+');
	while (iFld is not null)
	{
		cAddrFlds := cAddrFlds + 1;
		sSearch := subseq (sSearch, iFld + 1);
		iFld := strchr (sSearch, '+');
	}

	if (cAddrFlds = 6)
	{
		tmp := sprintf_inverse (full_address, '%s+%s+%s+%s+%s+%s', 0);
		address := sprintf('%s+%s+%s', tmp[0], tmp[1], tmp[2]);
		citystatezip := sprintf('%s+%s+%s', tmp[3], tmp[4], tmp[5]);
	}
	else
	{
		-- Look for common delimiters separating the address & citystatezip components.
		iAve := strstr(full_address, 'Ave+');
		iDr := strstr(full_address, 'Dr+');
		iLn := strstr(full_address, 'Ln+');
		iPl := strstr(full_address, 'Pl+');
		iRd := strstr(full_address, 'Rd+');
		iSt := strstr(full_address, 'St+');
		iUnit := strcasestr(full_address, 'UNIT+');
		iWay := strstr(full_address, 'Way+');

		if (iUnit is not null)
		{
			iUnit := iUnit + 5;
			iUnit := iUnit + strchr(subseq(full_address, iUnit), '+');
			address := subseq (full_address, 0, iUnit);
			citystatezip := subseq (full_address, iUnit + 1);
		}
		else if (iAve is not null)
		{
			address := subseq (full_address, 0, iAve + 3);
			citystatezip := subseq (full_address, iAve + 4);
		}
		else if (iDr is not null)
		{
			address := subseq (full_address, 0, iDr + 2);
			citystatezip := subseq (full_address, iDr + 3);
		}
		else if (iLn is not null)
		{
			address := subseq (full_address, 0, iLn + 2);
			citystatezip := subseq (full_address, iLn + 3);
		}
		else if (iPl is not null)
		{
			address := subseq (full_address, 0, iPl + 2);
			citystatezip := subseq (full_address, iPl + 3);
		}
		else if (iRd is not null)
		{
			address := subseq (full_address, 0, iRd + 2);
			citystatezip := subseq (full_address, iRd + 3);
		}
		else if (iSt is not null)
		{
			address := subseq (full_address, 0, iSt + 2);
			citystatezip := subseq (full_address, iSt + 3);
		}
		else if (iWay is not null)
		{
			address := subseq (full_address, 0, iWay + 3);
			citystatezip := subseq (full_address, iWay + 4);
		}
		else
			return 0;
	}

	-- dbg_printf('address: %s', address);
	-- dbg_printf('citystatezip: %s', citystatezip);

	url := sprintf('http://www.zillow.com/webservice/GetDeepSearchResults.htm?zws-id=%s&address=%s&citystatezip=%s', api_key, address, citystatezip);
	url2 := sprintf('http://www.zillow.com/webservice/GetUpdatedPropertyDetails.htm?zws-id=%s&zpid=%s', api_key, zpid);

    tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
  	if (hdr[0] not like 'HTTP/1._ 200 %')
    	signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
    xd := xtree_doc (tmp);
	api_ret := cast(xpath_eval('//message/code', xd) as varchar);
	if (api_ret is null or api_ret <> '0')
		-- Possible cause could be we're handling an atypical address and didn't decode it correctly
	  	return 0;

    xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/zillow2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'currentDateTime', cast(date_iso8601(now()) as varchar) ));
    xd := serialize_to_UTF8_xml (xd);
    delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
    DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);

	-- GetUpdatedPropertyDetails often returns error code 501:
	--     "The updated data for the property you are requesting is not available due to legal restrictions"
	-- It looks like properties being sold by agents return this code, while properties being sold directly
	-- by the owner make the information available.

    tmp := http_client_ext (url2, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
  	if (hdr[0] not like 'HTTP/1._ 200 %')
    	signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
    xd := xtree_doc (tmp);
	api_ret := cast(xpath_eval('//message/code', xd) as varchar);
	if (api_ret is null or api_ret <> '0')
	  return 1;

    xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/zillow2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'currentDateTime', cast(date_iso8601(now()) as varchar) ));
    xd := serialize_to_UTF8_xml (xd);
    DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url2);

    return 1;
}
;

create procedure DB.DBA.RDF_LOAD_FRIENDFEED (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
    declare xd, xt, url, tmp, api_key, asin, hdr, exif any;
	asin := null;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	if (new_origin_uri like 'http://friendfeed.com/search?q=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://friendfeed.com/search?q=%s', 0);
		asin := rtrim (tmp[0], '/');
		if (asin is null)
			return 0;
		url := concat(new_origin_uri, '&format=atom');
	}
	else if (new_origin_uri like 'http://friendfeed.com/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://friendfeed.com/%s', 0);
		asin := rtrim (tmp[0], '/');
		if (strchr(tmp[0], '/') is not null)
			return 0;
		if (asin is null)
			return 0;
		url := sprintf('http://friendfeed.com/api/feed/user/%s?format=atom', asin);
	}
    else
        return 0;
    tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
    xd := xtree_doc (tmp);
    xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/atom2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
    delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
    xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/friendfeed2rdf.xsl', xt, vector ('baseUri', graph_iri, 'isDiscussion', 1));
    xd := serialize_to_UTF8_xml (xd);
    delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
    DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
    return 1;
}
;

create procedure DB.DBA.RDF_LOAD_TWFY (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, xt, url, tmp, api_key, asin, hdr, exif any;
	asin := null;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	api_key := _key;
	if (new_origin_uri like 'http://www.theyworkforyou.com/search/?s=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.theyworkforyou.com/search/?s=%s', 0);
		asin := rtrim (tmp[0], '/');
		if (asin is null)
			return 0;
		url := sprintf ('http://www.theyworkforyou.com/api/getHansard?search=%s&output=xml&key=%s',
			asin, api_key);
	}
        else if (new_origin_uri like 'http://www.theyworkforyou.com/mp/?pc=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.theyworkforyou.com/mp/?pc=%s', 0);
		asin := rtrim (tmp[0], '/');
		if (asin is null)
			return 0;
		url := sprintf ('http://www.theyworkforyou.com/api/getMP?postcode=%s&output=xml&key=%s',
			asin, api_key);
	}
	else if (new_origin_uri like 'http://www.theyworkforyou.com/mp/%/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.theyworkforyou.com/mp/%s/%s', 0);
		asin := trim (tmp[1], '/');
		if (asin is null)
			return 0;

		url := sprintf ('http://www.theyworkforyou.com/api/getMP?constituency=%s&output=xml&key=%s',
			asin, api_key);
	}
        else
            return 0;
   tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
  xd := xtree_doc (tmp);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/twfy2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_SLIDESIX (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
    declare xt, xd any;
    declare developer_key_, username_, password_, url, tmp, ses, query varchar;
    username_ := get_keyword ('username', opts);
    password_ := get_keyword ('password', opts);
    developer_key_ := get_keyword ('developerKey', opts);
    if (not isstring (username_) and isstring (password_) and isstring (developer_key_))
        return 0;        
    declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
            return 0;
    };
    url := sprintf ('http://slidesix.com/api/SlideSix.cfc?method=authenticateUser&APIKEY=%s&LOGINUSER=%s&LOGINPASSWORD=%s&RETURNTYPE=XML', developer_key_, username_, md5(password_));
    tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
    xd := xml_tree_doc(tmp);
    ses := cast(xpath_eval('/USER/REMOTESESSIONTOKEN', xd) as varchar);
    if (ses is null)
        return 0;
    if (new_origin_uri like 'http://slidesix.com/view/%')
    {
        tmp := sprintf_inverse (new_origin_uri, 'http://slidesix.com/view/%s', 0);
        query := tmp[0];
        if (query is null)
            return 0;
        url := sprintf ('http://slidesix.com/api/SlideSix.cfc?method=getSlideShows&APIKEY=%U&REMOTESESSIONTOKEN=%U&RETURNTYPE=XML&SEARCHSTRING=%U', developer_key_, ses, query);
    }
    else
        return 0;
    tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
    xd := xtree_doc (tmp);
    xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/slidesix2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
    xd := serialize_to_UTF8_xml (xt);
    delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
    DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
    return 1;
}
;

create procedure slideshare_hex_sha1_digest(in str varchar)
{
    declare res_str varchar;
    declare i integer;
    res_str:='';
    str:=decode_base64 (xenc_sha1_digest(str));
    for (i := 0; i < length (str); i := i + 1)
        res_str:=res_str||sprintf('%02x',str[i]);
    return res_str;
}
;

create procedure DB.DBA.RDF_LOAD_SLIDESHARE (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare qr, path, hdr any;
	declare test integer;
	declare tree, xt, xd, types, api_key, is_search, hash1 any;
	declare base, cnt, url, suffix, tmp, asin, SharedSecret, ApiKey, username, itemname  varchar;
	declare ts, query varchar;
	hdr := null;
	ApiKey := _key;
	SharedSecret := null;
	if (isarray (opts) and 0 = mod (length(opts), 2))
	  {
	    SharedSecret := get_keyword ('SharedSecret', opts);
	  }
	if ((0 = length (ApiKey)) or (0 = length (SharedSecret)))
	  return 0;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	ts :=  cast(datediff ('second', stringdate ('1970-1-1'), now ()) as varchar);
	hash1 := slideshare_hex_sha1_digest(concat(SharedSecret, ts));
	if (new_origin_uri like 'http://www.slideshare.net/search/slideshow?q=%&%' or
		new_origin_uri like 'http://www.slideshare.net/search/slideshow?%&q=%&%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.slideshare.net/search/slideshow?q=%s&%s', 0);
		query := tmp[0];
		if (query is null)
		{
			tmp := sprintf_inverse (new_origin_uri, 'http://www.slideshare.net/search/slideshow?%sq=%s&%s', 0);
			query := tmp[1];
			if (query is null)
				return 0;
		}
		url := sprintf ('http://www.slideshare.net/api/1/search_slideshows?api_key=%U&ts=%U&hash=%U&q=%U', ApiKey, ts, hash1, query);
	}
	else if (new_origin_uri like 'http://www.slideshare.net/search/slideshow?q=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.slideshare.net/search/slideshow?q=%s', 0);
		query := tmp[0];
		if (query is null)
			return 0;
		url := sprintf ('http://www.slideshare.net/api/1/search_slideshows?api_key=%U&ts=%U&hash=%U&q=%U', ApiKey, ts, hash1, query);
	}
	else if (new_origin_uri like 'http://www.slideshare.net/tag/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.slideshare.net/tag/%s', 0);
		query := tmp[0];
		if (query is null)
			return 0;
		url := sprintf ('http://www.slideshare.net/api/1/get_slideshow_by_tag?api_key=%U&ts=%U&hash=%U&tag=%U', ApiKey, ts, hash1, query);
	}
	else if (new_origin_uri like 'http://www.slideshare.net/group/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.slideshare.net/group/%s', 0);
		query := tmp[0];
		if (query is null)
			return 0;
		url := sprintf ('http://www.slideshare.net/api/1/get_slideshow_by_group?api_key=%U&ts=%U&hash=%U&group_name=%U', ApiKey, ts, hash1, query);
	}
	else if (new_origin_uri like 'http://www.slideshare.net/%/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.slideshare.net/%s/%s', 0);
		username := trim(tmp[0], '/');
		if (username = 'event')
			return 0;
		itemname := trim(tmp[1], '/');
		if (strchr(itemname, '?') is not null)
			itemname := left(new_origin_uri, strchr(new_origin_uri, '?'));
		else
			itemname := new_origin_uri;
		if (username is null)
			return 0;
		url := sprintf ('http://www.slideshare.net/api/1/get_slideshow_info?api_key=%U&ts=%U&hash=%U&slideshow_url=%U', ApiKey, ts, hash1, itemname);
	}
	else if (new_origin_uri like 'http://www.slideshare.net/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.slideshare.net/%s', 0);
		query := tmp[0];
		if (query is null)
			return 0;
		url := sprintf ('http://www.slideshare.net/api/1/get_slideshow_by_user?api_key=%U&ts=%U&hash=%U&username_for=%U', ApiKey, ts, hash1, query);
	}
	else
		return 0;
	tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/slideshare2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
	xd := serialize_to_UTF8_xml (xt);
	delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_DISQUS (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare qr, path, hdr any;
	declare test integer;
	declare tree, xt, xd, types, api_key, is_search any;
	declare base, cnt, url, suffix, tmp, asin varchar;
	hdr := null;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	if (new_origin_uri like 'http://disqus.com/people/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://disqus.com/people/%s', 0);
		asin := tmp[0];
		if (asin is null)
			return 0;
		asin := trim(asin, '/');
		test := strchr(asin, '/');
		if (test is not NULL)
			asin := subseq(asin, 0, test);
		url := sprintf ('http://disqus.com/people/%s/comments.rss', asin);
	}
	else if (new_origin_uri like 'http://%.disqus.com/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://%s.disqus.com/%s', 0);
		asin := tmp[0];
		if (asin is null)
			return 0;
		url := sprintf ('http://%s.disqus.com/comments.rss', asin);
	}
	else
		return 0;
	tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/rss2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
	xd := serialize_to_UTF8_xml (xt);
	delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	--DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RDF_LOAD_FEED_SIOC (xd, new_origin_uri, coalesce (dest, graph_iri), 1);
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure get_url2(in url varchar) returns varchar
{
  declare hdr any;
  declare olduri any;
  declare redirects, i, l int;

  hdr := null;
  redirects := 15;

  again:
  olduri := url;
  if (redirects <= 0)
    return '';

  http_client_ext (url=>url, headers=>hdr, http_method=>'HEAD', proxy=>connection_get ('sparql-get:proxy'));
  redirects := redirects - 1;

  if (hdr[0] not like 'HTTP/1._ 200 %')
    {
      if (hdr[0] like 'HTTP/1._ 30_ %')
	{
	  url := http_request_header (hdr, 'Location');
	  if (isstring (url))
	    {
	      url := WS.WS.EXPAND_URL (olduri, url);
	      goto again;
	    }
	}
      return '';
    }
  return url;
}
;

create procedure DB.DBA.RDF_LOAD_RHAPSODY (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
    declare xd, xt, url, tmp, id, id2, indicators any;
    declare pos int;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	if (new_origin_uri like 'http://www.rhapsody.com/goto?%&variant=data')
	{
		url := new_origin_uri;
	}
	else if (new_origin_uri like 'http://www.rhapsody.com/goto?rcid=%')
	{
		if (new_origin_uri like 'http://www.rhapsody.com/goto?rcid=%&%')
		{
			tmp := sprintf_inverse (new_origin_uri, 'http://www.rhapsody.com/goto?rcid=%s&%s', 0);
			id := trim (tmp[0], '/');
			url := get_url2(sprintf('http://www.rhapsody.com/goto?rcid=%s', id)) || '/data.xml';
		}
		else
		{
			tmp := sprintf_inverse (new_origin_uri, 'http://www.rhapsody.com/goto?rcid=%s', 0);
			id := trim (tmp[0], '/');
			if (left(id, 3) = 'tra')
				url := 'http://feeds.rhapsody.com/track-data.xml?trackId=' || id;
			else
				url := get_url2(new_origin_uri) || '/data.xml';
		}
	}
	else if (new_origin_uri like 'http://www.rhapsody.com/%')
	{
		url := get_url2(new_origin_uri) || '/data.xml';
	}
	else
		return 0;
	delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/rhapsody2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
	xd := serialize_to_UTF8_xml (xt);
        delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_TESCO (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
    declare xd, xt, tmp, id, ses, hdr, tree any;
    declare email_, password_, developer_key_, application_key_, session_key_, url varchar;
    declare exit handler for sqlstate '*'
      {
	DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
	return 0;
      };
    email_ := get_keyword ('email', opts);
    password_ := get_keyword ('password', opts);
    developer_key_ := get_keyword ('developerKey', opts);
    application_key_ := get_keyword ('applicationKey', opts);
    
    if (not isstring (email_) and isstring (password_) and isstring (developer_key_) and isstring (application_key_))
      return 0;
    
    url := sprintf('https://secure.techfortesco.com/groceryapi_b1/restservice.aspx?command=LOGIN&email=%s&password=%s&developerkey=%s&applicationkey=%s', email_, password_, developer_key_, application_key_);
  	tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
	if (hdr[0] not like 'HTTP/1._ 200 %')
		signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
    tree := json_parse (tmp);
    session_key_ := get_keyword ('SessionKey', tree);
    if (session_key_ is null or length(session_key_) = 0)
        return 0;
    if (new_origin_uri like 'http://%tesco.com/%?prodId=%')
      {
        tmp := sprintf_inverse (new_origin_uri, 'http://%stesco.com/%s?prodId=%s', 0);
        id := tmp[2];
      }
    else if (new_origin_uri like 'http://www.tesco.com/superstore/xpi/%/xpi%.htm')
      {
	tmp := sprintf_inverse (new_origin_uri, 'http://www.tesco.com/superstore/xpi/%s/xpi%s.htm', 0);
	id := tmp[1];
      }
    else if (new_origin_uri like 'http://www.tesco.com/%?id=%')
    {
        tmp := sprintf_inverse (new_origin_uri, 'http://www.tesco.com/%s?id=%s', 0);
        id := tmp[1];
    }
    else
      return 0;
    url := sprintf('http://www.techfortesco.com/groceryapi_b1/restservice.aspx?command=PRODUCTSEARCH&searchtext=%s&page=1&sessionkey=%s', id, session_key_);
    tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
	if (hdr[0] not like 'HTTP/1._ 200 %')
	{
		signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
		return 0;
	}
    tree := json_parse (tmp);
    xt := DB.DBA.SOCIAL_TREE_TO_XML (tree);
    xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/tesco2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
    xd := serialize_to_UTF8_xml (xt);
    delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
    DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
    return 1;
}
;

create procedure DB.DBA.RDF_LOAD_IDIOMAG (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
    declare xd, xt, urls, url, tmp, id, id2, indicators any;
    declare pos, i, l int;
    declare exit handler for sqlstate '*'
    {
		DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
		return 0;
    };
    urls := vector();
    if (new_origin_uri like 'http://www.idiomag.com/artist/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.idiomag.com/artist/%s/%s', 0);
		if (tmp is null)
			tmp := sprintf_inverse (new_origin_uri, 'http://www.idiomag.com/artist/%s', 0);
		id := trim (tmp[0], '/');
		id := trim (id, '#');
		id := replace (id, '_', '+');
		if (id is null)
			return 0;
		url := sprintf ('http://www.idiomag.com/api/artist/info/xml?key=%s&artist=%s', _key, id);
		urls := vector_concat(urls, vector(url));
		url := sprintf ('http://www.idiomag.com/api/artist/playlist/xml?key=%s&artist=%s', _key, id);
		urls := vector_concat(urls, vector(url));
		url := sprintf ('http://www.idiomag.com/api/artist/photos/xml?key=%s&artist=%s', _key, id);
		urls := vector_concat(urls, vector(url));
		url := sprintf ('http://www.idiomag.com/api/artist/videos/xml?key=%s&artist=%s', _key, id);
		urls := vector_concat(urls, vector(url));
		url := sprintf ('http://www.idiomag.com/api/artist/articles/xml?key=%s&artist=%s', _key, id);
		urls := vector_concat(urls, vector(url));
	}
	else if (new_origin_uri like 'http://www.idiomag.com/user/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.idiomag.com/user/%s/%s', 0);
		id := trim (tmp[0], '#');
		id := replace (id, '_', '+');
		if (id is null)
			return 0;
		url := sprintf ('http://www.idiomag.com/api/artist/info/xml?key=%s&artist=%s', _key, id);
	}
	else
	  return 0;

    delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	for (i := 0, l := length (urls); i < l; i := i + 1)
	{
		url := urls[i];
		tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
		xd := xtree_doc (tmp);
		xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/idiomag2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
		xd := serialize_to_UTF8_xml (xt);
		DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
		DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	}
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_RADIOPOP (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
    declare xd, xt, url, tmp, id, id2, indicators any;
    declare pos int;
    declare exit handler for sqlstate '*'
      {
	DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
	return 0;
      };
    if (new_origin_uri like 'http://www.radiopop.co.uk/users/%')
      {
	tmp := sprintf_inverse (new_origin_uri, 'http://www.radiopop.co.uk/users/%s', 0);
	id := trim (tmp[0], '/');
	id2 := null;
	if (id is null)
	  return 0;
	pos := strchr(id, '/');
	if (pos is not null)
	  {
	    id2 := subseq(id, pos + 1);
	    id := left(id, pos);
	  }
	if (id2 is not null)
	  {
	    pos := strchr(id2, '/');
	    if (pos is not null)
	      {
		id2 := left(id2, pos);
	      }
	  }
	if (id2 is null or id2 = '')
	  {
	    url := sprintf ('http://www.radiopop.co.uk/users/%s.xml', id);
	  }
	else if (id2 = 'friends')
	  {
	    url := sprintf ('http://www.radiopop.co.uk/users/%s/friends.xml', id);
	  }
	else if (id2 = 'listens')
	  {
	    url := sprintf ('http://www.radiopop.co.uk/users/%s/listens.xml', id);
	  }
	else if (id2 = 'pops')
	  {
	    url := sprintf ('http://www.radiopop.co.uk/users/%s/pops.xml', id);
	  }
	else
	  return 0;
	delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/radiopop2rdf.xsl', xd,
		vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'user', id ));
	xd := serialize_to_UTF8_xml (xt);
        delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
      }
    else
      return 0;
}
;

create procedure DB.DBA.RDF_LOAD_DISCOGS (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
    declare xd, xt, url, tmp, api_key, asin, hdr, exif any;
    declare pos integer;
    asin := null;
    declare exit handler for sqlstate '*'
      {
	DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
	return 0;
      };
    api_key := _key;
    if (new_origin_uri like 'http://www.discogs.com/artist/%')
      {
	tmp := sprintf_inverse (new_origin_uri, 'http://www.discogs.com/artist/%s', 0);
	asin := rtrim (tmp[0], '/');
	if (asin is null)
	  return 0;
	pos := strchr(asin, '?');
	if (pos is not null)
	  {
	    asin := left(asin, pos);
	  }
	url := sprintf ('http://www.discogs.com/artist/%s?f=xml&api_key=%s', asin, api_key);
      }
    else if (new_origin_uri like 'http://www.discogs.com/release/%')
      {
	tmp := sprintf_inverse (new_origin_uri, 'http://www.discogs.com/release/%s', 0);
	asin := rtrim (tmp[0], '/');
	if (asin is null)
	  return 0;
	  pos := strchr(asin, '?');
	if (pos is not null)
	  {
	    asin := left(asin, pos);
	  }
	url := sprintf ('http://www.discogs.com/release/%s?f=xml&api_key=%s', asin, api_key);
      }
    else if (new_origin_uri like 'http://www.discogs.com/search?ev=hs&q=%&btn=Search')
      {
	tmp := sprintf_inverse (new_origin_uri, 'http://www.discogs.com/search?ev=hs&q=%s&btn=Search', 0);
	asin := rtrim (tmp[0], '/');
	if (asin is null)
	  return 0;
	pos := strchr(asin, '?');
	if (pos is not null)
	  {
	    asin := left(asin, pos);
	  }
	url := sprintf ('http://www.discogs.com/search?type=all&q=%s&f=xml&api_key=%s', asin, api_key);
      }
    else
      return 0;
    -- we keep http_get here because it uses explicit gunzip
    tmp := http_get (url, null, 'GET', 'Accept-Encoding: gzip', null, proxy=>get_keyword_ucase ('get:proxy', opts));
    xd := xtree_doc (tmp);
    xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/discogs2rdf.xsl', xd,
    	vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
    xd := serialize_to_UTF8_xml (xt);
    delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
    DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
    return 1;
}
;

create procedure DB.DBA.RDF_LOAD_LIBRARYTHING (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, xt, url, tmp, api_key, id any;
  id := null;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  api_key := _key;
  if (not isstring (api_key))
    return 0;
  if (new_origin_uri like 'http://www.librarything.com/author/%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://www.librarything.com/author/%s', 0);
      id := trim (tmp[0], '/');
      if (id is null)
	return 0;
      if (atoi(id) > 0)
	url := sprintf ('http://www.librarything.com/services/rest/1.0/?method=librarything.ck.getauthor&id=%s&apikey=%s', id, api_key);
      else
	url := sprintf ('http://www.librarything.com/services/rest/1.0/?method=librarything.ck.getauthor&authorcode=%s&apikey=%s', id, api_key);
    }
  else if (new_origin_uri like 'http://www.librarything.com/work/%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://www.librarything.com/work/%s', 0);
      id := trim (tmp[0], '/');
      if (id is null)
	return 0;
      url := sprintf ('http://www.librarything.com/services/rest/1.0/?method=librarything.ck.getwork&id=%s&apikey=%s', id, api_key);
    }
  else
    {
      return 0;
    }
  tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
  xd := xtree_doc (tmp);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/lt2rdf.xsl', xd,
  	vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_ISBN (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xd, xt, url, tmp, api_key, asin, hdr, exif, books any;
	declare is_book integer;
	asin := null;
	is_book := 0;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	api_key := _key;
	if (not isstring (api_key))
		return 0;
	if (new_origin_uri like 'http%://%isbndb.com/d/subject/index.html?kw=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http%s://%sisbndb.com/d/subject/index.html?kw=%s', 0);
		asin := rtrim (tmp[2], '/');
		if (asin is null)
			return 0;
		url := sprintf ('http://isbndb.com/api/subjects.xml?access_key=%s&index1=name&value1=%s',
			api_key, asin);
	}
	else if (new_origin_uri like 'http%://%isbndb.com/d/book/%.html')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http%s://%sisbndb.com/d/book/%s.html', 0);
		asin := tmp[2];
		if (asin is null)
		  return 0;
		url := sprintf ('http://isbndb.com/api/books.xml?access_key=%s&index1=book_id&value1=%s',
			api_key, asin);
	}
	else if (new_origin_uri like 'http%://%isbndb.com/search-all.html?kw=%&%')
	{
		is_book := 1;
		tmp := sprintf_inverse (new_origin_uri, 'http%s://%sisbndb.com/search-all.html?kw=%s&%s', 0);
		asin := rtrim (tmp[2], '/');
		if (asin is null)
			return 0;
		url := sprintf ('http://isbndb.com/api/books.xml?access_key=%s&index1=title&value1=%s',
			api_key, asin);
	}
	else if (new_origin_uri like 'http%://%isbndb.com/search-all.html?kw=%')
	{
		is_book := 1;
		tmp := sprintf_inverse (new_origin_uri, 'http%s://%sisbndb.com/search-all.html?kw=%s', 0);
		asin := rtrim (tmp[2], '/');
		if (asin is null)
			return 0;
		url := sprintf ('http://isbndb.com/api/books.xml?access_key=%s&index1=title&value1=%s',
			api_key, asin);
	}
	else if (new_origin_uri like 'http%://%isbndb.com/d/book/index.html?kw=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http%s://%sisbndb.com/d/book/index.html?kw=%s', 0);
		asin := rtrim (tmp[2], '/');
		if (asin is null)
			return 0;
		url := sprintf ('http://isbndb.com/api/books.xml?access_key=%s&index1=title&value1=%s', api_key, asin);
		is_book := 1;
	}
	else if (new_origin_uri like 'http%://%isbndb.com/authors/search.html?kw=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http%s://%sisbndb.com/authors/search.html?kw=%s', 0);
		asin := rtrim (tmp[2], '/');
		if (asin is null)
			return 0;
		url := sprintf ('http://isbndb.com/api/authors.xml?access_key=%s&index1=name&value1=%s',
			api_key, asin);
	}
        else if (new_origin_uri like 'http%://%isbndb.com/c/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http%s://%sisbndb.com/c/%s', 0);
		asin := trim (tmp[2], '/');
		if (asin is null)
			return 0;
		url := sprintf ('http://isbndb.com/api/categories.xml?access_key=%s&index1=name&value1=%s',
			api_key, asin);
	}
        else if (new_origin_uri like 'http%://%isbndb.com/publishers/search.html?kw=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http%s://%sisbndb.com/publishers/search.html?kw=%s', 0);
		asin := trim (tmp[2], '/');
		if (asin is null)
			return 0;
		url := sprintf ('http://isbndb.com/api/publishers.xml?access_key=%s&index1=name&value1=%s',
			api_key, asin);
	}
	else
	{
		return 0;
	}
	tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
	if (hdr[0] not like 'HTTP/1._ 200 %')
		signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
	xd := xtree_doc (tmp);
	books := xpath_eval('//BookData', xd);
	if (is_book = 1 and books is null)
	{
		url := sprintf ('http://isbndb.com/api/books.xml?access_key=%s&index1=isbn&value1=%s', api_key, asin);
		tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
		if (hdr[0] not like 'HTTP/1._ 200 %')
			signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
		xd := xtree_doc (tmp);
	}
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/isbn2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
	xd := serialize_to_UTF8_xml (xt);
        delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_MEETUP2(in url varchar, in new_origin_uri varchar,  in dest varchar, in graph_iri varchar, in what_ varchar, in base varchar, inout opts any) returns integer
{
	declare xt, xd, hdr any;
	declare tmp, test1, test2 varchar;

	hdr := null;
	tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
	if (not length (hdr) or hdr[0] not like 'HTTP/1._ 200 %')
	  {
	    DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, 'API call failed:' || hdr[0]);
	    return 0;
	  }
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/meetup2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'base', base, 'what', what_ ));
	xd := serialize_to_UTF8_xml (xt);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_MEETUP (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar, inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, xt, url, tmp, api_key, hdr, id0, id1, id2, id3, id4, id5, id6 any;
  declare pos, len int;
  declare xsl2, what_, base varchar;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  api_key := _key;
  base := concat(trim(new_origin_uri, '/'), '/');
  if (new_origin_uri like 'http://%.meetup.com/%')
  {
    tmp := sprintf_inverse (new_origin_uri, 'http://%s.meetup.com/%s/%s/%s/%s/%s', 0);
    if (tmp is null)
      tmp := sprintf_inverse (new_origin_uri, 'http://%s.meetup.com/%s/%s/%s/%s', 0);
    if (tmp is null)
      tmp := sprintf_inverse (new_origin_uri, 'http://%s.meetup.com/%s/%s/%s', 0);
    if (tmp is null)
      tmp := sprintf_inverse (new_origin_uri, 'http://%s.meetup.com/%s/%s', 0);
    if (tmp is null)
      tmp := sprintf_inverse (new_origin_uri, 'http://%s.meetup.com/%s', 0);
    len := length(tmp);
    if (len > 5)
      id5 := tmp[5];
    if (len > 4)
      id4 := tmp[4];
    if (len > 3)
      id3 := tmp[3];
    if (len > 2)
      id2 := tmp[2];
    if (len > 1)
      id1 := tmp[1];
    if (len > 0)
      id0 := tmp[0];
    if (id0 is null or (id0 = 'www' and id1 is null))
      return 0;
    delete from DB.DBA.RDF_QUAD where g =  iri_to_id (coalesce (dest, graph_iri));
    if (id0 = 'www')
      {
	if (id1 = 'cities')
	  {
	    if (id2 is not null)
	      {
		url := concat('http://api.meetup.com/groups.xml/?country=', id2);
		if (id3 is not null and id4 is not null)
		  {
		    url := concat(url, '&state=', id3);
		    if (id4 is not null and id4 <> 'groups')
		      {
			url := concat(url, '&city=', id4);
		      }
		  }
		else if (id3 is not null and (id4 is null or id4 = 'groups'))
		  {
		    url := concat(url, '&city=', id3);
		  }
		  what_ := 'groups';
	      }
	    else
	      return 0;
	    url := concat(url, '&key=', api_key );
	    DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
	  }
	if (id1 = 'members' and id2 is not null)
	  {
	    base := concat('http://www.meetup.com/members/', id2, '/');
	    url := concat('http://api.meetup.com/members.xml/?member_id=', id2, '&key=', api_key);
	    what_ := 'member';
	    DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
	  }
	else
	  {
	    base := concat('http://www.meetup.com/', id1, '/');
	    if (id1 is not null and id2 = 'members')
	      {
		url := concat('http://api.meetup.com/members.xml/?group_urlname=', id1, '&key=', api_key);
		what_ := 'members';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
	      }
	    else if (id1 is not null and id2 = 'calendar')
	      {
		if (id3 is null or id3 = '')
		  {
		    url := concat('http://api.meetup.com/events.xml/?group_urlname=', id1, '&key=', api_key);
		    what_ := 'events';
		    DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
		  }
		else
		  {
		    url := concat('http://api.meetup.com/events.xml/?id=', id3, '&key=', api_key);
		    what_ := 'event';
		    DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
		  }
	      }
	    else if (id1 is not null and id2 = 'photos')
	      {
		url := concat('http://api.meetup.com/photos.xml/?group_urlname=', id1, '&key=', api_key);
		what_ := 'photos';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
	      }
	    else
	      {
		url := sprintf('http://api.meetup.com/groups.xml/?group_urlname=%s&key=%s', id1, api_key);
		what_ := 'groups';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);

		url := concat('http://api.meetup.com/members.xml/?group_urlname=', id1, '&key=', api_key);
		what_ := 'members';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);

		url := concat('http://api.meetup.com/events.xml/?group_urlname=', id1, '&key=', api_key);
		what_ := 'events';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);

		url := sprintf('http://api.meetup.com/comments.xml/?group_urlname=%s&key=%s', id1, api_key);
		what_ := 'comments';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
	      }
	  }
      }
    else
      {
	if (id1 = 'cities')
	  {
	    if (id2 is not null)
	      {
		url := concat('http://api.meetup.com/groups.xml/?topic=%s&country=', id0, id2);
		if (id3 is not null and id4 is not null)
		  {
		    url := concat(url, '&state=', id3);
		    if (id4 is not null and id4 <> 'groups')
		      {
			url := concat(url, '&city=', id4);
		      }
		  }
		else if (id3 is not null and (id4 is null or id4 = 'groups'))
		  {
		    url := concat(url, '&city=', id3);
		  }
		  what_ := 'groups';
	      }
	    else
	      return 0;
	    url := concat(url, '&key=', api_key );
	    DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
	  }
	else
	  {
	    base := concat('http://', id0, '.meetup.com/', id1, '/');
	    if (id1 is not null and id2 = 'members')
	      {
		url := concat('http://api.meetup.com/members.xml/?topic=', id0, '&groupnum=', id1, '&key=', api_key);
		what_ := 'members';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
	      }
	    if (id1 is not null and id2 = 'photos')
	      {
		url := concat('http://api.meetup.com/photos.xml/?topic=', id0, '&groupnum=', id1, '&key=', api_key);
		what_ := 'photos';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
	      }
	    if (id1 is not null and id2 = 'calendar')
	      {
		if (id3 is null or id3 = '')
		  {
		    url := concat('http://api.meetup.com/events.xml/?topic=', id0, '&groupnum=', id1, '&key=', api_key);
		    what_ := 'events';
		    DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
		  }
		else
		  {
		    base := concat(trim(new_origin_uri, '/'), '/');
		    url := concat('http://api.meetup.com/events.xml/?id=', id3, '&key=', api_key);
		    what_ := 'event';
		    DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
		  }
	      }
	    if (id1 is null or id1 = '')
	      {
		base := concat(trim(new_origin_uri, '/'), '/');

		url := sprintf('http://api.meetup.com/groups.xml/?topic=%s&key=%s', id0, api_key);
		what_ := 'groups';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);

		url := concat('http://api.meetup.com/members.xml/?topic=', id0, '&key=', api_key);
		what_ := 'members';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);

		url := concat('http://api.meetup.com/events.xml/?topic=', id0, '&key=', api_key);
		what_ := 'events';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);

		url := concat('http://api.meetup.com/comments.xml/?topic=', id0, '&key=', api_key);
		what_ := 'comments';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
	      }
	    else
	      {
		url := sprintf('http://api.meetup.com/groups.xml/?topic=%s&groupnum=%s&key=%s', id0, id1, api_key);
		what_ := 'groups';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);

		url := concat('http://api.meetup.com/members.xml/?topic=', id0, '&groupnum=', id1, '&key=', api_key);
		what_ := 'members';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);

		url := concat('http://api.meetup.com/events.xml/?topic=', id0, '&groupnum=', id1, '&key=', api_key);
		what_ := 'events';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);

		url := concat('http://api.meetup.com/comments.xml/?topic=', id0, '&groupnum=', id1, '&key=', api_key);
		what_ := 'comments';
		DB.DBA.RDF_LOAD_MEETUP2(url, new_origin_uri, dest, graph_iri, what_, base, opts);
	      }
	  }
      }
  }
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_LASTFM2 (in url varchar, in new_origin_uri varchar,  in dest varchar, in graph_iri varchar, inout opts any)
 returns integer
{
	declare xt, xd any;
	declare tmp varchar;
	tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/lastfm2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
	xd := serialize_to_UTF8_xml (xt);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_LASTFM (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar, inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xd, xt, url, tmp, tmp1, server, api_key, hdr any;
	declare pos, len int;
	declare xsl2, origin_uri, id0, id1, id2, id3, id4 varchar;
	id0 := '';
	id1 := '';
	id2 := '';
	id3 := '';
	id4 := '';
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	api_key := _key;
	tmp1 := sprintf_inverse (new_origin_uri, 'http://%s/%s', 0);
	server := tmp1[0];
	if (server is null or server = '')
		return 0;
	origin_uri := trim(tmp1[1], '/');
	if (origin_uri is null or origin_uri = '')
		return 0;
	tmp := sprintf_inverse (origin_uri, '%s/%s/%s/%s/%s', 0);
    if (tmp is null)
		tmp := sprintf_inverse (origin_uri, '%s/%s/%s/%s', 0);
	if (tmp is null)
		tmp := sprintf_inverse (origin_uri, '%s/%s/%s', 0);
	if (tmp is null)
		tmp := sprintf_inverse (origin_uri, '%s/%s', 0);
	if (tmp is null)
		tmp := sprintf_inverse (origin_uri, '%s', 0);
	len := length(tmp);
	if (len > 4)
		id4 := tmp[4];
	if (len > 3)
		id3 := tmp[3];
	if (len > 2)
		id2 := tmp[2];
	if (len > 1)
		id1 := tmp[1];
	if (len > 0)
		id0 := tmp[0];
	else
		return 0;
	delete from DB.DBA.RDF_QUAD where g =  iri_to_id (coalesce (dest, graph_iri));
        
	if (id0 = 'music')
	{
		if (id1 is not null and id1 <> '')
		{
			if (id2 is not null and id2 <> '')
			{
				if (id3 is not null and id3 <> '')
				{
					url := sprintf('http://ws.audioscrobbler.com/2.0/?method=track.getinfo&api_key=%s&artist=%s&track=%s', api_key, id1, id3);
					DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri, opts);
					url := sprintf('http://ws.audioscrobbler.com/2.0/?method=track.getsimilar&artist=%s&track=%s&api_key=%s', id1, id3, api_key);
					return DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri, opts);
				}
				else
				{
					if (strchr(id2, '+') = 0)  -- todo: perhaps it needs some processing?
					{
						url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.getinfo&artist=%s&api_key=%s', id1, api_key);
						DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri, opts);

						url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.gettopalbums&artist=%s&api_key=%s', id1, api_key);
						DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri, opts);

						url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.getevents&artist=%s&api_key=%s', id1, api_key);
						DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

						url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.getsimilar&artist=%s&api_key=%s', id1, api_key);
						return DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);
					}
					else if (id1 = '+noredirect')
					{
						url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.getinfo&artist=%s&api_key=%s', id2, api_key);
						DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

						url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.gettopalbums&artist=%s&api_key=%s', id2, api_key);
						DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

						url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.getevents&artist=%s&api_key=%s', id2, api_key);
						DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

						url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.getsimilar&artist=%s&api_key=%s', id2, api_key);
						return DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);
					}
					else
					{
						url := sprintf('http://ws.audioscrobbler.com/2.0/?method=album.getinfo&api_key=%s&artist=%s&album=%s', api_key, id1, id2);
						return DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);
					}
				}
			}
			else
			{
				url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.getinfo&artist=%s&api_key=%s', id1, api_key);
				DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

				url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.gettopalbums&artist=%s&api_key=%s', id1, api_key);
				DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

				url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.getevents&artist=%s&api_key=%s', id1, api_key);
				DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

				url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.getsimilar&artist=%s&api_key=%s', id1, api_key);
				return DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);
			}
		}
		else
			return 0;
	}
	else if (id0 = 'listen')
	{
		if (id1 is not null and id1 <> '')
		{
			url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.getinfo&artist=%s&api_key=%s', id1, api_key);
			DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

			url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.gettopalbums&artist=%s&api_key=%s', id1, api_key);
			DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

			url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.getevents&artist=%s&api_key=%s', id1, api_key);
			DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

			url := sprintf('http://ws.audioscrobbler.com/2.0/?method=artist.getsimilar&artist=%s&api_key=%s', id1, api_key);
			return DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);
		}
		else
			return 0;
	}
	else if (id0 = 'event')
	{
		if (id1 is not null and id1 <> '')
		{
			pos := strchr(id1, '+');
			if (pos > 0)
				id1 := left(id1, pos);
			url := sprintf('http://ws.audioscrobbler.com/2.0/?method=event.getinfo&event=%s&api_key=%s', id1, api_key);
			return DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);
		}
		else
			return 0;
	}
	else if (id0 = 'user')
	{
		if (id1 is not null and id1 <> '' and (id2 = '' or id2 is null))
		{
			url := sprintf('http://ws.audioscrobbler.com/1.0/user/%s/profile.xml', id1);
			DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

			url := sprintf('http://ws.audioscrobbler.com/2.0/?method=user.getfriends&user=%s&api_key=%s', id1, api_key);
			DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

			url := sprintf('http://ws.audioscrobbler.com/2.0/?method=user.gettopalbums&user=%s&api_key=%s', id1, api_key);
			DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

			url := sprintf('http://ws.audioscrobbler.com/2.0/?method=user.gettopartists&user=%s&api_key=%s', id1, api_key);
			DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

			url := sprintf('http://ws.audioscrobbler.com/2.0/?method=user.gettoptracks&user=%s&api_key=%s', id1, api_key);
			DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);
			
			url := sprintf('http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=%s&api_key=%s', id1, api_key);
			DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

			url := sprintf('http://ws.audioscrobbler.com/2.0/?method=user.getplaylists&user=%s&api_key=%s', id1, api_key);
			DB.DBA.RDF_LOAD_LASTFM2(url, new_origin_uri,  dest, graph_iri,  opts);

			tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
			xd := xtree_doc (tmp);
			declare ids any;
			ids := xpath_eval ('/lfm/playlists/playlist/id', xd, 0);
			foreach (any y in ids) do
			{
				declare x, new_origin_uri2, url2 varchar;
				x := cast(y as varchar);
				new_origin_uri2 := concat(new_origin_uri, '#', x);
				url2:= sprintf('http://ws.audioscrobbler.com/2.0/?method=playlist.fetch&playlistURL=lastfm://playlist/%s&api_key=%s', x, api_key);
				tmp := http_client (url2, proxy=>get_keyword_ucase ('get:proxy', opts));
				xd := xtree_doc (tmp);
				xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/lastfm2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (new_origin_uri), 'id', x));
				xd := serialize_to_UTF8_xml (xt);
				DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
				DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url2);
			}
		}
		else if (id1 is not null and id1 <> '' and (id2 = 'library' and id3 = 'playlists' and id4 <> '' and id4 is not null))
		{
			return 0;
		}
		else
			return 0;
	}
	else
		return 0;
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_PICASA (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar, inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xd, host_part, xt, url, tmp, api_key, img_id, hdr, exif any;
	declare album_name, user_name varchar;

	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	if (
	  new_origin_uri like 'http://picasaweb.google.com/data/entry/api/%'
	  or
	  new_origin_uri like 'http://picasaweb.google.com/data/feed/api/%'
	  )
        {
	  tmp := _ret_body;
	  goto transform;
	}
	else if (new_origin_uri like 'http://picasaweb.google.com/%/%#%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://picasaweb.google.com/%s/%s#%s', 0);
		img_id := tmp[2];
		album_name := tmp[1];
		user_name := tmp[0];
		if ((user_name is null or user_name = '') or (album_name is null or album_name = ''))
			return 0;
	}
	else if (new_origin_uri like 'http://picasaweb.google.com/%/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://picasaweb.google.com/%s/%s', 0);
		album_name := tmp[1];
		user_name := tmp[0];
		if ((user_name is null or user_name = ''))
			return 0;
	}
	else if (new_origin_uri like 'http://picasaweb.google.com/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://picasaweb.google.com/%s', 0);
		user_name := tmp[0];
		if ((user_name is null or user_name = ''))
			return 0;
	}
	else
	{
		return 0;
	}

	if (user_name is not null and user_name <> '')
	{
		url := sprintf('http://picasaweb.google.com/data/feed/api/user/%s', user_name);
		tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
		transform:
		xd := xtree_doc (tmp);
		xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/picasa2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
		xd := serialize_to_UTF8_xml (xt);
		delete from DB.DBA.RDF_QUAD where g =  iri_to_id (coalesce (dest, graph_iri));
		DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
		DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
		return 1;
	}
	else
	{
		return 0;
	}
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_GEONAMES (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xd, xt, url, tmp, geo_id any;
	declare pos int;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	if (new_origin_uri like 'http://%.geonames.org/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://%s.geonames.org/%s', 0);
		geo_id := tmp[1];
		pos := strchr(geo_id, '/');
		if (pos > 0)
			geo_id := left(geo_id, pos);
		url := sprintf('http://sws.geonames.org/%s/about.rdf', geo_id);
	}
	else
		return 0;
	tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/geonames2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
	xd := serialize_to_UTF8_xml (xt);
        delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_VIMEO (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xd, xt, url, tmp, hdr, id any;
	declare pos int;
	declare exit handler for sqlstate '*'
	{
        DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
		return 0;
	};
	if (new_origin_uri like 'http://vimeo.com/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://vimeo.com/%s', 0);
        id := rtrim(tmp[0], '&/');
        pos := strchr(id, '/');
        if (pos > 0)
			id := left(id, pos);
		if (id is null)
			return 0;
        pos := strchr(id, '?');
        if (pos > 0)
			id := left(id, pos);
		if (id is null)
			return 0;
        if (atoi(id) > 0)
            url := sprintf('http://vimeo.com/api/v2/video/%s.xml', id);
        else
            url := sprintf('http://vimeo.com/api/v2/%s/info.xml', id);
	}
	else
		return 0;
    tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
    if (hdr[0] not like 'HTTP/1._ 200 %')
        signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/vimeo2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
	xd := serialize_to_UTF8_xml (xt);
    delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_YOUTUBE (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, host_part, xt, url, tmp, api_key, img_id, hdr, exif any;
  declare xsl2, user_id varchar;
  declare pos int;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };

  if (new_origin_uri like 'http://%.youtube.com/results?search_query=%')
  {
    tmp := sprintf_inverse (new_origin_uri, '%s://%s.youtube.com/results?search_query=%s&search_type=%s&%s', 0);
    img_id := tmp[2];
    host_part := tmp[3];
    if (host_part <> '' or img_id is null)
        return 0;
    url := concat('http://gdata.youtube.com/feeds/api/videos?vq=', img_id);
    tmp := DB.DBA.RDF_HTTP_URL_GET (url, url, hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
    xsl2 := 'xslt/main/atom2rdf.xsl';
  }
  else if (new_origin_uri like 'http://%.youtube.com/watch?v=%')
  {
    declare ar any;
    ar := WS.WS.PARSE_URI (new_origin_uri);
    ar := ar[4];
    ar := split_and_decode (ar);
    img_id := get_keyword ('v', ar);
    if (img_id is null)
        return 0;
    url := concat('http://gdata.youtube.com/feeds/api/videos/', img_id);
    tmp := DB.DBA.RDF_HTTP_URL_GET (url, url, hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
    xsl2 := 'xslt/main/atomentry2rdf.xsl';
  }
   else if (new_origin_uri like 'http://%.youtube.com/%' or new_origin_uri like 'http://%.youtube.com/user/%')
  {
    if (new_origin_uri like 'http://%.youtube.com/user/%')
        tmp := sprintf_inverse (new_origin_uri, '%s://%s.youtube.com/user/%s', 0);
    else if (new_origin_uri like 'http://%.youtube.com/%')
        tmp := sprintf_inverse (new_origin_uri, '%s://%s.youtube.com/%s', 0);
    user_id := trim(tmp[2], '/');
    if (user_id is null)
        return 0;
    pos := strchr(user_id, '/');
    if (pos is not null and pos <> 0)
        user_id := left(user_id, pos);
    pos := strchr(user_id, '&');
    if (pos is not null and pos <> 0)
        user_id := left(user_id, pos);
    pos := strchr(user_id, '?');
    if (pos is not null and pos <> 0)
        user_id := left(user_id, pos);
    pos := strchr(user_id, '#');
    if (pos is not null and pos <> 0)
        user_id := left(user_id, pos);
    url := concat('http://gdata.youtube.com/feeds/api/users/', user_id);
    tmp := DB.DBA.RDF_HTTP_URL_GET (url, url, hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
    if (hdr[0] not like 'HTTP/1._ 200 %')
        signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
    xd := xtree_doc (tmp);
    xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/youtube2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
    xd := serialize_to_UTF8_xml (xt);
    DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
    return 1;
  }
  else
    return 0;
  if (hdr[0] not like 'HTTP/1._ 200 %')
    signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
  xd := xtree_doc (tmp);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || xsl2, xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id (coalesce (dest, graph_iri));
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_DIGG (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar, inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, section_name, search, xt, url, tmp, story_url, appkey any;
  story_url := '';
  appkey := 'http://www.openlinksw.com/virtuoso';
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  if (new_origin_uri like 'http://digg.com/search?%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://digg.com/search?section=%s&s=%s', 0);
      section_name := tmp[0];
      search := tmp[1];
      if (search is null)
	return 0;
      url := sprintf('http://digg.com/rss_search?search=%s&area=promoted&type=both&section=%s', search, section_name);
      tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
      xd := xtree_doc (tmp);
      xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/rss2rdf.xsl', xd,
      	vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'isDiscussion', '1'));
      xd := serialize_to_UTF8_xml (xt);
      delete from DB.DBA.RDF_QUAD where g =  iri_to_id (coalesce (dest, graph_iri));
      --DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
      DB.DBA.RDF_LOAD_FEED_SIOC (xd, new_origin_uri, coalesce (dest, graph_iri), 1);
      DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
      return 1;
    }
  else if (new_origin_uri like 'http://digg.com/%')
    {
      declare ext_url, gr, id, comm varchar;
      gr := coalesce (dest, graph_iri);
      whenever not found goto ret;
      select "o" into ext_url from (sparql prefix dc: <http://purl.org/dc/elements/1.1/>
  	select ?o where { graph ?:gr { ?s dc:source ?o } } ) sp;
      url := sprintf ('http://services.digg.com/stories?link=%U&appkey=%U', ext_url, appkey);
      tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
      xd := xtree_doc (tmp);
      id := cast (xpath_eval ('string (/stories/story/@id)', xd) as varchar);
      comm := cast (xpath_eval ('string (/stories/story/@comments)', xd) as varchar);
      story_url := cast (xpath_eval ('string (/stories/story/@href)', xd) as varchar);
      xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/digg2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
      xd := serialize_to_UTF8_xml (xt);
      delete from DB.DBA.RDF_QUAD where g =  iri_to_id (coalesce (dest, graph_iri));
      DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
      DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
      url := sprintf ('http://services.digg.com/story/%s/comments?count=%s&appkey=%U', id, comm, appkey);
      tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
      goto diggsvc;
    }
  else -- http://services.digg.com
    {
      if (new_origin_uri like 'http://services.digg.com/story/%/%') -- if it is a comment
	{
	  tmp := sprintf_inverse (new_origin_uri, 'http://services.digg.com/story/%s/%s', 0);
	  url := sprintf ('http://services.digg.com/story/%s?appkey=%U', tmp[0], appkey);
	  tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	  xd := xtree_doc (tmp);
	  story_url := cast (xpath_eval ('string (/stories/story/@href)', xd) as varchar);
	}
      tmp := _ret_body;
      diggsvc:
      xd := xtree_doc (tmp);
      xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/digg2rdf.xsl', xd,
      		vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'storyUrl', story_url));
      xd := serialize_to_UTF8_xml (xt);
      delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
      DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
      DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
      return 1;
    }
ret:
  return 0;
}
;

create procedure DB.DBA.RDF_LOAD_DELICIOUS (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar, inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xd, section_name, search, xt, url, tmp any;
	declare what varchar;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	if (new_origin_uri like 'http://%delicious.com/tags/%' or new_origin_uri like 'http://feeds.delicious.com/v2/rss/tags/%')
		what := 'tags';
	else if (new_origin_uri like 'http://%delicious.com/url/%' or new_origin_uri like 'http://feeds.delicious.com/v2/rss/url/%')
	{
		what := 'url';
		return 1;
	}
	else if (new_origin_uri like 'http://%delicious.com/%/%' or new_origin_uri like 'http://feeds.delicious.com/v2/rss/%/%')
		what := 'tag';
	else
		what := 'user';
	if (new_origin_uri like 'http://%delicious.com/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://%sdelicious.com/%s', 0);
		section_name := trim(tmp[1]);
		section_name := trim(section_name, '/');
		if (section_name is null)
			return 0;
		if (what = 'user')
		{
			if (strchr(section_name, '/') is not null)
				return 0;
		}
		url := sprintf('http://feeds.delicious.com/v2/rss/%s', section_name);
	}
	else if (new_origin_uri like 'http://feeds.delicious.com/%')
		url := new_origin_uri;
	else
		return 0;

	tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/delicious2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'what', what));
	xd := serialize_to_UTF8_xml (xt);
	delete from DB.DBA.RDF_QUAD where g =  iri_to_id (coalesce (dest, graph_iri));
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	declare result, meta, state, message any;
	state := '00000';
	exec (sprintf('sparql select ?l from <%s> where { <%s> <http://scot-project.org/scot/ns#name> ?l }', graph_iri, graph_iri), state, message, vector (), 0, meta, result);
	foreach (any str in result) do
	{
		if (isstring (str[0]))
		{
			declare meaning_iri varchar;
			declare keyword varchar;
			keyword := str[0];
			state := '00000';
			result := vector();
			exec(sprintf ('select mu_id, mu_url from moat.DBA.moat_user_meanings where mu_tag = \'%s\'', keyword), state, message, vector(), 0, meta, result);
			if (state = '00000')
			{
				declare i, l int;
				for (i := 0, l := length (result); i < l; i := i + 1)
				{
					declare rs any;
      				meaning_iri := graph_iri || sprintf ('#meaning/%d', result[i][0]);
					DB.DBA.RDF_QUAD_URI (graph_iri, graph_iri, 'http://moat-project.org/ns#hasMeaning', meaning_iri);
					DB.DBA.RDF_QUAD_URI (graph_iri, meaning_iri, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 'http://moat-project.org/ns#Meaning');
					DB.DBA.RDF_QUAD_URI (graph_iri, meaning_iri, 'http://moat-project.org/ns#meaningURI', result[i][1]);
				}
			}
		}
	}

	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_GOOGLE_DOCUMENT (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xd, host_part, xt, url, tmp, api_key, hdr, exif any;
	declare pos int;
	declare spread_id varchar;
	declare mail, pwd, auth, auth_header varchar;
	mail := get_keyword ('email', opts, null);
	pwd := get_keyword ('password', opts, null);
	declare exit handler for sqlstate '*'
	{
		DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	auth_header := null;
	if (length (mail) + length (pwd))
	{
		tmp := http_client (url=>'https://www.google.com/accounts/ClientLogin',
			http_method=>'POST', body=>sprintf ('Email=%U&Passwd=%U&source=OpenLink-Sponger-1&service=writely', mail, pwd),
			proxy=>get_keyword_ucase ('get:proxy', opts));
		if (tmp like 'Error=%')
			return 0;
		tmp := replace (tmp, '\r', '\n');
		tmp := replace (tmp, '\n\n', '\n');
		tmp := split_and_decode (tmp, 0, '\0\0\n=');
		auth := get_keyword ('Auth', tmp);
		if (auth is not null)
			auth_header := 'Authorization: GoogleLogin auth='||auth;
	}
	if (new_origin_uri like 'http%://docs.google.com/Doc?docid=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http%s://docs.google.com/Doc?docid=%s', 0);
		spread_id := trim(tmp[1], '/');
		if (spread_id is null)
			return 0;
		pos := strchr(spread_id, '/');
		if (pos is not null and pos <> 0)
			spread_id := left(spread_id, pos);
		pos := strchr(spread_id, '&');
		if (pos is not null and pos <> 0)
			spread_id := left(spread_id, pos);
		url := sprintf('http://docs.google.com/feeds/default/private/full/%s?v=3', spread_id);
	}
	else if (new_origin_uri like 'http%://docs.google.com/present/view?id=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http%s://docs.google.com/present/view?id=%s', 0);
		spread_id := trim(tmp[1], '/');
		if (spread_id is null)
			return 0;
		pos := strchr(spread_id, '/');
		if (pos is not null and pos <> 0)
			spread_id := left(spread_id, pos);
		pos := strchr(spread_id, '&');
		if (pos is not null and pos <> 0)
			spread_id := left(spread_id, pos);
		url := sprintf('http://docs.google.com/feeds/default/private/full/%s?v=3', spread_id);
	}
	else
		return 0;
	tmp := DB.DBA.RDF_HTTP_URL_GET (url, url, hdr, 'GET', auth_header, proxy=>get_keyword_ucase ('get:proxy', opts));
	if (hdr[0] not like  'HTTP/1._ 200 %')
		return 0;
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/google_document2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
	xd := serialize_to_UTF8_xml (xt);
        delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_GOOGLE_SPREADSHEET (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xd, xd2, host_part, xt, url, tmp, api_key, hdr, ids, exif any;
	declare pos int;
	declare spread_id varchar;
	declare mail, pwd, auth, auth_header varchar;
	mail := get_keyword ('email', opts, null);
	pwd := get_keyword ('password', opts, null);
	declare exit handler for sqlstate '*'
	{
		DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	auth_header := null;
	if (length (mail) + length (pwd))
	{
		tmp := http_client (url=>'https://www.google.com/accounts/ClientLogin',
			http_method=>'POST', body=>sprintf ('Email=%U&Passwd=%U&source=OpenLink-Sponger-1&service=wise', mail, pwd),
			proxy=>get_keyword_ucase ('get:proxy', opts));
		if (tmp like 'Error=%')
			return 0;
		tmp := replace (tmp, '\r', '\n');
		tmp := replace (tmp, '\n\n', '\n');
		tmp := split_and_decode (tmp, 0, '\0\0\n=');
		auth := get_keyword ('Auth', tmp);
		if (auth is not null)
			auth_header := 'Authorization: GoogleLogin auth='||auth;
	}
	if (new_origin_uri like 'http%://spreadsheets.google.com/ccc?key=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http%s://spreadsheets.google.com/ccc?key=%s', 0);
		spread_id := trim(tmp[1], '/');
		if (spread_id is null)
			return 0;
		pos := strchr(spread_id, '/');
		if (pos is not null and pos <> 0)
			spread_id := left(spread_id, pos);
		pos := strchr(spread_id, '&');
		if (pos is not null and pos <> 0)
			spread_id := left(spread_id, pos);
		url := sprintf('http://spreadsheets.google.com/feeds/worksheets/%s/private/full', spread_id);
	}
	else
		return 0;
	tmp := DB.DBA.RDF_HTTP_URL_GET (url, url, hdr, 'GET', auth_header, proxy=>get_keyword_ucase ('get:proxy', opts));
	if (hdr[0] not like  'HTTP/1._ 200 %')
		return 0;
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/google_spreadsheet2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'what', 'doc'));
	xd2 := serialize_to_UTF8_xml (xt);
        delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd2, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);

	ids := xpath_eval ('/feed/entry/link[@rel="http://schemas.google.com/spreadsheets/2006#cellsfeed"]/@href', xd, 0);
	foreach (any y in ids) do
	{
		declare x, new_origin_uri2, url2 varchar;
		url := cast(y as varchar);
		tmp := DB.DBA.RDF_HTTP_URL_GET (url, url, hdr, 'GET', auth_header, proxy=>get_keyword_ucase ('get:proxy', opts));
		xd := xtree_doc (tmp);
		xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/google_spreadsheet2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'what', 'cells'));
		xd := serialize_to_UTF8_xml (xt);
		DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
		DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	}
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_OREILLY (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, host_part, xt, url, tmp, api_key, hdr, exif any;
  declare pos int;
  declare book_id varchar;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
    if (new_origin_uri like 'http://www.oreilly.com/catalog/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.oreilly.com/catalog/%s', 0);
		book_id := trim(tmp[0], '/');
		if (book_id is null)
			return 0;
		pos := strchr(book_id, '/');
		if (pos is not null and pos <> 0)
			book_id := left(book_id, pos);
	}
	else if (new_origin_uri like 'http://oreilly.com/catalog/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://oreilly.com/catalog/%s', 0);
		book_id := trim(tmp[0], '/');
		if (book_id is null)
			return 0;
		pos := strchr(book_id, '/');
		if (pos is not null)
			book_id := left(book_id, pos);
	}
	else
		return 0;
    url := sprintf('http://oreilly.com/catalog/%s/', book_id);
	tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	xd := xtree_doc (tmp, 2);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/oreilly2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'currentDateTime', cast(date_iso8601(now()) as varchar)));
	xd := serialize_to_UTF8_xml (xt);
        delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_GOOGLE_BOOK (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, host_part, xt, url, tmp, api_key, hdr, exif any;
  declare pos int;
  declare book_id varchar;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
      return 0;
    };
    if (new_origin_uri like 'http://books.google.com/books?id=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://books.google.com/books?id=%s', 0);
		book_id := trim(tmp[0], '/');
		if (book_id is null)
			return 0;
		pos := strchr(book_id, '&');
		if (pos is not null and pos <> 0)
			book_id := left(book_id, pos);
	}
	else
		return 0;
    url := sprintf('http://books.google.com/books/feeds/volumes/%s', book_id);
	tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	xd := xtree_doc (tmp, 2);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/google_book2rdf.xsl',
        xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
	xd := serialize_to_UTF8_xml (xt);
    delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_ETSY (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar, inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, host_part, xt, url, tmp, hdr, tree any;
  declare pos int;
  declare item_id, action varchar;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
      return 0;
    };
    if (new_origin_uri like 'http://www.etsy.com/people/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.etsy.com/people/%s', 0);
		item_id := trim(tmp[0], '/');
		if (item_id is null)
			return 0;
		pos := strchr(item_id, '/');
		if (pos is not null and pos <> 0)
			item_id := left(item_id, pos);
	    url := sprintf('http://beta-api.etsy.com/v1/users/%s?api_key=%s&detail_level=high', item_id, _key);
	    action := 'user';
	}
    else if (new_origin_uri like 'http://www.etsy.com/view_listing.php?listing_id=%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.etsy.com/view_listing.php?listing_id=%s', 0);
		item_id := trim(tmp[0], '/');
		if (item_id is null)
			return 0;
		pos := strchr(item_id, '/');
		if (pos is not null and pos <> 0)
			item_id := left(item_id, pos);
	    url := sprintf('http://beta-api.etsy.com/v1/listings/%s?api_key=%s&detail_level=high', item_id, _key);
		action := 'prod';
	}
    else if (new_origin_uri like 'http://www.etsy.com/listing/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.etsy.com/listing/%s', 0);
		item_id := trim(tmp[0], '/');
		if (item_id is null)
			return 0;
		pos := strchr(item_id, '/');
		if (pos is not null and pos <> 0)
			item_id := left(item_id, pos);
	    url := sprintf('http://beta-api.etsy.com/v1/listings/%s?api_key=%s&detail_level=high', item_id, _key);
		action := 'prod';
	}
	else
		return 0;
	tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	tree := json_parse (tmp);
	xt := DB.DBA.SOCIAL_TREE_TO_XML (tree);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/etsy2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'action', action));
	xd := serialize_to_UTF8_xml (xt);
    delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_TUMBLR (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, host_part, xt, url, tmp, hdr, exif any;
  declare _id, _id2 varchar;
  declare pos int;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
      return 0;
    };
    if (new_origin_uri like 'http://%.tumblr.com' or new_origin_uri like 'http://%.tumblr.com/')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://%s.tumblr.com%s', 0);
		_id := tmp[0];
		if (_id is null)
			return 0;
		url := sprintf('http://%s.tumblr.com/api/read', _id);
	}
    else if (new_origin_uri like 'http://%.tumblr.com/post/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://%s.tumblr.com/post/%s', 0);
		_id := tmp[0];
		_id2 := tmp[1];
		if (_id is null)
			return 0;
		url := sprintf('http://%s.tumblr.com/api/read', _id);
		if (_id2 is not null)
		{
			pos := strchr(_id2, '/');
			if (pos is not null)
				_id2 := left(_id2, pos);
			url := sprintf('%s?id=%s', url, _id2);
		}			
	}
	else
		return 0;
    tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
    if (hdr[0] not like 'HTTP/1._ 200 %')
        signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
    xd := xtree_doc (tmp);
    xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/tumblr2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
    xd := serialize_to_UTF8_xml (xt);
    delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
    DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_WINE (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, host_part, xt, url, tmp, hdr, exif any;
  declare wine_id varchar;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
      return 0;
    };
    if (new_origin_uri like 'http://www.wine.com/V6/%/wine/%/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.wine.com/V6/%s/wine/%s/%s', 0);
		wine_id := tmp[1];
		if (wine_id is null)
			return 0;
		url := sprintf('http://services.wine.com/api/beta/service.svc/xml/catalog?filter=product(%s)&apikey=%s', wine_id, _key);
	}
    else if (new_origin_uri like 'http://www.wine.com/V6/%/gift/%/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.wine.com/V6/%s/gift/%s/%s', 0);
		wine_id := tmp[1];
		if (wine_id is null)
			return 0;
		url := sprintf('http://services.wine.com/api/beta/service.svc/xml/catalog?filter=product(%s)&apikey=%s', wine_id, _key);
	}
	else
		return 0;
    tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
    if (hdr[0] not like 'HTTP/1._ 200 %')
        signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
    xd := xtree_doc (tmp);
    xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/wine2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
    xd := serialize_to_UTF8_xml (xt);
    delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
    DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_EVRI (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, host_part, xt, url, tmp, hdr, exif any;
  declare entity_id, _id varchar;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
      return 0;
    };
    if (new_origin_uri like 'http://www.evri.com/%/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.evri.com/%s/%s', 0);
		entity_id := tmp[0];
		_id := tmp[1];
		if (entity_id = 'person' or entity_id = 'location' or entity_id = 'product' or entity_id = 'organization')
			url := sprintf('http://api.evri.com/v1/%s/%s?appId=evri.com-restdoc', entity_id, _id);
		else
			return 0;
	}
	else
		return 0;
	tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
    if (hdr[0] not like 'HTTP/1._ 200 %')
        signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
    xd := xtree_doc (tmp);
    xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/evri2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'entity', entity_id));
    xd := serialize_to_UTF8_xml (xt);
    delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
    DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
    DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_CNET (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, host_part, xt, url, tmp, api_key, hdr, exif any;
  declare pos int;
  declare soft_id varchar;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
    if (new_origin_uri like 'http://www.download.com/%/%.html%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.download.com/%s/%s.html%s', 0);
		soft_id := tmp[1];
		if (soft_id is null)
			return 0;
		pos := strrchr(soft_id, '-');
		if (pos is not null and pos <> 0)
			soft_id := right(soft_id, length(soft_id) - (pos + 1));
		url := sprintf('http://developer.api.cnet.com/rest/v1.0/softwareProduct?iod=none&partKey=%s&partTag=%s&productSetId=%s', _key, _key, soft_id);

	}
	else if (new_origin_uri like 'http://download.com/%/%.html%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://download.com/%s/%s.html%s', 0);
		soft_id := tmp[1];
		if (soft_id is null)
			return 0;
		pos := strrchr(soft_id, '-');
		if (pos is not null and pos <> 0)
			soft_id := right(soft_id, length(soft_id) - (pos + 1));
		url := sprintf('http://developer.api.cnet.com/rest/v1.0/softwareProduct?iod=none&partKey=%s&partTag=%s&productSetId=%s', _key, _key, soft_id);
	}
	else if (new_origin_uri like 'http://download.cnet.com/%/%.html%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://download.cnet.com/%s/%s.html%s', 0);
		soft_id := tmp[1];
		if (soft_id is null)
			return 0;
		pos := strrchr(soft_id, '-');
		if (pos is not null and pos <> 0)
			soft_id := right(soft_id, length(soft_id) - (pos + 1));
		url := sprintf('http://developer.api.cnet.com/rest/v1.0/softwareProduct?iod=none&partKey=%s&partTag=%s&productId=%s', _key, _key, soft_id);
	}
    else if (new_origin_uri like 'http://shopper.cnet.com/%/%.html%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://shopper.cnet.com/%s/%s.html%s', 0);
		soft_id := tmp[1];
		if (soft_id is null)
			return 0;
		pos := strrchr(soft_id, '-');
		if (pos is not null and pos <> 0)
			soft_id := right(soft_id, length(soft_id) - (pos + 1));
		url := sprintf('http://developer.api.cnet.com/rest/v1.0/techProduct?iod=breadcrumb,hlPrice,goodBad,userRatings,productSeries,accessories,images,productAuxiliary&partKey=%s&partTag=%s&productId=%s', _key, _key, soft_id);
	}
	else if (new_origin_uri like 'http://reviews.cnet.com/%/%.html%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://reviews.cnet.com/%s/%s.html%s', 0);
		soft_id := tmp[1];
		if (soft_id is null)
			return 0;
		pos := strrchr(soft_id, '-');
		if (pos is not null and pos <> 0)
			soft_id := right(soft_id, length(soft_id) - (pos + 1));
		url := sprintf('http://developer.api.cnet.com/rest/v1.0/techProduct?iod=breadcrumb,hlPrice,goodBad,userRatings,productSeries,accessories,images,productAuxiliary&partKey=%s&partTag=%s&productId=%s', _key, _key, soft_id);
	}
	else
		return 0;
	tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/cnet2rdf.xsl', xd,
	    vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'currentDateTime', cast(date_iso8601(now()) as varchar)));
	xd := serialize_to_UTF8_xml (xt);
        delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_YELP (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xd, host_part, xt, url, tmp, api_key, hdr, exif any;
	declare pos int;
	declare link varchar;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	if (new_origin_uri like 'http://%.yelp.com/%')
	{
		tmp := http_client (new_origin_uri, proxy=>get_keyword_ucase ('get:proxy', opts));
		xt := xtree_doc (tmp, 2);
		url := xpath_eval ('//link[ @rel="alternate" and @type="application/rss+xml" ]/@href', xt, 0);
		if (length(url) > 0)
			url := cast(url[0] as varchar);
		else
			return 0;
	}
	else
		return 0;
	tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/yelp2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
	xd := serialize_to_UTF8_xml (xt);
        delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_REVYU (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xd, host_part, xt, url, tmp, api_key, hdr, exif any;
	declare pos int;
	declare link, user_id varchar;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	if (new_origin_uri like 'http://%revyu.com/people/%')
	{
            tmp := sprintf_inverse (new_origin_uri, 'http://%srevyu.com/people/%s', 0);
            user_id := tmp[1];
            pos := strstr(user_id, '/about');
            if (pos is not NULL)
            {
                user_id := subseq(user_id, 0, pos);
            }
            url := sprintf('http://revyu.com/people/%s/about/rdf', user_id);
	}
	else
		return 0;
	tmp := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/revyu2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
	xd := serialize_to_UTF8_xml (xt);
        delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_BUGZILLA (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, host_part, xt, url, tmp, api_key, img_id, hdr, exif any;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  tmp := sprintf_inverse (new_origin_uri, '%s://%s/show_bug.cgi?id=%s', 0);
  if (length(tmp) < 2)
	return 0;
  img_id := tmp[2];
  host_part := tmp[1];
  if (img_id is null)
    return 0;
  if (right(host_part, 6) = 'issues')
	url := concat(tmp[0], '://', host_part, '/xml.cgi?id=', img_id);
  else
	url := concat(new_origin_uri, '&ctype=xml');
  tmp := DB.DBA.RDF_HTTP_URL_GET (url, url, hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
  if (hdr[0] not like 'HTTP/1._ 200 %')
    signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
  xd := xtree_doc (tmp);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/bugzilla2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_OPENLIBRARY (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare qr, path any;
  declare tree, xt, xd, types any;
  declare k, cnt, url, tmp, img_id varchar;
  declare pos integer;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  tmp := sprintf_inverse (new_origin_uri, 'http://openlibrary.org/b/%s', 0);
  img_id := tmp[0];
  pos := strchr(img_id, '/');
  if (pos is not null)
    {
      img_id := left(img_id, pos);
    }
  if (img_id is null)
    return 0;
  url := concat('http://openlibrary.org/api/get?key=/b/', img_id);
  url := concat(url, '&prettyprint=true&text=true');
  cnt := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
  tree := json_parse (cnt);
  xt := DB.DBA.SOCIAL_TREE_TO_XML (tree);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/openlibrary2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_SOCIALGRAPH (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare qr, path, hdr any;
  declare tree, xt, xd, types any;
  declare k, cnt, url varchar;
  hdr := null;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  url := new_origin_uri;
  cnt := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
  tree := json_parse (cnt);
  xt := DB.DBA.SOCIAL_TREE_TO_XML (tree);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/sg2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
  return 1;
}
;

create procedure csv_detect_opts (in s any, in n int := 10)
{
  declare delim, quot char;
  declare r, delims, seprs, best_match, best_delim, best_quot any;
  declare i, rws int;
  declare ss, orig any;

  delims := ',\t;:|';
  seprs  := '"\'';
  best_match := -1;
  best_delim := best_quot := null;
  ss := string_output ();
  foreach (int d in delims) do
    {
      foreach (int sp in seprs) do 
	{
	  i := 0; rws := 0;
	  delim := chr (d);
	  quot := chr (sp);
	  string_output_flush (ss);
	  http (s, ss);
	  while (i < n and isvector (r := get_csv_row (ss, delim, quot)))
        {
            if (i = 0)
		rws := length (r);
	      else if (length (r) <> rws)
		goto fail;   
	      i := i + 1;
	    }
	  if (i < n)
	    goto fail;
	  if (best_match < rws)
            {
	      best_match := rws;
	      best_delim := delim;
	      best_quot := quot;
	    }
	  fail:;
            }
    }
  return vector (best_delim, best_quot);
}
;

create procedure csv_make_head (in r any)
{
  declare ret any;
  ret := make_array (length (r), 'any');      
  for (declare i int, i := 0; i < length (r); i := i + 1)
    {
      if (isstring (r[i]) and length (r[i]))
	ret[i] := SYS_ALFANUM_NAME (r[i]);
      else
        ret[i] := sprintf ('COL%d', i);	
    }
  return ret;
}
;

create procedure csv_to_xml (in s any)
{
  declare r, opts, head, ss, ses any;
  declare i, rcnt int;

  ses := string_output ();
  http (s, ses);
  opts := csv_detect_opts (s);
  head := null;
  ss := string_output ();
  http ('<csv>\n', ss);
  rcnt := 1;
  while (isvector (r := get_csv_row (ses, opts[0], opts[1])))
    {
      if (head is null)
	head := csv_make_head (r);
            else
            {
	  http (sprintf ('\t<row id="%d">\n\t\t', rcnt), ss);
	  for (i := 0; i < length (head); i := i + 1)
	     {
	       if (i < length (r))
		 {
		   if (not isnull (r[i]))
		     http_value (r[i], head[i], ss);
		 }
	     }
	  http ('\n\t</row>\n', ss);
	  rcnt := rcnt + 1;
            }
        }
  http ('</csv>', ss);
  return ss;
    }
;

create procedure DB.DBA.RDF_LOAD_CSV (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, xt, url, tmp any;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
      return 0;
    };

  xt := csv_to_xml (_ret_body);  
  xt := xtree_doc (xt);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/csvxml2rdf.xsl', xt, 
    vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), null);
    return 1;
}
;

create procedure DB.DBA.RDF_LOAD_SVG (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, xt, url, tmp, api_key, img_id, hdr, exif any;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  xd := xtree_doc (_ret_body);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/svg2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), null);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_MS_DOCUMENT (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare meta, tmp varchar;
  declare xt, xd any;
  if (__proc_exists ('unzip_file', 2) is null)
    return 0;
  tmp := tmp_file_name ('rdfm', 'doc');

  string_to_file (tmp, _ret_body, -2);
  meta := unzip_file (tmp, 'docProps/app.xml');
  file_delete (tmp, 1);
  if (meta is null)
    return 0;
  xt := xtree_doc (meta);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/ms_doc2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));

  string_to_file (tmp, _ret_body, -2);
  meta := unzip_file (tmp, 'docProps/core.xml');
  file_delete (tmp, 1);
  if (meta is null)
    return 0;
  xt := xtree_doc (meta);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/ms_doc2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), null);
  return 1;
}
;


create procedure DB.DBA.RDF_LOAD_OO_DOCUMENT (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare meta, tmp varchar;
  declare xt, xd any;
  if (__proc_exists ('unzip_file', 2) is null)
    return 0;
  tmp := tmp_file_name ('rdfm', 'odt');
  string_to_file (tmp, _ret_body, -2);
  meta := unzip_file (tmp, 'meta.xml');
  file_delete (tmp, 1);
  if (meta is null)
    return 0;
  xt := xtree_doc (meta);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/oo2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), null);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_OO_DOCUMENT2 (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare meta, tmp varchar;
  declare xt, xd any;
  xt := xtree_doc (_ret_body);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/fod2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), null);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_YAHOO_TRAFFIC_DATA (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare meta, tmp varchar;
  declare xt, xd any;

  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  xt := xtree_doc (_ret_body);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/yahoo_trf2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), null);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_ICAL (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare meta, tmp varchar;
  declare xt, xd any;

  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  xt := xml_tree_doc (DB.DBA.IMC_TO_XML (_ret_body));
  xml_tree_doc_encoding (xt, 'UTF-8');
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/ics2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), null);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_WEBCAL (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  return DB.DBA.RDF_LOAD_ICAL (graph_iri, new_origin_uri, dest, _ret_body, aq, ps, _key, opts);
}
;

create procedure DB.DBA.RDF_LOAD_BESTBUY (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xd, xt, url, tmp, api_key, asin, hdr, exif any;
	declare pos, is_sku, is_store integer;

  asin := null;
  is_sku := 0;
	is_store := 0;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
	if (new_origin_uri like 'http://stores.bestbuy.com/%')
	{
		declare arr any;
		arr := sprintf_inverse (new_origin_uri, 'http://stores.bestbuy.com/%s', 0);
		asin := arr[0];
		pos := strchr(asin, '/');
		if (pos is not null)
			asin := left(asin, pos);
		pos := strchr(asin, '?');
		if (pos is not null)
			asin := left(asin, pos);
		is_store := 1;
	}
	else if (new_origin_uri like 'http://%.bestbuy.com/site/olspage.jsp?%' or new_origin_uri like 'http://%.bestbuy.com/%/%?%')
    {
      declare arr any;
      arr := WS.WS.PARSE_URI (new_origin_uri);
      arr := arr[4];
      if (arr = '')
	return 0;
      arr := split_and_decode (arr);
      if (length (arr) and mod (length (arr), 2) = 0)
	asin := get_keyword ('id', arr);
      if (asin not like '[0-9]+')
	{
          asin := get_keyword ('skuId', arr);
			if (asin not like '[0-9]+')
				return 0;
	  is_sku := 1;
	}
    }
  else if (new_origin_uri like 'http://%.bestbuy.com/%/%/%/')
    {
      declare arr any;
      arr := sprintf_inverse (new_origin_uri, 'http://%s.bestbuy.com/%s/%s/%s/', 0);
      if (length (arr) = 4)
	{
	  asin := arr[3];
	  is_sku := 1;
	}
      else
	return 0;
    }
  else
    {
      return 0;
    }
  api_key := _key;
  if (asin is null or not isstring (api_key))
    return 0;
  if (is_sku)
    url := sprintf ('http://api.remix.bestbuy.com/v1/products/%s.xml?apiKey=%s', asin, api_key);
  else
    url := sprintf ('http://api.remix.bestbuy.com/v1/products(productId=%s)?apiKey=%s&format=xml&show=all', asin, api_key);
	if (is_store)
		url := sprintf ('http://api.remix.bestbuy.com/v1/stores(storeId=%s)?apiKey=%s&format=xml&show=all', asin, api_key);
  tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
  if (hdr[0] not like 'HTTP/1._ 200 %')
    signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
  xd := xtree_doc (tmp);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/bestbuy2rdf.xsl', xd,
		vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'currentDateTime', cast(date_iso8601(now()) as varchar), 'is_store', cast(is_store as varchar)));
  xd := serialize_to_UTF8_xml (xt);
  delete from DB.DBA.RDF_QUAD where g =  iri_to_id(new_origin_uri); 
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_AMAZON_QRY_SGN (in canon any, in secret_key any)
{
  declare url, StringToSign, hmacKey, signed any;

  StringToSign := concat('GET\necs.amazonaws.com\n/onca/xml\n', canon);
  if (not xenc_key_exists ('amazon_key'))
    hmacKey := xenc_key_RAW_read ('amazon_key', encode_base64(secret_key));
  signed := xenc_hmac_sha1_digest (StringToSign, 'amazon_key');
  xenc_key_remove ('amazon_key');
  signed := replace(replace(signed, '+', '%2B'), '=', '%3D');
  url := concat('http://ecs.amazonaws.com/onca/xml?', canon, '&Signature=', signed);
  return url;
}
;

create procedure DB.DBA.RDF_LOAD_AMAZON_ARTICLE (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare index1, xd, xd_utf8, xt, url, tmp, api_key, asin, hdr, exif, secret_key, datenow, canon, StringToSign, hmacKey, signed any;
  declare pos, is_wish_list integer;
  declare associate_key varchar;
  asin := null;
  associate_key := null;
  is_wish_list := 0;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  if (new_origin_uri like 'http://%amazon.%/gp/product/product-description/%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://%samazon.%s/gp/product/product-description/%s', 0);
      asin := rtrim (tmp[2], '/');
    }
  else if (new_origin_uri like 'http://%amazon.%/gp/product/%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://%samazon.%s/gp/product/%s', 0);
      asin := rtrim (tmp[2], '/');
    }
  else if (new_origin_uri like 'http://%amazon.%/gp/registry/wishlist/%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://%samazon.%s/gp/registry/wishlist/%s', 0);
      asin := rtrim (tmp[2], '/');
      is_wish_list := 1;
    }
    else if (new_origin_uri like 'http://%amazon.%/s?%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://%samazon.%s/s?%skeywords=%s', 0);
      asin := tmp[3];
      if (strchr(asin, '&') is not NULL)
      {
        tmp := sprintf_inverse (asin, '%s&%s', 0);
        asin := tmp[0];
        if (strchr(tmp[1], 'index=') is not NULL)
        {
            tmp := sprintf_inverse (tmp[1], 'index=%s', 0);
            index1 := tmp[0];
            if (strchr(index1, '&') is not NULL)
            {
                index1 := left(index1, strchr(index1, '&'));
            }
        }
        else
        {
            index1 := 'None';
        }
      }
      is_wish_list := 2;
    }
  else if (new_origin_uri like 'http://%amazon.%/o/ASIN/%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://%samazon.%s/o/ASIN/%s', 0);
      asin := rtrim (tmp[2], '/');
    }
  else if (new_origin_uri like 'http://%amazon.%/%/product-reviews/%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://%samazon.%s/%s/product-reviews/%s', 0);
      asin := tmp[3];
      pos := strchr(asin, '?');
      if (pos is not null)
	{
	  asin := left(asin, pos);
	}
    }
  else if (new_origin_uri like 'http://%amazon.%/%/dp/%\\%3%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://%samazon.%s/%s/dp/%s%%3%s', 0);
      asin := tmp[3];
    }
    else if (new_origin_uri like 'http://%amazon.%/dp/%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://%samazon.%s/dp/%s', 0);
      asin := tmp[2];
      pos := strchr(asin, '?');
		if (pos is not null)
			asin := left(asin, pos);
    }
  else if (new_origin_uri like 'http://%amazon.%/%/dp/%/%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://%samazon.%s/%s/dp/%s/%s', 0);
      asin := tmp[3];
    }
  else if (new_origin_uri like 'http://%amazon.%/%/dp/%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://%samazon.%s/%s/dp/%s', 0);
      asin := tmp[3];
    }
  else if (new_origin_uri like 'http://%amazon.%/exec/obidos/ASIN/%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://%samazon.%s/exec/obidos/ASIN/%s', 0);
      asin := rtrim (tmp[2], '/');
    }
  else if (new_origin_uri like 'http://%amazon.%/exec/obidos/tg/detail/-/%/%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://%samazon.%s/exec/obidos/tg/detail/-/%s/%s', 0);
      asin := tmp[2];
    }
  else
    {
      return 0;
    }
  pos := strchr(asin, '/');
  if (pos is not null)
    {
      asin := left(asin, pos);
    }

  api_key := _key;
  secret_key := null;
  if (isarray (opts) and 0 = mod (length(opts), 2))
    {
      secret_key := get_keyword ('secret_key', opts);
      associate_key := get_keyword ('associate_key', opts);
    }
  if ((0 = length (api_key)) or (0 = length (secret_key)))
    return 0;
  if (asin is null)
    return 0;

  datenow := replace(date_iso8601 (dt_set_tz (now(), 0)), ':', '%3A');
  -- Note: Query parameter/value pairs *must* be sorted by byte value before the query string is signed.
  --       Lowercase parameters will come after uppercase ones in the canonical query string.
  if (is_wish_list = 1)
  {
    canon := sprintf('AWSAccessKeyId=%s&Condition=All&ListId=%s&ListType=WishList&MerchantId=All&Operation=ListLookup&ResponseGroup=ItemAttributes%%2COffers%%2CReviews&Service=AWSECommerceService&SignatureMethod=HmacSHA1&Timestamp=%s', api_key, asin, datenow);
  }
  else if (is_wish_list = 2)
  {
    canon := sprintf('AWSAccessKeyId=%s&Availability=Available&Condition=All&Keywords=%s&MerchantId=All&Operation=ItemSearch&ResponseGroup=ItemAttributes%%2COffers%%2CReviews&SearchIndex=%s&Service=AWSECommerceService&SignatureMethod=HmacSHA1&Timestamp=%s', api_key, asin, index1, datenow);
  }
  else
  {
      canon := sprintf('AWSAccessKeyId=%s&Condition=All&ItemId=%s&MerchantId=All&Operation=ItemLookup&ResponseGroup=ItemAttributes%%2COffers%%2CReviews&Service=AWSECommerceService&SignatureMethod=HmacSHA1&Timestamp=%s', api_key, asin, datenow);
  }
  url := DB.DBA.RDF_LOAD_AMAZON_QRY_SGN (canon, secret_key);
  tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
  if (hdr[0] not like 'HTTP/1._ 200 %')
    signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
  xd := xtree_doc (tmp);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/amazon2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'asin', asin, 'currentDateTime', cast(date_iso8601(now()) as varchar), 'wish_list', cast(is_wish_list as varchar), 'associate_key', associate_key));
  xd_utf8 := serialize_to_UTF8_xml (xt);
   {
     declare mlist varchar;
     declare xdMerchants, merchantIds any;
     declare strTmp varchar;

     -- Extract the merchantIds contained in initial AWS query response
     mlist := '';
     merchantIds := xpath_eval('//Offer/Merchant/MerchantId', xd, 0);
     foreach (any mid in merchantIds) do
     {
       declare id varchar;
       id := cast(mid as varchar);
       if (length (mlist))
         mlist := mlist || '%2C';
       mlist := mlist || id ;
     }

     -- Query AWS to get the names of these merchants
     canon := sprintf('AWSAccessKeyId=%s&Operation=SellerLookup&SellerId=%s&Service=AWSECommerceService&SignatureMethod=HmacSHA1&Timestamp=%s',
  	api_key, mlist, datenow);
     url := DB.DBA.RDF_LOAD_AMAZON_QRY_SGN (canon, secret_key);
     tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
     if (hdr[0] not like 'HTTP/1._ 200 %')
     --  signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
     --  leave legalName of gr:BusinessEntity instances as MERCHANTID_<merchantId>
       goto skip_merchantid2name;

     xdMerchants := xtree_doc (tmp);

     foreach (any mid in merchantIds) do
     {
       declare id, sellerName varchar;
       declare sName, sNickname any;
       id := cast(mid as varchar);
       sellerName := '';
       sName := xpath_eval('//Seller[SellerId="' || id || '"]/SellerName', xdMerchants);
       sNickname := xpath_eval('//Seller[SellerId="' || id || '"]/Nickname', xdMerchants);

       if (sName is not null)
	 sellerName := cast (sName as varchar);
       else if (sNickname is not null)
	 sellerName := cast (sNickname as varchar);

      -- Replace MERCHANTID_xxx placeholders with seller name
      if (length(sellerName))
       xd_utf8 := replace (xd_utf8, 'MERCHANTID_' || id, sellerName);
     }
   }
skip_merchantid2name:

  delete from DB.DBA.RDF_QUAD where g = iri_to_id (coalesce (dest, graph_iri));
  DB.DBA.RM_RDF_LOAD_RDFXML (xd_utf8, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_OPENSTREETMAP (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xd, xt, url, tmp, lon1, lat1, hdr, exif any;
	declare zoom, layers varchar;
	declare lat, lon, left_point, bottom_point, right_point, top_point float;
	declare pos integer;

	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	if (new_origin_uri like 'http://%openstreetmap.org/%?lat=%&lon=%')
	{

		tmp := sprintf_inverse (new_origin_uri, 'http://%sopenstreetmap.org/%s?lat=%s&lon=%s', 0);
		lat1 := tmp[2];
		lon1 := tmp[3];
		pos := strchr (lon1, '&');
		if (pos > 0)
			lon1 := subseq(lon1, 0, pos);
	}
	else if (new_origin_uri like 'http://%openstreetmap.org/%?mlat=%&mlon=%')
	{

		tmp := sprintf_inverse (new_origin_uri, 'http://%sopenstreetmap.org/%s?mlat=%s&mlon=%s', 0);
		lat1 := tmp[0];
		lon1 := tmp[1];
		pos := strchr (lon1, '&');
		if (pos > 0)
			lon1 := subseq(lon1, 0, pos);
	}
	else
		return 0;

	{
		lat := atof(lat1);
		lon := atof(lon1);
		--zoom := atoi(tmp[2]);
		--layers := tmp[3];
		left_point := lon - 0.01;
		right_point := lon + 0.01;
		bottom_point := lat - 0.01;
		top_point := lat + 0.01;
		url := sprintf('http://api.openstreetmap.org/api/0.6/map?bbox=%f,%f,%f,%f', left_point, bottom_point, right_point, top_point);
	}
	tmp := http_client(url, proxy=>get_keyword_ucase ('get:proxy', opts));
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/openstreet2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'lon', lon1, 'lat', lat1));
	xd := serialize_to_UTF8_xml (xt);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_USTREAM (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xd, xt, url, tmp, api_key, img_id, hdr, what, pos any;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE); 	
		return 0;
	};
	api_key := _key;
	if (not isstring (api_key))
		return 0;
	if (new_origin_uri like 'http://www.ustream.tv/channel/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.ustream.tv/channel/%s', 0);
		if (tmp is null)
		    return 0;
		img_id := tmp[0];
		pos := strchr(img_id, '/');
		if (pos is not null)
                    img_id := left(img_id, pos);
                url := sprintf('http://api.ustream.tv/xml/channel/%s/getInfo?key=%s', img_id, api_key);
                what := 'channel';
	}
	else if (new_origin_uri like 'http://www.ustream.tv/user/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.ustream.tv/user/%s', 0);
		if (tmp is null)
		    return 0;
		img_id := tmp[0];
		pos := strchr(img_id, '/');
		if (pos is not null)
                    img_id := left(img_id, pos);
                url := sprintf('http://api.ustream.tv/xml/user/%s/getInfo?key=%s', img_id, api_key);
                what := 'user';
	}
	else if (new_origin_uri like 'http://www.ustream.tv/recorded/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://www.ustream.tv/recorded/%s', 0);
		if (tmp is null)
		    return 0;
		img_id := tmp[0];
		pos := strchr(img_id, '/');
		if (pos is not null)
                    img_id := left(img_id, pos);
                url := sprintf('http://api.ustream.tv/xml/video/%s/getInfo?key=%s', img_id, api_key);
                what := 'video';
	}
	else
	    return 0;
	tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
	if (hdr[0] not like 'HTTP/1._ 200 %')
		signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
	xd := xtree_doc (tmp);
	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/ustream2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'what', what));
	xd := serialize_to_UTF8_xml (xt);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_FLICKR_IMG (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
	declare xd, xt, url, tmp, api_key, img_id, hdr, exif any;
	declare exit handler for sqlstate '*'
	{
	  DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
		return 0;
	};
	api_key := _key;
	if (not isstring (api_key))
		return 0;
	if (new_origin_uri like 'http://farm%.static.flickr.com/%/%')
	{
		tmp := sprintf_inverse (new_origin_uri, 'http://farm%s.static.flickr.com/%s/%s_%s.%s', 0);
		if (tmp is null or length (tmp) <> 5)
			return 0;
		img_id := tmp[2];
	}
	else if (new_origin_uri like 'http://www.flickr.com/photos/%/%')
	{
		declare pos	integer;
		tmp := sprintf_inverse (new_origin_uri, 'http://www.flickr.com/photos/%s/%s', 0);
		img_id := tmp[1];
		pos := strchr(img_id, '/');
		if (pos is not null)
			img_id := left(img_id, pos);
	}
	else
		return 0;
	url := sprintf ('http://api.flickr.com/services/rest/?method=flickr.photos.getInfo&photo_id=%s&api_key=%s', img_id, api_key);
	tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
	if (hdr[0] not like 'HTTP/1._ 200 %')
		signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
	xd := xtree_doc (tmp);
	exif := xtree_doc ('<rsp/>');
	{
		declare exit handler for sqlstate '*' { goto ende; };
		url := sprintf ('http://api.flickr.com/services/rest/?method=flickr.photos.getExif&photo_id=%s&api_key=%s',
		img_id, api_key);
		tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
		if (hdr[0] like 'HTTP/1._ 200 %')
			exif := xtree_doc (tmp);
		ende:;
	}

	xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/flickr2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'exif', exif));
	xd := serialize_to_UTF8_xml (xt);
	DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
	return 1;
}
;

create procedure DB.DBA.RDF_LOAD_EBAY_ARTICLE (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout ser_key any, inout opts any)
{
  declare xd, xd_utf8, xt, url, tmp, api_key, item_id, hdr, karr, use_sandbox, user_id, node any;
  declare product_id varchar;
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };

  use_sandbox := 0;

  if (new_origin_uri like 'http://cgi.sandbox.ebay.com/%&item=%&%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://cgi.sandbox.ebay.com/%s&item=%s&%s', 0);
      use_sandbox := 1;
    }
  else if (new_origin_uri like 'http://cgi.ebay.com/%QQitemZ%QQ%')
    tmp := sprintf_inverse (new_origin_uri, 'http://cgi.ebay.com/%sQQitemZ%sQQ%s', 0);
  else if (new_origin_uri like 'http://cgi.ebay.com/%/eBayISAPI.dll?ViewItem&item=%')
    tmp := sprintf_inverse (new_origin_uri, 'http://cgi.ebay.com/%s/eBayISAPI.dll?ViewItem&item=%s', 0);
  else if (new_origin_uri like 'http://cgi.ebay.com/%/%?%')
    tmp := sprintf_inverse (new_origin_uri, 'http://cgi.ebay.com/%s/%s?%s', 0);
  else
    return 0;

  api_key := ser_key;

  if (tmp is null or not isstring (api_key))  -- length (tmp) <> 3
    return 0;

  item_id := tmp[1];

  url := sprintf ('http://open.api.ebay.com/shopping?callname=GetSingleItem&responseencoding=XML&appid=%s&siteid=0&version=515&ItemID=%s&IncludeSelector=Description,Details,ItemSpecifics', api_key, item_id);
  tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
  if (hdr[0] not like 'HTTP/1._ 200 %')
    signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');

  xd := xtree_doc (tmp);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/ebay2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'currentDateTime', cast(date_iso8601(now()) as varchar)));
  xd_utf8 := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd_utf8, new_origin_uri, coalesce (dest, graph_iri));

  -- Get any reviews
  node := xpath_eval('//Item/ProductID[@type="Reference"]', xd);
  product_id := cast (node as varchar);
  if (not length(product_id))
    goto skipReviews;

  url := sprintf ('http://open.api.ebay.com/shopping?callname=FindReviewsAndGuides&responseencoding=XML&appid=%s&siteid=0&version=515&ProductID.type=Reference&ProductID.value=%s', api_key, product_id);
  tmp := http_client_ext (url, headers=>hdr, proxy=>get_keyword_ucase ('get:proxy', opts));

  if (hdr[0] not like 'HTTP/1._ 200 %')
    goto skipReviews;

  xd := xtree_doc (tmp);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/ebay2rdf.xsl', xd, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri), 'currentDateTime', cast(date_iso8601(now()) as varchar)));
  xd := serialize_to_UTF8_xml (xt);

  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));

skipReviews:
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_DAV_META (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout ser_key any, inout opts any)
{
  declare xd, localdest, groupdest, dep any;
  localdest := coalesce (dest, graph_iri);
  groupdest := get_keyword_ucase ('get:group-destination', opts);
  xd := DAV_EXTRACT_META_AS_RDF_XML (new_origin_uri, _ret_body);
  if (xd is not null)
    {
      DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, localdest);
      if (groupdest is not null)
        DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, groupdest);
      return 1;
    }
  dep := (sparql define input:storage ""
     select (sql:VECTOR_AGG (?o))
    where { graph `iri(?:localdest)` {
            `iri(?:localdest)` <http://www.w3.org/2000/01/rdf-schema#seeAlso> ?o .
            filter (isIRI (?o)) } } );
  if (length (dep) > 0)
    {
      return vector ('seeAlso', dep);
    }
  return 1;
}
;

create procedure DB.DBA.RDF_MAPPER_CACHE_CHECK (in url varchar, in top_url varchar, out old_etag varchar, out old_last_modified any)
{
  declare old_exp_is_true, old_expiration, old_read_count any;
  whenever not found goto no_record;
  select HS_EXP_IS_TRUE, HS_EXPIRATION, HS_LAST_MODIFIED, HS_LAST_ETAG, HS_READ_COUNT
      into old_exp_is_true, old_expiration, old_last_modified, old_etag, old_read_count
      from DB.DBA.SYS_HTTP_SPONGE where HS_FROM_IRI = url and HS_PARSER = 'DB.DBA.RDF_LOAD_HTTP_RESPONSE';
  -- as we are at point we load everything we always do re-load
no_record:
  return 0;
}
;

create procedure
RDF_MAPPER_CACHE_REGISTER (in url varchar, in top_url varchar, inout hdr any,
                   in old_last_modified any, in download_size int, in load_msec int)
{
  declare explicit_refresh, new_expiration, ret_content_type, ret_etag, ret_date, ret_expires, ret_last_modif,
      ret_dt_date, ret_dt_expires, ret_dt_last_modified any;

  if (not isarray (hdr))
    return;

  url := WS.WS.EXPAND_URL (top_url, url);
  explicit_refresh := null;
  new_expiration := now ();
  DB.DBA.SYS_HTTP_SPONGE_GET_CACHE_PARAMS (explicit_refresh, old_last_modified,
      hdr, new_expiration, ret_content_type, ret_etag, ret_date, ret_expires, ret_last_modif,
       ret_dt_date, ret_dt_expires, ret_dt_last_modified);
  insert replacing DB.DBA.SYS_HTTP_SPONGE (
      HS_LAST_LOAD,
      HS_LAST_ETAG,
      HS_LAST_READ,
      HS_EXP_IS_TRUE,
      HS_EXPIRATION,
      HS_LAST_MODIFIED,
      HS_DOWNLOAD_SIZE,
      HS_DOWNLOAD_MSEC_TIME,
      HS_READ_COUNT,
      HS_SQL_STATE,
      HS_SQL_MESSAGE,
      HS_LOCAL_IRI,
      HS_PARSER,
      HS_ORIGIN_URI,
      HS_ORIGIN_LOGIN,
      HS_FROM_IRI)
      values
      (
       now (),
       ret_etag,
       now(),
       case (isnull (ret_dt_expires)) when 1 then 0 else 1 end,
       coalesce (ret_dt_expires, new_expiration, now()),
       ret_dt_last_modified,
       download_size,
       load_msec,
       1,
       NULL,
       NULL,
       url,
       'DB.DBA.RDF_LOAD_HTTP_RESPONSE',
       url,
       NULL,
       top_url
       );

  return;
}
;

create procedure DB.DBA.RDF_LOAD_OPENSOCIAL_PERSON (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare xt, xd, tmp, cnt, hdr any;
  declare mail, pwd, auth, auth_header varchar;

  mail := get_keyword ('email', opts, null);
  pwd := get_keyword ('password', opts, null);
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  auth_header := null;
  if (length (mail) + length (pwd))
    {
      cnt := http_client (url=>'https://www.google.com/accounts/ClientLogin',
        http_method=>'POST', body=>sprintf ('Email=%U&Passwd=%U&source=OpenLink-Sponger-1&service=ot', mail, pwd),
	proxy=>get_keyword_ucase ('get:proxy', opts));
      if (cnt like 'Error=%')
    return 0;
      cnt := replace (cnt, '\r', '\n');
      cnt := replace (cnt, '\n\n', '\n');
      tmp := split_and_decode (cnt, 0, '\0\0\n=');
      auth := get_keyword ('Auth', tmp);
      if (auth is not null)
    auth_header := 'Authorization: GoogleLogin auth='||auth;
    }
  cnt := DB.DBA.RDF_HTTP_URL_GET (new_origin_uri, new_origin_uri, hdr, 'GET', auth_header, proxy=>get_keyword_ucase ('get:proxy', opts));
  if (hdr[0] not like  'HTTP/1._ 200 %')
    return 0;
  xd := xtree_doc (cnt);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/ospeople2rdf.xsl', xd,
    vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), null);
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_WIKIPEDIA_ARTICLE
    (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
         inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
    declare get_uri, body, dbpiri any;
    declare code, base any;
    get_uri := split_and_decode (new_origin_uri, 0, '\0\0/');
    get_uri := get_uri[length (get_uri) - 1];
    get_uri := split_and_decode (get_uri)[0];
    base := get_keyword ('DBpediaBase', opts);
      {
	declare exit handler for sqlstate '*'
	  {
	    DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
	    return 0;
	  };
	body := sprintf('<?xml version=\"1.0\" encoding=\"utf-8\"?>
	        <rdf:RDF
	        xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"
	        xmlns:foaf=\"http://xmlns.com/foaf/0.1/\">
	        <foaf:Document rdf:about=\"%s\">
            <foaf:primaryTopic rdf:resource=\"http://dbpedia.org/resource/%U\"/>
            </foaf:Document>
            </rdf:RDF>', new_origin_uri, get_uri);
	--body := http_get ('http://dbpedia.org/data/'|| get_uri, null, 'GET', 'Accept: application/xml, */*');
	--delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (coalesce (dest, graph_iri));
	DB.DBA.RM_RDF_LOAD_RDFXML (body, new_origin_uri, coalesce (dest, graph_iri));
      }
    if (base is not null and isstring (file_stat (base)) and __proc_exists ('php_str', 2) is not null)
      {
	declare exit handler for sqlstate '*'
	  {
	    goto fallback;
	  };
	  code := RDFMAP_DBPEDIA_EXTRACT_PHP (base, get_uri);
	  body := php_str (code);
	  if (length (body) > 2 and body[0] = 239 and body[1] = 187 and body[2] = 191)
	    body := subseq (body, 3);
	  dbpiri := sprintf ('http://dbpedia.org/resource/%U', get_uri);
	  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (coalesce (dest, dbpiri));
	  DB.DBA.TTLP (body, dbpiri, dbpiri);
	  insert soft DB.DBA.SYS_HTTP_SPONGE (HS_LOCAL_IRI, HS_PARSER, HS_ORIGIN_URI, HS_ORIGIN_LOGIN, HS_LAST_LOAD, HS_EXPIRATION)
		  values (dbpiri, 'DB.DBA.RDF_LOAD_HTTP_RESPONSE', dbpiri, dbpiri, now(), dateadd ('hour', 1, now ()));
      }
    fallback:
    DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), null);
    return 1;
}
;


create procedure DB.DBA.RDF_DO_XSLT_AND_LOAD (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    in xt any, inout mdta any, in xslt_sheet varchar, in what varchar, in base varchar, inout opts any)
{
  declare xslt_uri varchar;
  declare xslt_body, xd, media, ret, xsl_doc any;
  xsl_doc := null;
  ret := null;
  declare exit handler for sqlstate '*' { goto try_next; };
  xslt_uri := WS.WS.EXPAND_URL (base, cast (xslt_sheet as varchar));
  {
    declare exit handler for sqlstate '*'
    {
      if (registry_get ('__sparql_sponge_use_w3c_xslt') = 'on')
    goto try_w3c;
      else
    goto try_next;
    };
    xslt_stale (xslt_uri);
    {
      -- /* we try to get xslt with content negotiation */
      declare exit handler for sqlstate '*' {
    goto try_next;
      };
      xslt_body := http_get (xslt_uri, null, 'GET', 'Accept: application/xml, */*', null, get_keyword_ucase ('get:proxy', opts));
      if (length (xslt_body))
    {
      declare exit handler for sqlstate '*' {
         if (registry_get ('__sparql_sponge_use_w3c_xslt') = 'on')
           goto try_w3c;
         else
           goto try_next;
      };
      xslt_sheet (xslt_uri, xtree_doc (xslt_body, 0, xslt_uri));
    }
    }
    xd := DB.DBA.RDF_MAPPER_XSLT (xslt_uri, xt);
    xsl_doc := xd;
    if (what <> '')
      goto try_next;
    if (xpath_eval ('count(/RDF/*)', xd) > 0)
      {
    mdta := mdta + 1;
      }
    media := xml_tree_doc_media_type (xd);
    xd := serialize_to_UTF8_xml (xd);
    if (media = 'text/rdf+n3')
      {
    DB.DBA.TTLP (xd, base, coalesce (dest, graph_iri));
    mdta := mdta + 1;
      }
    else
      DB.DBA.RDF_LOAD_RDFXML (xd, base, coalesce (dest, graph_iri));
    goto try_next;
  }
  try_w3c:
  if (0)
    log_message (sprintf ('Using w3c xslt=[%s]', xslt_uri));
  xd := http_client (sprintf ('http://www.w3.org/2000/06/webdata/xslt?xslfile=%U;xmlfile=%U', xslt_uri, new_origin_uri),
    	proxy=>get_keyword_ucase ('get:proxy', opts));
  xsl_doc := xtree_doc (xd);
  if (what <> '')
    goto try_next;
  if (xpath_eval ('count(/RDF/*)', xsl_doc) > 0)
    {
      mdta := mdta + 1;
    }
  xslt_done:
  DB.DBA.RDF_LOAD_RDFXML (xd, base, coalesce (dest, graph_iri));
  try_next:;
  if (isentity (xsl_doc))
    {
      if (what = 'ns')
        {
      ret  := xpath_eval ('[ xmlns:dv="http://www.w3.org/2003/g/data-view#" '||
        ' xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ] '||
        '//dv:namespaceTransformation/@rdf:resource', xsl_doc, 0);
        }
      else if (what = 'pf')
        {
          ret := xpath_eval ('[ xmlns:dv="http://www.w3.org/2003/g/data-view#" '||
        ' xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ] '||
        '//dv:profileTransformation/@rdf:resource', xsl_doc, 0);
        }
    }
  return ret;
};

create procedure DB.DBA.RDF_MAPPER_EXPN_URLS (in all_xslt any, in base varchar)
{
  declare ret any;
  ret := vector ();
  foreach (any _xslt in all_xslt) do
    {
      declare split any;
      split := split_and_decode (cast (_xslt as varchar),0, '\0\0 ');
      foreach (any xslt in split) do
        {
      if (length (xslt))
        {
          xslt := WS.WS.EXPAND_URL (base, xslt);
          ret := vector_concat (ret, vector (xslt));
        }
    }
    }
  return ret;
};

create procedure DB.DBA.RDF_LOAD_GRDDL_REC (in doc_base varchar, in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    in xt any, inout mdta any, inout visited any, in what varchar, in lev int, inout opts any)
{
  declare pf_docs, ns_doc, barr any;
  declare profile varchar;
  declare profs, hdr, ret_arr any;
  declare base_url, ns_url varchar;
  declare tf1, tf2, tf3, all_xslt, ns_trf, profile_trf  any;

  -- we limit up to 100
  if (lev > 100)
    return null;

  lev := lev + 1;

  ret_arr := null;
  pf_docs := null;
  ns_doc := tf1 := tf2 := tf3 := null;
  profile_trf := ns_trf := null;

  -- take base & PF & NS URL
  base_url := cast (xpath_eval ('/html/head/base/@href', xt) as varchar);
  if (length (base_url) = 0)
    {
      base_url := cast (xpath_eval ('/*[1]/@xml:base', xt) as varchar);
    }

  if (length (base_url) = 0)
     base_url := doc_base;

  barr := WS.WS.PARSE_URI (base_url);
  -- if base is relative
  if (barr [0] = '')
    base_url := WS.WS.EXPAND_URL (doc_base, base_url);

  profile := cast (xpath_eval ('/html/head/@profile', xt) as varchar);
  profs := null;
  if (profile is not null)
    profs := split_and_decode (profile, 0, '\0\0 ');

  ns_url := cast (xpath_eval ('namespace-uri (/*[1])', xt) as varchar);
  -- /* known NS */
  if (
      strstr (ns_url, 'http://www.w3.org/2003/g/data-view') is not null
      or ns_url = 'http://www.w3.org/1999/xhtml'
      or ns_url = 'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
      or ns_url = 'http://www.w3.org/2005/Atom'
      )
    ns_url := null;

  -- take 'transform' attributes
  if (strstr (profile, 'http://www.w3.org/2003/g/data-view') is not null)
    {
      tf1 := xpath_eval ('/html/head/link[@rel="transformation"]/@href', xt, 0);
      tf2 := xpath_eval ('//a[contains(concat(" ",@rel," "), " transformation ")]/@href', xt, 0);
    }
  -- /* xml doc */
  tf3 := xpath_eval ('[ xmlns:dv="http://www.w3.org/2003/g/data-view#" ] /*[1]/@dv:transformation', xt, 0);

  -- take NS transform
  if (length (ns_url) and strstr (visited, ' ' || ns_url || ' ') is null)
    {
      declare uarr, stat, msg, dta, meta any;
      declare cnt, tmp_url, tmp_xt, tmp_prof, tmp_profs any;

      tmp_xt := null;
      visited := visited || ' ' || ns_url || ' ';
      uarr := WS.WS.PARSE_URI (ns_url);
      uarr[5] := '';
      ns_url := vspx_uri_compose (uarr);

      declare exit handler for sqlstate '*' {
         goto no_ns_doc;
      };

      hdr := null;
      tmp_xt := null;
      if (0)
	log_message (sprintf ('NS get %s', ns_url));
      cnt := DB.DBA.RDF_HTTP_URL_GET (ns_url, base_url, hdr, 'GET', 'Accept: application/rdf+xml, application/xml, */*', proxy=>get_keyword_ucase ('get:proxy', opts));
      tmp_xt := xtree_doc (cnt, 0);

      ns_doc := vector (vector (ns_url, tmp_xt));

      ns_trf := xpath_eval ('[ xmlns:dv="http://www.w3.org/2003/g/data-view#" '||
      ' xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ] '||
      '//dv:namespaceTransformation/@rdf:resource', tmp_xt, 0);
      ns_trf := DB.DBA.RDF_MAPPER_EXPN_URLS (ns_trf, ns_url);
      no_ns_doc:;
    }

  -- take PF transform
  foreach (any prof in profs) do
    {
      declare prof_base any;
      if (length (prof) = 0)
        goto next_prof_1;
      prof_base := null;
      prof := WS.WS.EXPAND_URL (base_url, prof);
      declare cnt, tmp_url, tmp_xt, tmp_prof, tmp_profs any;
      declare exit handler for sqlstate '*' {
    goto next_prof_1;
      };
      hdr := null;
      tmp_xt := null;
      if (strstr (prof, 'http://www.w3.org/2003/g/data-view') is not null)
        goto next_prof_1;
      if (0)
        log_message (sprintf ('PF get %s', prof));
      cnt := DB.DBA.RDF_HTTP_URL_GET (prof, base_url, hdr, 'GET', 'Accept: */*', proxy=>get_keyword_ucase ('get:proxy', opts));
      tmp_xt := xtree_doc (cnt, 0);

      pf_docs := vector_concat (pf_docs, vector (vector (prof, tmp_xt)));

      prof_base := cast (xpath_eval ('/html/head/base/@href', tmp_xt) as varchar);
      if (length (prof_base) = 0)
        {
      prof_base := cast (xpath_eval ('/*[1]/@xml:base', tmp_xt) as varchar);
    }
      if (length (prof_base) = 0)
        prof_base := prof;

      tmp_prof := xpath_eval (
      '//*[contains (concat (" ", @rel, " "), " profileTransformation ")]/@href', tmp_xt, 0);
      --  get here profileTransformation and push into a profile_trf
      tmp_prof := DB.DBA.RDF_MAPPER_EXPN_URLS (tmp_prof, prof_base);
      profile_trf := vector_concat (profile_trf, tmp_prof);

      tmp_prof := xpath_eval ('[ xmlns:dv="http://www.w3.org/2003/g/data-view#" '||
    ' xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ] '||
    '//dv:profileTransformation/@rdf:resource', tmp_xt, 0);
      tmp_prof := DB.DBA.RDF_MAPPER_EXPN_URLS (tmp_prof, prof_base);
      profile_trf := vector_concat (profile_trf, tmp_prof);
      next_prof_1:;
    }

  all_xslt := vector_concat (tf1, tf2, tf3, profile_trf, ns_trf);

  -- if no xslt, traverse the NF & PF docs above
  if (length (all_xslt) = 0)
    {
      declare ret any;
      foreach (any pf_item in pf_docs) do
        {
      ret := DB.DBA.RDF_LOAD_GRDDL_REC (base_url, graph_iri, pf_item[0], dest, pf_item[1], mdta, visited, 'pf', lev, opts);
      all_xslt := vector_concat (all_xslt, ret);
    }
      foreach (any ns_item in ns_doc) do
        {
      ret := DB.DBA.RDF_LOAD_GRDDL_REC (base_url, graph_iri, ns_item[0], dest, ns_item[1], mdta, visited, 'ns', lev, opts);
      all_xslt := vector_concat (all_xslt, ret);
    }
    }

  -- if any apply xslt
  foreach (any _xslt in all_xslt) do
    {
      declare ret, split any;
      split := split_and_decode (cast (_xslt as varchar),0, '\0\0 ');
      foreach (any xslt in split) do
        {
	  if (0)
	   log_message (sprintf ('TRANSFORM=[%s] XSLT=[%s]', new_origin_uri, xslt));
	  ret := DB.DBA.RDF_DO_XSLT_AND_LOAD (graph_iri, new_origin_uri, dest, xt, mdta, xslt, what, base_url, opts);
	  ret_arr := vector_concat (ret_arr, ret);
        }
    }
  return ret_arr;
};

--
-- /* RDFA comaptibility wrapper */
--
create procedure DB.DBA.RDF_LOAD_RDFA_1 (inout ret_body any, inout new_origin_uri varchar, inout thisgr varchar, in flag int)
{
  if (__proc_exists ('DB.DBA.RDF_LOAD_RDFA_WITH_IRI_TRANSLATION') is not null)
    DB.DBA.RDF_LOAD_RDFA_WITH_IRI_TRANSLATION (ret_body, new_origin_uri, thisgr, flag, 'DB.DBA.RM_XLAT_CONCAT', null);
  else
    DB.DBA.RDF_LOAD_RDFA (ret_body, new_origin_uri, thisgr, flag);
}
;


--
-- /* GRDDL filters, if signature changed web robot needs to be updated too */
--
create procedure DB.DBA.RDF_LOAD_HTML_RESPONSE (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  -- check to microformats
  declare xt_sav, xt, xd, profile, mdta, xslt_style, profs, profs_done, feed_url, xt_xml any;
  declare xmlnss, i, l, nss, rdf_url_arr, content, hdr, rdf_in_html, old_etag, old_last_modified any;
  declare ret_flag, is_grddl, download_size, load_msec int;
  declare get_feeds, add_html_meta, grddl_loop int;
  declare base_url, ns_url, reg, doc_base, proxy_iri, cset varchar;
  declare profile_trf, ns_trf, ext_profs, thisgr, cnt any;
  declare dict any;

  get_feeds := add_html_meta := 0;
  if (isarray (opts) and 0 = mod (length(opts), 2))
    {
      if (get_keyword ('get-feeds', opts) = 'yes')
        get_feeds := 1;
      if (get_keyword ('add-html-meta', opts) = 'yes')
        add_html_meta := 1;
    }
  set_user_id ('dba');
  mdta := 0;
  ret_flag := 1;
  hdr := null;
  xt_xml := null;
  profile_trf := vector ();
  ns_trf := vector ();
  ext_profs := vector ();
  grddl_loop := 0;
  if (registry_get ('__rdf_cartridges_original_doc_uri__') = '1')
    proxy_iri := new_origin_uri;
  else
    proxy_iri := DB.DBA.RDF_SPONGE_PROXY_IRI (new_origin_uri);

  declare exit handler for sqlstate '*'
    {
      goto no_microformats;
    };
  cset := coalesce (get_keyword ('charset', opts), current_charset ());
  cset := coalesce (cast(charset_canonical_name (cset) as varchar), current_charset ());
  xt_sav := xt := xtree_doc (ret_body, 2, '', cset);
  {
    declare exit handler for sqlstate '*' {
    xt_xml := null; goto no_xml_cont; };
    xt_xml := xtree_doc (ret_body, 0, '', cset);
    no_xml_cont:;
  }

  -- this maybe is not need to be here, as it's a kind of content negotiation
  rdf_url_arr  := xpath_eval ('//head/link[ @rel="meta" and contains (@type, "/rdf+") ]/@href', xt, 0);
  if (not length (rdf_url_arr))
    rdf_url_arr  := xpath_eval ('//head/link[ @rel="alternate" and contains (@type, "/rdf+") ]/@href', xt, 0);
  if (not length (rdf_url_arr))
    rdf_url_arr  := xpath_eval ('//head/link[ @rel="meta" ]/@href', xt, 0);

  if (length (rdf_url_arr))
    {
      declare rdf_url_inx int;
      declare ss any;
      rdf_url_inx := 0;
      dict := dict_new ();
      ss := string_output ();
      http ('@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n', ss);
      foreach (any rdf_url in rdf_url_arr) do
	{
	  declare ret_content_type any;
	  declare exit handler for sqlstate '*' { goto try_next_link; };
	  rdf_url := cast (rdf_url as varchar);
	  --if (RDF_MAPPER_CACHE_CHECK (rdf_url, new_origin_uri, old_etag, old_last_modified))
	  --  goto try_next_link;
	  if (dict_get (dict, rdf_url))
	    goto try_next_link;

	  http (sprintf ('<%s> rdfs:seeAlso <%s> .\n', new_origin_uri, WS.WS.EXPAND_URL (new_origin_uri, rdf_url)), ss);
	  goto try_next_link; -- we just expose seeAlso link

	  load_msec := msec_time ();
	  hdr := null;
	  content := DB.DBA.RDF_HTTP_URL_GET (rdf_url, new_origin_uri, hdr, 'GET', 'Accept: application/rdf+xml, text/rdf+n3, */*', proxy=>get_keyword_ucase ('get:proxy', opts));
	  load_msec := msec_time () - load_msec;
	  download_size := length (content);
	  ret_content_type := http_request_header (hdr, 'Content-Type', null, null);
	  ret_content_type := DB.DBA.RDF_SPONGE_GUESS_CONTENT_TYPE (new_origin_uri, ret_content_type, content);
	  if (strstr (ret_content_type, 'application/rdf+xml') is not null)
	     DB.DBA.RM_RDF_LOAD_RDFXML (content, new_origin_uri, coalesce (dest, graph_iri), 0);
	  else
	     DB.DBA.TTLP (content, new_origin_uri, coalesce (dest, graph_iri));
	  mdta := mdta + 1;
	  --RDF_MAPPER_CACHE_REGISTER (rdf_url, new_origin_uri, hdr, old_last_modified, download_size, load_msec);
	  dict_put (dict, rdf_url, 1);
	  rdf_url_inx := rdf_url_inx + 1;
	  ret_flag := -1;
	  try_next_link:;
	}
	DB.DBA.TTLP (ss, new_origin_uri, coalesce (dest, graph_iri));
    }

  -- sometimes RDF is inside the xhtml
  if (xpath_eval ('/html//rdf', xt) is not null and xt_xml is not null)
    {
      declare exit handler for sqlstate '*' { goto try_grddl; };
      rdf_in_html := xpath_eval ('/html//RDF', xt_xml, 0);
      foreach (any x in rdf_in_html) do
    {
        xd := serialize_to_UTF8_xml (x);
        DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri), 0);
      mdta := mdta + 1;
    }
    }

try_grddl:
  xmlnss := xmlnss_get (xt);
  nss := '<namespaces>';
  for (i := 0, l := length (xmlnss); i < l; i := i + 2)
    {
      nss := nss || sprintf ('<namespace prefix="%s">%s</namespace>', xmlnss[i], xmlnss[i+1]);
    }
  nss := nss || '</namespaces>';
  nss := xtree_doc (nss);

  is_grddl := 0;
  if (xpath_eval ('[ xmlns:dv="http://www.w3.org/2003/g/data-view#" ] /*[1]/@dv:transformation', xt) is not null)
    {
      if (xpath_eval ('/rdf', xt) is not null and xt_xml is not null)
    {
      declare exit handler for sqlstate '*' { goto not_rdf; };
          xd :=  DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/rdf_wo_grddl.xsl', xt_xml);
      xd := serialize_to_UTF8_xml (xd);
      DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
      mdta := mdta + 1;
    }
      not_rdf:;
      is_grddl := 1;
      if (xt_xml is not null)
    xt := xt_xml;
    }

  profs := null;
  profs_done := vector ();
  profile := cast (xpath_eval ('/html/head/@profile', xt) as varchar);
  if (profile is not null)
    profs := split_and_decode (profile, 0, '\0\0 ');

  reg := '';
  doc_base := get_keyword ('http-redirect-to', opts, new_origin_uri);
  DB.DBA.RDF_LOAD_GRDDL_REC (doc_base, graph_iri, new_origin_uri, dest, xt, mdta, reg, '', 0, opts);
  if (registry_get ('__rdf_cartridges_original_doc_uri__') = '1' and mdta) -- It is recognized as GRDDL, data is loaded (testing the grddl only mode)
    goto ret;
  try_rdfa:;
  -- RDFa
  thisgr := coalesce (dest, graph_iri);
  cnt := (sparql define input:storage "" select count(*) { graph `iri(?:thisgr)` { ?s ?p ?o }});
  {
      {
	declare exit handler for sqlstate '*';
	DB.DBA.RDF_LOAD_RDFA_1 (ret_body, new_origin_uri, thisgr, 0);
	goto rdfa_end;
      }
      {
	declare exit handler for sqlstate '*';
	DB.DBA.RDF_LOAD_RDFA_1 (ret_body, new_origin_uri, thisgr, 1);
	goto rdfa_end;
      }
      {
	declare exit handler for sqlstate '*';
	DB.DBA.RDF_LOAD_RDFA_1 (ret_body, new_origin_uri, thisgr, 2);
	rdfa_end:;
      }
  }
  -- we process grddl & rdfa both should give us same result
  if (mdta) -- It is recognized as GRDDL and data is loaded, stop there WAS: is_grddl and xpath_eval ('/html', xt) is null)
    goto ret;
  cnt := (sparql define input:storage "" select count(*) { graph `iri(?:thisgr)` { ?s ?p ?o }}) - cnt;
  if (cnt > 0)
    mdta := mdta + 1;
  -- /* GRDDL - plan A, eRDF going here */
  foreach (any prof in profs) do
    {
      prof := WS.WS.EXPAND_URL (new_origin_uri, prof);
      xslt_style := (select GM_XSLT from DB.DBA.SYS_GRDDL_MAPPING where GM_PROFILE = prof);
      if (xslt_style is not null)
	{
	  declare exit handler for sqlstate '*' { goto next_prof; };
	  xd := DB.DBA.RDF_MAPPER_XSLT (xslt_style, xt, vector ('baseUri', coalesce (dest, graph_iri)));
	  if (xpath_eval ('count(/RDF/*)', xd) > 0)
            {
	      mdta := mdta + 1;
	    }
	  xd := serialize_to_UTF8_xml (xd);
	  DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	  profs_done := vector_concat (profs_done, vector (prof));
	}
      next_prof:;
    }

  -- brute force attack, scan w/o profile
  if (xt_xml is not null)
    xt := xt_xml;
  if (mdta < 2)
    {
      -- currently no profile in RDFa and some similar, so we try it to extract directly
      for select GM_XSLT, GM_PROFILE, GM_FLAG from DB.DBA.SYS_GRDDL_MAPPING do
        {
          if (position (GM_PROFILE, profs_done) > 0)
	    goto try_next1;
          declare exit handler for sqlstate '*' { goto try_next1; };
          xd := DB.DBA.RDF_MAPPER_XSLT (GM_XSLT, xt, vector ('baseUri', coalesce (dest, graph_iri), 'nss', nss));
	  if (xpath_eval ('count(/RDF/*)', xd) > 0)
	    {
	      mdta := mdta + 1;
	      xd := serialize_to_UTF8_xml (xd);
	      if (GM_FLAG = 2)
		delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
	      DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	      if (GM_FLAG > 0)
		return mdta;
	    }
      try_next1:;
    }
    }
    -- /* feed formats */
   if (get_feeds = 1)
    {
      -- try looking for feed
      declare rss, atom any;

      rss  := cast (xpath_eval('//head/link[ @rel="alternate" and @type="application/rss+xml" ]/@href', xt) as varchar);
      atom := cast (xpath_eval('//head/link[ @rel="alternate" and @type="application/atom+xml" ]/@href', xt) as varchar);

   declare exit handler for sqlstate '*' { goto no_feed; };

      xt := null;
      hdr := null;
      if (atom is not null)
        {
      declare exit handler for sqlstate '*' { goto try_rss; };
      feed_url := atom;
      --if (RDF_MAPPER_CACHE_CHECK (atom, new_origin_uri, old_etag, old_last_modified))
      --  goto no_feed;
      load_msec := msec_time ();
      content := DB.DBA.RDF_HTTP_URL_GET (atom, new_origin_uri, hdr, 'GET', 'Accept: */*', proxy=>get_keyword_ucase ('get:proxy', opts));
      load_msec := msec_time () - load_msec;
      download_size := length (content);
      xt := xtree_doc (content);
      goto do_detect;
        }
try_rss:;
      if (rss is not null)
        {
      declare exit handler for sqlstate '*' { goto no_microformats; };
      feed_url := rss;
      --if (RDF_MAPPER_CACHE_CHECK (rss, new_origin_uri, old_etag, old_last_modified))
      --  goto no_feed;
      load_msec := msec_time ();
      content := DB.DBA.RDF_HTTP_URL_GET (rss, new_origin_uri, hdr, 'GET', 'Accept: */*', proxy=>get_keyword_ucase ('get:proxy', opts));
      load_msec := msec_time () - load_msec;
      download_size := length (content);
      xt := xtree_doc (content);
        }
do_detect:;

    -- the document itself is a feed
    if (xt is null and xpath_eval ('/rdf|/rss|/feed', xt_sav) is not null)
      xt := xt_xml;

    if (xt is null)
      goto no_feed;
    else if (xpath_eval ('/RDF', xt) is not null and content is not null)
      {
        xd := content;
        goto ins_rdf;
      }
    else if (xpath_eval ('/feed', xt) is not null)
      {
        xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/atom2rdf.xsl', xt);
      }
    else if (xpath_eval ('/rss', xt) is not null)
      {
        xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/rss2rdf.xsl', xt);
      }
    else
      goto no_feed;

    if (xpath_eval ('count(/RDF/*)', xd) > 0)
          {
        mdta := mdta + 1;
      }
    xd := serialize_to_UTF8_xml (xd);
ins_rdf:
    DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri), 0);
    DB.DBA.RDF_LOAD_FEED_SIOC (xd, new_origin_uri, coalesce (dest, graph_iri));
    --RDF_MAPPER_CACHE_REGISTER (feed_url, new_origin_uri, hdr, old_last_modified, download_size, load_msec);
    ret_flag := 1;
no_feed:;
    }
  -- /* generic xHTML, extraction as per our ontology */
  xt := xt_sav;
  if (add_html_meta = 1 and xpath_eval ('/html', xt) is not null)
    {
      xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/html2rdf.xsl', xt, vector ('baseUri', coalesce (dest, graph_iri)));
      if (xpath_eval ('count(/RDF/*)', xd) > 0)
        {
	  mdta := mdta + 1;
          xd := serialize_to_UTF8_xml (xd);
          DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri), 1);
        }
    }
ret:
  if (mdta > 0 and aq is not null)
    aq_request (aq, 'DB.DBA.RDF_SW_PING', vector (ps, new_origin_uri));

  -- /* decide how to return */
  declare ord, mime any;
  mime := get_keyword ('content-type', opts);
  ord := (select RM_ID from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = 'DB.DBA.RDF_LOAD_HTML_RESPONSE');
  for select RM_PATTERN, RM_TYPE, RM_HOOK from DB.DBA.SYS_RDF_MAPPERS
    where RM_ID > ord and RM_TYPE in ('URL', 'MIME') and RM_ENABLED = 1 order by RM_ID do
    {
      if (RM_TYPE = 'URL' and regexp_match (RM_PATTERN, new_origin_uri) is not null)
        mdta := 0;
      else if (RM_TYPE = 'MIME' and mime is not null and RM_HOOK <> 'DB.DBA.RDF_LOAD_DAV_META' and regexp_match (RM_PATTERN, mime) is not null)
        mdta := 0;
    }
  mdta := mdta * ret_flag;
  -- needs a flag
  if (0 and mdta <> 0)
    {
      declare localdest, dep any;
      localdest := coalesce (dest, graph_iri);
      dep := (sparql define input:storage ""
        select (sql:VECTOR_AGG (?o))
        where { graph `iri(?:localdest)` {
                `iri(?:localdest)` <http://www.w3.org/2000/01/rdf-schema#seeAlso> ?o .
                filter (isIRI (?o)) } } );
      if (length (dep) > 0)
        {
          return vector ('seeAlso', dep);
        }
    }
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), null);
  return mdta;
  no_microformats:;
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), null);
  return 0;
}
;

create procedure DB.DBA.RDF_LOAD_FEED_RESPONSE (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare content, xd, xt, ret_flag, mdta any;
  content := ret_body;
  declare exit handler for sqlstate '*'
    {
      goto no_xml;
    };
  mdta := 0;
  xt := xtree_doc (content);

  if (xpath_eval ('/RDF', xt) is not null and content is not null)
    {
      xd := content;
      mdta := 1;
      goto ins_rdf;
    }
  else if (xpath_eval ('/feed', xt) is not null)
    {
      xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/atom2rdf.xsl', xt);
    }
  else if (xpath_eval ('/rss', xt) is not null)
    {
      xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/rss2rdf.xsl', xt);
    }
  else if (xpath_eval ('/entry', xt) is not null)
    {
      xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/google2rdf.xsl', xt);
      if (xpath_eval ('count(/RDF/*)', xd) > 0)
	mdta := 1;
      xd := serialize_to_UTF8_xml (xd);
      DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
      goto no_feed;
    }
    else if (xpath_eval ('/service', xt) is not null)
    {
      xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/odata2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (dest, graph_iri)));
      if (xpath_eval ('count(/RDF/*)', xd) > 0)
	mdta := 1;
      xd := serialize_to_UTF8_xml (xd);
      DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
      goto no_feed;
    }
  else
    goto no_feed;

  if (xpath_eval ('count(/RDF/*)', xd) > 0)
    {
      mdta := 1;
    }
  xd := serialize_to_UTF8_xml (xd);
ins_rdf:
  mdta := DB.DBA.RDF_LOAD_FEED_SIOC (xd, new_origin_uri, coalesce (dest, graph_iri));
no_feed:

  declare ord, mime any;
  mime := get_keyword ('content-type', opts);
  ord := (select RM_ID from DB.DBA.SYS_RDF_MAPPERS where RM_HOOK = current_proc_name ());
  for select RM_PATTERN, RM_TYPE, RM_HOOK from DB.DBA.SYS_RDF_MAPPERS
    where RM_ID > ord and RM_TYPE in ('URL', 'MIME') and RM_ENABLED = 1 order by RM_ID do
    {
      if (RM_TYPE = 'URL' and regexp_match (RM_PATTERN, new_origin_uri) is not null)
        mdta := 0;
      else if (RM_TYPE = 'MIME' and mime is not null and RM_HOOK <> 'DB.DBA.RDF_LOAD_DAV_META' and regexp_match (RM_PATTERN, mime) is not null)
        mdta := 0;
    }
  return mdta;
no_xml:;
  return 0;
}
;

-- /* convert the feed in rss 1.0 format to sioc */
create procedure DB.DBA.RDF_LOAD_FEED_SIOC (in content any, in iri varchar, in graph_iri varchar, in is_disc int := '')
{
  declare xt, xd any;
  declare exit handler for sqlstate '*'
    {
      goto no_sioc;
    };
  xt := xtree_doc (content);
  xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/feed2sioc.xsl', xt, vector ('baseUri', graph_iri, 'isDiscussion', is_disc));
  xd := serialize_to_UTF8_xml (xd);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, iri, graph_iri, 0);
  DB.DBA.RM_ADD_PRV (current_proc_name (), iri, graph_iri, null);
  return 1;
  no_sioc:
  return 0;
}
;

registry_set ('__sparql_sponge_use_w3c_xslt', 'on')
;


create procedure DB.DBA.SYS_URN_SPONGE_UP (in local_iri varchar, in get_uri varchar, in options any)
{
  if (lower (local_iri) like 'urn:lsid:%')
    {
      options := vector_concat (vector ('get:uri', 'http://lsid.tdwg.org/'||get_uri), options);
      return DB.DBA.SYS_HTTP_SPONGE_UP (local_iri, get_uri,
      'DB.DBA.RDF_LOAD_HTTP_RESPONSE', 'DB.DBA.RDF_FORGET_HTTP_RESPONSE', options);
    }
  else
    {
      signal ('RDFZZ', 'This version of Virtuoso Sponger do not support "urn" IRI scheme');
    }
}
;

create procedure DB.DBA.SYS_DOI_SPONGE_UP (in local_iri varchar, in get_uri varchar, in options any)
{
  if (lower (local_iri) like 'doi:%' and __proc_exists ('HS_Resolve', 2) is not null)
    {
      declare new_get_uri varchar;
      new_get_uri := HS_Resolve (substring (get_uri, 5, length (get_uri)));
      if (new_get_uri is null)
        signal ('RDFZZ', 'Cannot resolve IRI='||get_uri);
      options := vector_concat (vector ('get:uri', new_get_uri), options);
      return DB.DBA.SYS_HTTP_SPONGE_UP (local_iri, get_uri,
      'DB.DBA.RDF_LOAD_HTTP_RESPONSE', 'DB.DBA.RDF_FORGET_HTTP_RESPONSE', options);
    }
  else
    {
      signal ('RDFZZ', 'This version of Virtuoso Sponger do not support "doi" IRI scheme');
    }
}
;

create procedure DB.DBA.SYS_FEED_SPONGE_UP (in local_iri varchar, in get_uri varchar, in options any)
{
  declare url varchar;
  url := 'http:' || subseq (get_uri, 5);
  options := vector_concat (vector ('get:uri', url), options);
  return DB.DBA.SYS_HTTP_SPONGE_UP (local_iri, get_uri,
      'DB.DBA.RDF_LOAD_HTTP_RESPONSE', 'DB.DBA.RDF_FORGET_HTTP_RESPONSE', options);
}
;

create procedure DB.DBA.SYS_WEBCAL_SPONGE_UP (in local_iri varchar, in get_uri varchar, in options any)
{
  declare url varchar;
  url := 'http:' || subseq (get_uri, 7);
  options := vector_concat (vector ('get:uri', url), options);
  return DB.DBA.SYS_HTTP_SPONGE_UP (local_iri, get_uri,
      'DB.DBA.RDF_LOAD_HTTP_RESPONSE', 'DB.DBA.RDF_FORGET_HTTP_RESPONSE', options);
}
;

create procedure DB.DBA.RDF_LOAD_YAHOO_STOCK_DATA (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare meta, tmp, content varchar;
  declare symbol varchar;
  declare arr any;

  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  arr := sprintf_inverse (new_origin_uri, 'http://finance.yahoo.com/q?s=%s', 0);
  symbol := arr[0];

  rdfm_yq_get_quote (symbol, new_origin_uri, dest, graph_iri, opts);
  rdfm_yq_get_history (symbol, new_origin_uri, dest, graph_iri, opts);
  rdfm_yq_get_feed (symbol, new_origin_uri, dest, graph_iri, opts);
  rdfm_yq_get_events (symbol, new_origin_uri, dest, graph_iri, opts);
  rdfm_yq_get_mb (symbol, new_origin_uri, dest, graph_iri, opts);
  rdfm_yq_get_competitors (symbol, new_origin_uri, dest, graph_iri, opts);
  return 1;
}
;


create procedure rdfm_yq_get_quote (in symbol varchar, in new_origin_uri varchar, in  dest varchar, in graph_iri varchar, inout opts any)
{
  declare arr, cnt, ses, content, url any;
  declare xt, xd any;

  ses := string_output ();
  url := sprintf ('http://download.finance.yahoo.com/d/quotes.csv?s=%U&f=nsbavophg&e=.csv', symbol);
  cnt := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
  arr := rdfm_yq_parse_csv (cnt);
  http ('<quote stock="NASDAQ">', ses);
  foreach (any q in arr) do
    {
      http_value (q[0], 'company', ses);
      http_value (q[1], 'symbol', ses);
      http_value (q[2], 'bid', ses);
      http_value (q[3], 'ask', ses);
      http_value (q[4], 'volume', ses);
      http_value (q[5], 'open', ses);
      http_value (q[6], 'prev.close', ses);
      http_value (q[7], 'high', ses);
      http_value (q[8], 'low', ses);
    }
  http ('</quote>', ses);
  content := string_output_string (ses);
  xt := xtree_doc (content);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/yahoo_stock2rdf.xsl', xt,
      vector ('baseUri', 'http://finance.yahoo.com/q?s='||symbol));
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
  return;
}
;

create procedure rdfm_yq_get_history (in symbol varchar, in new_origin_uri varchar, in  dest varchar, in graph_iri varchar, inout opts any)
{
  declare arr, cnt, ses, content, url any;
  declare xt, xd any;

  ses := string_output ();
  url := sprintf ('http://ichart.finance.yahoo.com/table.csv?s=%U&d=10&e=13&f=2007&g=d&a=8&b=7&c=2007&ignore=.csv', symbol);
  cnt := http_client (url, proxy=>get_keyword_ucase ('get:proxy', opts));
  arr := rdfm_yq_parse_csv (cnt);
  http (sprintf ('<history stock="NASDAQ" symbol="%V">', symbol), ses);
  foreach (any q in arr) do
    {
      if (q[0] <> 'Date')
    {
      http ('<hist-price>', ses);
      http_value (q[0], 'date', ses);
      http_value (q[1], 'open', ses);
      http_value (q[2], 'high', ses);
      http_value (q[3], 'low', ses);
      http_value (q[4], 'close', ses);
      http_value (q[5], 'volume', ses);
      http_value (q[6], 'adjclose', ses);
      http ('</hist-price>', ses);
    }
    }
  http ('</history>', ses);
  content := string_output_string (ses);
  xt := xtree_doc (content);
  xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/yahoo_stock2rdf.xsl', xt, vector ('baseUri', 'http://finance.yahoo.com/q/hp?s='||symbol));
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
  return;
}
;

create procedure rdfm_yq_date_cvt (in d varchar)
{
  declare arr any;
  declare dt any;
  declare exit handler for sqlstate '*'
    {
      return null;
    };
  arr := sprintf_inverse (trim (cast (d as varchar)), '%d-%s-%d', 0);
  if (length(arr) < 3)
    return null;
  dt := http_string_date (sprintf ('Mon, %02d %s 20%02d 00:00:00 GMT', arr[0], arr[1], arr[2]));
  dt := dt_set_tz (dt, 0);
  return date_iso8601 (dt);
}
;

create procedure rdfm_yq_get_competitors (in symbol varchar, in new_origin_uri varchar, in  dest varchar, in graph_iri varchar, inout opts any)
{
  declare content, iri any;
  declare xt, xd, xp, ses any;
  content := http_client (sprintf ('http://finance.yahoo.com/q/co?s=%U', symbol), proxy=>get_keyword_ucase ('get:proxy', opts));
  --content := file_to_string ('temp/xx');
  xt := xtree_doc (content, 2);
  xp := xpath_eval ('//table[tr/td/small/b[ contains (., "DIRECT COMPETITOR COMPARISON")]]/following-sibling::table[2]/tr[1]/td/table/tr[1]//a/text()', xt, 0);
  ses := string_output ();
  foreach (any x in xp) do
    {
      x := cast (x as varchar);
      if (x <> symbol and x <> 'Industry')
	{
	  http (sprintf ('<http://dbpedia.org/resource/%s> <http://xbrlontology.com/ontology/finance/stock_market#hasCompetitor> <http://dbpedia.org/resource/%s> .\n', symbol, x), ses);
	  http (sprintf ('<http://dbpedia.org/resource/%s> <http://www.openlinksw.com/schema/attribution#isDescribedUsing> <http://finance.yahoo.com/q?s=%s> .\n', x, x), ses);
	}
    }
  content := string_output_string (ses);
  TTLP (content, new_origin_uri, coalesce (dest, graph_iri));
  return;
}
;

create procedure rdfm_yq_get_events (in symbol varchar, in new_origin_uri varchar, in  dest varchar, in graph_iri varchar, inout opts any)
{
  declare content, iri any;
  declare xt, xd, xp, ses any;
  iri := sprintf ('http://finance.yahoo.com/q/ce?s=%U', symbol);
  content := http_client (sprintf ('http://finance.yahoo.com/q/ce?s=%U', symbol), proxy=>get_keyword_ucase ('get:proxy', opts));
  xt := xtree_doc (content, 2);
  xp := xpath_eval ('//table[tr/td[@class="yfnc_tablehead1" and normalize-space (.) = "Event"]]/tr', xt, 0);
  ses := string_output ();
  http ('<r:RDF xmlns:r="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:c="http://www.w3.org/2002/12/cal/icaltzd#">\n', ses);
  http (sprintf ('<c:Vcalendar r:about="http://finance.yahoo.com/q/ce?s=%V#this">\n', symbol), ses);
  http ('<c:prodid>-//connolly.w3.org//palmagent 0.6 (BETA)//EN</c:prodid>\n', ses);
  http ('<c:version>2.0</c:version>\n', ses);
  foreach (any x in xp) do
    {
      declare _time, _desc, _uri varchar;
      _time := xpath_eval ('string(td[1])', x);
      _desc := xpath_eval ('string(td[2])', x);
      _uri :=  xpath_eval ('td[2]/a/@href', x);
      if (length (_time) and length (_desc))
    {
      _time := rdfm_yq_date_cvt (_time);
      if (length (_time))
        {
          http ('<c:component>\n', ses);
          http ('<c:Vevent>\n', ses);
          http (sprintf ('<c:description>%V</c:description>\n', _desc), ses);
          http (sprintf ('<c:dtstart r:datatype="http://www.w3.org/2001/XMLSchema#dateTime">%V</c:dtstart>\n', _time), ses);
          if (_uri is not null)
        http (sprintf ('<c:url r:resource="%V"/>\n', _uri), ses);
          http ('</c:Vevent>\n', ses);
          http ('</c:component>\n', ses);
        }
    }
    }
  http ('</c:Vcalendar>\n', ses);
  http ('</r:RDF>\n', ses);
  content := string_output_string (ses);
  DB.DBA.RM_RDF_LOAD_RDFXML (content, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), iri);
  return;
}
;

create procedure rdfm_yq_get_mb (in symbol varchar, in new_origin_uri varchar, in  dest varchar, in graph_iri varchar, inout opts any)
{
  declare content, hdr any;
  declare xt, xp any;
  content := http_client ('http://messages.finance.yahoo.com/mb/'||symbol, proxy=>get_keyword_ucase ('get:proxy', opts));
  xt := xtree_doc (content, 2);
  xp := cast(xpath_eval ('//a[normalize-space(.) = "RSS"]/@href', xt) as varchar);
  if (length (xp))
    {
      content := DB.DBA.RDF_HTTP_URL_GET (xp, '', hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
      rdfm_yq_load_feed (content, new_origin_uri, dest, graph_iri);
    }
}
;

create procedure rdfm_yq_load_feed (inout content any, in new_origin_uri varchar, in  dest varchar, in graph_iri varchar)
{
  declare xt, xd any;
  xt := xtree_doc (content);
  if (xpath_eval ('/RDF', xt) is not null and content is not null)
    {
      xd := content;
      goto ins_rdf;
    }
  else if (xpath_eval ('/feed', xt) is not null)
    {
      xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/atom2rdf.xsl', xt);
    }
  else if (xpath_eval ('/rss', xt) is not null)
    {
      xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/rss2rdf.xsl', xt);
    }
  else
    goto no_feed;
  xd := serialize_to_UTF8_xml (xd);
  ins_rdf:
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RDF_LOAD_FEED_SIOC (xd, new_origin_uri, coalesce (dest, graph_iri));
  no_feed:
  return;
}
;

create procedure rdfm_yq_get_feed (in symbol varchar, in new_origin_uri varchar, in  dest varchar, in graph_iri varchar, inout opts any)
{
  declare content, hdr any;
  content := DB.DBA.RDF_HTTP_URL_GET (sprintf ('http://us.rd.yahoo.com/finance/news/rss/add/*http://finance.yahoo.com/rss/SeekingAlpha?s=%U', symbol), '', hdr, proxy=>get_keyword_ucase ('get:proxy', opts));
  rdfm_yq_load_feed (content, new_origin_uri, dest, graph_iri);
  return;
}
;


create procedure rdfm_yq_parse_csv (in str varchar)
{
  declare ses any;
  declare ret, line, v any;

  ses := string_output ();
  http (str, ses);
  ret := vector ();
  while (1)
    {
      line := ses_read_line (ses, 0, 0, 1);
      if (not isstring (line))
    goto finish;
      line := replace (line, '\r', '\n');
      line := replace (line, '\n\n', '\n');
      v := rdfm_yq_parse_csv_line (line);
      ret := vector_concat (ret, vector (v));
    }
  finish:
  return ret;
}
;

create procedure rdfm_yq_parse_csv_line (inout line varchar)
{
  declare res any;
  declare len, i, stat, prev int;
  declare tmp varchar;

  res := vector ();
  len := length (line);
  stat := 0;
  tmp := '';
  prev := 0;
  for (i := 0; i < len; i := i + 1)
    {
      if (stat = 0 and (line[i] = ascii (',') or line[i] = ascii ('\n')))
    {
      res := vector_concat (res, vector (tmp));
      tmp := '';
    }
      else if (line[i] = ascii ('"'))
    {
      if (stat = 1)
        {
          stat := 0;
        }
      else if (stat = 0)
        {
          if (prev = line[i])
            tmp := tmp || chr (line[i]);
              stat := 1;
        }
    }
      else if (stat)
    tmp := tmp || chr (line[i]);
      else if (stat = 1 and line[i] = ascii (' '))
        tmp := tmp || ' ';
      else if (stat = 0 and line[i] <> ascii (' '))
        tmp := tmp || chr (line[i]);
      prev := line[i];
    }
  return res;
}
;


create procedure RDFM_IDENT_RESOLVE_INIT ()
{
  declare cnt, hdr, url, xt, xp, sch, delim any;
  for select OS_ID as _id, OS_SERVER as _server from DB.DBA.OAI_SERVERS do
    {
      xp := sch := delim := '';
      declare exit handler for sqlstate '*'
    {
      update DB.DBA.OAI_SERVERS set OS_ENABLED = 0 where OS_ID = _id;
      goto try_next;
    };
      url := _server || '?verb=Identify';
      commit work;
      cnt := DB.DBA.RDF_HTTP_URL_GET (url, _server, hdr); -- this is for initing , no opts here
      xt := xtree_doc (cnt);
      xp := xpath_eval ('string (/OAI-PMH/Identify/description/oai-identifier/repositoryIdentifier)', xt);
      sch := xpath_eval ('string (/OAI-PMH/Identify/description/oai-identifier/scheme)', xt);
      delim := xpath_eval ('string (/OAI-PMH/Identify/description/oai-identifier/delimiter)', xt);
      if (length (xp))
        update DB.DBA.OAI_SERVERS set OS_URN_PATTERN = sch||delim||xp, OS_ENABLED = 1 where OS_ID = _id;
      else
    update DB.DBA.OAI_SERVERS set OS_ENABLED = 0 where OS_ID = _id;
      try_next:;
    }
}
;

create procedure DB.DBA.SYS_OAI_SPONGE_UP (in local_iri varchar, in get_uri varchar, in options any)
{
  declare url, hdr, xt, xd, cnt any;
  declare new_origin_uri, dest, graph_iri varchar;
  new_origin_uri := cast (get_keyword_ucase ('get:uri', options, get_uri) as varchar);
  graph_iri := get_uri;
  dest := get_keyword_ucase ('get:destination', options);
  for select OS_SERVER as _server from DB.DBA.OAI_SERVERS where get_uri like OS_URN_PATTERN || ':%' and OS_ENABLED = 1 do
    {
      declare exit handler for sqlstate '*'
    {
      return local_iri;
    };
      url := sprintf ('%s?verb=GetRecord&identifier=%s&metadataPrefix=oai_dc', _server, get_uri);
      cnt := DB.DBA.RDF_HTTP_URL_GET (url, _server, hdr, proxy=>get_keyword_ucase ('get:proxy', options));
      xt := xtree_doc (cnt);
      xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/oai2rdf.xsl', xt, vector ('baseUri', get_uri));
      xd := serialize_to_UTF8_xml (xd);
      if (dest is null)
	delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
      DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
      DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), url);
    }
  return local_iri;
}
;

create procedure DB.DBA.LOAD_RDF_MAPPER_XBRL_ONTOLOGIES()
{
  if (registry_get ('RDF_MAPPER_XBRL_ONTOLOGIES') = '1')
    return;
  for select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_FULL_PATH like '/DAV/VAD/rdf_mappers/ontologies/xbrl/%.owl.gz' do
    {
      declare str_out any;
      str_out := gzip_uncompress (cast (RES_CONTENT as varchar));
      DB.DBA.RDF_LOAD_RDFXML (str_out, 'http://www.openlinksw.com/schemas/xbrl/', 'http://www.openlinksw.com/schemas/RDF_Mapper_Ontology/1.0/');
    }
  registry_set ('RDF_MAPPER_XBRL_ONTOLOGIES','1');
}
;

RDF_GRAPH_GROUP_CREATE ('http://www.openlinksw.com/schemas/virtrdf#schemas', 1);

--registry_remove ('RM_LOAD_ONTOLOGIES');

create procedure DB.DBA.RM_LOAD_ONTOLOGIES ()
{
  if (registry_get ('RM_LOAD_ONTOLOGIES') = '2')
    return;
  for select RES_CONTENT, RES_NAME from WS.WS.SYS_DAV_RES where RES_FULL_PATH like '/DAV/VAD/rdf_mappers/ontologies/owl/%.owl.gz' do
    {
      declare str_out, xt, owl_iri, base_iri, graph_iri any;

      str_out := gzip_uncompress (cast (RES_CONTENT as varchar));
      xt := xtree_doc (str_out);
      owl_iri := cast (xpath_eval ('/RDF/Ontology/@about', xt) as varchar);
      if (owl_iri is null)
	owl_iri := cast (xpath_eval ('/RDF/Description[type[@resource = "http://www.w3.org/2002/07/owl#Ontology"]]/@about', xt) as varchar);
      base_iri := cast (xpath_eval ('/RDF/@xml:base', xt) as varchar);
      if (length (owl_iri))
	graph_iri := owl_iri;
      else if (length (base_iri))
	graph_iri := base_iri;
      else
	{
	  log_message ('Can not load: ' || RES_NAME);
          goto skip_owl;
	}
      if (length (base_iri) = 0)
        base_iri := graph_iri;

      DB.DBA.RDF_LOAD_RDFXML (str_out, base_iri, graph_iri);
      RDF_GRAPH_GROUP_INS ('http://www.openlinksw.com/schemas/virtrdf#schemas', graph_iri);
      skip_owl:;
    }
  registry_set ('RM_LOAD_ONTOLOGIES','2');
}
;


DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('xbrl_rule1', 1, '/schemas/xbrl/(.*)', vector('path'), 1,
'/sparql?query=DESCRIBE%%20%%3Chttp%%3A//www.openlinksw.com/schemas/xbrl/%U%%3E%%20FROM%%20%%3Chttp%%3A//www.openlinksw.com/schemas/RDF_Mapper_Ontology/1.0/%%3E',
vector('path'), null, '(text/rdf.n3)|(application/rdf.xml)', 0, null);

DB.DBA.URLREWRITE_CREATE_RULELIST ('xbrl_rule_list1', 1, vector('xbrl_rule1'));

DB.DBA.VHOST_REMOVE (lpath=>'/schemas/xbrl');

DB.DBA.VHOST_DEFINE (lpath=>'/schemas/xbrl', ppath=>'/DAV/VAD/rdf_mappers/ontologies/xbrl/msft2007.owl', vsp_user=>'dba', is_dav=>1, is_brws=>0, opts=>vector ('url_rewrite', 'xbrl_rule_list1'));
-- dbpedia_extract.php

CREATE PROCEDURE RDFMAP_DBPEDIA_EXTRACT_PHP (in base varchar, in title varchar)
{
  declare ses any;
  ses := string_output ();
  http ('<?php\n', ses);
  http (sprintf ('\x24basePath = "%s";\n', base), ses);
  http (sprintf ('\x24pageTitlesEn[] = "%s";\n', title), ses);
  http ('\n', ses);
  http ('set_include_path (\x24basePath.\':\'.\x24basePath.\'/extractors:\'.\x24basePath.\'/destinations\');\n', ses);
  http ('require_once \'dbpedia.php\';\n', ses);
  http ('\n', ses);
  http ('\x24manager = new ExtractionManager();\n', ses);
  http ('\x24jobEnWiki = new ExtractionJob (new LiveWikipediaCollection("en"), new ArrayObject(\x24pageTitlesEn));\n', ses);
  http ('\n', ses);
  http ('\x24group = new ExtractionGroup(new SimpleDumpDestination());\n', ses);
  http ('\x24group->addExtractor(new LabelExtractor());\n', ses);
  http ('\x24group->addExtractor(new ArticleCategoriesExtractor ());\n', ses);
  http ('\x24group->addExtractor(new PageLinksExtractor ());\n', ses);
  http ('\x24group->addExtractor(new WikipageExtractor ());\n', ses);
  http ('\x24group->addExtractor(new ActiveAbstractExtractor ());\n', ses);
  http ('\x24group->addExtractor(new PersondataExtractor ());\n', ses);
  http ('\x24group->addExtractor(new ChemboxExtractor ());\n', ses);
  http ('\x24group->addExtractor(new GeoExtractor ());\n', ses);
  http ('\x24group->addExtractor(new DisambiguationExtractor ());\n', ses);
  http ('\x24group->addExtractor(new CharacterCountExtractor ());\n', ses);
  http ('\x24group->addExtractor(new RedirectExtractor ());\n', ses);
  http ('\x24group->addExtractor(new HomepageExtractor ());\n', ses);
  http ('\x24jobEnWiki->addExtractionGroup(\x24group);\n', ses);
  http ('\n', ses);
  http ('\x24manager->execute(\x24jobEnWiki);\n', ses);
  http ('?>\n', ses);
  return string_output_string (ses);
}
;

--no_c_escapes-
-- Cartridge for sponging Powerpoint PPTX files.

create procedure DB.DBA.RDF_LOAD_PPTX_DOCUMENT (
in graph_iri varchar, in new_origin_uri varchar, in dest varchar,
inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any
)
{
  declare urihost, baseUri, original_dest varchar;
  declare core_meta, app_meta, slides_meta varchar;
  declare slide_list, slide_vec, slide_content, slide_path any;
  declare meta_xml, tmpFile, fileName, fileExt varchar;
  declare xt, xd any;
  declare extracted_image_collection_dav_root, extracted_image_collection_dav_path varchar;
  declare dav_uid, dav_pwd varchar;

  declare exit handler for sqlstate '*'
  {
    DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
    return 0;
  };
  if (__proc_exists ('unzip_file', 2) is null)
    return 0;

  dav_uid := 'dav';
  dav_pwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME=dav_uid);

  -- Create a tmp file from input stream
  tmpFile := tmp_file_name ('rdfm', 'pptx');
  string_to_file (tmpFile, _ret_body, -2);
  -- Extract the required meta-data from the PPTX file
  core_meta := unzip_file (tmpFile, 'docProps/core.xml');
  app_meta := unzip_file (tmpFile, 'docProps/app.xml');
  slides_meta := unzip_file (tmpFile, 'ppt/_rels/presentation.xml.rels');
  if (core_meta is null or app_meta is null or slides_meta is null)
    return 0;
  urihost := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  fileExt := regexp_substr('.*(\.pptx|\.PPTX)\$', new_origin_uri, 1);
  fileName := subseq(new_origin_uri, strrchr(new_origin_uri, '/') + 1);
  extracted_image_collection_dav_root :='/DAV/home/dav/sponged/';
  extracted_image_collection_dav_path := extracted_image_collection_dav_root || fileName || '/';

  -- Override dest so graph URI doesn't refer to original location of the source .PPTX file
  -- Using a fixed URL, instead of the source document URL, as the graph name makes
  -- creating rewrite rules easier. The same rewrite rules can be used for all sponged .PPTX files.
  original_dest := coalesce(dest, graph_iri);
  -- Disabled - Breaks description.vsp
  -- dest := 'http://' || urihost || '/PPTX';
  -- baseUri := dest || '/' || fileName;
  dest := original_dest;
  baseUri := original_dest;

  -- Construct graph $original_dest which contains link to graph $dest created solely for sponged PPTX metadata
  {
    declare ses, tmp any;

    ses := string_output ();
    http ('<rdf:RDF', ses);
    http ('  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"\n', ses);
    http ('  xmlns:http="http://www.w3.org/2006/http#"\n', ses);
    http ('  xmlns:dc="http://purl.org/dc/elements/1.1/"\n', ses);
    http ('>\n', ses);
    http ('<rdf:Description rdf:about="' || original_dest || '">\n', ses);
    http ('<dc:relation rdf:resource="' || baseUri || '"/>\n', ses);
    http ('</rdf:Description>\n', ses);
    http ('</rdf:RDF>\n', ses);
    tmp := string_output_string (ses);
    DB.DBA.RDF_LOAD_RDFXML (tmp, new_origin_uri, original_dest);
  }

  -- Get base RDF description of presentation
  meta_xml := vector(core_meta, app_meta);
  foreach (any meta in meta_xml) do
  {
    xt := xtree_doc (meta);
    xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/pptx2rdf.xsl', xt,
            vector ('baseUri', baseUri, 'sourceDoc', original_dest, 'urihost', urihost, 'fileExt', fileExt));
    xd := serialize_to_UTF8_xml (xt);
    DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  }

  -- Get a colon-delimited list of slides contained in the presentation
  xt := xtree_doc (slides_meta);
  xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/pptx2rdf.xsl', xt,
          vector ('baseUri', baseUri, 'sourceDoc', original_dest, 'urihost', urihost, 'fileExt', fileExt, 'mode', 'get_slide_list'));
  slide_list := serialize_to_UTF8_xml (xd);

  -- Transform slide list into a vector
  {
    declare tmp, _start, _end any;
    slide_vec := vector();
    tmp := slide_list;
    -- First slide occurs after first ':'
    _start := strchr(tmp, ':');
    while (_start is not null)
    {
      tmp := subseq(tmp, _start + 1);
      _end := strchr(tmp, ':');
      slide_path := subseq(tmp, 0, _end);
      slide_vec := vector_concat (slide_vec, vector(slide_path));
      _start := _end;
    }
  }

  -- Handle any embedded images
  {
    declare create_dav_col int;
    create_dav_col := 1;

    foreach (any slide_path2 in slide_vec) do
    {
      declare slide_rels, slide_basename, slide_num varchar;
      declare slide_images, image_path, image_vec any;

      -- slide path takes form 'slides/slide<n>.xml'
      slide_basename := subseq(slide_path2, 7);
      slide_num := regexp_substr('[0-9]+', slide_basename, 0);
      slide_rels := unzip_file (tmpFile, 'ppt/slides/_rels/' || slide_basename || '.rels'); 

      -- Generate RDF description of each embedded image
      xt := xtree_doc (slide_rels);
      xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/pptx2rdf.xsl', xt,
             vector ('baseUri', baseUri, 'sourceDoc', original_dest, 'urihost', urihost, 'fileExt', fileExt, 'mode',
	             'get_image_descs', 'slideNum', slide_num, 'imageDavPath', extracted_image_collection_dav_path));
      if (xpath_eval('//text()', xd) is not null)
      {
        xd := serialize_to_UTF8_xml (xd);
        DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
      }

      -- Extract each embedded image file and place it in DAV storage
      xt := xtree_doc (slide_rels);
      xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/pptx2rdf.xsl', xt,
             vector ('baseUri', baseUri, 'sourceDoc', original_dest, 'urihost', urihost, 'fileExt', fileExt, 'mode', 'get_image_file_list'));
      slide_images := serialize_to_UTF8_xml (xd);
      -- slide_images is colon separated list of images in the slide
      -- e.g. :../media/image4.png:../media/image5.png

      -- Transform image list into a vector
      {
        declare tmp, _start, _end any;
        image_vec := vector();
        tmp := slide_images;
        -- First image occurs after first ':'
        _start := strchr(tmp, ':');
        while (_start is not null)
        {
          tmp := subseq(tmp, _start + 1);
          _end := strchr(tmp, ':');
          image_path := subseq(tmp, 0, _end);
          image_vec := vector_concat (image_vec, vector(image_path));
          _start := _end;
        }
      }

      -- Copy each image file to DAV
      foreach (any img_path in image_vec) do
      {
        declare image_basename, image_str, image_ext, image_mime_type varchar;

        -- Extract file e.g. ../media/image4.png
	image_mime_type := null;
        image_basename := regexp_substr('(media/)(.+)', image_path, 2);
	image_ext := subseq(lcase(image_basename), strrchr(image_basename, '.') + 1);
	if (image_ext is not null)
	{
	  image_mime_type := case
	    when (image_ext = 'bmp') then 'image/bmp'
	    when (image_ext = 'gif') then 'image/gif'
	    when (image_ext = 'jpeg') then 'image/jpeg'
	    when (image_ext = 'jpg') then 'image/jpeg'
	    when (image_ext = 'png') then 'image/png'
	    when (image_ext = 'svg') then 'image/svg+xml'
	    when (image_ext = 'tiff') then 'image/tiff'
	    when (image_ext = 'tif') then 'image/tiff'
	    end;
	}
	else
	{
	  --dbg_printf('.PPTX Cartridge - Error: image_mime_type is null for embedded image %s', image_basename);
	  ;
	}

	if (image_basename is not null and image_mime_type is not null)
	{
          image_str := unzip_file (tmpFile, 'ppt/media/' || image_basename);
	  if (image_str is not null)
	  {
	    declare rc int;

            if (create_dav_col)
	    {
              rc := DB.DBA.DAV_COL_CREATE(extracted_image_collection_dav_root, '110110110R', 'dav','dav', dav_uid, dav_pwd);
	      if (rc >= 0 or rc = (-3) )
	      {
		DB.DBA.DAV_DELETE(extracted_image_collection_dav_path, 1, dav_uid, dav_pwd);
                rc := DB.DBA.DAV_COL_CREATE(extracted_image_collection_dav_path, '110110110R', 'dav','dav', dav_uid, dav_pwd);
	      }
	      if (rc >= 0)
	        create_dav_col := 0;
              else
	        dbg_printf('.PPTX Cartridge - DAV_COL_CREATE failed(%d): %s', rc, extracted_image_collection_dav_path);
	    }

	    if (create_dav_col = 0)
	    {
              rc := DB.DBA.DAV_RES_UPLOAD (extracted_image_collection_dav_path || image_basename, image_str, image_mime_type,'110110110R','dav','dav', dav_uid, dav_pwd);
	      if (rc < 0)
	        dbg_printf('.PPTX Cartridge - DAV_RES_UPLOAD failed (%d) with file %s', rc, extracted_image_collection_dav_path || image_basename);
	    }
	  }
	  else
	  {
	    --dbg_printf('.PPTX Cartridge - Error: image_str is null for embedded image %s', image_basename);
	    ;
	  }
	}
      }
    }
  }
  -- end: Embedded image handling

  --Get text content of all slides
  {
    declare presentation_text, slide_text, ses1, ses2, tmp2 any;
    declare slide_basename varchar;

    -- Get the raw text contained in each slide and concatenate it
    presentation_text := '';
    ses1 := string_output();
    foreach (any slide_path3 in slide_vec) do
    {
      declare slideUri varchar;

      -- slide path takes form 'slides/slide<n>.xml'
      slide_basename := subseq(slide_path3, 7);
      slideUri :=  baseUri || '#' || subseq(slide_basename, 0, strrchr(slide_basename, '.'));
      slide_content := unzip_file (tmpFile, 'ppt/' || slide_path3); 
      if (slide_content is null)
      {
        --dbg_printf('.PPTX Cartridge - Error: slide content is null for slide %s\n', slide_path3);
        goto next_slide;
      }

      xt := xtree_doc (slide_content);
      xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/pptx2rdf.xsl', xt,
             vector ('baseUri', baseUri, 'sourceDoc', original_dest, 'urihost', urihost, 'fileExt', fileExt,
	             'mode', 'raw_slide_content'));
      slide_text := cast(xpath_eval('/slide_text/text()', xd) as varchar);
      http(slide_text || ' ', ses1);

      --dbg_printf('.PPTX Cartridge - slide text\n');
      --dbg_printf('%s', slide_text || ' ' );
      --dbg_printf('<<');

      -- Get text from each individual slide as RSS content:encoded
      xt := xtree_doc (slide_content);
      xt := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/pptx2rdf.xsl', xt,
             vector ('baseUri', baseUri, 'sourceDoc', original_dest, 'urihost', urihost, 'fileExt', fileExt,
	             'mode', 'html_encode_slide_content', 'slideUri', slideUri));
      xd := serialize_to_UTF8_xml (xt);
      DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));

      -- Construct RDF to hold text from each individual slide
      -- ses2 := string_output();
      -- http ('<rdf:RDF', ses2);
      -- http ('  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"\n', ses2);
      -- http ('  xmlns:http="http://www.w3.org/2006/http#"\n', ses2);
      -- http ('  xmlns:bibo="http://purl.org/ontology/bibo/"\n', ses2);
      -- http ('>\n', ses2);
      -- http ('<rdf:Description rdf:about="' || slideUri || '">\n', ses2);
      -- http ('<bibo:content>\n', ses2);
      -- http (slide_text || ' ', ses2);
      -- http ('</bibo:content>\n', ses2);
      -- http ('</rdf:Description>\n', ses2);
      -- http ('</rdf:RDF>\n', ses2);
      -- tmp2 := string_output_string (ses2);
      -- DB.DBA.RDF_LOAD_RDFXML (tmp2, new_origin_uri, coalesce (dest, graph_iri));
next_slide:
        ;
    }

    presentation_text := string_output_string (ses1);

    --dbg_printf('.PPTX Cartridge - presentation text:');
    --dbg_printf('%s', presentation_text);
    --dbg_printf('<<');

    -- Construct RDF to hold combined text from *all* slides
    {
      declare ses, tmp any;

      ses := string_output ();
      http ('<rdf:RDF', ses);
      http ('  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"\n', ses);
      http ('  xmlns:http="http://www.w3.org/2006/http#"\n', ses);
      http ('  xmlns:bibo="http://purl.org/ontology/bibo/"\n', ses);
      http ('  xmlns:dc="http://purl.org/dc/elements/1.1/"\n', ses);
      http ('  xmlns:sioc="http://rdfs.org/sioc/ns#"\n', ses);
      http ('>\n', ses);
      http ('<rdf:Description rdf:about="' || baseUri || '">\n', ses);

      http ('<bibo:content>\n', ses);
      http (presentation_text, ses);
      http ('</bibo:content>\n', ses);

      http ('</rdf:Description>\n', ses);
      http ('</rdf:RDF>\n', ses);
      tmp := string_output_string (ses);
      DB.DBA.RDF_LOAD_RDFXML (tmp, new_origin_uri, coalesce (dest, graph_iri));
    }
    --dbg_printf('.PPTX Cartridge - Presentation text extraction done');
  }

  --dbg_printf('.PPTX Cartridge - All done');

  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_MBZ_1 (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    in kind varchar, in id varchar, in inc varchar, inout opts any)
{
  declare uri, cnt, xt, xd, hdr any;
  uri := sprintf ('http://musicbrainz.org/ws/1/%s/%s?type=xml&inc=%U', kind, id, inc);
  cnt := DB.DBA.RDF_HTTP_URL_GET (uri, '', hdr, 'GET', 'Accept: */*', proxy=>get_keyword_ucase ('get:proxy', opts));
  xt := xtree_doc (cnt);
  xd := DB.DBA.RDF_MAPPER_XSLT (registry_get ('_rdf_mappers_path_') || 'xslt/main/mbz2rdf.xsl', xt, vector ('baseUri', RDF_SPONGE_DOC_IRI (new_origin_uri)));
  xd := serialize_to_UTF8_xml (xd);
  DB.DBA.RM_RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  DB.DBA.RM_ADD_PRV (current_proc_name (), new_origin_uri, coalesce (dest, graph_iri), uri);
};

create procedure DB.DBA.RDF_LOAD_MBZ (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any, inout opts any)
{
  declare kind, id varchar;
  declare tmp, incs any;
  declare uri, cnt, hdr, inc, xd, xt varchar;

  tmp := regexp_parse ('http://musicbrainz.org/([^/]*)/([^\.]+)', new_origin_uri, 0);
  declare exit handler for sqlstate '*'
    {
      DB.DBA.RM_RDF_SPONGE_ERROR (current_proc_name (), graph_iri, dest, __SQL_MESSAGE);
      return 0;
    };
  if (length (tmp) < 6)
    return 0;

  kind := subseq (new_origin_uri, tmp[2], tmp[3]);
  id :=   subseq (new_origin_uri, tmp[4], tmp[5]);
  incs := vector ();
  if (kind = 'artist')
    {
      inc := 'aliases artist-rels label-rels release-rels track-rels url-rels';
      incs :=
      	vector (
	'sa-Album', 'sa-Single', 'sa-EP', 'sa-Compilation', 'sa-Soundtrack',
	'sa-Spokenword', 'sa-Interview', 'sa-Audiobook', 'sa-Live', 'sa-Remix', 'sa-Other'
	, 'va-Album', 'va-Single', 'va-EP', 'va-Compilation', 'va-Soundtrack',
	'va-Spokenword', 'va-Interview', 'va-Audiobook', 'va-Live', 'va-Remix', 'va-Other'
	);
      --incs := vector ();
    }
  else if (kind = 'release')
    inc := 'artist counts release-events discs tracks artist-rels label-rels release-rels track-rels url-rels track-level-rels labels';
  else if (kind = 'track')
    inc := 'artist releases puids artist-rels label-rels release-rels track-rels url-rels';
  else if (kind = 'label')
    inc := 'aliases artist-rels label-rels release-rels track-rels url-rels';
  else
    return 0;
  if (dest is null)
    delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
  DB.DBA.RDF_LOAD_MBZ_1 (graph_iri, new_origin_uri, dest, kind, id, inc, opts);
  -- DELME: should not be there
  --DB.DBA.TTLP (sprintf ('<%S> <http://xmlns.com/foaf/0.1/primaryTopic> <%S> .\n<%S> a <http://xmlns.com/foaf/0.1/Document> .',
  --	new_origin_uri, DB.DBA.RDF_SPONGE_PROXY_IRI (new_origin_uri), new_origin_uri),
  --	'', graph_iri);
  foreach (any inc1 in incs) do
    {
      DB.DBA.RDF_LOAD_MBZ_1 (graph_iri, new_origin_uri, dest, kind, id, inc1, opts);
    }
  return 1;
};

-- /* import all namespaces to SYS_XML_PERSISTENT_NS_DECL */
create procedure DB.DBA.RM_LOAD_PREFIXES ()
{
  declare nss, dict, vec any;
  dict := dict_new (33);
  XML_REMOVE_NS_BY_PREFIX ('virt-xbrl', 2);
  XML_REMOVE_NS_BY_PREFIX ('opl-xbrl', 2);
  XML_REMOVE_NS_BY_PREFIX ('umbel', 2);
  XML_REMOVE_NS_BY_PREFIX ('ore', 2);
  XML_REMOVE_NS_BY_PREFIX ('dbpedia-owl', 2);
  XML_REMOVE_NS_BY_PREFIX ('opencyc', 2);
  XML_REMOVE_NS_BY_PREFIX ('geonames', 2);
  XML_REMOVE_NS_BY_PREFIX ('proxy', 2);
  XML_REMOVE_NS_BY_PREFIX ('http-voc', 2);
  XML_REMOVE_NS_BY_PREFIX ('cnet', 2);
  XML_REMOVE_NS_BY_PREFIX ('geospecies', 2);
  XML_REMOVE_NS_BY_PREFIX ('oplbb', 2);
  XML_REMOVE_NS_BY_PREFIX ('uClassify', 2);
  for select RES_CONTENT, RES_NAME from WS.WS.SYS_DAV_RES where
    	RES_FULL_PATH like '/DAV/VAD/rdf_mappers/xslt/%/%.xsl' do
    {
      nss := xmlnss_get (xtree_doc (RES_CONTENT));
      for (declare i, l int, i := 0, l := length (nss); i < l; i := i + 2)
        {
	  declare pref varchar;
	  if (nss[i] = 'h') -- special case
	    nss[i] := 'xhtml';
	  if (length (nss[i]) = 0 or nss[i] = 'xml')
	    ;
	  else if ((pref := dict_get (dict, nss[i+1])) <> nss[i])
	    ;
	  else if (dict_get (dict, nss[i+1]) is null)
	    dict_put (dict, nss[i+1], nss[i]);
        }
    }
  vec := dict_to_vector (dict, 1);
  for (declare i, l int, i := 0, l := length (vec); i < l; i := i + 2)
    {
      if (__xml_get_ns_prefix (vec[i+1], 2) is null)
        DB.DBA.XML_SET_NS_DECL (vec[i+1], vec[i], 2);
    }
  XML_SET_NS_DECL ('umbel-sc', 'http://umbel.org/umbel/sc/', 2);
  XML_SET_NS_DECL ('umbel-owl', 'http://umbel.org/umbel#', 2);
  XML_SET_NS_DECL ('umbel-ac', 'http://umbel.org/umbel/ac/', 2);
  XML_SET_NS_DECL ('oplweb', 'http://www.openlinksw.com/schemas/oplweb#', 2);
  XML_SET_NS_DECL ('oplevri', 'http://www.openlinksw.com/schemas/oplevri#', 2);
  XML_SET_NS_DECL ('fbase', 'http://rdf.freebase.com/ns/', 2);
  XML_SET_NS_DECL ('ore', 'http://www.openarchives.org/ore/terms/', 2);
  XML_SET_NS_DECL ('dbpedia-owl', 'http://dbpedia.org/ontology/', 2);
  XML_SET_NS_DECL ('opencyc', 'http://sw.opencyc.org/2008/06/10/concept/', 2);
  XML_SET_NS_DECL ('geonames', 'http://www.geonames.org/ontology#', 2);
  if (isstring (registry_get ('URIQADefaultHost')))
    XML_SET_NS_DECL ('proxy', sprintf ('http://%s/about/id/', registry_get ('URIQADefaultHost')), 2);
  XML_SET_NS_DECL ('http-voc', 'http://www.w3.org/2006/http#', 2);
  XML_SET_NS_DECL ('cnet', 'http://api.cnet.com/rest/v1.0/', 2);
  XML_SET_NS_DECL ('geospecies', 'http://rdf.geospecies.org/ont/geospecies#', 2);
  XML_SET_NS_DECL ('uClassify', 'http://api.uclassify.com/1/ResponseSchema#', 2);
};

DB.DBA.RM_LOAD_PREFIXES ();

create procedure DB.DBA.RM_GRAPH_PT_CK (in graph_iri varchar, in dest varchar)
{
  if (registry_get ('__sparql_mappers_debug') = '1')
    {
      if (exists (select 1 from RDF_QUAD where G = iri_to_id (graph_iri)
	and isiri_id (O) and  S = O and P = iri_to_id ('http://xmlns.com/foaf/0.1/primaryTopic')))
	dbg_obj_print ('Error: foaf:primaryTopic to document itself');
    }
}
;

create procedure RM_CHECK_CLASS_MATCH (in pattern varchar, in graph varchar)
{
  declare x any;
  for select "tp" from (sparql define input:storage "" 
        prefix foaf: <http://xmlns.com/foaf/0.1/>
  	select ?tp where { graph `iri(?:graph)` { ?doc foaf:primaryTopic ?s . ?s a ?tp }}) x do
    {
      x := rdfdesc_uri_curie ("tp");
      if (regexp_match (pattern, x) is not null)
	return 1;
    }
  return 0;
}
;

create procedure DB.DBA.RDF_LOAD_POST_PROCESS (in graph_iri varchar, in new_origin_uri varchar, in dest varchar,
    inout ret_body any, in ret_content_type varchar, inout options any)
{
  declare new_opts any;
  declare dummy, spmode, triples, graph, tmp any;
  declare rc int;

  dummy := null;
  RM_LOG_CLEAR ();
  RM_GRAPH_PT_CK (graph_iri, dest);
  graph := coalesce (dest, graph_iri);
  spmode := get_keyword ('meta-cartridges-mode', options, '');
  if (spmode = 'none')
    return 0;
  if (spmode <> '')
    {
      triples := (select vector_agg (vector (S,P,O)) from RDF_QUAD where g = iri_to_id (graph));
      tmp := split_and_decode (spmode, 0, '\0\0,');
      if (length (tmp) = 1 and atoi (tmp[0]) <= 0)
	spmode := abs (atoi (tmp[0]));
      else
        {
	  declare inx any;
	  inx := 0;
	  foreach (varchar x in tmp) do
	     {
	       tmp[inx] := atoi (tmp[inx]);
	       inx := inx + 1;
	     }  
	  spmode := tmp;
        }	  
    }  
  for select MC_ID, MC_PATTERN, MC_TYPE, MC_HOOK, MC_KEY, MC_OPTIONS, MC_API_TYPE 
    from DB.DBA.RDF_META_CARTRIDGES where MC_ENABLED = 1 order by MC_SEQ do
    {
      declare val_match, st any;

      if (MC_TYPE = 'MIME')
	{
	  val_match := ret_content_type;
	}
      else if (MC_TYPE = 'URL')
	{
	  val_match := new_origin_uri;
	}
      else if (MC_TYPE = 'CLASS' and RM_CHECK_CLASS_MATCH (MC_PATTERN, coalesce (dest, graph_iri)))
	{
	  goto try_cartridge; 
	}
      else
	val_match := null;

      if (spmode <> '' and isinteger (spmode) and spmode <> MC_API_TYPE)
        goto try_next_mapper;	
      if (spmode <> '' and isvector (spmode) and not position (MC_ID, spmode))
        goto try_next_mapper;	

      if (registry_get ('__sparql_mappers_debug') = '1')
	dbg_obj_prin1 ('Trying PP ', MC_HOOK);
      if (isstring (val_match) and regexp_match (MC_PATTERN, val_match) is not null)
	{
	  try_cartridge:
	  if (__proc_exists (MC_HOOK) is null)
	    goto try_next_mapper;

	  declare exit handler for sqlstate '*'
	    {
	      goto try_next_mapper;
	    };
          if (registry_get ('__sparql_mappers_debug') = '1')
	    dbg_obj_prin1 ('Match PP ', MC_HOOK);
	  new_opts := vector_concat (options, MC_OPTIONS, vector ('content-type', ret_content_type));
	  commit work;
	  st := msec_time ();
	  rc := call (MC_HOOK) (graph_iri, new_origin_uri, dest, ret_body, dummy, dummy, MC_KEY, new_opts);
	  RM_GRAPH_PT_CK (graph_iri, dest);
	  prof_sample (MC_HOOK, msec_time () - st, 1);
          if (registry_get ('__sparql_mappers_debug') = '1')
	    {
	      dbg_obj_prin1 ('Return PP rc=', rc, ' ', MC_HOOK, ' time=', (msec_time () - st)/1000.0);
	      if (rc < 0 or rc > 0)
	        dbg_obj_prin1 ('END of PP mappings');
	    }
	  if (rc < 0 or rc > 0)
	    {
	      return (case when rc < 0 then 0 else 1 end);
	    }
	}
      try_next_mapper:;
    }
  if (spmode <> '')
    DB.DBA.RDF_DELETE_TRIPLES (graph, triples);
  if (registry_get ('__sparql_mappers_debug') = '1')
    dbg_obj_prin1 ('END of PP mappings');
}
;

--- should be obsolete, keep for reference
create procedure DB.DBA.RM_GET_LITERALS (in base varchar, in graph varchar)
{
  declare data, meta any;
  declare ses, cont, xt, xd, arr any;
  ses := string_output ();
  declare exit handler for sqlstate '*'
    {
      return '';
    };
  exec (sprintf (
      'sparql select ?o from <%S> where { ?s ?p ?o . filter (isLiteral (?o) and ?o != "" and !(str(?p) like "http://www.openlinksw.com/schema/attribution#%%")) }', graph, base), null, null, vector (), 0, meta, data);
  foreach (any str in data) do
    {
      if (isstring (str[0]))
	{
	  http (str[0], ses);
	  http (' ', ses);
	}
    }
  ses := string_output_string (ses);
  return trim(ses);
}
;

DB.DBA.VHOST_REMOVE (lpath=>'/services/rdf/curies.get');
DB.DBA.VHOST_DEFINE (lpath=>'/services/rdf/curies.get', ppath=>'/SOAP/Http/RM_GET_CURIES', soap_user=>'PROXY');

create procedure
DB.DBA.RM_GET_CURIES () __SOAP_HTTP 'text/json'
{
  declare curie, accept varchar;
  declare res, ses any;
  declare params any;

  params := http_param ();
  res := dict_new (3);
  ses := string_output ();
  for (declare i, l int, l := length (params); i < l; i := i + 2)
    {
      if (params[i] = 'uri')
	{
	  curie := rdfdesc_uri_curie (params [i+1]);
	  dict_put (res, params [i+1], curie);
	}
    }
  res := dict_to_vector (res, 1);
  if (length (res) = 0)
    signal ('22023', 'No uri params specified.');
  accept := http_request_header_full (http_request_header(), 'Accept','*/*');
  accept := HTTP_RDF_GET_ACCEPT_BY_Q (accept);
  if (accept is null) accept := '';
  if (accept = 'text/xml')
    {
      http ('<?xml version="1.0" ?>\n<results>\n', ses);
      for (declare i, l int, l := length (res); i < l; i := i + 2)
	{
	  http (sprintf ('  <result>\n    <uri>%V</uri>\n    <curie>%s</curie>\n  </result>\n', res[i], res[i+1]), ses);
	}
      http ('</results>\n', ses);
      http_header ('Content-Type: text/xml; charset=UTF-8\r\n');
      ses := string_output_string (ses);
    }
  else -- default format is json
    {
      http ('{"results":[ ', ses);
      for (declare i, l int, l := length (res); i < l; i := i + 2)
	{
	  http (sprintf ('\n  {"uri":"%s","curie":"%s"},', res[i], res[i+1]), ses);
	}
      ses := rtrim (string_output_string (ses), ',');
      ses := ses || '\n ]}\n';
    }
  return ses;
}
;

grant execute on DB.DBA.RM_GET_CURIES to PROXY;

DB.DBA.LOAD_RDF_MAPPER_XBRL_ONTOLOGIES()
;

drop procedure DB.DBA.LOAD_RDF_MAPPER_XBRL_ONTOLOGIES
;

DB.DBA.RM_LOAD_ONTOLOGIES ();

drop procedure DB.DBA.RM_LOAD_ONTOLOGIES;

create procedure RM_DO_SPONGE (in _G any, in sp_type varchar := '', in do_refresh int := null)
{
  declare dedl int;
  set_user_id ('SPARQL');
  dedl := 10;
  declare exit handler for sqlstate '40001' 
  {
    rollback work;
    if (dedl <= 0)
      resignal; 
    dedl := dedl - 1;  
    goto again;
  };
again:  
  if (do_refresh is null)
    DB.DBA.RDF_SPONGE_UP (_G, vector ('get:soft',  'soft',  'refresh_free_text' ,  1, 'meta-cartridges-mode', sp_type));
  else
    DB.DBA.RDF_SPONGE_UP (_G, vector ('get:soft',  'soft',  'refresh_free_text' ,  1, 'meta-cartridges-mode', sp_type, 'get:refresh', do_refresh));
}
;

create procedure RM_GET_TZ (in tz varchar)
{
  return get_keyword (tz, vector (
    'ACDT', -10*60+30,
    'ACST', -09*60+30,
    'ADT', 03*60+00,
    'AEDT', -11*60+00,
    'AEST', -10*60+00,
    'AHDT', 09*60+00,
    'AHST', 10*60+00,
    'AST', 04*60+00,
    'AT', 02*60+00,
    'AWDT', -09*60+00,
    'AWST', -08*60+00,
    'BAT', -03*60+00,
    'BDST', -02*60+00,
    'BET', 11*60+00,
    'BST', -01*60+00,
    'BT', -03*60+00,
    'BZT2', 03*60+00,
    'CADT', -10*60+30,
    'CAST', -09*60+30,
    'CAT', 10*60+00,
    'CCT', -08*60+00,
    'CDT', 05*60+00,
    'CED', -02*60+00,
    'CET', -01*60+00,
    'CST', 06*60+00,
    'EAST', -10*60+00,
    'EDT', 04*60+00,
    'EED', -03*60+00,
    'EET', -02*60+00,
    'EEST', -03*60+00,
    'EST', 05*60+00,
    'FST', -02*60+00,
    'FWT', -01*60+00,
    'GMT', 00*60+00,
    'GST', -10*60+00,
    'HDT', 09*60+00,
    'HST', 10*60+00,
    'IDLE', -12*60+00,
    'IDLW', 12*60+00,
    'IST', -05*60+30,
    'IT', -03*60+30,
    'JST', -09*60+00,
    'JT', -07*60+00,
    'KST', -09*60+00,
    'MDT', 06*60+00,
    'MED', -02*60+00,
    'MET', -01*60+00,
    'MEST', -02*60+00,
    'MEWT', -01*60+00,
    'MST', 07*60+00,
    'MT', -08*60+00,
    'NDT', 02*60+30,
    'NFT', 03*60+30,
    'NT', 11*60+00,
    'NST', -06*60+30,
    'NZ', -11*60+00,
    'NZST', -12*60+00,
    'NZDT', -13*60+00,
    'NZT', -12*60+00,
    'PDT', 07*60+00,
    'PST', 08*60+00,
    'ROK', -09*60+00,
    'SAD', -10*60+00,
    'SAST', -09*60+00,
    'SAT', -09*60+00,
    'SDT', -10*60+00,
    'SST', -02*60+00,
    'SWT', -01*60+00,
    'USZ3', -04*60+00,
    'USZ4', -05*60+00,
    'USZ5', -06*60+00,
    'USZ6', -07*60+00,
    'UT', 00*60+00,
    'UTC', 00*60+00,
    'UZ10', -11*60+00,
    'WAT', 01*60+00,
    'WET', 00*60+00,
    'WST', -08*60+00,
    'YDT', 08*60+00,
    'YST', 09*60+00,
    'ZP4', -04*60+00,
    'ZP5', -05*60+00,
    'ZP6', -06*60+00
 ));
}
;

-- scheduler task if needed to keep volume under certain limit
create procedure CLEAN_SPONGE (in d int := 30, in n int := 2000)
{
  declare res, stat, msg varchar;
  declare inx int;

  declare exit handler for sqlstate '*'
    {
      log_enable (1);
      resignal;
    }
  ;
  log_enable (2);
  inx := 0;
  for select HS_LOCAL_IRI as graph from DB.DBA.SYS_HTTP_SPONGE where HS_EXPIRATION < dateadd ('day', -1*d, now ()) do
    {
       inx := inx + 1;
       stat := '00000';
       exec ('sparql clear graph <'||graph||'>', stat, msg);
       if (inx > n)
         goto endp;
    }
 endp:
  log_enable (1);
}
;

