--
--  $Id$
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

create function DAV_GUESS_MIME_TYPE_BY_NAME (in orig_res_name varchar) returns varchar
{
  declare dot_pos integer;
  declare orig_res_ext, orig_res_ext_upper varchar;
  -- dbg_obj_princ ('DAV_GUESS_MIME_TYPE_BY_NAME (', orig_res_name, ')');
  dot_pos := strrchr (orig_res_name, '.');
  if (dot_pos is null or (0 = dot_pos))
    return null;
  else
    orig_res_ext := subseq (orig_res_name, dot_pos);
  orig_res_ext_upper := upper (orig_res_ext);
  if (position (orig_res_ext_upper, vector ('.EML')))
    return 'text/eml';
  if (position (orig_res_ext_upper, vector ('.HTM', '.HTML', '.XHTML')))
    return 'text/html';
  if (position (orig_res_ext_upper, vector ('.XSL', '.XSLT', '.XSD')))
    return 'application/xml';
  if (position (orig_res_ext_upper, vector ('.VCARD', '.VCF', '.ICAL', '.ICS')))
    return 'text/directory';
  if (position (orig_res_ext_upper, vector ('.DTD')))
    return 'application/xml-dtd';
  if (position (orig_res_ext_upper, vector ('.VAD')))
    return 'application/x-openlinksw-vad';
  if (position (orig_res_ext_upper, vector ('.VSP')))
    return 'application/x-openlinksw-vsp';
  if (position (orig_res_ext_upper, vector ('.LIC')))
    return 'application/x-openlink-license';
  if (position (orig_res_ext_upper, vector ('.XBRL')))
    return 'application/xbrl+xml';
  if (position (orig_res_ext_upper, vector ('.TXT')) and 
	connection_get ('oWiki Topic') is not null and 
	connection_get ('oWiki Topic') = orig_res_name)
    {
      return 'text/wiki';
    }
  if (position (orig_res_ext_upper,
    vector ('.BMP', '.DIB', '.RLE', '.CR2', '.CRW', '.EMF', '.EPS', '.IFF', '.LBM', '.JP2', '.JPX', '.JPK', '.J2K',
     '.JPC', '.J2C', '.JPE', '.JIF', '.JFIF', '.JPG', '.JPEG', '.GIF') ) )
    return 'application/x-openlink-image';
--  if (position (orig_res_ext_upper,
--    vector ('.RDF', '.RDFS') ) )
--    return 'application/rdf+xml';
  if (position (orig_res_ext_upper,
    vector ('.XML', '.RDF', '.RDFS', '.RSS', '.RSS2', '.XBEL', '.FOAF', '.OPML', '.WSDL', '.BPEL', '.VSPX', '.VSCX', '.XDDL') ) )
    return 'text/xml';
  if (position (orig_res_ext_upper,
    vector ('.TAR') ) )
    return 'application/tar';
  if (position (orig_res_ext_upper,
    vector ('.TAZ') ) )
    return 'application/taz';
  if (position (orig_res_ext_upper,
    vector ('.GZ') ) )
    return 'application/gz';
  if (position (orig_res_ext_upper,
    vector ('.MSI') ) )
    return 'application/msi';
  if (position (orig_res_ext_upper,
    vector ('.DMG') ) )
    return 'application/dmg';
  if (position (orig_res_ext_upper,
    vector ('.ARJ') ) )
    return 'application/arj';
  if (position (orig_res_ext_upper,
    vector ('.BZ') ) )
    return 'application/bz';
  if (position (orig_res_ext_upper,
    vector ('.BZ2') ) )
    return 'application/bz2';
  if (position (orig_res_ext_upper,
    vector ('.TGZ') ) )
    return 'application/tgz';
  if (position (orig_res_ext_upper,
    vector ('.RAR') ) )
    return 'application/rar';
  if (position (orig_res_ext_upper,
    vector ('.ZIP') ) )
    return 'application/zip';
  if (position (orig_res_ext_upper,
    vector ('.CAB') ) )
    return 'application/cab';
  if (position (orig_res_ext_upper,
    vector ('.LZH') ) )
    return 'application/lzh';
  if (position (orig_res_ext_upper,
    vector ('.ACE') ) )
    return 'application/ace';
  if (position (orig_res_ext_upper,
    vector ('.ISO') ) )
    return 'application/iso';
  if (position (orig_res_ext_upper,
    vector ('.TTL') ) )
    return 'text/rdf+ttl';
  if (position (orig_res_ext_upper,
    vector ('.N3') ) )
    return 'text/rdf+n3';
  return coalesce ((select T_TYPE from WS.WS.SYS_DAV_RES_TYPES where T_EXT = lower (subseq (orig_res_ext, 1))));
}
;

create function DAV_GUESS_MIME_TYPE (in orig_res_name varchar, inout content any, inout html_start any) returns varchar
{
  declare content_len integer;
  declare dflt_ret varchar;
  -- dbg_obj_princ ('DAV_GUESS_MIME_TYPE (', orig_res_name, '..., ...)');
  whenever sqlstate '*' goto no_op;
  content_len := length (content);
  if (__tag (content) in (125, 126, 132, 133))
    {
      declare beginning varchar;
      if (content_len < 10000000)
        beginning := blob_to_string (content);
      else
        beginning := null;
      return DAV_GUESS_MIME_TYPE (orig_res_name, beginning, html_start);
    }
  dflt_ret := DAV_GUESS_MIME_TYPE_BY_NAME (orig_res_name);
  if ('text/xml' = dflt_ret)
    {
      declare exit handler for sqlstate '*'
        {
          return dflt_ret;
        };
      if (content is null)
        {
          -- dbg_obj_princ ('null content');
          return 'text/xml';
        }
      if (html_start is null)
        {
          if (230 = __tag (content))
            html_start := content;
          else
            {
              declare frag_len, min_frag_len, max_frag_len integer;
              max_frag_len := length (content);
              if (max_frag_len > 30000)
                {
                  max_frag_len := 30000;
                  min_frag_len := 20000;
                }
              else
                {
                  min_frag_len := max_frag_len;
                }
              for (frag_len := max_frag_len; (frag_len >= min_frag_len) and (html_start is null); frag_len := frag_len - 1000)
                {
                  -- dbg_obj_princ ('Will try to parse\n', subseq (content, 0, frag_len));
          	  html_start := xtree_doc (subseq (content, 0, frag_len), 18, 'http://localdav.virt/' || orig_res_name, 'LATIN-1', 'x-any',
            			'Validation=DISABLE Include=DISABLE BuildStandalone=DISABLE SchemaDecl=DISABLE' );
                  -- dbg_obj_princ ('The result is\n', html_start);
                }
            }
        }
      -- dbg_obj_princ ('guessing ', html_start);
      -- dbg_obj_princ ('based on ', content, 'dtp', __tag (content));
      if (xpath_eval ('[xmlns="http://usefulinc.com/ns/doap#"] exists (/project)', html_start))
        return 'application/doap+rdf';
      if (xpath_eval ('[xmlns:atom="http://purl.org/atom/ns#"] exists (/atom:feed[@version])', html_start))
        return 'application/atom+xml';
      if (xpath_eval ('[xmlns:w="http://schemas.microsoft.com/office/word/2003/wordml"] exists (/w:worddocument)', html_start))
        return 'application/msword+xml';
      if (xpath_eval ('[xmlns="urn:schemas-microsoft-com:office:spreadsheet"] exists (/Workbook)', html_start))
          return 'application/msexcel+xml';
      if (xpath_eval ('[xmlns="http://schemas.microsoft.com/project"] exists (/Project)', html_start))
          return 'application/msproject+xml';
      if (xpath_eval ('[xmlns="http://schemas.microsoft.com/visio/2003/core"] exists (/VisioDocument)', html_start))
          return 'application/msvisio+xml';
      if (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:foaf="http://xmlns.com/foaf/0.1/"]exists (/rdf:rdf/foaf:*)', html_start))
        return 'application/foaf+xml';
      if (xpath_eval ('exists (/xbel)', html_start))
        return 'application/xbel+xml';
      if (xpath_eval ('exists (/database)', html_start))
        return 'application/xddl+xml';
      -- modscollection is lowercase, instead of proper modsCollection, dirty HTML again.
      if (xpath_eval ('exists (/modscollection|/mods)', html_start))
        return 'application/mods+xml';
      if (xpath_eval ('exists (/opml[@version])', html_start))
        return 'application/opml+xml';
      -- rdf:rdf is lowercase, instead of proper rdf:RDF because dirty HTML mode converts names.
      if (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rss="http://purl.org/rss/1.0/"]exists (/rdf:rdf/rss:channel)', html_start))
        return 'application/rss+xml';
      if (xpath_eval ('exists (/rss[@version])', html_start))
        return 'application/rss+xml';
      if (xpath_eval ('[xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"]exists (/wsdl:definitions)', html_start))
        return 'application/wsdl+xml';
      if (xpath_eval ('[xmlns:gd="http://schemas.google.com/g/2005"] exists (/entry)', html_start))
        return 'application/google-kinds+xml';
      if (xpath_eval ('[xmlns:bpel="http://schemas.xmlsoap.org/ws/2003/03/business-process/"]exists (/bpel:process)', html_start))
        return 'application/bpel+xml';
      if (xpath_eval ('[xmlns:v="http://www.openlinksw.com/vspx/"]exists (/v:*|//v:page)', html_start))
        return 'application/x-openlinksw-vspx+xml';
      if (xpath_eval ('[xmlns="http://www.xbrl.org/2003/instance"] exists (/xbrl)', html_start))
        return 'application/xbrl+xml';
      -- rdf:rdf is lowercase, instead of proper rdf:RDF because dirty HTML mode converts names.
      if (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"] exists(/rdf:rdf)', html_start))
        return 'application/rdf+xml';
      return dflt_ret;
    }
  if (dflt_ret = 'application/x-openlink-license')
    {
      declare mydata, exp_date varchar;
      mydata := "asn1_to_xml" (content, length(blob_to_string (content)));
      exp_date := cast(xpath_eval('//SEQUENCE/SEQUENCE/SEQUENCE/SEQUENCE[PRINTABLESTRING="ExpireDate"]/PRINTABLESTRING[position() > 1]/text()', xtree_doc(mydata)) as varchar);
      if (exp_date is not null and exp_date <> '')
        {
          return 'application/x-openlink-license';
        }
    }
  if (dflt_ret = 'application/x-openlink-image')
    {
      declare image_format varchar;
      image_format := "IM GetImageBlobFormat" (content, length(blob_to_string (content)));
      if (image_format is not null)
        {
          image_format := "IM GetImageBlobAttribute" (content, length(blob_to_string (content)), 'EXIF:Model');
          if (image_format is not null and image_format <> '' and image_format <> 'unknown' and image_format <> '.')
            return 'application/x-openlink-photo';
          else
            return 'application/x-openlink-image';		
        }
    }
no_op:
  return dflt_ret;
}
;

create procedure file_space_fmt (in d integer) returns varchar
{
  declare ret float;
  if (d is null or d = 0)
    return 'N/A';
  if (d >= 1024 and d < 1048576)
  {
    ret := d/1024;
    return sprintf('%d KB', ret);
  }
  if (d >= 1048576)
  {
    ret := d/1024/1024;
    return sprintf('%d MB', ret);
  }
  else
    return sprintf('%d B', d);
}
;

create function "DAV_EXTRACT_RDF_application/x-openlink-license" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
  declare doc, metas, res, content any;
  whenever sqlstate '*' goto errexit;
	content := blob_to_string (content1);
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/x-openlink-license (', orig_res_name, ',... )');
  xte_nodebld_init(res);
  declare mydata, reg_to, con_num, serial varchar;
  mydata := "asn1_to_xml" (content, length(blob_to_string (content)));
  reg_to := cast(xpath_eval('//SEQUENCE/SEQUENCE/SEQUENCE/SEQUENCE[PRINTABLESTRING="RegisteredTo"]/PRINTABLESTRING[position() > 1]/text()', xtree_doc(mydata)) as varchar);
  con_num := cast(xpath_eval('//SEQUENCE/SEQUENCE/SEQUENCE/SEQUENCE[PRINTABLESTRING="NumberOfConnections"]/PRINTABLESTRING[position() > 1]/text()', xtree_doc(mydata)) as varchar);
  serial := cast(xpath_eval('//SEQUENCE/SEQUENCE/SEQUENCE/SEQUENCE[PRINTABLESTRING="SerialNumber"]/PRINTABLESTRING[position() > 1]/text()', xtree_doc(mydata)) as varchar);
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/OplLic#RegisteredTo'), reg_to));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/OplLic#ConnectionNumber'), con_num));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/OplLic#SerialNumber'), serial));
  xte_nodebld_final(res, xte_head (UNAME' root'));
  return xml_tree_doc (res);
errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/x-openlink-image" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
  declare doc, metas, res, content any;
  whenever sqlstate '*' goto errexit;
	content := blob_to_string (content1);
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/x-openlink-image (', orig_res_name, ',... )');
  xte_nodebld_init(res);
  declare image_size, xsize, ysize, depth integer; 
  declare image_format, comments, xres, yres varchar;
	image_format := "IM GetImageBlobFormat"(content, length(content));
  image_size := length(content);
  xsize := "IM GetImageBlobWidth"(content, length(content));
	ysize := "IM GetImageBlobHeight"(content, length(content));
  xres := "IM GetImageBlobAttribute"(content, length(content), 'EXIF:XResolution');
  yres := "IM GetImageBlobAttribute"(content, length(content), 'EXIF:YResolution');
  depth := "IM GetImageBlobDepth"(content, length(content));
  comments := "IM GetImageBlobAttribute"(content, length(content), 'Comment');
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Image#type'), image_format));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Image#size'), file_space_fmt(image_size)));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Image#dimensions'), sprintf('%dx%d', xsize, ysize)));
  if (xres is not null and yres is not null)
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Image#resolutions'), sprintf('%s:%s', xres, yres)));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Image#depth'), sprintf('%d', depth)));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Image#comments'), comments));
  xte_nodebld_final(res, xte_head (UNAME' root'));
  return xml_tree_doc (res);
errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/x-openlink-photo" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
  declare doc, metas, res, content any;
  whenever sqlstate '*' goto errexit;
	content := blob_to_string (content1);
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/x-openlink-image (', orig_res_name, ',... )');
  xte_nodebld_init(res);
  declare image_size, xsize, ysize, depth integer; 
  declare image_format, comments, xres, yres varchar;
	image_format := "IM GetImageBlobFormat"(content, length(content));
  image_size := length(content);
  xsize := "IM GetImageBlobWidth"(content, length(content));
	ysize := "IM GetImageBlobHeight"(content, length(content));
  xres := "IM GetImageBlobAttribute"(content, length(content), 'EXIF:XResolution');
  yres := "IM GetImageBlobAttribute"(content, length(content), 'EXIF:YResolution');
  depth := "IM GetImageBlobDepth"(content, length(content));
  comments := "IM GetImageBlobAttribute"(content, length(content), 'Comment');
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Photo#type'), image_format));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Photo#size'), file_space_fmt(image_size)));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Photo#dimensions'), sprintf('%dx%d', xsize, ysize)));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Photo#resolutions'), sprintf('%s:%s', xres, yres)));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Photo#depth'), sprintf('%d', depth)));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Photo#comments'), comments));
  xte_nodebld_final(res, xte_head (UNAME' root'));
  return xml_tree_doc (res);
errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/msoffice+xml" (in type_descr varchar, in orig_res_name varchar, inout content any, inout html_start any, inout docprops any)
{
  declare doc, metas, extras any;
  whenever sqlstate '*' goto errexit;
  if (docprops is null)
    {
      doc := xtree_doc (content, 0);
      docprops := xpath_eval ('/*/*:DocumentProperties', doc);
    }
  metas := vector (
        'http://www.openlinksw.com/schemas/Office#Title'	, 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Title'					, NULL,
        'http://www.openlinksw.com/schemas/Office#Author'	, 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Author|o:Creator'				, NULL,
        'http://www.openlinksw.com/schemas/Office#LastAuthor'	, 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:LastAuthor'					, NULL,
        'http://www.openlinksw.com/schemas/Office#Company'	, 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Company'					, NULL,
        'http://www.openlinksw.com/schemas/Office#Words'	, 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Words'					, NULL,
        'http://www.openlinksw.com/schemas/Office#Pages'	, 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Pages'					, NULL,
        'http://www.openlinksw.com/schemas/Office#Lines'	, 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Lines'					, NULL,
        'http://www.openlinksw.com/schemas/Office#Last-Saved'	, 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:LastSaved|o:TimeSaved'			, NULL,
        'http://www.openlinksw.com/schemas/Office#Last-Printed'	, 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:LastPrinted|o:TimePrinted'			, NULL,
        'http://www.openlinksw.com/schemas/Office#Created'	, 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Created|o:TimeCreated|o:CreationDate'	, NULL );
  extras := vector (
        'http://www.openlinksw.com/schemas/Office#TypeDescr'	,  type_descr );
  return "DAV_EXTRACT_RDF_BY_METAS" (docprops, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;


create function "DAV_EXTRACT_RDF_application/msexcel" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  doc := null;
  metas := null;
  extras := vector (
        'http://www.openlinksw.com/schemas/Office#TypeDescr'	,  'MS Excel spreadsheet' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
}
;


create function "DAV_EXTRACT_RDF_application/msproject" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  doc := null;
  metas := null;
  extras := vector (
        'http://www.openlinksw.com/schemas/Office#TypeDescr'	,  'MS Project document' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
}
;


create function "DAV_EXTRACT_RDF_application/mspowerpoint" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  doc := null;
  metas := null;
  extras := vector (
        'http://www.openlinksw.com/schemas/Office#TypeDescr'	,  'MS PowerPoint presentation' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
}
;


create function "DAV_EXTRACT_RDF_application/msword" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  doc := null;
  metas := null;
  extras := vector (
        'http://www.openlinksw.com/schemas/Office#TypeDescr'	,  'MS Word document' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
}
;


create function "DAV_EXTRACT_RDF_application/pdf" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  doc := null;
  metas := null;
  extras := vector (
        'http://www.openlinksw.com/schemas/Office#TypeDescr'	,  'PDF (Acrobat)' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
}
;


create function "DAV_EXTRACT_RDF_application/xbrl+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  metas := vector (
        'http://www.openlinksw.com/schemas/xbrl#identifier', 'declare namespace xmlns="http://www.xbrl.org/2003/instance"; /xmlns:xbrl/xmlns:context/xmlns:entity/xmlns:identifier', '',
        'http://www.openlinksw.com/schemas/xbrl#startDate', 'declare namespace xmlns="http://www.xbrl.org/2003/instance"; /xmlns:xbrl/xmlns:context/xmlns:period/xmlns:startDate union /xmlns:xbrl/xmlns:context/xmlns:period/xmlns:instant', '',
        'http://www.openlinksw.com/schemas/xbrl#endDate', 'declare namespace xmlns="http://www.xbrl.org/2003/instance"; /xmlns:xbrl/xmlns:context/xmlns:period/xmlns:endDate union /xmlns:xbrl/xmlns:context/xmlns:period/xmlns:instant', ''
        );
  extras := null;
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/doap+rdf" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/doap+rdf (', orig_res_name, ',... )');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
	  -- dbg_obj_princ (doc);
  metas := vector (
        'http://www.openlinksw.com/schemas/doap#title', 'declare namespace xmlns="http://usefulinc.com/ns/doap#"; /xmlns:Project/xmlns:name', '',
        'http://www.openlinksw.com/schemas/doap#description', 'declare namespace xmlns="http://usefulinc.com/ns/doap#"; /xmlns:Project/xmlns:shortdesc', '',
        'http://www.openlinksw.com/schemas/doap#creationDate', 'declare namespace xmlns="http://usefulinc.com/ns/doap#"; /xmlns:Project/xmlns:created', ''
        );
  extras := null;
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/xddl+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  metas := vector (
        'http://www.openlinksw.com/schemas/XDDL#catalog', '/database/catalog', NULL,
        'http://www.openlinksw.com/schemas/XDDL#schema', '/database/schema', NULL,
        'http://www.openlinksw.com/schemas/XDDL#table', '/database/tables/table/@name', NULL,
        'http://www.openlinksw.com/schemas/XDDL#view', '/database/views/view/@name', NULL,
        'http://www.openlinksw.com/schemas/XDDL#procedure', '/database/procedures/procedure/@name', NULL
        );
  extras := vector (
        'http://www.openlinksw.com/virtdav#dynRdfExtractor', 'application/xddl+xml'
        );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/archive" (in type_descr varchar, in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  --dbg_obj_princ ('DAV_EXTRACT_RDF_application/archive (', type_descr, orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  metas := vector (
        'http://www.openlinksw.com/schemas/Archive#type', type_descr, type_descr);
  extras := null; 
  --vector (
  --      'http://www.openlinksw.com/virtdav#dynRdfExtractor', 'application/archive');
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/tar" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('TAR archive', orig_res_name, content, html_start);
}
;

create function "DAV_EXTRACT_RDF_application/taz" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('TAZ archive', orig_res_name, content, html_start);
}
;

create function "DAV_EXTRACT_RDF_application/gz" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('Gzip archive', orig_res_name, content, html_start);
}
;

create function "DAV_EXTRACT_RDF_application/msi" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('Microsoft installer', orig_res_name, content, html_start);
}
;

create function "DAV_EXTRACT_RDF_application/dmg" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('DMG install package', orig_res_name, content, html_start);
}
;

create function "DAV_EXTRACT_RDF_application/arj" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('ARJ archive', orig_res_name, content, html_start);
}
;

create function "DAV_EXTRACT_RDF_application/bz" (in orig_res_name varchar, inout content any, inout html_start any)
{
 return "DAV_EXTRACT_RDF_application/archive" ('BZ archive', orig_res_name, content, html_start);
}
;

create function "DAV_EXTRACT_RDF_application/bz2" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('BZ2 archive', orig_res_name, content, html_start);
}
;

create function "DAV_EXTRACT_RDF_application/tgz" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('TGZ archive', orig_res_name, content, html_start);
}
;

create function "DAV_EXTRACT_RDF_application/rar" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('RAR archive', orig_res_name, content, html_start);
}
;
 
create function "DAV_EXTRACT_RDF_application/zip" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('ZIP archive', orig_res_name, content, html_start);
}
;  

create function "DAV_EXTRACT_RDF_application/cab" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('CAB archive', orig_res_name, content, html_start);
}
;  

create function "DAV_EXTRACT_RDF_application/lzh" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('LZH archive', orig_res_name, content, html_start);
}
;  

create function "DAV_EXTRACT_RDF_application/ace" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('ACE archive', orig_res_name, content, html_start);
}
;  

create function "DAV_EXTRACT_RDF_application/iso" (in orig_res_name varchar, inout content any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/archive" ('ISO image archive', orig_res_name, content, html_start);
}
;  

create function "DAV_EXTRACT_RDF_application/msword+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare docprops any;
  docprops := null;
  return "DAV_EXTRACT_RDF_application/msoffice+xml" ('Word Document', orig_res_name, content, html_start, docprops);
}
;

create function "DAV_EXTRACT_RDF_application/msexcel+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare docprops any;
  docprops := null;
  return "DAV_EXTRACT_RDF_application/msoffice+xml" ('Excel Spreadsheet', orig_res_name, content, html_start, docprops);
}
;

create function "DAV_EXTRACT_RDF_application/msproject+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare docprops any;
  docprops := null;
  return "DAV_EXTRACT_RDF_application/msoffice+xml" ('Project', orig_res_name, content, html_start, docprops);
}
;

create function "DAV_EXTRACT_RDF_application/msvisio+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare docprops any;
  docprops := null;
  return "DAV_EXTRACT_RDF_application/msoffice+xml" ('Visio', orig_res_name, content, html_start, docprops);
}
;


create function "DAV_EXTRACT_RDF_application/rss+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, res any;
  xte_nodebld_init (res);
   -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/rss+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto final;
  doc := xtree_doc (content, 0);
  -- dbg_obj_princ ('doc is ', doc);
  if (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rss="http://purl.org/rss/1.0/"]exists (/rdf:RDF/rss:channel)', doc))
    {
      declare tmp_n3, channel_props any;
      declare about varchar;
      -- dbg_obj_princ ('RDF RSS, ', doc);
      tmp_n3 := xslt ('http://local.virt/rdfxml2n3xml', doc);
      -- dbg_obj_princ ('tmp_n3 is ', tmp_n3);
      about := xpath_eval ('/N3[@N3P="http://www.w3.org/1999/02/22-rdf-syntax-ns#type"][@N3O="http://purl.org/rss/1.0/channel"]/@N3S', tmp_n3);
      if (about is null)
        {
          -- dbg_obj_princ ('final?');
          goto final;
        }
      channel_props := xpath_eval ('/N3[@N3S=\044about][not (exists (@N3O))]', tmp_n3, 0, vector (UNAME'about', about));
      foreach (any prop in channel_props) do
        {
          -- dbg_obj_princ ('prop ', prop);
          xte_nodebld_acc (res,
            xte_node (
              xte_head (UNAME'N3', UNAME'N3S', 'http://local.virt/this', UNAME'N3P', xpath_eval ('@N3P', prop)),
              xpath_eval ('string (.)', prop) ) );
        }
    }
  else
    {
      declare version decimal;
      declare metas, extras any;
      version := xpath_eval ('number (/rss/@version)', doc);
      if (version < 0.9)
        goto final;
      metas := vector (
        'http://purl.org/rss/1.0/title', '/rss/channel/title', NULL,
        'http://purl.org/rss/1.0/link', '/rss/channel/link', NULL,
        'http://purl.org/rss/1.0/description', '/rss/channel/description', NULL,
        'http://purl.org/rss/1.0/language', '/rss/channel/language', NULL,
        'http://purl.org/rss/1.0/copyright', '/rss/channel/copyright', NULL,
        'http://purl.org/rss/1.0/docs', '/rss/channel/docs', NULL,
        'http://purl.org/rss/1.0/lastBuildDate', 'declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; virtbpel:unix-datetime-parser (/rss/channel/lastBuildDate | /rss/channel/pubDate, 0, 2)', NULL
        );
      extras := null;
      return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
    }

final:
  xte_nodebld_final (res, xte_head (UNAME' root'));
  return xml_tree_doc (res);
}
;


create function "DAV_EXTRACT_RDF_application/atom+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  declare version decimal;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/atom+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  -- dbg_obj_princ ('doc is ', doc);

  version := xpath_eval ('[xmlns:atom="http://purl.org/atom/ns#"] number (/atom:feed/@version)', doc);
  if (version < 0.1)
    goto errexit;
  metas := vector (
        'http://purl.org/rss/1.0/title', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/atom:title', NULL,
        'http://purl.org/rss/1.0/link', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/atom:link/@href', NULL,
        'http://purl.org/rss/1.0/description', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/atom:tagline', NULL,
        'http://purl.org/rss/1.0/language', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/@xml:lang', NULL,
        'http://purl.org/rss/1.0/copyright', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/atom:copyright', NULL,
        'http://purl.org/rss/1.0/docs', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/atom:info', NULL,
        'http://purl.org/rss/1.0/lastBuildDate', 'declare namespace atom="http://purl.org/atom/ns#"; declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; virtbpel:unix-datetime-parser (/atom:feed/atom:modified, 0, 2)', NULL
        );
  extras := null;
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_text/eml" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
  declare doc, metas, res, content any;
  whenever sqlstate '*' goto errexit;
	content := blob_to_string (content1);
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/x-openlink-image (', orig_res_name, ',... )');
  xte_nodebld_init(res);
	declare vec any;	
  declare from_, subject_, date_ varchar;
  vec := vector();
	vec := split_and_decode(content, 1, '=_\n:');
	declare i, l int;
  i := 0;
	l := length (vec);
  while (i < l)
  {
  	if (vec[i] = 'FROM')
    	from_ := trim(vec[i+1], '\r\n ');
  	if (vec[i] = 'SUBJECT')
    	subject_ := trim(vec[i+1], '\r\n ');
  	if (vec[i] = 'DATE')
    	date_ := trim(vec[i+1], '\r\n ');
    i := i + 2;
  }
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Email#from'), from_));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Email#subject'), subject_));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/Email#date'), date_));
  xte_nodebld_final(res, xte_head (UNAME' root'));
  return xml_tree_doc (res);
errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/xbel+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/xbel+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  -- dbg_obj_princ ('doc is ', doc);
  --version := xpath_eval ('number (/xbel/@version)', doc);
  --if (version < 0.1)
  --  goto final;
  metas := vector (
        'http://www.openlinksw.com/virtdav#dynRdfExtractor', '"application/xbel+xml"', NULL,
        'http://www.openlinksw.com/virtdav#dynArchiver', '"XBEL"', NULL,
        'http://www.python.org/topics/xml/xbel/title', '/xbel/title', NULL,
        --'http://www.python.org/topics/xml/xbel/link', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/atom:link/@href', NULL,
        'http://www.python.org/topics/xml/xbel/description', '/xbel/description', NULL,
        --'http://www.python.org/topics/xml/xbel/language', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/@xml:lang', NULL,
        --'http://www.python.org/topics/xml/xbel/copyright', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/atom:copyright', NULL,
        --'http://www.python.org/topics/xml/xbel/docs', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/atom:info', NULL,
        'http://www.python.org/topics/xml/xbel/lastBuildDate', 'declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; for \044v in /xbel/@added return virtbpel:unix-datetime-parser (\044v, 0, 2)', NULL,
        'http://www.python.org/topics/xml/xbel/folderTitle', '/xbel//folder/title', NULL
        );
  extras := null;
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/rdf+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/rdf+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  metas := vector (
        'http://www.openlinksw.com/schemas/RDF#format', '"RDF+XML"', 'RDF+XML'
        );
  extras := vector (
        'http://www.openlinksw.com/virtdav#dynRdfExtractor', 'application/rdf+xml' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_text/rdf+ttl" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  --dbg_obj_princ ('DAV_EXTRACT_RDF_text/rdf+ttl (', orig_res_name, content, html_start, ')');
  doc := null;
  metas := null;
  extras := vector (
        'http://www.openlinksw.com/schemas/RDF#format', 'TURTLE' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
}
;

create function "DAV_EXTRACT_RDF_text/rdf+n3" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  --dbg_obj_princ ('DAV_EXTRACT_RDF_text/rdf+ttl (', orig_res_name, content, html_start, ')');
  doc := null;
  metas := null;
  extras := vector (
        'http://www.openlinksw.com/schemas/RDF#format', 'N3' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
}
;

create function "DAV_EXTRACT_RDF_application/foaf+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, res any;
  declare tmp_n3, obj1_props any;
  declare about varchar;
  xte_nodebld_init (res);
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/foaf+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto final;
  doc := xtree_doc (content, 0);
  -- dbg_obj_princ ('doc is ', doc);
  tmp_n3 := xslt ('http://local.virt/rdfxml2n3xml', doc);
  -- dbg_obj_princ ('tmp_n3 is ', tmp_n3);
  about := xpath_eval ('/N3[@N3P="http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]/@N3S', tmp_n3);
  if (about is null or
    xpath_eval (
      '/N3[@N3S=\044about][@N3P="http://xmlns.com/foaf/0.1/name"]', tmp_n3, 1,
      vector (UNAME'about', about) ) is null )
    about := xpath_eval ('/N3[@N3P="http://xmlns.com/foaf/0.1/name"]/@N3S', tmp_n3);
  if (about is null)
    {
       -- dbg_obj_princ ('final?');
       goto final;
    }
  -- dbg_obj_princ ('about=', about);
  obj1_props := xpath_eval ('/N3[@N3S=\044about][starts-with (@N3P, "http://xmlns.com/foaf/0.1/")]', tmp_n3, 0, vector (UNAME'about', about));
  foreach (any prop in obj1_props) do
    {
      declare obj any;
      -- dbg_obj_princ ('prop ', prop);
      obj := cast (xpath_eval ('@N3O', prop) as varchar);
      if (obj is null)
        {
          -- dbg_obj_princ ('obj is null: ', prop);
          xte_nodebld_acc (res,
           xte_node (
             xte_head (UNAME'N3', UNAME'N3S', 'http://local.virt/this', UNAME'N3P', xpath_eval ('@N3P', prop)),
             xpath_eval ('string (.)', prop) ) );
        }
      else if ((obj like 'node%') or (obj like '#%'))
        {
          declare obj_names any;
          -- dbg_obj_princ ('obj is local: ', prop);
          obj_names := xpath_eval ('/N3[@N3S = \044obj][@N3P="http://xmlns.com/foaf/0.1/name"]', tmp_n3, 0, vector (UNAME'obj', obj));
          -- dbg_obj_princ ('obj_names are: ', obj_names);
          foreach (any oname in obj_names) do
            {
	      xte_nodebld_acc (res,
	        xte_node (
                  xte_head (UNAME'N3', UNAME'N3S', 'http://local.virt/this', UNAME'N3P', xpath_eval ('@N3P', prop) || N'-name'),
                xpath_eval ('string (.)', oname) ) );
            }
        }
      else if ((obj like 'http://%') or (obj like 'https://%') or (obj like 'tel:%') or (obj like 'mailto:%') or (obj like 'urn:%') or (obj like '/%'))
        {
          -- dbg_obj_princ ('obj is global: ', prop);
          xte_nodebld_acc (res,
           xte_node (
             xte_head (UNAME'N3', UNAME'N3S', 'http://local.virt/this', UNAME'N3P', xpath_eval ('@N3P', prop) || N'-uri'),
             obj ) );
        }
      else
        {
          -- dbg_obj_princ ('obj is weird: ', prop);
        ;
        }
    }
final:
  xte_nodebld_final (res, xte_head (UNAME' root'));
  return xml_tree_doc (res);
}
;


create function "DAV_EXTRACT_RDF_application/mods+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/mods+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  -- dbg_obj_princ ('doc is ', doc);
  if (xpath_eval ('exists (/modsCollection)', doc))
    doc := xpath_eval ('/modsCollection', doc);
  if (xpath_eval ('count (mods)', doc) <> 1)
    {
      metas := vector (
        'http://www.openlinksw.com/schemas/MODS#topic', 'mods/subject/topic', NULL );
    }
  else
    {
      metas := vector (
        'http://www.openlinksw.com/schemas/MODS#topic', 'mods/subject/topic', NULL,
        'http://www.openlinksw.com/schemas/MODS#title', 'mods/titleInfo/title', NULL,
        'http://www.openlinksw.com/schemas/MODS#subtitle', 'mods/titleInfo/subtitle', NULL,
        'http://www.openlinksw.com/schemas/MODS#url', 'mods/location/url', NULL );
    }
  extras := vector (
        'http://www.openlinksw.com/virtdav#dynRdfExtractor', 'application/mods+xml' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;


create function "DAV_EXTRACT_RDF_application/opml+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/opml+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  -- dbg_obj_princ ('doc is ', doc);
  --version := xpath_eval ('number (/xbel/@version)', doc);
  --if (version < 0.1)
  --  goto final;
  metas := vector (
        'http://www.openlinksw.com/schemas/OPML#title', '/opml/head/title', 'Untitled OPML',
        'http://www.openlinksw.com/schemas/OPML#dateCreated', 'declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; for \044d in /opml/head/dateCreated return virtbpel:unix-datetime-parser (\044d)', NULL,
        'http://www.openlinksw.com/schemas/OPML#dateModified', 'declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; for \044d in /opml/head/dateModified return virtbpel:unix-datetime-parser (\044d)', NULL,
        'http://www.openlinksw.com/schemas/OPML#ownerName', '/opml/head/ownerName', 'Unknown OPML owner',
        'http://www.openlinksw.com/schemas/OPML#ownerEmail', '/opml/head/ownerEmail', NULL
        );
  extras := vector (
        'http://www.openlinksw.com/virtdav#dynRdfExtractor', 'application/opml+xml' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;


create function "DAV_EXTRACT_RDF_text/html" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare metas, extras any;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_text/html (', orig_res_name, content, html_start, ')');
  if (html_start is null)
    html_start := xtree_doc (content, 18, 'http://localdav.virt/' || orig_res_name, 'LATIN-1', 'x-any',
      'Validation=DISABLE Include=DISABLE BuildStandalone=DISABLE SchemaDecl=DISABLE' );
  if (html_start is null)
    goto errexit;
  whenever sqlstate '*' goto errexit;
  -- dbg_obj_princ ('head is ', html_start);
  metas := vector (
        'http://www.openlinksw.com/schemas/XHTML#title', '/*/head/title|/*/*:head/*:title', 'Untitled',
        'http://www.openlinksw.com/schemas/XHTML#description', '(/*/head/meta[@name="description" or @name="Description"]/@content) | (/*/*:head/*:meta[@name="description" or @name="Description"]/@content)', NULL,
        'http://www.openlinksw.com/schemas/XHTML#copyright', '(/*/head/meta[@name="copyright" or @name="Copyright"]/@content) | (/*/*:head/*:meta[@name="copyright" or @name="Copyright"]/@content)', NULL,
        'http://www.openlinksw.com/schemas/XHTML#keyword', 'declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; virtbpel:split-list ((/*/head/meta[@name="keywords" or @name="KeyWords"]/@content) | (/*/*:head/*:meta[@name="keywords" or @name="KeyWords"]/@content))', NULL,
        'http://www.openlinksw.com/schemas/XHTML#calendar', '(/*/div[@class="vevent"]/div/abbr) | (/*/*:div[@class="vevent"]/*:div/*:abbr) | (/*/div[@class="vjournal"]/div/abbr) | (/*/*:div[@class="vjournal"]/*:div/*:abbr) | (/*/div[@class="vtodo"]/div/abbr) | (/*/*:div[@class="vtodo"]/*:div/*:abbr) | (/*/div[@class="vfreebusy"]/div/abbr) | (/*/*:div[@class="vfreebusy"]/*:div/*:abbr)', NULL,
        'http://www.openlinksw.com/schemas/XHTML#contacts', '(/div[@class="vcard"]/span/a/span[@class="given-name"] | /div[@class="vcard"]/span/a/span[@class="family-name"] | /div[@class="vcard"]/a/span/span[@class="given-name"] | /div[@class="vcard"]/a/span/span[@class="family-name"] | /div[@class="vcard"]/a/span[@class="given-name"] | /div[@class="vcard"]/a/span[@class="family-name"] | /div[@class="vcard"]/a[@class="url fn"])', NULL
        );
  extras := null;
  return "DAV_EXTRACT_RDF_BY_METAS" (html_start, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;


create function "DAV_EXTRACT_RDF_application/x-openlinksw-vsp" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare metas, extras any;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/x-openlinksw-vsp (', orig_res_name, content, html_start, ')');
  if (html_start is null)
    html_start := xtree_doc (content, 18, 'http://localdav.virt/' || orig_res_name, 'LATIN-1', 'x-any',
      'Validation=DISABLE Include=DISABLE BuildStandalone=DISABLE SchemaDecl=DISABLE' );
  if (html_start is null)
    goto errexit;
  whenever sqlstate '*' goto errexit;
  -- dbg_obj_princ ('head is ', xpath_eval('/*/*', html_start));
  metas := vector (
        'http://www.openlinksw.com/schemas/VSPX#title', '/*/head/title|/*/*:head/*:title', 'Untitled',
        'http://www.openlinksw.com/schemas/VSPX#description', '(/*/head/meta[@name="description" or @name="Description"]/@content) | (/*/*:head/*:meta[@name="description" or @name="Description"]/@content)', NULL,
        'http://www.openlinksw.com/schemas/VSPX#copyright', '(/*/head/meta[@name="copyright" or @name="Copyright"]/@content) | (/*/*:head/*:meta[@name="copyright" or @name="Copyright"]/@content)', NULL,
        'http://www.openlinksw.com/schemas/VSPX#keyword', 'declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; virtbpel:split-list ((/*/head/meta[@name="keywords" or @name="KeyWords"]/@content) | (/*/*:head/*:meta[@name="keywords" or @name="KeyWords"]/@content))', NULL
        );
  extras := vector (
        'http://www.openlinksw.com/schemas/VSPX#type', 'VSP' );
  return "DAV_EXTRACT_RDF_BY_METAS" (html_start, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;


create function "DAV_EXTRACT_RDF_application/x-openlinksw-vspx+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/x-openlinksw-vspx+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  -- dbg_obj_princ ('doc is ', doc);
  --version := xpath_eval ('number (/xbel/@version)', doc);
  --if (version < 0.1)
  --  goto final;
  metas := vector (
        'http://www.openlinksw.com/schemas/VSPX#pageId', 'declare namespace v="http://www.openlinksw.com/vspx/"; //v:page/@name', 'Unidentified',
        'http://www.openlinksw.com/schemas/VSPX#title', '/*/head/title|/*/*:head/*:title', 'Untitled',
        'http://www.openlinksw.com/schemas/VSPX#description', '(/*/head/meta[@name="description"]/@content) | (/*/*:head/*:meta[@name="description"]/@content)', NULL,
        'http://www.openlinksw.com/schemas/VSPX#copyright', '(/*/head/meta[@name="copyright"]/@content) | (/*/*:head/*:meta[@name="copyright"]/@content)', NULL,
        'http://www.openlinksw.com/schemas/VSPX#keyword', 'declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; virtbpel:split-list ((/*/head/meta[@name="keyword"]/@content) | (/*/*:head/*:meta[@name="keyword"]/@content))', NULL
        );
  extras := vector (
        'http://www.openlinksw.com/schemas/VSPX#type', 'VSPX' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/bpel+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/bpel+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  -- dbg_obj_princ ('doc is ', doc);
  --version := xpath_eval ('number (/xbel/@version)', doc);
  --if (version < 0.1)
  --  goto final;
  metas := vector (
        'http://www.openlinksw.com/schemas/WSDL#processName', 'declare namespace bpel="http://schemas.xmlsoap.org/ws/2003/03/business-process/"; /bpel:process/@name', 'Unidentified',
        'http://www.openlinksw.com/schemas/WSDL#targetNamespace', 'declare namespace bpel="http://schemas.xmlsoap.org/ws/2003/03/business-process/"; /bpel:process/@targetNamespace', NULL
        );
  extras := vector (
        'http://www.openlinksw.com/schemas/WSDL#type', 'BPEL' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/google-kinds+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/google-kinds+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  -- dbg_obj_princ ('doc is ', doc);
  --version := xpath_eval ('number (/xbel/@version)', doc);
  --if (version < 0.1)
  --  goto final;
  metas := vector (
        'http://www.openlinksw.com/schemas/google-kinds#title', '/entry/title', 'Untitled OPML',
        'http://www.openlinksw.com/schemas/google-kinds#published', '/entry/published', NULL,
        'http://www.openlinksw.com/schemas/google-kinds#updated', '/entry/updated', NULL,
        'http://www.openlinksw.com/schemas/google-kinds#author', '/entry/author/name', 'Unknown author'
        );
  extras := null;
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/wsdl+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/wsdl+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  -- dbg_obj_princ ('doc is ', doc);
  --version := xpath_eval ('number (/xbel/@version)', doc);
  --if (version < 0.1)
  --  goto final;
  metas := vector (
        'http://www.openlinksw.com/schemas/WSDL#processName', 'declare namespace wsdl="http://schemas.xmlsoap.org/wsdl/"; /wsdl:definitions/@name', 'Unidentified',
        'http://www.openlinksw.com/schemas/WSDL#targetNamespace', 'declare namespace wsdl="http://schemas.xmlsoap.org/wsdl/"; /wsdl:definitions/@targetNamespace', NULL
        );
  extras := vector (
        'http://www.openlinksw.com/schemas/WSDL#type', 'WSDL' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/x-openlinksw-vad" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras, tree, cont any;
  declare s1, s2, s3, s4, len1 integer;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/x-openlinksw-vad (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  if (aref(subseq(content, 0, 1), 0) <> 182)
    goto errexit;
  if (subseq(content, 5, 8) <> 'VAD')
    goto errexit;
  if (subseq(content, 87, 94) <> 'STICKER')
    goto errexit;
  s4 := aref(subseq(content, 95, 96), 0);
  s3 := aref(subseq(content, 96, 97), 0);
  s2 := aref(subseq(content, 97, 98), 0);
  s1 := aref(subseq(content, 98, 99), 0);
  len1 := s1 + 256 * ( s2 + 256 * ( s3 + 256 * ( s4 )));
  cont := subseq(content, 99, 99 + len1);
  tree := xml_tree (cont);
  doc := xml_tree_doc (tree);
  --doc := xtree_doc (cont, 0);
  declare items any;
--  items := xpath_eval ('/sticker/caption/version/@package', doc, 0);
--  if (length (items) = 0)
--    goto errexit;
--  items := xpath_eval ('/sticker/caption/name/prop[@name=\'Title\']', doc, 0);
--  if (length (items) = 0)
--    goto errexit;
--  items := xpath_eval ('/sticker/caption/version/@package', doc, 0);
--  if (length (items) = 0)
--    goto errexit;
  --  goto final;
  metas := vector (
        'http://www.openlinksw.com/schemas/VAD#packageName', '/sticker/caption/name/@package', NULL,
        'http://www.openlinksw.com/schemas/VAD#packageTitle', '/sticker/caption/name/prop[@name="Title"]/@value[1]', NULL,
        'http://www.openlinksw.com/schemas/VAD#packageDeveloper', '/sticker/caption/name/prop[@name="Developer"]/@value[1]', NULL,
        'http://www.openlinksw.com/schemas/VAD#packageCopyright', '/sticker/caption/name/prop[@name="Copyright"]/@value[1]', NULL,
        'http://www.openlinksw.com/schemas/VAD#packageDownload', '/sticker/caption/name/prop[@name="Download"]/@value[1]', NULL,
        'http://www.openlinksw.com/schemas/VAD#versionNumber', '/sticker/caption/version/@package', NULL,
        'http://www.openlinksw.com/schemas/VAD#versionBuild', '/sticker/caption/version/prop[@name="Build"]/@value[1]', NULL,
        'http://www.openlinksw.com/schemas/VAD#releaseDate', '/sticker/caption/version/prop[@name="Release Date"]/@value[1]', NULL
        );
  extras := vector (
        'http://www.openlinksw.com/virtdav#dynRdfExtractor', 'application/x-openlinksw-vad' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);

errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_text/wiki" (in orig_res_name varchar, inout content any, inout html_start any)
{  
  if (1)
    {
      declare _author varchar;
      declare _cluster varchar;
      declare _title varchar;
      declare _cats, _categories any;
      declare _date datetime;

      declare _res, _ent any;
      _author := coalesce (connection_get ('HTTP_CLI_UID'), 'Unknown');
      _cluster := connection_get ('oWiki Cluster', 'Main');

      _ent := xtree_doc ( "WikiV lexer" (content || '\r\n', 'Main', 'DoesntMatter', 'wiki', null), 2);
      -- descendant-or-self::* is important here,
      -- since title text can be under anchor or other html tag
      declare titles any;
      titles := xpath_eval ('string(//h1/*)', _ent, 0);
      _title := NULL;
      foreach (varchar t in titles) do
        {
	  if (length (t) > length (_title))
	    _title := cast (t as varchar);
	}
      if (_title is null)
        _title := subseq (orig_res_name, 0, length (orig_res_name) - 4);
      else
        _title := cast (_title as varchar);
      _date := now();	
      _cats := xpath_eval ('//a[@style="wikiword" and text() like "Category%"]/text()', _ent, 0);
      -- dbg_obj_print ('cats: ', _cats);
      vectorbld_init (_categories);
      _res := XMLELEMENT ('Wiki', 
        	XMLELEMENT('Cluster', _cluster),
		XMLELEMENT('Title', _title),
		XMLELEMENT('Author', _author),
		XMLELEMENT('Date', cast (_date as varchar)));
      -- declare _wiki_ent any;
      _ent := xpath_eval ('/Wiki', _res);
      foreach (any _c in _cats) do 
        {
	  XMLAppendChildren (_ent, XMLELEMENT ('Category', cast (_c as varchar)));
	}
      declare metas, extras any;
      metas := vector (
        'http://www.openlinksw.com/schemas/Wiki#Cluster', '/Wiki/Cluster', NULL,
        'http://www.openlinksw.com/schemas/Wiki#Title', '/Wiki/Title', NULL,
        'http://www.openlinksw.com/schemas/Wiki#Author', '/Wiki/Author', NULL,
        'http://www.openlinksw.com/schemas/Wiki#Date', '/Wiki/Date', NULL,
        'http://www.openlinksw.com/schemas/Wiki#Category', '/Wiki/Category', NULL);
      extras := vector (
        'http://www.openlinksw.com/virtdav#dynRdfExtractor', 'text/wiki' );
      return "DAV_EXTRACT_RDF_BY_METAS" (_res, metas, extras);
    }
}
;
      

-- This gets an IMC stream such as VCARD or VCALENDAR and parses it without validation into XML, returning xml-tree vector
create function IMC_TO_XML (in _src varchar)
{
  declare stack any;
  declare lines any;
  declare curr_IMC any;
  declare line_idx, lines_count integer;
  declare IMC_type varchar;
  declare line, head, head_name, data, name, params varchar;
  declare colon_pos, param_count, param_idx integer;
  declare delims, head_parts, data_parts, line_acc any;
  -- dbg_obj_princ ('IMC_TO_XML (', _src);
  if (length (_src) > 2)
    {
      if ((_src[0] = 254) and (_src[1] = 255))
        _src := charset_recode (subseq (_src, 2), 'UTF-16BE', 'UTF-8');
      else if ((_src[0] = 255) and (_src[1] = 254))
        _src := charset_recode (subseq (_src, 2), 'UTF-16LE', 'UTF-8');
    }
  IMC_type := ' root';
  stack := vector ();
  xte_nodebld_init (curr_IMC);
  _src := replace (_src, '\015\012', '\012');
  _src := replace (_src, '\012\015', '\012');
  _src := replace (_src, '\015', '\012');
  _src := replace (_src, '\012 ', '');
  lines := split_and_decode (_src, 0, '\0\0\n');
  lines_count := length (lines);
  -- dbg_obj_princ (lines);
  -- dbg_obj_princ ('total ', lines_count, ' lines');
  line_idx := 0;
  while (line_idx < lines_count)
    {
      line := lines [line_idx];
      -- dbg_obj_princ ('lines[', line_idx, ']=', line);
      if (line = '')
        goto next_line;
      if (regexp_match ('^([A-Za-z0-9-]+[.])?((BEGIN)|(begin)):([A-Z]+)\044', line) is not null)
        {
	  stack := vector_concat (vector (IMC_type, curr_IMC), stack);
	  IMC_type := upper (subseq (line, strchr (line, ':') + 1));
	  xte_nodebld_init (curr_IMC);
	  xte_nodebld_acc (curr_IMC, '\n');
	  goto next_line;
	}
      if (regexp_match ('^([A-Za-z0-9-]+[.])?((END)|(end)):([A-Z]+)\044', line) is not null)
        {
          declare sub_IMC any;
          declare close_type varchar;
          if (2 > length (stack))
            signal ('22007', sprintf ('IMC text contains redundand "END" at line %d', line_idx + 1));
          close_type := upper (subseq (line, strchr (line, ':') + 1));
          if (close_type <> IMC_type)
            signal ('22007', sprintf ('IMC text contains "END:%s" instead of expected "END:%s" at line %d', close_type, IMC_type, line_idx + 1));
	  xte_nodebld_final (curr_IMC, xte_head ('IMC-' || IMC_type));
	  sub_IMC := curr_IMC;
	  IMC_type := stack[0];
	  curr_IMC := stack[1];
	  stack := subseq (stack, 2);
	  xte_nodebld_acc (curr_IMC, sub_IMC);
	  xte_nodebld_acc (curr_IMC, '\n');
          goto next_line;
        }
      xte_nodebld_init (line_acc);
      delims := regexp_parse (
--2                3 4             56                                                                                                                                               78   90            1
'^([A-Za-z0-9-]+[.])?([A-Za-z0-9-]+)(([;][A-Za-z0-9-]+(=(([^\001-\037\200-\377";:,]*)|("[^\001-\037\200-\377"]*"))(,(([^\001-\037\200-\377";:,]*)|("[^\001-\037\200-\377"]*")))*)?)*)([:])([\040-\377]*)\044',
--(group        [.])?name           ((param-name      (=(plain-param-value           |quoted_param_value         )(,(plain-param-value           |quoted_param_value         ))*)?)*) [:]  value
            line, 0 );
	  -- dbg_obj_princ (delims);
	  if (delims is null)
	    {
	      head := 'X-ERROR';
	      data := line;
	    }
	  else
	    {
	      colon_pos := delims[7];
	      head := subseq (line, 0, colon_pos);
	      data := subseq (line, colon_pos + 1);
	    }
	  head_parts := split_and_decode (head, 0, '\0\0;');
	  head_name := head_parts [0];
	  param_idx := 1;
	  param_count := length (head_parts);
	  while (param_idx < param_count)
	    {
	      declare param_strg, param_name, param_data varchar;
	      declare eq_pos integer;
	      param_strg := head_parts [param_idx];
              eq_pos := strchr (param_strg, '=');
	      if (eq_pos is null)
	        xte_nodebld_acc (line_acc,
	          xte_node (xte_head (UNAME'TYPE'), param_strg) );
	      else
	        {
		  param_name := subseq (param_strg, 0, eq_pos);
		  param_data := split_and_decode (subseq (param_strg, eq_pos + 1), 0, '\0\0,');
		  foreach (varchar pd in param_data) do
		    {
		      if (pd like '"%"')
		        pd := subseq (pd, 1, length (pd) - 1);
                      xte_nodebld_acc (line_acc,
                        xte_node (xte_head (param_name), pd) );
		    }
		}
	      param_idx := param_idx + 1;
	    }
	  if ((length (data) > 0) and
	    ( position ('ENCODING=QUOTED-PRINTABLE', head_parts) or
	      position ('ENCODING="QUOTED-PRINTABLE"', head_parts) ) )
	    {
	      while ((data [length (data) - 1] = 61) and
	        ((line_idx + 1) < lines_count) )
	        {
		  line_idx := line_idx + 1;
	          data := subseq (data, 0, length (data) - 1) || lines [line_idx];
		}
	    }
          -- dbg_obj_princ ('1. data=', data);
	  data := replace (data, '\\,', '\1');
	  data := replace (data, '\\;', '\2');
	  data := replace (data, '\\n', '\015\012');
	  data := replace (data, '\\N', '\015\012');
	  data := replace (data, '\\\\', '\\');
          -- dbg_obj_princ ('2. data=', data);
	  if (strchr (data, ';') is not null)
	    {
	      data_parts := split_and_decode (data, 0, '\0\0;');
              -- dbg_obj_princ ('3. data_parts=', data_parts);
	      foreach (varchar datum in data_parts) do
	        {
		  declare recoded varchar;
		  datum := replace (datum, '\1', ',');
		  datum := replace (datum, '\2', ';');
		  recoded := charset_recode (datum, 'UTF-8', '_WIDE_');
		  if (not (isstring (recoded)))
		    recoded := charset_recode (datum, NULL, '_WIDE_');
                  xte_nodebld_acc (line_acc, xte_node (xte_head (UNAME'fld'), recoded));
		}
	    }
	  else if (strchr (data, ',') is not null)
	    {
	      data_parts := split_and_decode (data, 0, '\0\0,');
	      -- dbg_obj_princ ('3. data_parts=', data_parts);
	      foreach (varchar datum in data_parts) do
	        {
		  declare recoded varchar;
		  datum := replace (datum, '\1', ',');
		  datum := replace (datum, '\2', ';');
		  recoded := charset_recode (datum, 'UTF-8', '_WIDE_');
		  if (not (isstring (recoded)))
		    recoded := charset_recode (datum, NULL, '_WIDE_');
                  xte_nodebld_acc (line_acc, xte_node (xte_head (UNAME'val'), recoded));
		}
	    }
	  else
	    {
	      declare recoded varchar;
              data := replace (data, '\1', ',');
              data := replace (data, '\2', ';');
	      recoded := charset_recode (data, 'UTF-8', '_WIDE_');
	      if (not (isstring (recoded)))
		recoded := charset_recode (data, NULL, '_WIDE_');
              xte_nodebld_acc (line_acc, xte_node (xte_head (UNAME'val'), recoded));
	    }
          xte_nodebld_final (line_acc, xte_head (head_name));
          xte_nodebld_acc (curr_IMC, line_acc, '\n');
next_line:
	  line_idx := line_idx + 1;
      ;
    }

  if (0 <> length (stack))
    signal ('22007', sprintf ('IMC text has no closing "END:%s" before the end of text', stack[0]));
  xte_nodebld_final (curr_IMC, xte_head (UNAME' root'));
  return curr_IMC;
}
;


create function "DAV_EXTRACT_RDF_text/directory" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, diritems, res, metas, extras any;
  xte_nodebld_init (res);
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_text/directory (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto final;
  if (not isstring (content))
    doc := IMC_TO_XML (cast (content as varchar));
  else
    doc := IMC_TO_XML (content);
  doc := xml_tree_doc (doc);
  -- dbg_obj_princ ('doc is ', doc);
  diritems := xpath_eval ('/*', doc, 0);
  foreach (any diritm in diritems) do
    {
      declare itemname varchar;
      declare ctr, len integer;
      itemname := xpath_eval ('name(.)', diritm);
      if (itemname = 'IMC-VCARD')
        metas := vector (
          'http://www.openlinksw.com/virtdav#dynRdfExtractor', '"text/directory"',
-- basic props
          'http://www.w3.org/2001/vcard-rdf/3.0#FN', 'FN/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#NICKNAME', 'NICKNAME/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#BDAY', 'declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; for \044v in BDAY/val return virtbpel:unix-datetime-parser (\044v)',
          'http://www.w3.org/2001/vcard-rdf/3.0#MAILER', 'MAILER/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#GEO', 'GEO/val', -- If proper lattitude/longitude pair of <fld> is specified then do not display
          'http://www.w3.org/2001/vcard-rdf/3.0#TITLE', 'TITLE/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#ROLE', 'ROLE/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#CATEGORIES', 'CATEGORIES/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#N', 'if (N/val) then concat (N/val, ";;;;") else concat (N/fld[1], ";", N/fld[2], ";", N/fld[3], ";", N/fld[4], ";", N/fld[5])',
          'http://www.w3.org/2001/vcard-rdf/3.0#SOURCE', 'SOURCE/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#NOTE', 'NOTE/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#PRODID', 'PRODID/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#REV', 'REV/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#SORT-STRING', 'SORT-STRING/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#CLASS', 'CLASS/val',
-- attributed, but attr is turned into substring
          'http://www.w3.org/2001/vcard-rdf/3.0#TEL', 'for \044v in TEL/val return concat (\044v, for \044t in \044v/../TYPE return concat (" (", \044t, ")"))',
          'http://www.w3.org/2001/vcard-rdf/3.0#EMAIL', 'for \044v in EMAIL/val return concat (\044v, for \044t in \044v/../TYPE return concat (" (", \044t, ")"))',
          'http://www.w3.org/2001/vcard-rdf/3.0#ADR', 'for \044v in ADR return concat (if (\044v/val) then concat (\044v/val, ";;;;;;") else concat (\044v/fld[1], ";", \044v/fld[2], ";", \044v/fld[3], ";", \044v/fld[4], ";", \044v/fld[5], ";", \044v/fld[6], ";", \044v/fld[7]), for \044t in \044v/TYPE return concat (" (", \044t, ")"))',
          'http://www.w3.org/2001/vcard-rdf/3.0#LABEL', 'for \044v in LABEL/val return concat (\044v, for \044t in \044v/../TYPE return concat (" (", \044t, ")"))',
-- attributed, but attr is ignored
          'http://www.w3.org/2001/vcard-rdf/3.0#UID', 'CLASS/val',
-- structured
          'http://www.w3.org/2001/vcard-rdf/3.0#Name-Family', 'N/fld[1]|N/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#Name-Given', 'N/fld[2]',
          'http://www.w3.org/2001/vcard-rdf/3.0#Name-Other', 'N/fld[3]',
          'http://www.w3.org/2001/vcard-rdf/3.0#Name-Prefix', 'N/fld[4]',
          'http://www.w3.org/2001/vcard-rdf/3.0#Name-Suffix', 'N/fld[5]',
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Pobox', 'ADR/fld[1]|ADR/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Extadd', 'ADR/fld[2]',
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Street', 'ADR/fld[3]',
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Locality', 'ADR/fld[4]',
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Region', 'ADR/fld[5]',
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Pcode', 'ADR/fld[6]',
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Country', 'ADR/fld[7]',
          'http://www.w3.org/2001/vcard-rdf/3.0#Org-Orgname', 'ORG/fld[1]|ORG/val',
          'http://www.w3.org/2001/vcard-rdf/3.0#Org-Orgunit', 'ORG/fld[position() > 1]'
          );
      else if (itemname = 'IMC-VCALENDAR')
        {
          if ((length (diritems) = 1) and (xpath_eval('count (IMC-VEVENT)', diritm) = 1))
            metas := vector (
              'http://www.openlinksw.com/schemas/ICS#SUMMARY', 'IMC-VEVENT/SUMMARY/val',
              'http://www.openlinksw.com/schemas/ICS#LOCATION', 'IMC-VEVENT/LOCATION/val',
              'http://www.openlinksw.com/schemas/ICS#CATEGORIES', 'IMC-VEVENT/CATEGORIES/val',
              'http://www.openlinksw.com/schemas/ICS#ATTENDEE', 'IMC-VEVENT/ATTENDEE/val',
              'http://www.openlinksw.com/schemas/ICS#ORGANIZER', 'IMC-VEVENT/ORGANIZER/val' );
          else
            metas := vector (
              'http://www.openlinksw.com/schemas/ICS#ORGANIZER', 'IMC-VEVENT/ORGANIZER/val' );
        }
      else
        metas := vector ();

      len := length (metas);
      for (ctr := 0; ctr < len; ctr := ctr + 2)
        {
          declare vals varchar;
          -- dbg_obj_princ ('Prop ', ctr/2, ' of ', len/2, ': ', metas [ctr + 1]);
          vals := xquery_eval (metas [ctr + 1], diritm, 0);
          if (vals is not null)
            {
          foreach (any val in vals) do
            xte_nodebld_acc (res,
              xte_node (
                xte_head (UNAME'N3', UNAME'N3S', 'http://local.virt/this', UNAME'N3P', metas [ctr]),
                cast (val as varchar) ) );
            }
        }
    }

final:
  xte_nodebld_final (res, xte_head (UNAME' root'));
  return xml_tree_doc (res);
}
;


create function "DAV_EXTRACT_RDF_BY_METAS" (inout doc any, inout metas any, inout extras any)
{
  declare res any;
  declare ctr, len integer;
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_BY_METAS" (', doc, metas, extras, ')');
  xte_nodebld_init (res);
  whenever sqlstate '*' goto final;
  len := length (metas);
  for (ctr := 0; ctr < len; ctr := ctr + 3)
    {
      declare vals varchar;
      vals := xquery_eval (metas [ctr + 1], doc, 0);
      -- dbg_obj_princ ('DAV_EXTRACT_RDF_BY_METAS: values for ', metas [ctr + 1], ' are ', vals);
      if (length (vals) = 0)
        {
          vals := metas [ctr + 2];
          if (vals is not null)
            vals := vector (vals);
        }
      foreach (any val in vals) do
        xte_nodebld_acc (res,
          xte_node (
            xte_head (UNAME'N3', UNAME'N3S', 'http://local.virt/this', UNAME'N3P', metas [ctr]),
            cast (val as varchar) ) );
    }
  len := length (extras);
  for (ctr := 0; ctr < len; ctr := ctr + 2)
    {
      declare val any;
      val := extras [ctr + 1];
      if (val is not null)
        xte_nodebld_acc (res,
          xte_node (
            xte_head (UNAME'N3', UNAME'N3S', 'http://local.virt/this', UNAME'N3P', extras [ctr]),
            cast (val as varchar) ) );
    }
final:
  xte_nodebld_final (res, xte_head (UNAME' root'));
  return xml_tree_doc (res);
}
;


-- This parses formats
-- Tue, 22 Mar 2005 19:22:17 EST
-- 22 Mar 2005 19:22:17 EST
-- 2005-03-22 19:22:17 EST
-- 2005-03-22T19:22:17Z
create function DB.DBA.UNIX_DATETIME_PARSER (in strg varchar, in trap_error integer := 0, in output_mode integer := 0)
{
  declare m integer;
  declare res varchar;
  declare parts any;
  declare Yr, Mo, MN, Da, hms, tz varchar;
  -- dbg_obj_princ ('DB.DBA.UNIX_DATETIME_PARSER (', strg, trap_error, output_mode, ')');
  if (strg is null)
    return null;
  strg := cast (strg as varchar);
  --                      2                  4             6                       8                      10                                12
  parts := regexp_parse('^([A-Z][a-z][a-z]), ([ 0-3][0-9]) ([A-Z][A-Za-z][A-Za-z]) ([0-2][0-9][0-9][0-9]) ([0-2][0-9]:[0-6][0-9]:[0-6][0-9])(( [A-Z0-9:+-]+)?)\044', strg, 0);
  if (parts is not null)
    {
      Da := subseq (strg, parts[4], parts[5]);
      MN := subseq (strg, parts[6], parts[7]);
      Yr := subseq (strg, parts[8], parts[9]);
      hms := subseq (strg, parts[10], parts[11]);
      tz := subseq (strg, parts[12], parts[13]);
      Mo := null;
      goto parts_ready;
    }
  --                      2             4                       6                      8                                 10
  parts := regexp_parse('^([ 0-3][0-9]) ([A-Z][A-Za-z][A-Za-z]) ([0-2][0-9][0-9][0-9]) ([0-2][0-9]:[0-6][0-9]:[0-6][0-9])(( [A-Z0-9:+-]+)?)\044', strg, 0);
  if (parts is not null)
    {
      Da := subseq (strg, parts[2], parts[3]);
      MN := subseq (strg, parts[4], parts[5]);
      Yr := subseq (strg, parts[6], parts[7]);
      hms := subseq (strg, parts[8], parts[9]);
      tz := subseq (strg, parts[10], parts[11]);
      Mo := null;
      goto parts_ready;
    }
  --                      2                      4             6            8    10                                12
  parts := regexp_parse('^([0-2][0-9][0-9][0-9])-([ 0-1][0-9])-([ 0-3][0-9])( |T)([0-2][0-9]:[0-6][0-9]:[0-6][0-9])(([Z+-][0-9:]*)?)\044', strg, 0);
  if (parts is not null)
    {
      Yr := subseq (strg, parts[2], parts[3]);
      Mo := subseq (strg, parts[4], parts[5]);
      Da := subseq (strg, parts[6], parts[7]);
      hms := subseq (strg, parts[10], parts[11]);
      tz := subseq (strg, parts[12], parts[13]);
      MN := null;
      goto parts_ready;
    }
  parts := regexp_parse('^([0-2][0-9][0-9][0-9])([0-1][0-9])([0-3][0-9])(T)([0-2][0-9][0-6][0-9][0-6][0-9])(([Z+-][0-9:]*)?)\044', strg, 0);
  if (parts is not null)
    {
      Yr := subseq (strg, parts[2], parts[3]);
      Mo := subseq (strg, parts[4], parts[5]);
      Da := subseq (strg, parts[6], parts[7]);
      hms := subseq (strg, parts[10], parts[11]);
      hms := subseq (hms, 0, 2) || ':' || 
        subseq (hms, 2, 4) || ':' ||
	subseq (hms, 4, 6) ;
      tz := subseq (strg, parts[12], parts[13]);
      MN := null;
      goto parts_ready;
    }
  res := DB.DBA.UNIX_DATE_PARSER (strg, 1, 0);
  if (res is not null)
    {
      res := cast (res as datetime);
      goto final_cast;
    }
  if (trap_error)
    return NULL;
  signal ('22005', sprintf ('UNIX_DATETIME_PARSER has failed to parse "%.200s"', strg));

parts_ready:
  if (Mo is null)
    Mo := get_keyword (upper (MN), vector ('JAN', '01', 'FEB', '02', 'MAR', '03', 'APR', '04', 'MAY', '05', 'JUN', '06', 'JUL', '07', 'AUG', '08', 'SEP', '09', 'OCT', '10', 'NOV', '11', 'DEC', '12'));
  res := sprintf ('%s-%s-%s %s', Yr, Mo, Da, hms);
  -- dbg_obj_princ ('res=',res);
  if (trap_error)
    {
      whenever sqlstate '*' goto recov;
      res := cast (res as datetime);
    }
  else
    res := cast (res as datetime);

final_cast:
  if (output_mode = 0)
    return res;
  if (output_mode = 1)
    return cast (res as varchar);
  if (output_mode = 2)
    return replace (cast (res as varchar), ' ', 'T');

recov:
  if (output_mode = 0)
    return null;
  return '?' || strg;
}
;

grant execute on DB.DBA.UNIX_DATETIME_PARSER to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/bpel:unix-datetime-parser', fix_identifier_case ('DB.DBA.UNIX_DATETIME_PARSER'), 0)
;

-- This parses formats
-- Tue, 22 Mar 2005
-- 22 Mar 2005
-- 2005-03-22
-- 2005-03-22
create function DB.DBA.UNIX_DATE_PARSER (in strg varchar, in trap_error integer := 0, in output_mode integer := 0)
{
  declare m integer;
  declare res varchar;
  declare parts any;
  declare Yr, Mo, MN, Da, tz varchar;
  -- dbg_obj_princ ('DB.DBA.UNIX_DATETIME_PARSER (', strg, trap_error, output_mode, ')');
  if (strg is null)
    return null;
  strg := cast (strg as varchar);
  --                      2                  4             6                       8                     10
  parts := regexp_parse('^([A-Z][a-z][a-z]), ([ 0-3][0-9]) ([A-Z][A-Za-z][A-Za-z]) ([0-2][0-9][0-9][0-9])(( [A-Z0-9:+-]+)?)\044', strg, 0);
  if (parts is not null)
    {
      -- dbg_obj_princ ('parts=', parts);
      Da := subseq (strg, parts[4], parts[5]);
      MN := subseq (strg, parts[6], parts[7]);
      Yr := subseq (strg, parts[8], parts[9]);
      tz := subseq (strg, parts[10], parts[11]);
      Mo := null;
      goto parts_ready;
    }
  --                      2             4                       6                     8
  parts := regexp_parse('^([ 0-3][0-9]) ([A-Z][A-Za-z][A-Za-z]) ([0-2][0-9][0-9][0-9])(( [A-Z0-9:+-]+)?)\044', strg, 0);
  if (parts is not null)
    {
      -- dbg_obj_princ ('parts=', parts);
      Da := subseq (strg, parts[2], parts[3]);
      MN := subseq (strg, parts[4], parts[5]);
      Yr := subseq (strg, parts[6], parts[7]);
      tz := subseq (strg, parts[8], parts[9]);
      Mo := null;
      goto parts_ready;
    }
  --                      2                      4             6            8
  parts := regexp_parse('^([0-2][0-9][0-9][0-9])-([ 0-1][0-9])-([ 0-3][0-9])(([Z+-][0-9:]*)?)\044', strg, 0);
  if (parts is not null)
    {
      -- dbg_obj_princ ('parts=', parts);
      Yr := subseq (strg, parts[2], parts[3]);
      Mo := subseq (strg, parts[4], parts[5]);
      Da := subseq (strg, parts[6], parts[7]);
      tz := subseq (strg, parts[8], parts[9]);
      MN := null;
      goto parts_ready;
    }
  --                      2                     4           6           8
  parts := regexp_parse('^([0-2][0-9][0-9][0-9])([0-1][0-9])([0-3][0-9])(([Z+-][0-9:]*)?)\044', strg, 0);
  if (parts is not null)
    {
      -- dbg_obj_princ ('parts=', parts);
      Yr := subseq (strg, parts[2], parts[3]);
      Mo := subseq (strg, parts[4], parts[5]);
      Da := subseq (strg, parts[6], parts[7]);
      tz := subseq (strg, parts[8], parts[9]);
      MN := null;
      goto parts_ready;
    }
  if (trap_error)
    return NULL;
  signal ('22005', sprintf ('UNIX_DATE_PARSER has failed to parse "%.200s"', strg));

parts_ready:
  if (Mo is null)
    Mo := get_keyword (upper (MN), vector ('JAN', '01', 'FEB', '02', 'MAR', '03', 'APR', '04', 'MAY', '05', 'JUN', '06', 'JUL', '07', 'AUG', '08', 'SEP', '09', 'OCT', '10', 'NOV', '11', 'DEC', '12'));
  res := sprintf ('%s-%s-%s', Yr, Mo, Da);
  -- dbg_obj_princ ('res=',res);
  if (trap_error)
    {
      whenever sqlstate '*' goto recov;
      res := cast (res as date);
    }
  else
    res := cast (res as date);
  if (output_mode = 0)
    return res;
  if (output_mode = 1)
    return cast (res as varchar);
  if (output_mode = 2)
    return cast (res as varchar);

recov:
  if (output_mode = 0)
    return null;
  return '?' || strg;
}
;

grant execute on DB.DBA.UNIX_DATE_PARSER to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/bpel:unix-date-parser', fix_identifier_case ('DB.DBA.UNIX_DATE_PARSER'), 0)
;


-- This parses formats
-- Tue, 22 Mar 2005
-- 22 Mar 2005
-- 2005-03-22
-- 2005-03-22
create function DB.DBA.BPEL_SPLIT_LIST (in strg varchar)
{
  declare parts, res any;
  -- dbg_obj_princ ('DB.DBA.BPEL_SPLIT_LIST (', strg, ')');
  if (strg is null)
    return null;
  strg := cast (strg as varchar);
  if (strchr (strg, ';'))
    parts := split_and_decode (strg, 0, '\0\0;');
  else if (strchr (strg, ','))
    parts := split_and_decode (strg, 0, '\0\0,');
  else
    parts := split_and_decode (strg, 0, '\0\0 ,');
  if (length (parts) = 0)
    return null;
  xq_sequencebld_init (res);
  foreach (varchar part in parts) do
    {
      xq_sequencebld_acc (res, charset_recode (trim (part), NULL, 'UTF-8'));
    }
  xq_sequencebld_final (res);
  return res;
}
;

grant execute on DB.DBA.BPEL_SPLIT_LIST to public
;

xpf_extension ('http://www.openlinksw.com/virtuoso/bpel:split-list', fix_identifier_case ('DB.DBA.BPEL_SPLIT_LIST'), 0)
;


create function DAV_EXTRACT_SPOTLIGHT (in resname varchar, inout rescontent any) returns any
{
  declare temp_name varchar;
  declare sp_metadata, virt_metas, ret, _reg any;

  declare exit handler for sqlstate '*'
  { log_message ('SpotLight import fail: ' || __SQL_MESSAGE); return NULL; };

  if (not spotlight_status ())
    return;

  _reg := cast (registry_get ('VAD_is_run') as varchar);
  if (_reg <> '0')
    return NULL;

  sys_mkdir ('sptmp');
  temp_name := 'sptmp/' || resname;

  string_to_file (temp_name, blob_to_string (rescontent), -2);
  -- Why not: run_executable ('mdimport', '-f', temp_name);
  -- 1. run_executable is not documented.
  -- 2. run_executable presume mdimport is located in good know directory
  --    We need to do this work silent for user.
  -- Where's the check for exit code?
  -- Where's check for sqlstate 42000?
  -- IMHO this is not major important to break uploading in DAV.
  -- 
--  system ('mdimport -f ' || temp_name);
  run_executable ('/usr/bin/mdimport', 1, ' -f ', server_root () || temp_name);
  sp_metadata := SPOTLIGHT_METADATA (temp_name);
  sys_unlink (temp_name);

  virt_metas := DAV_CONVERT_SPOTLIGHT_TO_VIRTUOSO (sp_metadata);

  return virt_metas;
}
;


create function DAV_CONVERT_SPOTLIGHT_TO_VIRTUOSO (in sp_data any) returns any
{
   declare loop_names, len, v_meta, ret, ctr, res, added integer;

   loop_names := 0;
   added := 0;
   len := length (sp_data);
   v_meta := vector ();
   xte_nodebld_init (res);

   while (len > loop_names)
     {
	declare line, name, vals any;
	line := sp_data [loop_names];
	name := line [0];
	vals := line [1];
	if (name in ('kMDItemLastUsedDate', 'kMDItemUsedDates', 'kMDItemFSFinderFlags',
		'kMDItemFSOwnerUserID', 'kMDItemFSOwnerGroupID', 'kMDItemFSTypeCode',
		'kMDItemID', 'kMDItemFSSize', 'kMDItemFSCreationDate', 'kMDItemContentCreationDate',
		'kMDItemFSContentChangeDate', 'kMDItemFSCreatorCode', 'kMDItemFSLabel',
		'kMDItemFSInvisible', 'kMDItemFSNodeCount', 'kMDItemAttributeChangeDate',
		'kMDItemDisplayName', 'kMDItemContentModificationDate', 'kMDItemFSName', 'kMDItemContentTypeTree'))
	   goto end_loop;

	if (__tag (vals) = 193)
	    foreach (any val in line [1]) do
	      DAV_SPOTLIGHT_ADD (res, name, val);
	else
	  DAV_SPOTLIGHT_ADD (res, name, line [1]);

	added := added + 1;

end_loop:
	loop_names := loop_names + 1;
     }

	xte_nodebld_final (res, xte_head (UNAME' root'));
    if (added)
      return xml_tree_doc (res);

    return null;
}
;


create procedure DAV_SPOTLIGHT_ADD (inout res any, in name varchar, inout val any)
{
    xte_nodebld_acc (res,
      xte_node (
        xte_head (UNAME'N3', UNAME'N3S', 'http://local.virt/this', UNAME'N3P',
	  'http://www.apple.com/metadata#' || name),
	    cast (val as nvarchar) ) );
}
;
