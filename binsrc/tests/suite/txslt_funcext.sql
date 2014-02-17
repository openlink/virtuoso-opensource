--  
--  $Id: txslt_funcext.sql,v 1.5.10.1 2013/01/02 16:15:37 source Exp $
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
--  
create procedure DB.DBA.STR_CONCAT (in a varchar, in b varchar, in c integer)
{
  return concat (a, ':', b, ':',  sprintf ('%d', c));
};

grant execute on DB.DBA.STR_CONCAT to public;

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:concat_strings', 'DB.DBA.STR_CONCAT');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": XPATH function extension for XSL-T declared : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure xstext ()
{
  declare xsl, xm varchar;
  declare xt, xe, r any;
  xsl := '<?xml version=''1.0''?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl" xmlns:virt="http://www.openlinksw.com/virtuoso/xslt">
  <xsl:template match="/doc/a">
    <HTML>
     <BODY>
     <xsl:if test="function-available(''virt:concat_strings'')">
      <xsl:value-of select="virt:concat_strings (@id, ., @n)"/>
     </xsl:if>
     <xsl:if test="function-available(''virt:not_exists_concat_strings'')">
      <xsl:value-of select="virt:concat_strings (@id, ., @n)"/>
     </xsl:if>
     </BODY>
    </HTML>
  </xsl:template>
</xsl:stylesheet>';
  xm := '<doc><a id="foo" n="12">bar</a></doc>';

  xt := xslt_sheet ('xslt_test_ext', xml_tree_doc (xsl));
  xe := xml_tree_doc (xm);
  r := xslt ('xslt_test_ext', xe);
  declare ses any;
  ses := string_output ();
  http_value (r, null, ses);
  ses := string_output_string(ses);
  if (trim(ses) <> '<HTML><BODY>foo:bar:12</BODY></HTML>')
    signal ('XSLTE', sprintf ('The extension function execution failed. Result retrned: %s', ses));
  return ses;
};

select xstext ();
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": XPATH function extensions for XSL-T : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
