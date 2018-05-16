--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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
  if (position (orig_res_ext_upper, vector ('.ODT')))
    return 'application/vnd.oasis.opendocument.text';
  if (position (orig_res_ext_upper, vector ('.ODB')))
    return 'application/vnd.oasis.opendocument.database';
  if (position (orig_res_ext_upper, vector ('.ODG')))
    return 'application/vnd.oasis.opendocument.graphics';
  if (position (orig_res_ext_upper, vector ('.ODP')))
    return 'application/vnd.oasis.opendocument.presentation';
  if (position (orig_res_ext_upper, vector ('.ODS')))
    return 'application/vnd.oasis.opendocument.spreadsheet';
  if (position (orig_res_ext_upper, vector ('.ODC')))
    return 'application/vnd.oasis.opendocument.chart';
  if (position (orig_res_ext_upper, vector ('.ODF')))
    return 'application/vnd.oasis.opendocument.formula';
  if (position (orig_res_ext_upper, vector ('.ODI')))
    return 'application/vnd.oasis.opendocument.image';
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
      return 'text/wiki';
  if (position (orig_res_ext_upper,
    vector ('.BMP', '.DIB', '.RLE', '.CR2', '.CRW', '.EMF', '.EPS', '.IFF', '.LBM', '.JP2', '.JPX', '.JPK', '.J2K',
     '.JPC', '.J2C', '.JPE', '.JIF', '.JFIF', '.JPG', '.JPEG', '.GIF', '.PNG') ) )
    return 'application/x-openlink-image';
  if (position (orig_res_ext_upper,
    vector ('.XML', '.RDF', '.RDFS', '.RSS', '.RSS2', '.XBEL', '.FOAF', '.OPML', '.WSDL', '.BPEL', '.VSPX', '.VSCX', '.XDDL', '.OCS') ) )
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
    return 'text/turtle';
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
          --dbg_obj_princ('Exit handler: ', __SQL_STATE, __SQL_MESSAGE);
          return dflt_ret;
        };
      if (content is null)
          return 'text/xml';
      if (html_start = 0)
          html_start := null;
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
                  min_frag_len := max_frag_len;
              for (frag_len := max_frag_len; (frag_len >= min_frag_len) and (html_start is null); frag_len := frag_len - 1000)
                {
                  html_start := xtree_doc (subseq (content, 0, frag_len), 18, 'http://localdav.virt/' || orig_res_name, 'LATIN-1', 'x-any',
                                'Validation=DISABLE Include=DISABLE BuildStandalone=DISABLE SchemaDecl=DISABLE' );
                }
            }
        }
      if (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:bm="http://www.w3.org/2002/01/bookmark#"] exists (/rdf:rdf/bm:bookmark)', html_start))
        return 'application/annotea+xml';
      if (xpath_eval ('[xmlns="http://usefulinc.com/ns/doap#"] exists (/project)', html_start) or
        xpath_eval ('[xmlns:rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns="http://usefulinc.com/ns/doap#"] exists (/rdf:rdf/project)', html_start))
        return 'application/doap+rdf';
      if (xpath_eval ('[xmlns:atom="http://purl.org/atom/ns#"] exists (/atom:feed[@version])', html_start) or
        xpath_eval ('[xmlns:atom="http://www.w3.org/2005/Atom"]exists (/atom:feed)', html_start))
        return 'application/atom+xml';
      if (xpath_eval ('[xmlns:w="http://schemas.microsoft.com/office/word/2003/wordml"] exists (/w:worddocument)', html_start))
        return 'application/msword+xml';
      if (xpath_eval ('[xmlns="urn:schemas-microsoft-com:office:spreadsheet"] exists (/Workbook)', html_start))
          return 'application/msexcel+xml';
      if (xpath_eval ('[xmlns="http://schemas.microsoft.com/project"] exists (/Project)', html_start))
          return 'application/msproject+xml';
      if (xpath_eval ('[xmlns="http://schemas.microsoft.com/visio/2003/core"] exists (/VisioDocument)', html_start))
          return 'application/msvisio+xml';
      if (xpath_eval ('[xmlns:n0="rdf" xmlns:n2="foaf"] exists (//n2:person)', html_start) or xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:foaf="http://xmlns.com/foaf/0.1/"]exists (/rdf:rdf/foaf:*)', html_start))
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
      if (xpath_eval ('[xmlns:rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:ocs = "http://InternetAlchemy.org/ocs/directory#" xmlns:dc = "http://purl.org/metadata/dublin_core#"] exists (/rdf:rdf/rdf:description/dc:title)', html_start))
        return 'application/ocs+xml';
      if (xpath_eval ('[xmlns:rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:dc  = "http://purl.org/metadata/dublin_core#" xmlns = "http://purl.org/ocs/directory/0.5/#"] exists (/rdf:rdf/directory)', html_start))
        return 'application/ocs+xml';
      -- rdf:rdf is lowercase, instead of proper rdf:RDF because dirty HTML mode converts names.
      if (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rss="http://purl.org/rss/1.0/"]exists (/rdf:rdf/rss:channel)', html_start))
        return 'application/rss+xml';
      if (xpath_eval ('exists (/rss[@version])', html_start))
        return 'application/rss+xml';
      if (xpath_eval ('[xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"]exists (/wsdl:definitions)', html_start))
        return 'application/wsdl+xml';
      if (xpath_eval ('[xmlns="http://www.w3.org/2005/Atom" xmlns:gm="http://base.google.com/ns-metadata/1.0"] exists (/entry)', html_start))
        return 'application/google-base+xml';
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
  if (d is null or d = 0)
    return 'N/A';

  if (d < 1024)
    return sprintf('%d B', d);

  if (d < 1048576)
    return sprintf('%d KB', d / 1024);

  return sprintf('%d MB', d / 1024 / 1024);
}
;

create function "DAV_EXTRACT_RDF_application/x-openlink-license" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_application/x-openlink-license (', orig_res_name, ',... )');
  declare res, content any;
  declare mydata, reg_to, con_num, serial varchar;
  whenever sqlstate '*' goto errexit;

  content := blob_to_string (content1);
  xte_nodebld_init(res);
  mydata := "asn1_to_xml" (content, length(blob_to_string (content)));
  reg_to := cast(xpath_eval('//SEQUENCE/SEQUENCE/SEQUENCE/SEQUENCE[PRINTABLESTRING="RegisteredTo"]/PRINTABLESTRING[position() > 1]/text()', xtree_doc(mydata)) as varchar);
  con_num := cast(xpath_eval('//SEQUENCE/SEQUENCE/SEQUENCE/SEQUENCE[PRINTABLESTRING="NumberOfConnections"]/PRINTABLESTRING[position() > 1]/text()', xtree_doc(mydata)) as varchar);
  serial := cast(xpath_eval('//SEQUENCE/SEQUENCE/SEQUENCE/SEQUENCE[PRINTABLESTRING="SerialNumber"]/PRINTABLESTRING[position() > 1]/text()', xtree_doc(mydata)) as varchar);
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/OplLic#RegisteredTo'), reg_to));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/OplLic#NumberOfConnections'), con_num));
  xte_nodebld_acc(res, xte_node(xte_head(UNAME'N3', UNAME'N3S', 'http://local.virt/this',
    UNAME'N3P', 'http://www.openlinksw.com/schemas/OplLic#SerialNumber'), serial));
  xte_nodebld_final(res, xte_head (UNAME' root'));
  return xml_tree_doc (res);
errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_opendocument" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
  declare doc, metas, extras, res any;
  whenever sqlstate '*' goto errexit;
  --dbg_obj_princ ('DAV_EXTRACT_RDF_opendocument (', orig_res_name, ',... )');
  declare meta, tmp varchar;
  declare xt, xd any;
  if (__proc_exists ('UNZIP_UnzipFileFromArchive', 2) is null)
    goto errexit;
  tmp := tmp_file_name ('rdfm', 'odt');
  string_to_file (tmp, content1, -2);
  meta := UNZIP_UnzipFileFromArchive (tmp, 'meta.xml');
  file_delete (tmp, 1);
  meta := replace(meta, '\n', '');
  xt := xtree_doc (meta, 0);
  metas := vector (
          'http://purl.org/dc/elements/1.1/date', 'declare namespace dc="http://purl.org/dc/elements/1.1/"; //dc:date', NULL,
          'http://purl.org/dc/elements/1.1/language', 'declare namespace dc="http://purl.org/dc/elements/1.1/"; //dc:language', NULL,
          'http://purl.org/dc/elements/1.1/creator', 'declare namespace dc="http://purl.org/dc/elements/1.1/"; //dc:creator', NULL,
          'http://purl.org/dc/elements/1.1/description', 'declare namespace dc="http://purl.org/dc/elements/1.1/"; //dc:description', NULL,
          'http://purl.org/dc/elements/1.1/subject', 'declare namespace dc="http://purl.org/dc/elements/1.1/"; //dc:subject', NULL,
          'http://purl.org/dc/elements/1.1/title', 'declare namespace dc="http://purl.org/dc/elements/1.1/"; //dc:title', NULL,
          'urn:oasis:names:tc:opendocument:xmlns:meta:1.0:creation-date', 'declare namespace meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0"; //meta:creation-date', NULL,
          'urn:oasis:names:tc:opendocument:xmlns:meta:1.0:editing-cycles', 'declare namespace meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0"; //meta:editing-cycles', NULL,
          'urn:oasis:names:tc:opendocument:xmlns:meta:1.0:editing-duration', 'declare namespace meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0"; //meta:editing-duration', NULL,
          'urn:oasis:names:tc:opendocument:xmlns:meta:1.0:generator', 'declare namespace meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0"; //meta:generator', NULL,
          'urn:oasis:names:tc:opendocument:xmlns:meta:1.0:initial-creator', 'declare namespace meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0"; //meta:initial-creator', NULL,
          'urn:oasis:names:tc:opendocument:xmlns:meta:1.0:keyword', 'declare namespace meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0"; //meta:keyword', NULL,
          'urn:oasis:names:tc:opendocument:xmlns:meta:1.0:print-date', 'declare namespace meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0"; //meta:print-date', NULL,
          'urn:oasis:names:tc:opendocument:xmlns:meta:1.0:printed-by', 'declare namespace meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0"; //meta:printed-by', NULL
          );
  extras := null;
  return "DAV_EXTRACT_RDF_BY_METAS" (xt, metas, extras);
errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/vnd.oasis.opendocument.text" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
        return "DAV_EXTRACT_RDF_opendocument" (orig_res_name, content1, html_start);
}
;

create function "DAV_EXTRACT_RDF_application/vnd.oasis.opendocument.database" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
        return "DAV_EXTRACT_RDF_opendocument" (orig_res_name, content1, html_start);
}
;

create function "DAV_EXTRACT_RDF_application/vnd.oasis.opendocument.graphics" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
        return "DAV_EXTRACT_RDF_opendocument" (orig_res_name, content1, html_start);
}
;

create function "DAV_EXTRACT_RDF_application/vnd.oasis.opendocument.presentation" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
        return "DAV_EXTRACT_RDF_opendocument" (orig_res_name, content1, html_start);
}
;
create function "DAV_EXTRACT_RDF_application/vnd.oasis.opendocument.spreadsheet" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
        return "DAV_EXTRACT_RDF_opendocument" (orig_res_name, content1, html_start);
}
;
create function "DAV_EXTRACT_RDF_application/vnd.oasis.opendocument.chart" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
        return "DAV_EXTRACT_RDF_opendocument" (orig_res_name, content1, html_start);
}
;
create function "DAV_EXTRACT_RDF_application/vnd.oasis.opendocument.formula" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
        return "DAV_EXTRACT_RDF_opendocument" (orig_res_name, content1, html_start);
}
;
create function "DAV_EXTRACT_RDF_application/vnd.oasis.opendocument.image" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
        return "DAV_EXTRACT_RDF_opendocument" (orig_res_name, content1, html_start);
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

create function "DAV_EXTRACT_RDF_application/audio" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
  declare content any;
  content := blob_to_string (content1);
  return xml_tree_doc (audio_to_xml (content, length (content), 1));
}
;

create function "DAV_EXTRACT_RDF_audio/mpeg" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/audio" (orig_res_name, content1, html_start);
}
;

create function "DAV_EXTRACT_RDF_audio/x-flac" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/audio" (orig_res_name, content1, html_start);
}
;

create function "DAV_EXTRACT_RDF_audio/x-mp3" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/audio" (orig_res_name, content1, html_start);
}
;

create function "DAV_EXTRACT_RDF_audio/x-m4a" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/audio" (orig_res_name, content1, html_start);
}
;

create function "DAV_EXTRACT_RDF_audio/x-m4p" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/audio" (orig_res_name, content1, html_start);
}
;

create function "DAV_EXTRACT_RDF_application/ogg" (in orig_res_name varchar, inout content1 any, inout html_start any)
{
  return "DAV_EXTRACT_RDF_application/audio" (orig_res_name, content1, html_start);
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
        'http://www.openlinksw.com/schemas/Office#Title'        , 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Title'                                      , NULL,
        'http://www.openlinksw.com/schemas/Office#Author'       , 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Author|o:Creator'                           , NULL,
        'http://www.openlinksw.com/schemas/Office#LastAuthor'   , 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:LastAuthor'                                 , NULL,
        'http://www.openlinksw.com/schemas/Office#Company'      , 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Company'                                    , NULL,
        'http://www.openlinksw.com/schemas/Office#Words'        , 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Words'                                      , NULL,
        'http://www.openlinksw.com/schemas/Office#Pages'        , 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Pages'                                      , NULL,
        'http://www.openlinksw.com/schemas/Office#Lines'        , 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Lines'                                      , NULL,
        'http://www.openlinksw.com/schemas/Office#Last-Saved'   , 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:LastSaved|o:TimeSaved'                      , NULL,
        'http://www.openlinksw.com/schemas/Office#Last-Printed' , 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:LastPrinted|o:TimePrinted'                  , NULL,
        'http://www.openlinksw.com/schemas/Office#Created'      , 'declare namespace o="urn:schemas-microsoft-com:office:office"; o:Created|o:TimeCreated|o:CreationDate'       , NULL );
  extras := vector (
        'http://www.openlinksw.com/schemas/Office#TypeDescr'    ,  type_descr );
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
        'http://www.openlinksw.com/schemas/Office#TypeDescr'    ,  'MS Excel spreadsheet' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
}
;

create function "DAV_EXTRACT_RDF_application/msaccess" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  doc := null;
  metas := null;
  extras := vector (
        'http://www.openlinksw.com/schemas/Office#TypeDescr'    ,  'MS Access database' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
}
;

create function "DAV_EXTRACT_RDF_application/msproject" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  doc := null;
  metas := null;
  extras := vector (
        'http://www.openlinksw.com/schemas/Office#TypeDescr'    ,  'MS Project document' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
}
;


create function "DAV_EXTRACT_RDF_application/mspowerpoint" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  doc := null;
  metas := null;
  extras := vector (
        'http://www.openlinksw.com/schemas/Office#TypeDescr'    ,  'MS PowerPoint presentation' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
}
;


create function "DAV_EXTRACT_RDF_application/msword" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  doc := null;
  metas := null;
  extras := vector (
        'http://www.openlinksw.com/schemas/Office#TypeDescr'    ,  'MS Word document' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
}
;


create function "DAV_EXTRACT_RDF_application/pdf" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  doc := null;
  metas := null;
  extras := vector (
        'http://www.openlinksw.com/schemas/Office#TypeDescr'    ,  'PDF (Acrobat)' );
  return "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
}
;


create function "DAV_EXTRACT_RDF_application/xbrl+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  metas := vector (
        'http://www.openlinksw.com/schemas/xbrl#identifier', 'declare namespace xmlns="http://www.xbrl.org/2003/instance"; /xmlns:xbrl/xmlns:context/xmlns:entity/xmlns:identifier/text()', '',
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
  --dbg_obj_princ ('DAV_EXTRACT_RDF_application/doap+rdf (', orig_res_name, ',... )');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  metas := vector (
        'http://www.openlinksw.com/schemas/doap#title', 'declare namespace xmlns="http://usefulinc.com/ns/doap#"; //xmlns:Project/xmlns:name', '',
        'http://www.openlinksw.com/schemas/doap#description', 'declare namespace xmlns="http://usefulinc.com/ns/doap#"; //xmlns:Project/xmlns:shortdesc', '',
        'http://www.openlinksw.com/schemas/doap#creationDate', 'declare namespace xmlns="http://usefulinc.com/ns/doap#"; //xmlns:Project/xmlns:created', ''
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
  metas := null;
  extras := vector (
        'http://www.openlinksw.com/schemas/Archive#type', type_descr);
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
  --dbg_obj_princ ('DAV_EXTRACT_RDF_application/rss+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto final;
  doc := xtree_doc (content, 0);
  if (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rss="http://purl.org/rss/1.0/"]exists (/rdf:RDF/rss:channel)', doc))
    {
      declare tmp_n3, channel_props any;
      declare about varchar;
      tmp_n3 := xslt ('http://local.virt/rdfxml2n3xml', doc);
      about := xpath_eval ('/N3[@N3P="http://www.w3.org/1999/02/22-rdf-syntax-ns#type"][@N3O="http://purl.org/rss/1.0/channel"]/@N3S', tmp_n3);
      if (about is null)
        {
          goto final;
        }
      channel_props := xpath_eval ('/N3[@N3S=\044about][not (exists (@N3O))]', tmp_n3, 0, vector (UNAME'about', about));
      foreach (any prop in channel_props) do
        {
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
  --dbg_obj_princ ('DAV_EXTRACT_RDF_application/atom+xml (', orig_res_name, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  version := xpath_eval ('[xmlns:atom="http://purl.org/atom/ns#"] number (/atom:feed/@version)', doc);
  if (version < 0.1)
    goto atom2005;
  metas := vector (
        'http://purl.org/rss/1.0/title', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/atom:title', NULL,
        'http://purl.org/rss/1.0/link', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/atom:link/@href', NULL,
        'http://purl.org/rss/1.0/description', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/atom:tagline', NULL,
        'http://purl.org/rss/1.0/language', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/@xml:lang', NULL,
        'http://purl.org/rss/1.0/copyright', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/atom:copyright', NULL,
        'http://purl.org/rss/1.0/docs', 'declare namespace atom="http://purl.org/atom/ns#"; /atom:feed/atom:info', NULL,
        'http://purl.org/rss/1.0/lastBuildDate', 'declare namespace atom="http://purl.org/atom/ns#"; declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; virtbpel:unix-datetime-parser (/atom:feed/atom:modified, 0, 2)', NULL
        );
atom2005:
   if (xpath_eval ('[xmlns:atom="http://www.w3.org/2005/Atom"] exists (/atom:feed)', doc))
   {
        metas := vector (
        'http://purl.org/rss/1.0/title', 'declare namespace atom="http://www.w3.org/2005/Atom"; /atom:feed/atom:title', NULL,
        'http://purl.org/rss/1.0/link', 'declare namespace atom="http://www.w3.org/2005/Atom"; /atom:feed/atom:link/@href', NULL,
        'http://purl.org/rss/1.0/description', 'declare namespace atom="http://www.w3.org/2005/Atom"; /atom:feed/atom:subtitle', NULL,
        'http://purl.org/rss/1.0/language', 'declare namespace atom="http://www.w3.org/2005/Atom"; /atom:feed/@xml:lang', NULL,
        'http://purl.org/rss/1.0/copyright', 'declare namespace atom="http://www.w3.org/2005/Atom"; /atom:feed/atom:rights', NULL,
        'http://purl.org/rss/1.0/docs', 'declare namespace atom="http://www.w3.org/2005/Atom"; /atom:feed/atom:summary', NULL,
        'http://purl.org/rss/1.0/lastBuildDate', 'declare namespace atom="http://www.w3.org/2005/Atom"; declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; virtbpel:unix-datetime-parser (/atom:feed/atom:updated, 0, 2)', NULL
        );
   }
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

create function "DAV_EXTRACT_RDF_text/turtle" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  --dbg_obj_princ ('DAV_EXTRACT_RDF_text/turtle (', orig_res_name, content, html_start, ')');
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
  --dbg_obj_princ ('DAV_EXTRACT_RDF_application/foaf+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto final;
  doc := xtree_doc (content, 0);
  tmp_n3 := xslt ('http://local.virt/rdfxml2n3xml', doc);
  about := xpath_eval ('/N3[@N3P="http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]/@N3S', tmp_n3);
  if (about is null or
    xpath_eval (
      '/N3[@N3S=\044about][@N3P="http://xmlns.com/foaf/0.1/name"]', tmp_n3, 1,
      vector (UNAME'about', about) ) is null )
    about := xpath_eval ('/N3[@N3P="http://xmlns.com/foaf/0.1/name"]/@N3S', tmp_n3);
  if (about is null)
    {
       goto final;
    }
  obj1_props := xpath_eval ('/N3[@N3S=\044about][starts-with (@N3P, "http://xmlns.com/foaf/0.1/")]', tmp_n3, 0, vector (UNAME'about', about));
  foreach (any prop in obj1_props) do
    {
      declare obj any;
      obj := cast (xpath_eval ('@N3O', prop) as varchar);
      if (obj is null)
        {
          xte_nodebld_acc (res,
           xte_node (
             xte_head (UNAME'N3', UNAME'N3S', 'http://local.virt/this', UNAME'N3P', xpath_eval ('@N3P', prop)),
             xpath_eval ('string (.)', prop) ) );
        }
      else if ((obj like 'node%') or (obj like '#%'))
        {
          declare obj_names any;
          obj_names := xpath_eval ('/N3[@N3S = \044obj][@N3P="http://xmlns.com/foaf/0.1/name"]', tmp_n3, 0, vector (UNAME'obj', obj));
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
          xte_nodebld_acc (res,
           xte_node (
             xte_head (UNAME'N3', UNAME'N3S', 'http://local.virt/this', UNAME'N3P', xpath_eval ('@N3P', prop) || N'-uri'),
             obj ) );
        }
      else
        {
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
  --dbg_obj_princ ('DAV_EXTRACT_RDF_application/mods+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
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
        'http://www.openlinksw.com/schemas/MODS#subtitle', 'mods/titleInfo/subTitle', NULL,
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
  declare doc, metas, extras, result, vals, outlines any;
  declare graph_uri, new_uri, title, dateCreated, dateModified, ownerName, ownerEmail, owner_iri varchar;
  --dbg_obj_princ ('DAV_EXTRACT_RDF_application/opml+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  metas := vector (
        'http://www.openlinksw.com/schemas/OPML#title', '/opml/head/title', 'Untitled OPML',
        'http://www.openlinksw.com/schemas/OPML#dateCreated', 'declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; for \044d in /opml/head/dateCreated return virtbpel:unix-datetime-parser (\044d)', NULL,
        'http://www.openlinksw.com/schemas/OPML#dateModified', 'declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; for \044d in /opml/head/dateModified return virtbpel:unix-datetime-parser (\044d)', NULL,
        'http://www.openlinksw.com/schemas/OPML#ownerName', '/opml/head/ownerName', 'Unknown OPML owner',
        'http://www.openlinksw.com/schemas/OPML#ownerEmail', '/opml/head/ownerEmail', NULL
        );
  extras := vector (
        'http://www.openlinksw.com/virtdav#dynRdfExtractor', 'application/opml+xml' );
  result := "DAV_EXTRACT_RDF_BY_METAS" (doc, metas, extras);
  title := cast(xquery_eval ('/N3[@N3P="http://www.openlinksw.com/schemas/OPML#title"]', result, 1) as varchar);
  dateCreated := cast(xquery_eval ('/N3[@N3P="http://www.openlinksw.com/schemas/OPML#dateCreated"]', result, 1) as varchar);
  dateModified := cast(xquery_eval ('/N3[@N3P="http://www.openlinksw.com/schemas/OPML#dateModified"]', result, 1) as varchar);
  ownerName := cast(xquery_eval ('/N3[@N3P="http://www.openlinksw.com/schemas/OPML#ownerName"]', result, 1) as varchar);
  ownerEmail := cast(xquery_eval ('/N3[@N3P="http://www.openlinksw.com/schemas/OPML#ownerEmail"]', result, 1) as varchar);
  graph_uri := registry_get ('DB.DBA.DAV_RDF_GRAPH_URI');
  new_uri := DB.DBA.DAV_FULL_PATH_TO_IRI (graph_uri, orig_res_name);
  if (left(orig_res_name, 4) = '/DAV')
    orig_res_name := right(orig_res_name, length(orig_res_name) - 4);
  DB.DBA.RDF_QUAD_URI (graph_uri, new_uri, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 'http://rdfs.org/sioc/ns#SubscriptionList');
  if (ownerName is not null)
  {
    declare s_out any;
    s_out := string_output();
    declare s varchar;
    http_url(ownerName, null, s_out);
    s := string_output_string(s_out);
    owner_iri := concat(new_uri, '#', s);
  }
  if (ownerEmail is not null)
    DB.DBA.RDF_QUAD_URI (graph_uri, new_uri, 'http://rdfs.org/sioc/ns#email', 'mailto:'|| ownerEmail);
  if (title is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_uri, new_uri, 'http://purl.org/dc/elements/1.1/title', title);
  if (ownerName is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_uri, new_uri, 'http://rdfs.org/sioc/ns#has_owner', ownerName);
  if (dateModified is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_uri, new_uri, 'http://purl.org/dc/terms/modified', dateModified);
  if (dateCreated is not null)
    DB.DBA.RDF_QUAD_URI_L (graph_uri, new_uri, 'http://purl.org/dc/terms/created', dateCreated);
  return result;
errexit:
  return xml_tree_doc (xte_node (xte_head (UNAME' root')));
}
;

create function "DAV_EXTRACT_RDF_application/ocs+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  --dbg_obj_princ ('DAV_EXTRACT_RDF_application/ocs+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  metas := vector (
        'http://www.openlinksw.com/schemas/OPML#title', '//*:directory/*:title|//*:description/*:title', 'Untitled OCS',
        'http://www.openlinksw.com/schemas/OPML#dateCreated', '//*:directory/*:date|//*:description/*:date', NULL,
        'http://www.openlinksw.com/schemas/OPML#dateModified', '//*:directory/*:date|//*:description/*:date', NULL,
        'http://www.openlinksw.com/schemas/OPML#ownerName', '//*:directory/*:publisher|//*:description/*:creator', 'Unknown OPML owner',
        'http://www.openlinksw.com/schemas/OPML#ownerEmail', '//*:directory/*:creator|//*:description/*:creator', NULL
        );
  extras := vector (
        'http://www.openlinksw.com/virtdav#dynRdfExtractor', 'application/ocs+xml' );
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

create function "DAV_EXTRACT_RDF_application/annotea+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  --dbg_obj_princ ('DAV_EXTRACT_RDF_application/annotea+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  metas := vector (
        'http://www.openlinksw.com/schemas/Annotea#Bookmark', 'declare namespace dc="http://purl.org/dc/elements/1.1/"; /*/*:Bookmark/@dc:title', 'Untitled',
        'http://www.openlinksw.com/schemas/Annotea#Topic', 'declare namespace dc="http://purl.org/dc/elements/1.1/"; /*/*:Topic/@dc:title', 'Untitled'
        );
  extras := null;
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

create function "DAV_EXTRACT_RDF_application/google-base+xml" (in orig_res_name varchar, inout content any, inout html_start any)
{
  declare doc, metas, extras any;
  --dbg_obj_princ ('DAV_EXTRACT_RDF_application/google-base+xml (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto errexit;
  doc := xtree_doc (content, 0);
  metas := vector (
    'http://www.openlinksw.com/schemas/google-base#actor', '/*:entry/*:actor', '',
    'http://www.openlinksw.com/schemas/google-base#adult', 'null', NULL,
    'http://www.openlinksw.com/schemas/google-base#age', '/*:entry/*:age', NULL,
    'http://www.openlinksw.com/schemas/google-base#age_range', '/*:entry/*:age_range', NULL,
    'http://www.openlinksw.com/schemas/google-base#agent', '/*:entry/*:agent', NULL,
    'http://www.openlinksw.com/schemas/google-base#album', '/*:entry/*:album', NULL,
    'http://www.openlinksw.com/schemas/google-base#apparel_type', '/*:entry/*:apparel_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#area', '/*:entry/*:area', NULL,
    'http://www.openlinksw.com/schemas/google-base#artist', '/*:entry/*:artist', NULL,
    'http://www.openlinksw.com/schemas/google-base#aspect_ratio', '/*:entry/*:aspect_ratio', NULL,
    'http://www.openlinksw.com/schemas/google-base#author', '/*:entry/*:author/*:name', NULL,
    'http://www.openlinksw.com/schemas/google-base#bathrooms', '/*:entry/*:bathrooms', NULL,
    'http://www.openlinksw.com/schemas/google-base#battery_life', '/*:entry/*:battery_life', NULL,
    'http://www.openlinksw.com/schemas/google-base#bedrooms', '/*:entry/*:bedrooms', NULL,
    'http://www.openlinksw.com/schemas/google-base#binding', '/*:entry/*:binding', NULL,
    'http://www.openlinksw.com/schemas/google-base#brand', '/*:entry/*:brand', NULL,
    'http://www.openlinksw.com/schemas/google-base#broker', '/*:entry/*:broker', NULL,
    'http://www.openlinksw.com/schemas/google-base#calories', '/*:entry/*:calories', NULL,
    'http://www.openlinksw.com/schemas/google-base#capacity', '/*:entry/*:capacity', NULL,
    'http://www.openlinksw.com/schemas/google-base#category', '/*:entry/*:category', NULL,
    'http://www.openlinksw.com/schemas/google-base#cholesterol', '/*:entry/*:cholesterol', NULL,
    'http://www.openlinksw.com/schemas/google-base#color', '/*:entry/*:color', NULL,
    'http://www.openlinksw.com/schemas/google-base#color_output', '/*:entry/*:color_output', NULL,
    'http://www.openlinksw.com/schemas/google-base#condition', '/*:entry/*:condition', NULL,
    'http://www.openlinksw.com/schemas/google-base#cooking_time', '/*:entry/*:cooking_time', NULL,
    'http://www.openlinksw.com/schemas/google-base#countries', '/*:entry/*:countries', NULL,
    'http://www.openlinksw.com/schemas/google-base#course', '/*:entry/*:course', NULL,
    'http://www.openlinksw.com/schemas/google-base#cuisine', '/*:entry/*:cuisine', NULL,
    'http://www.openlinksw.com/schemas/google-base#delivery', '/*:entry/*:delivery', NULL,
    'http://www.openlinksw.com/schemas/google-base#delivery_notes', '/*:entry/*:delivery_notes', NULL,
    'http://www.openlinksw.com/schemas/google-base#delivery_radius', '/*:entry/*:delivery_radius', NULL,
    'http://www.openlinksw.com/schemas/google-base#department', '/*:entry/*:department', NULL,
    'http://www.openlinksw.com/schemas/google-base#devices', '/*:entry/*:devices', NULL,
    'http://www.openlinksw.com/schemas/google-base#director', '/*:entry/*:director', NULL,
    'http://www.openlinksw.com/schemas/google-base#display_type', '/*:entry/*:display_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#edition', '/*:entry/*:edition', NULL,
    'http://www.openlinksw.com/schemas/google-base#education', '/*:entry/*:education', NULL,
    'http://www.openlinksw.com/schemas/google-base#employer', '/*:entry/*:employer', NULL,
    'http://www.openlinksw.com/schemas/google-base#ethnicity', '/*:entry/*:ethnicity', NULL,
    'http://www.openlinksw.com/schemas/google-base#event_date_range', '/*:entry/*:event_date_range', NULL,
    'http://www.openlinksw.com/schemas/google-base#event_parking', '/*:entry/*:event_parking', NULL,
    'http://www.openlinksw.com/schemas/google-base#event_performer', '/*:entry/*:event_performer', NULL,
    'http://www.openlinksw.com/schemas/google-base#event_type', '/*:entry/*:event_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#expiration_date', '/*:entry/*:expiration_date', NULL,
    'http://www.openlinksw.com/schemas/google-base#expiration_date', '/*:entry/*:expiration_date', NULL,
    'http://www.openlinksw.com/schemas/google-base#feature', '/*:entry/*:feature', NULL,
    'http://www.openlinksw.com/schemas/google-base#fiber', '/*:entry/*:fiber', NULL,
    'http://www.openlinksw.com/schemas/google-base#file_type', '/*:entry/*:file_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#film_type', '/*:entry/*:film_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#focus_type', '/*:entry/*:focus_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#format', '/*:entry/*:format', NULL,
    'http://www.openlinksw.com/schemas/google-base#from_location', '/*:entry/*:from_location', NULL,
    'http://www.openlinksw.com/schemas/google-base#functions', '/*:entry/*:functions', NULL,
    'http://www.openlinksw.com/schemas/google-base#gender', '/*:entry/*:gender', NULL,
    'http://www.openlinksw.com/schemas/google-base#genre', '/*:entry/*:genre', NULL,
    'http://www.openlinksw.com/schemas/google-base#heel_height', '/*:entry/*:heel_height', NULL,
    'http://www.openlinksw.com/schemas/google-base#height', '/*:entry/*:height', NULL,
    'http://www.openlinksw.com/schemas/google-base#hoa_dues', '/*:entry/*:hoa_dues', NULL,
    'http://www.openlinksw.com/schemas/google-base#immigration_status', '/*:entry/*:immigration_status', NULL,
    'http://www.openlinksw.com/schemas/google-base#installation', '/*:entry/*:installation', NULL,
    'http://www.openlinksw.com/schemas/google-base#interested_in', '/*:entry/*:interested_in', NULL,
    'http://www.openlinksw.com/schemas/google-base#isbn', '/*:entry/*:isbn', NULL,
    'http://www.openlinksw.com/schemas/google-base#job_function', '/*:entry/*:job_function', NULL,
    'http://www.openlinksw.com/schemas/google-base#job_industry', '/*:entry/*:job_industry', NULL,
    'http://www.openlinksw.com/schemas/google-base#job_type', '/*:entry/*:job_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#languages', '/*:entry/*:languages', NULL,
    'http://www.openlinksw.com/schemas/google-base#length', '/*:entry/*:length', NULL,
    'http://www.openlinksw.com/schemas/google-base#listing_status', '/*:entry/*:listing_status', NULL,
    'http://www.openlinksw.com/schemas/google-base#listing_type', '/*:entry/*:listing_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#load_type', '/*:entry/*:load_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#location', '/*:entry/*:location', NULL,
    'http://www.openlinksw.com/schemas/google-base#lot_size', '/*:entry/*:lot_size', NULL,
    'http://www.openlinksw.com/schemas/google-base#made_in', '/*:entry/*:made_in', NULL,
    'http://www.openlinksw.com/schemas/google-base#main_ingredient', '/*:entry/*:main_ingredient', NULL,
    'http://www.openlinksw.com/schemas/google-base#make', '/*:entry/*:make', NULL,
    'http://www.openlinksw.com/schemas/google-base#marital_status', '/*:entry/*:marital_status', NULL,
    'http://www.openlinksw.com/schemas/google-base#material', '/*:entry/*:material', NULL,
    'http://www.openlinksw.com/schemas/google-base#meal_type', '/*:entry/*:meal_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#megapixels', '/*:entry/*:megapixels', NULL,
    'http://www.openlinksw.com/schemas/google-base#memory_card_slot', '/*:entry/*:memory_card_slot', NULL,
    'http://www.openlinksw.com/schemas/google-base#mileage', '/*:entry/*:mileage', NULL,
    'http://www.openlinksw.com/schemas/google-base#mls_listing_id', '/*:entry/*:mls_listing_id', NULL,
    'http://www.openlinksw.com/schemas/google-base#mls_name', '/*:entry/*:mls_name', NULL,
    'http://www.openlinksw.com/schemas/google-base#mobile_url', '/*:entry/*:mobile_url', NULL,
    'http://www.openlinksw.com/schemas/google-base#model', '/*:entry/*:model', NULL,
    'http://www.openlinksw.com/schemas/google-base#model_number', '/*:entry/*:model_number', NULL,
    'http://www.openlinksw.com/schemas/google-base#name_of_item_reviewed', '/*:entry/*:name_of_item_reviewed', NULL,
    'http://www.openlinksw.com/schemas/google-base#news_source', '/*:entry/*:news_source', NULL,
    'http://www.openlinksw.com/schemas/google-base#occasion', '/*:entry/*:occasion', NULL,
    'http://www.openlinksw.com/schemas/google-base#occupation', '/*:entry/*:occupation', NULL,
    'http://www.openlinksw.com/schemas/google-base#open_house_date_range', '/*:entry/*:open_house_date_range', NULL,
    'http://www.openlinksw.com/schemas/google-base#operating_system', '/*:entry/*:operating_system', NULL,
    'http://www.openlinksw.com/schemas/google-base#optical_drive', '/*:entry/*:optical_drive', NULL,
    'http://www.openlinksw.com/schemas/google-base#pages', '/*:entry/*:pages', NULL,
    'http://www.openlinksw.com/schemas/google-base#payment', '/*:entry/*:payment', NULL,
    'http://www.openlinksw.com/schemas/google-base#payment_notes', '/*:entry/*:payment_notes', NULL,
    'http://www.openlinksw.com/schemas/google-base#pickup', '/*:entry/*:pickup', NULL,
    'http://www.openlinksw.com/schemas/google-base#platform', '/*:entry/*:platform', NULL,
    'http://www.openlinksw.com/schemas/google-base#preparation_method', '/*:entry/*:preparation_method', NULL,
    'http://www.openlinksw.com/schemas/google-base#preparation_time', '/*:entry/*:preparation_time', NULL,
    'http://www.openlinksw.com/schemas/google-base#price', '/*:entry/*:price', NULL,
    'http://www.openlinksw.com/schemas/google-base#price_type', '/*:entry/*:price_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#price_units', '/*:entry/*:price_units', NULL,
    'http://www.openlinksw.com/schemas/google-base#processor_speed', '/*:entry/*:processor_speed', NULL,
    'http://www.openlinksw.com/schemas/google-base#product_type', '/*:entry/*:product_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#property_taxes', '/*:entry/*:property_taxes', NULL,
    'http://www.openlinksw.com/schemas/google-base#property_type', '/*:entry/*:property_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#protein', '/*:entry/*:protein', NULL,
    'http://www.openlinksw.com/schemas/google-base#provider_class', '/*:entry/*:provider_class', NULL,
    'http://www.openlinksw.com/schemas/google-base#provider_rank', '/*:entry/*:provider_rank', NULL,
    'http://www.openlinksw.com/schemas/google-base#publication_name', '/*:entry/*:title', NULL,
    'http://www.openlinksw.com/schemas/google-base#publication_volume', '/*:entry/*:publication_volume', NULL,
    'http://www.openlinksw.com/schemas/google-base#publish_date', '/*:entry/*:publish_date', NULL,
    'http://www.openlinksw.com/schemas/google-base#publish_date', '/*:entry/*:publish_date', NULL,
    'http://www.openlinksw.com/schemas/google-base#publish_year', '/*:entry/*:publish_year', NULL,
    'http://www.openlinksw.com/schemas/google-base#publisher', '/*:entry/*:publisher', NULL,
    'http://www.openlinksw.com/schemas/google-base#publisher_url', '/*:entry/*:publisher_url', NULL,
    'http://www.openlinksw.com/schemas/google-base#quantity', '/*:entry/*:quantity', NULL,
    'http://www.openlinksw.com/schemas/google-base#rating', '/*:entry/*:rating', NULL,
    'http://www.openlinksw.com/schemas/google-base#recommended_usage', '/*:entry/*:recommended_usage', NULL,
    'http://www.openlinksw.com/schemas/google-base#resolution', '/*:entry/*:resolution', NULL,
    'http://www.openlinksw.com/schemas/google-base#review_type', '/*:entry/*:review_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#reviewer_type', '/*:entry/*:reviewer_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#salary', '/*:entry/*:salary', NULL,
    'http://www.openlinksw.com/schemas/google-base#salary_type', '/*:entry/*:salary_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#saturated_fat', '/*:entry/*:saturated_fat', NULL,
    'http://www.openlinksw.com/schemas/google-base#school', '/*:entry/*:school', NULL,
    'http://www.openlinksw.com/schemas/google-base#school_district', '/*:entry/*:school_district', NULL,
    'http://www.openlinksw.com/schemas/google-base#screen_size', '/*:entry/*:screen_size', NULL,
    'http://www.openlinksw.com/schemas/google-base#season_or_occasion', '/*:entry/*:season_or_occasion', NULL,
    'http://www.openlinksw.com/schemas/google-base#service_type', '/*:entry/*:service_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#servings', '/*:entry/*:servings', NULL,
    'http://www.openlinksw.com/schemas/google-base#sexual_orientation', '/*:entry/*:sexual_orientation', NULL,
    'http://www.openlinksw.com/schemas/google-base#shipping', '/*:entry/*:shipping', NULL,
    'http://www.openlinksw.com/schemas/google-base#shoe_width', '/*:entry/*:shoe_width', NULL,
    'http://www.openlinksw.com/schemas/google-base#size', '/*:entry/*:size', NULL,
    'http://www.openlinksw.com/schemas/google-base#sodium', '/*:entry/*:sodium', NULL,
    'http://www.openlinksw.com/schemas/google-base#style', '/*:entry/*:style', NULL,
    'http://www.openlinksw.com/schemas/google-base#tax_percent', '/*:entry/*:tax_percent', NULL,
    'http://www.openlinksw.com/schemas/google-base#tax_region', '/*:entry/*:tax_region', NULL,
    'http://www.openlinksw.com/schemas/google-base#tech_spec_link', '/*:entry/*:tech_spec_link', NULL,
    'http://www.openlinksw.com/schemas/google-base#to_location', '/*:entry/*:to_location', NULL,
    'http://www.openlinksw.com/schemas/google-base#tone_type', '/*:entry/*:tone_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#total_carbs', '/*:entry/*:total_carbs', NULL,
    'http://www.openlinksw.com/schemas/google-base#total_fat', '/*:entry/*:total_fat', NULL,
    'http://www.openlinksw.com/schemas/google-base#travel_date_range', '/*:entry/*:travel_date_range', NULL,
    'http://www.openlinksw.com/schemas/google-base#upc', '/*:entry/*:upc', NULL,
    'http://www.openlinksw.com/schemas/google-base#url_of_item_reviewed', '/*:entry/*:url_of_item_reviewed', NULL,
    'http://www.openlinksw.com/schemas/google-base#vehicle_type', '/*:entry/*:vehicle_type', NULL,
    'http://www.openlinksw.com/schemas/google-base#vin', '/*:entry/*:vin', NULL,
    'http://www.openlinksw.com/schemas/google-base#web_url', '/*:entry/*:web_url', NULL,
    'http://www.openlinksw.com/schemas/google-base#weight', '/*:entry/*:weight', NULL,
    'http://www.openlinksw.com/schemas/google-base#width', '/*:entry/*:width', NULL,
    'http://www.openlinksw.com/schemas/google-base#wireless_interface', '/*:entry/*:wireless_interface', NULL,
    'http://www.openlinksw.com/schemas/google-base#year', '/*:entry/*:year', NULL,
    'http://www.openlinksw.com/schemas/google-base#zoning', '/*:entry/*:zoning', NULL,
    'http://www.openlinksw.com/schemas/google-base#zoom', '/*:entry/*:zoom', NULL
        );
  extras := null;
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
  declare items any;
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

      _ent := xtree_doc ( "WikiV lexer" (blob_to_string(content) || '\r\n', 'Main', 'DoesntMatter', 'wiki', null), 2);
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
      {
        declare pos integer;
        pos := strrchr(orig_res_name, '/');
        if (pos > 0)
          pos := pos + 1;
        else
          pos := 0;
        _title := subseq (orig_res_name, pos, length (orig_res_name) - 4);
      }
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
  line_idx := 0;
  while (line_idx < lines_count)
    {
      line := lines [line_idx];
      while ((line_idx+1 < lines_count) and (chr (lines [line_idx+1][0]) = ' ' or chr (lines [line_idx+1][0]) = '\t'))
        {
          line := line || subseq (lines [line_idx+1], 1);
          line_idx := line_idx + 1;
        }
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
            signal ('22007', sprintf ('IMC text contains redundant "END" at line %d', line_idx + 1));
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
'^([A-Za-z0-9-]+[.])?([A-Za-z0-9-]+)(([;][A-Za-z0-9-]+(=(([^\001-\037\200-\377";:,]*)|("[^\001-\037\200-\377"]*"))(,(([^\001-\037\200-\377";:,]*)|("[^\001-\037\200-\377"]*")))*)?)*)([:])([\011\040-\377]*)\044',
--(group        [.])?name           ((param-name      (=(plain-param-value           |quoted_param_value         )(,(plain-param-value           |quoted_param_value         ))*)?)*) [:]  value
            line, 0 );
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
          data := replace (data, '\\\\', '\\'); --' - this single quote in comment is to keep syntax highlight happy in MC and the like.
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
  --dbg_obj_princ ('DAV_EXTRACT_RDF_text/directory (', orig_res_name, content, html_start, ')');
  whenever sqlstate '*' goto final;
  if (not isstring (content))
    doc := IMC_TO_XML (cast (content as varchar));
  else
    doc := IMC_TO_XML (content);
  doc := xml_tree_doc (doc);
  --dbg_obj_princ ('doc is ', doc);
  diritems := xpath_eval ('/*', doc, 0);
  foreach (any diritm in diritems) do
    {
      declare itemname varchar;
      declare ctr, len integer;
      itemname := xpath_eval ('name(.)', diritm);
      if (itemname = 'IMC-VCARD')
      {
        metas := vector (
          'http://www.openlinksw.com/virtdav#dynRdfExtractor', '"text/directory"', null,
-- basic props
          'http://www.w3.org/2001/vcard-rdf/3.0#FN', 'FN/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#NICKNAME', 'NICKNAME/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#BDAY', 'declare namespace virtbpel="http://www.openlinksw.com/virtuoso/bpel"; for \044v in BDAY/val return virtbpel:unix-datetime-parser (\044v)', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#MAILER', 'MAILER/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#GEO', 'GEO/val', null, -- If proper latitude/longitude pair of <fld> is specified then do not display
          'http://www.w3.org/2001/vcard-rdf/3.0#TITLE', 'TITLE/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#ROLE', 'ROLE/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#CATEGORIES', 'CATEGORIES/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#N', 'if (N/val) then concat (N/val, ";;;;") else concat (N/fld[1], ";", N/fld[2], ";", N/fld[3], ";", N/fld[4], ";", N/fld[5])', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#SOURCE', 'SOURCE/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#NOTE', 'NOTE/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#PRODID', 'PRODID/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#REV', 'REV/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#SORT-STRING', 'SORT-STRING/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#CLASS', 'CLASS/val', null,
-- attributed, but attr is turned into substring
          'http://www.w3.org/2001/vcard-rdf/3.0#TEL', 'for \044v in TEL/val return concat (\044v, for \044t in \044v/../TYPE return concat (" (", \044t, ")"))', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#EMAIL', 'for \044v in EMAIL/val return concat (\044v, for \044t in \044v/../TYPE return concat (" (", \044t, ")"))', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#ADR', 'for \044v in ADR return concat (if (\044v/val) then concat (\044v/val, ";;;;;;") else concat (\044v/fld[1], ";", \044v/fld[2], ";", \044v/fld[3], ";", \044v/fld[4], ";", \044v/fld[5], ";", \044v/fld[6], ";", \044v/fld[7]), for \044t in \044v/TYPE return concat (" (", \044t, ")"))', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#LABEL', 'for \044v in LABEL/val return concat (\044v, for \044t in \044v/../TYPE return concat (" (", \044t, ")"))', null,
-- attributed, but attr is ignored
          'http://www.w3.org/2001/vcard-rdf/3.0#UID', 'CLASS/val', null,
-- structured
          'http://www.w3.org/2001/vcard-rdf/3.0#Name-Family', 'N/fld[1]|N/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#Name-Given', 'N/fld[2]', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#Name-Other', 'N/fld[3]', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#Name-Prefix', 'N/fld[4]', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#Name-Suffix', 'N/fld[5]', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Pobox', 'ADR/fld[1]|ADR/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Extadd', 'ADR/fld[2]', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Street', 'ADR/fld[3]', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Locality', 'ADR/fld[4]', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Region', 'ADR/fld[5]', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Pcode', 'ADR/fld[6]', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#Address-Country', 'ADR/fld[7]', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#Org-Orgname', 'ORG/fld[1]|ORG/val', null,
          'http://www.w3.org/2001/vcard-rdf/3.0#Org-Orgunit', 'ORG/fld[position() > 1]', null
          );
      }
      else if (itemname = 'IMC-VCALENDAR')
        {
          --dbg_obj_princ('diritems: ', length(diritems), itemname, xpath_eval('count (IMC-VEVENT)', diritm));
          if ((length (diritems) = 1) and (xpath_eval('count (IMC-VEVENT)', diritm) > 0))
          {
            metas := vector (
              'http://www.openlinksw.com/schemas/ICS#SUMMARY', 'IMC-VEVENT/SUMMARY/val', null,
              'http://www.openlinksw.com/schemas/ICS#LOCATION', 'IMC-VEVENT/LOCATION/val', null,
              'http://www.openlinksw.com/schemas/ICS#CATEGORIES', 'IMC-VEVENT/CATEGORIES/val', null,
              'http://www.openlinksw.com/schemas/ICS#ATTENDEE', 'IMC-VEVENT/ATTENDEE/val', null,
              'http://www.openlinksw.com/schemas/ICS#ORGANIZER', 'IMC-VEVENT/ORGANIZER/val', null );
          }
          else if ((length (diritems) = 1) and (xpath_eval('count (IMC-VTODO)', diritm) > 0))
          {
            metas := vector (
              'http://www.openlinksw.com/schemas/ICS#SUMMARY', 'IMC-VTODO/SUMMARY/val', null,
              'http://www.openlinksw.com/schemas/ICS#LOCATION', 'IMC-VTODO/LOCATION/val', null,
              'http://www.openlinksw.com/schemas/ICS#CATEGORIES', 'IMC-VTODO/CATEGORIES/val', null,
              'http://www.openlinksw.com/schemas/ICS#ATTENDEE', 'IMC-VTODO/ATTENDEE/val', null,
              'http://www.openlinksw.com/schemas/ICS#ORGANIZER', 'IMC-VTODO/ORGANIZER/val', null);
          }
          else
          {
--            metas := vector (
--              'http://www.openlinksw.com/schemas/ICS#ORGANIZER', 'IMC-VEVENT/ORGANIZER/val', null );
            metas := vector (
              'http://www.openlinksw.com/schemas/ICS#SUMMARY', 'IMC-VEVENT/SUMMARY/val', null );

          }
        }
      else
        metas := vector ();

      extras := vector ();

      return "DAV_EXTRACT_RDF_BY_METAS" (diritm, metas, extras);

      len := length (metas);

      for (ctr := 0; ctr < len; ctr := ctr + 2)
        {
          declare vals varchar;
          vals := xquery_eval (metas [ctr + 1], diritm, 0);
          --dbg_obj_princ ('Prop ', ctr/2, ' of ', len/2, ': ', metas [ctr + 1], vals);

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
  --dbg_obj_princ('Result: ', xml_tree_doc (res));
  return xml_tree_doc (res);
}
;

-- /* meta data extractor */
create function "DAV_EXTRACT_RDF_BY_METAS" (inout doc any, inout metas any, inout extras any)
{
  -- dbg_obj_princ ('DAV_EXTRACT_RDF_BY_METAS" (', doc, ')');
  declare res any;
  declare ctr, len integer;

  xte_nodebld_init (res);
  whenever sqlstate '*' goto final;
  len := length (metas);
  for (ctr := 0; ctr < len; ctr := ctr + 3)
    {
      declare vals varchar;
      vals := xquery_eval (metas [ctr + 1], doc, 0);
      --dbg_obj_princ ('DAV_EXTRACT_RDF_BY_METAS: values for ', metas [ctr + 1], ' are ', vals);
      if (length (vals) = 0)
        {
          vals := metas [ctr + 2];
          if (vals is not null)
            vals := vector (vals);
        }
      foreach (any val in vals) do
      {
        --dbg_obj_princ('val: ', replace(cast (val as varchar), '?', '_') );
        xte_nodebld_acc (res,
          xte_node (
            xte_head (UNAME'N3', UNAME'N3S', 'http://local.virt/this', UNAME'N3P', metas [ctr]),
            replace(cast (val as varchar), '?', '_') ) );
      }
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
    return NULL;

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

--!AWK PUBLIC
create procedure DB.DBA.XML_UNIX_DATE_TO_ISO (in unixdt integer)
{
  declare ts any;
  if (not isinteger (unixdt))
    return '';
  ts := dateadd ('second', unixdt, stringdate ('1970-1-1'));
  ts := dt_set_tz (ts, 0);
  return soap_print_box (ts, '', 0);
}
;

insert soft DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME)
       VALUES ('http://www.openlinksw.com/xsltext/:unixTime2ISO', 'DB.DBA.XML_UNIX_DATE_TO_ISO')
;

xpf_extension ('http://www.openlinksw.com/xsltext/:unixTime2ISO', 'DB.DBA.XML_UNIX_DATE_TO_ISO', 0)
;

create procedure DAV_EXTRACT_META_AS_RDF_XML (
  in resname varchar,
  in rescontent any := null)
{
  -- dbg_obj_princ ('DAV_EXTRACT_META_AS_RDF_XML ()');
  declare res_type_uri, restype varchar;
  declare html_start, type_tree any;
  declare addon_n3, spotlight_addon_n3, ret any;

  if (rescontent is null)
    rescontent := XML_URI_GET (resname, '');
  html_start := null;
  spotlight_addon_n3 := null;
  addon_n3 := null;
  restype := DAV_GUESS_MIME_TYPE (resname, rescontent, html_start);
  if (restype is not null)
    {
      declare exit handler for sqlstate '*'
        {
          goto addon_n3_set;
        };
      addon_n3 := call ('DB.DBA.DAV_EXTRACT_RDF_' || restype)(resname, rescontent, html_start);
      res_type_uri := DAV_GET_RES_TYPE_URI_BY_MIME_TYPE(restype);
      if (res_type_uri is not null)
	{
	  type_tree := xtree_doc ('<N3 N3S="http://local.virt/this" N3P="http://www.w3.org/1999/02/22-rdf-syntax-ns#type" N3O="' || res_type_uri || '"/>' );
	  addon_n3 := DAV_RDF_MERGE (addon_n3, type_tree, null, 0);
	}
addon_n3_set: ;
    }
  if (__proc_exists ('SPOTLIGHT_METADATA', 2) is not null)
    spotlight_addon_n3 := DAV_EXTRACT_SPOTLIGHT (resname, rescontent);

  if (addon_n3 is null and spotlight_addon_n3 is null)
    goto no_op;

no_old:
  if (spotlight_addon_n3 is not null)
    {
      if (addon_n3 is not null)
        addon_n3 := DAV_RDF_MERGE (addon_n3, spotlight_addon_n3, null, 0);
      else
        addon_n3 := spotlight_addon_n3;
    }
  ret := xslt ('http://local.virt/davxml2rdfxml', addon_n3, vector ('this-real-uri', resname));
  if (xpath_eval ('count(/RDF/*)', ret) = 0)
    goto no_op;
  ret := serialize_to_UTF8_xml (ret);
  -- FIXME: use a rules in the xslt above instead of string replace
  ret := replace (ret, 'http://local.virt/this', resname);
  return ret;
no_op:
  return NULL;
}
;
