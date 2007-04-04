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

-- install the handlers for supported metadata, keep in sync with xslt/html2rdf.xsl rules
delete from DB.DBA.SYS_RDF_MAPPERS where RM_PATTERN = '(text/html)|(application/atom.xml)|(text/xml)|(application/xml)|(application/rss.xml)' and RM_TYPE = 'MIME';

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('(text/html)|(application/atom.xml)|(text/xml)|(application/xml)|(application/rss.xml)|(application/rdf.xml)',
            'MIME', 'DB.DBA.RDF_LOAD_HTML_RESPONSE', null, 'xHTML and feeds');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('http://farm[0-9]*.static.flickr.com/.*',
            'URL', 'DB.DBA.RDF_LOAD_FLICKR_IMG', null, 'Flickr Images');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('(http://www.amazon.com/gp/product/.*)|(http://www.amazon.[^/]/o/ASIN/.*)',
            'URL', 'DB.DBA.RDF_LOAD_AMAZON_ARTICLE', null, 'Amazon articles');

insert soft DB.DBA.SYS_RDF_MAPPERS (RM_PATTERN, RM_TYPE, RM_HOOK, RM_KEY, RM_DESCRIPTION)
    values ('(http://cgi.sandbox.ebay.com/.*&item=[A-Z0-9]*&.*)|(http://cgi.ebay.com/.*QQitemZ[A-Z0-9]*QQ.*)',
            'URL', 'DB.DBA.RDF_LOAD_EBAY_ARTICLE', null, 'eBay articles');


-- the GRDDL filters
EXEC_STMT(
'create table DB.DBA.SYS_GRDDL_MAPPING (
    GM_NAME varchar,
    GM_PROFILE varchar,
    GM_XSLT varchar,
    primary key (GM_NAME)
)
create index SYS_GRDDL_MAPPING_PROFILE on DB.DBA.SYS_GRDDL_MAPPING (GM_PROFILE)', 0)
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('eRDF', 'http://purl.org/NET/erdf/profile', registry_get ('_rdf_mappers_path_') || 'xslt/erdf2rdfxml.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('RDFa', '', registry_get ('_rdf_mappers_path_') || 'xslt/rdfa2rdfxml.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('hCard', 'http://www.w3.org/2006/03/hcard', registry_get ('_rdf_mappers_path_') || 'xslt/hcard2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('hCalendar', 'http://dannyayers.com/microformats/hcalendar-profile', registry_get ('_rdf_mappers_path_') || 'xslt/hcal2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('hReview', 'http://dannyayers.com/micromodels/profiles/hreview', registry_get ('_rdf_mappers_path_') || 'xslt/hreview2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('relLicense', '', registry_get ('_rdf_mappers_path_') || 'xslt/cc2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('Dublin Core', '', registry_get ('_rdf_mappers_path_') || 'xslt/dc2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('geoURL', '', registry_get ('_rdf_mappers_path_') || 'xslt/geo2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('Google Base', '', registry_get ('_rdf_mappers_path_') || 'xslt/google2rdf.xsl')
;

insert replacing DB.DBA.SYS_GRDDL_MAPPING (GM_NAME, GM_PROFILE, GM_XSLT)
    values ('Ning Metadata', '', registry_get ('_rdf_mappers_path_') || 'xslt/ning2rdf.xsl')
;

create procedure DB.DBA.XSLT_REGEXP_MATCH (in pattern varchar, in val varchar)
{
  return regexp_match (pattern, val);
}
;

grant execute on DB.DBA.XSLT_REGEXP_MATCH to public;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt/:regexp-match', 'DB.DBA.XSLT_REGEXP_MATCH');

--create procedure RDF_LOAD_AMAZON_ARTICLE_INIT ()
--{
--  if (__proc_exists ('DB.DBA.AmazonSearchService',0) is not null)
--    return;
--  SOAP_WSDL_IMPORT ('http://soap.amazon.com/schemas3/AmazonWebServices.wsdl');
--}
--;

--RDF_LOAD_AMAZON_ARTICLE_INIT ();

create procedure DB.DBA.RDF_LOAD_AMAZON_ARTICLE (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any)
{
  declare xd, xt, url, tmp, api_key, asin, hdr, exif any;
  declare exit handler for sqlstate '*'
    {
      return 0;
    };

  if (new_origin_uri like 'http://www.amazon.com/gp/product/%')
    tmp := sprintf_inverse (new_origin_uri, 'http://www.amazon.%s/gp/product/%s', 0);
  else if (new_origin_uri like 'http://www.amazon.%/o/ASIN/%')
    tmp := sprintf_inverse (new_origin_uri, 'http://www.amazon.%s/o/ASIN/%s', 0);
  else
    return 0;

  api_key := _key;
  if (tmp is null or length (tmp) <> 2 or not isstring (api_key))
    return 0;

  asin := tmp[1];

  url := sprintf ('http://xml.amazon.com/onca/xml3?t=webservices-20&dev-t=%s&AsinSearch=%s&type=lite&f=xml',
          api_key, asin);

--  tmp := xml_tree_doc (
--  	AmazonSearchService.AsinSearchRequest (
--	  soap_box_structure ('asin', asin, 'tag', 'webservices-20', 'type', 'lite', 'devtag', api_key)));
  tmp := http_get (url, hdr);
  if (hdr[0] not like 'HTTP/1._ 200 %')
    signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
  xd := xtree_doc (tmp);
  xt := xslt (registry_get ('_rdf_mappers_path_') || 'xslt/amazon2rdf.xsl', xd, vector ('baseUri', coalesce (dest, graph_iri)));
  -- don't delete here, done in html part already
  --if (dest is null)
  --  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  return 1;
}
;


create procedure DB.DBA.RDF_LOAD_FLICKR_IMG (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout _key any)
{
  declare xd, xt, url, tmp, api_key, img_id, hdr, exif any;
  declare exit handler for sqlstate '*'
    {
      return 0;
    };
  tmp := sprintf_inverse (new_origin_uri, 'http://farm%s.static.flickr.com/%s/%s_%s.%s', 0);
  img_id := tmp[2];
  api_key := _key; --cfg_item_value (virtuoso_ini_path (), 'SPARQL', 'FlickrAPIkey');
  if (tmp is null or length (tmp) <> 5 or not isstring (api_key))
    return 0;
  url := sprintf ('http://api.flickr.com/services/rest/?method=flickr.photos.getInfo&photo_id=%s&api_key=%s',
    img_id, api_key);
  tmp := http_get (url, hdr);
  if (hdr[0] not like 'HTTP/1._ 200 %')
    signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');
  xd := xtree_doc (tmp);
  exif := xtree_doc ('<rsp/>');

  {
      declare exit handler for sqlstate '*' { goto ende; };
      url := sprintf ('http://api.flickr.com/services/rest/?method=flickr.photos.getExif&photo_id=%s&api_key=%s',
	img_id, api_key);
      tmp := http_get (url, hdr);
      if (hdr[0] like 'HTTP/1._ 200 %')
	exif := xtree_doc (tmp);
      ende:;
  }

  xt := xslt (registry_get ('_rdf_mappers_path_') || 'xslt/flickr2rdf.xsl', xd, vector ('baseUri', coalesce (dest, graph_iri), 'exif', exif));
  if (dest is null)
    delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);
  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  return 1;
}
;

create procedure DB.DBA.RDF_LOAD_EBAY_ARTICLE (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout _ret_body any, inout aq any, inout ps any, inout ser_key any)
{
  declare xd, xt, url, tmp, api_key, item_id, hdr, karr, use_sandbox, user_id any;
  declare exit handler for sqlstate '*'
    {
      return 0;
    };

  use_sandbox := 0;
  karr := deserialize (ser_key);
  if (not isarray (karr) or length (karr) <> 2)
    return 0;

  if (new_origin_uri like 'http://cgi.sandbox.ebay.com/%&item=%&%')
    {
      tmp := sprintf_inverse (new_origin_uri, 'http://cgi.sandbox.ebay.com/%s&item=%s&%s', 0);
      use_sandbox := 1;
    }
  else if (new_origin_uri like 'http://cgi.ebay.com/%QQitemZ%QQ%')
    tmp := sprintf_inverse (new_origin_uri, 'http://cgi.ebay.com/%sQQitemZ%sQQ%s', 0);
  else
    return 0;

  api_key := karr[0];
  user_id := karr[1];
  if (tmp is null or length (tmp) <> 3 or not isstring (api_key) or not isstring (user_id))
    return 0;

  item_id := tmp[1];

  url := sprintf ('http://rest.api%s.ebay.com/restapi?CallName=GetItem&RequestToken=%s&RequestUserId=%s&ItemID=%s&Version=491',
          case when use_sandbox = 1 then '.sandbox' else '' end,
	  api_key, user_id, item_id);

--  dbg_obj_print (url);

  tmp := http_get (url, hdr);
  if (hdr[0] not like 'HTTP/1._ 200 %')
    signal ('22023', trim(hdr[0], '\r\n'), 'RDFXX');

  xd := xtree_doc (tmp);
  xt := xslt (registry_get ('_rdf_mappers_path_') || 'xslt/ebay2rdf.xsl', xd, vector ('baseUri', coalesce (dest, graph_iri)));

  xd := serialize_to_UTF8_xml (xt);
  DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
  return 1;
}
;

create procedure RDF_MAPPER_CACHE_CHECK (in url varchar, in top_url varchar, out old_etag varchar, out old_last_modified any)
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
  DB.DBA.SYS_HTTP_SPONGE_GET_CACHE_PARAMS (explicit_refresh, old_last_modified,
      hdr, new_expiration, ret_content_type, ret_etag, ret_date, ret_expires, ret_last_modif,
       ret_dt_date, ret_dt_expires, ret_dt_last_modified);

  --dbg_obj_print (old_last_modified, new_expiration, ret_content_type, ret_etag, ret_date, ret_expires, ret_last_modif,
  --     ret_dt_date, ret_dt_expires, ret_dt_last_modified);

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

--
-- GRDDL filters, if signature changed web robot needs to be updated too
--
create procedure DB.DBA.RDF_LOAD_HTML_RESPONSE (in graph_iri varchar, in new_origin_uri varchar,  in dest varchar,
    inout ret_body any, inout aq any, inout ps any, inout _key any)
{
  -- check to microformats
  declare xt_sav, xt, xd, profile, mdta, xslt_style, profs, profs_done, feed_url any;
  declare xmlnss, i, l, nss, rdf_url_arr, content, hdr, rdf_in_html, old_etag, old_last_modified any;
  declare ret_flag, is_grddl, download_size, load_msec int;

  set_user_id ('dba');
  mdta := 0;
  ret_flag := 1;
  hdr := null;
  declare exit handler for sqlstate '*'
    {
      goto no_microformats;
    };

  if (dest is null)
    delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_iri);

  xt_sav := xt := xtree_doc (ret_body, 2);

  -- this maybe is not need to be here, as it's a kind of content negotiation
  rdf_url_arr  := xpath_eval ('//head/link[ @rel="meta" and @type="application/rdf+xml" ]/@href', xt, 0);
  if (length (rdf_url_arr))
    {
      declare rdf_url_inx int;
      rdf_url_inx := 0;
      foreach (any rdf_url in rdf_url_arr) do
	{
	  declare exit handler for sqlstate '*' { goto try_next_link; };
	  rdf_url := cast (rdf_url as varchar);
	  if (RDF_MAPPER_CACHE_CHECK (rdf_url, new_origin_uri, old_etag, old_last_modified))
	    goto try_next_link;
	  load_msec := msec_time ();
	  hdr := null;
	  content := RDF_HTTP_URL_GET (rdf_url, new_origin_uri, hdr);
	  load_msec := msec_time () - load_msec;
	  download_size := length (content);
	  DB.DBA.RDF_LOAD_RDFXML (content, new_origin_uri, coalesce (dest, graph_iri));
	  RDF_MAPPER_CACHE_REGISTER (rdf_url, new_origin_uri, hdr, old_last_modified, download_size, load_msec);
	  rdf_url_inx := rdf_url_inx + 1;
	  ret_flag := -1;
	  try_next_link:;
	}
    }

  -- sometimes RDF is inside the xhtml
  if (xpath_eval ('/html//rdf', xt) is not null)
    {
      declare exit handler for sqlstate '*' { goto try_grddl; };
      rdf_in_html := xpath_eval ('/html//RDF', xtree_doc (ret_body), 0);
      foreach (any x in rdf_in_html) do
	{
	    xd := serialize_to_UTF8_xml (x);
	    DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
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
  profile := cast (xpath_eval ('/html/head/@profile', xt) as varchar);
  is_grddl := 0;
  if (xpath_eval ('[ xmlns:dv="http://www.w3.org/2003/g/data-view#" ] /*[1]/@dv:transformation', xt) is not null)
    {
      if (xpath_eval ('/rdf', xt) is not null)
	{
	  declare exit handler for sqlstate '*' { goto not_rdf; };
          xd :=  xslt (registry_get ('_rdf_mappers_path_') || 'xslt/rdf_wo_grddl.xsl', xtree_doc (ret_body));
	  xd := serialize_to_UTF8_xml (xd);
	  DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	  mdta := mdta + 1;
	}
      not_rdf:;
      is_grddl := 1;
    }
  profs := null;
  profs_done := vector ();
  if (profile is not null)
    profs := split_and_decode (profile, 0, '\0\0 ');

  -- GRDDL - plan A, eRDF going here
  if (profs is not null)
    {
      foreach (any prof in profs) do
	{
	  xslt_style := (select GM_XSLT from DB.DBA.SYS_GRDDL_MAPPING where GM_PROFILE = prof);
	  if (xslt_style is not null)
	    {
	      declare exit handler for sqlstate '*' { goto next_prof; };
	      xd := xslt (xslt_style, xt, vector ('baseUri', coalesce (dest, graph_iri)));
	      if (xpath_eval ('count(/RDF/*)', xd) > 0)
		mdta := mdta + 1;
	      xd := serialize_to_UTF8_xml (xd);
	      DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	      profs_done := vector_concat (profs_done, vector (prof));
	    }
	  next_prof:;
        }
    }
  if (strstr (profile, 'http://www.w3.org/2003/g/data-view') is not null or is_grddl)
    {
      declare xsl_arr, media any;
      -- GRDDL - plan B, the xslt is specified in the document
      declare exit handler for sqlstate '*' { goto try_rdfa; };
      xsl_arr := xpath_eval ('[ xmlns:dv="http://www.w3.org/2003/g/data-view#" ] '||
	'/html/head/link[@rel="transformation"]/@href|//a[@rel="transformation"]/@href|/*[1]/@dv:transformation',
         xt, 0);
      foreach (any xslt_uri in xsl_arr) do
	{
	  declare cnt, xsl_xd any;
	  declare exit handler for sqlstate '*' { goto try_next; };
	  xslt_uri := WS.WS.EXPAND_URL (new_origin_uri, cast (xslt_uri as varchar));
	  {
	    declare exit handler for sqlstate '*' { goto try_w3c; };
	    xd := xslt (xslt_uri, xt);
	    if (xpath_eval ('count(/RDF/*)', xd) > 0)
	      {
	        mdta := mdta + 1;
              }
	    media := xml_tree_doc_media_type (xd);
	    xd := serialize_to_UTF8_xml (xd);
	    if (media = 'text/rdf+n3')
	      {
	        DB.DBA.TTLP (xd, new_origin_uri, coalesce (dest, graph_iri));
	        mdta := mdta + 1;
	      }
	    else
	      DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	    goto try_next;
	  }
          try_w3c:
	  xd := http_get (sprintf ('http://www.w3.org/2000/06/webdata/xslt?xslfile=%U;xmlfile=%U', xslt_uri, graph_iri));
	  if (xpath_eval ('count(/RDF/*)', xtree_doc (xd)) > 0)
	    {
	      mdta := mdta + 1;
	    }
          xslt_done:
	  DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
          try_next:;
	}
    }
  try_rdfa:;

  if (is_grddl and xpath_eval ('/html', xt) is null)
    goto ret;

    {
      -- currently no profile in RDFa and some similar, so we try it to extract directly
      for select GM_XSLT, GM_PROFILE from DB.DBA.SYS_GRDDL_MAPPING do
	{
	  if (position (GM_PROFILE, profs_done) > 0)
	    goto try_next1;
	  declare exit handler for sqlstate '*' { goto try_next1; };
	  xd := xslt (GM_XSLT, xt, vector ('baseUri', coalesce (dest, graph_iri), 'nss', nss));
	  if (xpath_eval ('count(/RDF/*)', xd) > 0)
	    {
	      mdta := mdta + 1;
	      xd := serialize_to_UTF8_xml (xd);
	      DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	    }
	  try_next1:;
	}
    }
    -- /* feed formats */
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
	  if (RDF_MAPPER_CACHE_CHECK (atom, new_origin_uri, old_etag, old_last_modified))
	    goto no_feed;
	  load_msec := msec_time ();
	  content := DB.DBA.RDF_HTTP_URL_GET (atom, new_origin_uri, hdr);
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
	  if (RDF_MAPPER_CACHE_CHECK (rss, new_origin_uri, old_etag, old_last_modified))
	    goto no_feed;
	  load_msec := msec_time ();
	  content := DB.DBA.RDF_HTTP_URL_GET (rss, new_origin_uri, hdr);
	  load_msec := msec_time () - load_msec;
	  download_size := length (content);
	  xt := xtree_doc (content);
        }
do_detect:;

	-- the document itself is a feed
	if (xt is null and xpath_eval ('/rdf|/rss|/feed', xt_sav) is not null)
	  xt := xtree_doc (ret_body);

	if (xt is null)
	  goto no_feed;
	else if (xpath_eval ('/RDF', xt) is not null and content is not null)
	  {
	    xd := content;
	    goto ins_rdf;
	  }
	else if (xpath_eval ('/feed', xt) is not null)
	  {
	    xd := xslt (registry_get ('_rdf_mappers_path_') || 'xslt/atom2rdf.xsl', xt);
	  }
	else if (xpath_eval ('/rss', xt) is not null)
	  {
	    xd := xslt (registry_get ('_rdf_mappers_path_') || 'xslt/rss2rdf.xsl', xt);
	  }
	else
	  goto no_feed;

	if (xpath_eval ('count(/RDF/*)', xd) > 0)
          {
	    mdta := mdta + 1;
	  }
	xd := serialize_to_UTF8_xml (xd);
ins_rdf:
	DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	RDF_MAPPER_CACHE_REGISTER (feed_url, new_origin_uri, hdr, old_last_modified, download_size, load_msec);
	ret_flag := -1;
no_feed:;
    }
  -- generic xHTML, extraction as per our ontology
  xt := xt_sav;
  if (xpath_eval ('/html', xt) is not null)
    {
      xd := xslt (registry_get ('_rdf_mappers_path_') || 'xslt/html2rdf.xsl', xt, vector ('base', coalesce (dest, graph_iri)));
      if (xpath_eval ('count(/RDF/*)', xd) > 0)
        {
	  mdta := mdta + 1;
          xd := serialize_to_UTF8_xml (xd);
          DB.DBA.RDF_LOAD_RDFXML (xd, new_origin_uri, coalesce (dest, graph_iri));
	}
    }
ret:
  if (mdta > 0 and aq is not null)
    aq_request (aq, 'DB.DBA.RDF_SW_PING', vector (ps, new_origin_uri));

  -- special cases, which needs to call something else
  if (regexp_match ('(http://www.amazon.com/gp/product/[^/]*)|(http://www.amazon.[^/]*/o/ASIN/[^/]*)', new_origin_uri) is not null)
    mdta := 0;

  if (regexp_match ('(http://cgi.sandbox.ebay.com/.*&item=[A-Z0-9]*&.*)|(http://cgi.ebay.com/.*QQitemZ[A-Z0-9]*QQ.*)', new_origin_uri) is not null)
    mdta := 0;

  return (mdta * ret_flag);
  no_microformats:;
  return 0;
}
;
