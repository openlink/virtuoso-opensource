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
ECHO BOTH "STARTED: SOAP XMLA tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

xslt_sheet ('http://local.virt/xmla_test', xml_tree_doc (
'<?xml version="1.0"?>
<xsl:stylesheet
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:xd="urn:schemas-microsoft-com:xml-analysis:rowset"
		xmlns:sql="urn:schemas-microsoft-com:xml-sql"
		xmlns:xsd="http://www.w3.org/2001/XMLSchema"
		version="1.0" >

	<xsl:output method="text" />

<xsl:template match="/">
<xsl:apply-templates select="//xsd:schema/xsd:complexType[@name=''row'']//xsd:element/@sql:field" /><xsl:text>
</xsl:text>
<xsl:for-each select="//xd:row">
<xsl:apply-templates select="." /><xsl:text>
</xsl:text>
</xsl:for-each>
</xsl:template>

<xsl:template match="xd:row">
<xsl:variable name="varCurrRow" select="." />
<xsl:for-each select="//xsd:schema/xsd:complexType[@name=''row'']//xsd:element"><xsl:variable name="varCurrCol" select="./@name" /><xsl:choose><xsl:when test="\$varCurrRow/*[local-name() = \$varCurrCol]"><xsl:value-of select="\$varCurrRow/*[local-name() = \$varCurrCol]" />,</xsl:when><xsl:otherwise>null,</xsl:otherwise></xsl:choose>
</xsl:for-each>
</xsl:template>
<xsl:template match="@sql:field"><xsl:value-of select="." />,</xsl:template>
</xsl:stylesheet>
'));

--create user "XMLA"
--;

--user_set_qualifier ('XMLA', 'XMLA')
--;

--VHOST_REMOVE (lpath=>'/XMLA')
--;

--VHOST_DEFINE (lpath=>'/XMLA', ppath=>'/SOAP/', soap_user=>'XMLA',
--              soap_opts => vector ('ServiceName', 'XMLAnalysis', 'elementFormDefault', 'qualified'))
--;

grant execute on DB.."Discover" to "XMLA"
;

grant execute on DB.."Execute" to "XMLA"
;

grant execute on DB.DBA."xmla_vdd_dbschema_columns_rpoc" to "XMLA"
;

grant execute on DB.DBA."XMLA_VDD_DBSCHEMA_COLUMNS" to "XMLA"
;

grant all privileges on DB.DBA."XMLA_VDD_DBSCHEMA_COLUMNS" to "XMLA"
;

grant execute on DB.DBA."xmla_vdd_dbschema_tables_rpoc" to "XMLA"
;

grant execute on DB.DBA."XMLA_VDD_DBSCHEMA_TABLES" to "XMLA"
;

grant all privileges on DB.DBA."XMLA_VDD_DBSCHEMA_TABLES" to "XMLA"
;

grant all privileges on DB.DBA."XMLA_VDD_DBSCHEMA_PROVIDER_TYPES" to "XMLA"
;

grant execute on DB.DBA."xmla_vdd_dbschema_provider_types_rpoc" to "XMLA"
;


create procedure
xmla_check_result (in x any)
{
  declare text any;
  declare ses any;
  declare mdta any;
  dbg_obj_print (x);
  x := xml_tree_doc (x);
  x := xslt ('http://local.virt/xslt_copy', x);
  x := xslt ('http://local.virt/xmla_test', x);

  dbg_obj_print (x);

  ses := string_output ();
  http_value (x, null, ses);
  declare res any;
  declare i int;
  while (1)
    {
      declare arr any;
      text := ses_read_line (ses, 0);
      if (not isstring (text))
	{
	  return;
	}
      arr := split_and_decode (trim(text, ', '), 0, '\0\0,');
      if (not i)
        {
          i := 1;
          exec_metadata ('select ' || rtrim(repeat (''''',', length (arr)), ','),null, null, mdta);
	  exec_result_names (mdta[0]);
	}
	  exec_result (arr);
    }
}
;




xmla_check_result (
  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Discover',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Discover',
	 parameters=>
	    vector ('RequestType', 'DISCOVER_DATASOURCES',
	            'Restrictions', null,
		    'Properties', null
	           ), style=>0)
    );
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DISCOVER_DATASOURCES : " $LAST[1] "\n";

xmla_check_result (
  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Discover',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Discover',
	 parameters=>
	    vector ('RequestType', 'DISCOVER_PROPERTIES',
	            'Restrictions', null,
		    'Properties', null
	           ), style=>0)
    );
ECHO BOTH $IF $EQU $LAST[1] 'UserName' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DISCOVER_PROPERTIES : " $LAST[1] "\n";

xmla_check_result (
  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Discover',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Discover',
	 parameters=>
	    vector ('RequestType', 'DISCOVER_SCHEMA_ROWSETS',
	            'Restrictions', null,
		    'Properties', null
	           ), style=>0)
    );
--ECHO BOTH $IF $EQU $LAST[1] 'DISCOVER_LITERALS' "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": DISCOVER_SCHEMA_ROWSETS : " $LAST[1] "\n";


xmla_check_result (
  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Discover',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Discover',
	 parameters=>
	    vector ('RequestType', 'DISCOVER_LITERALS',
	            'Restrictions', null,
		    'Properties', null
	           ), style=>0)
    );
ECHO BOTH $IF $EQU $LAST[1] 'DBLITERAL_QUOTE_SUFFIX' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DISCOVER_LITERALS : " $LAST[1] "\n";


xmla_check_result (
  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Discover',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Discover',
	 parameters=>
	    vector ('RequestType', 'DISCOVER_KEYWORDS',
	            'Restrictions', null,
		    'Properties', null
	           ), style=>0)
    );
ECHO BOTH $IF $EQU $LAST[1] 'XPATH' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DISCOVER_KEYWORDS : " $LAST[1] "\n";

drop table "zzzzz".DBA.TEST1;
create table "zzzzz".DBA.TEST1 (ID integer);

insert into "zzzzz".DBA.TEST1 (ID) values (12345);

grant select on "zzzzz".DBA.TEST1 to XMLA;

xmla_check_result (
  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Discover',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Discover',
	 parameters=>
	    vector ('RequestType', 'DBSCHEMA_CATALOGS',
	            'Restrictions', null,
		    'Properties', null
	           ), style=>0)
    );
ECHO BOTH $IF $EQU $LAST[1] 'zzzzz' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DBSCHEMA_CATALOGS : " $LAST[1] "\n";

xmla_check_result (
  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Discover',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Discover',
	 parameters=>
	    vector ('RequestType', 'DBSCHEMA_TABLES',
	            'Restrictions', soap_box_structure ('RestrictionList' ,
		      soap_box_structure ('TABLE_CATALOG', 'zzzzz')),
		    'Properties',
		    	soap_box_structure ('PropertyList',
			  soap_box_structure ('DataSourceInfo', xmla_service_name (), 'UserName', 'dba', 'Password', 'dba'))
	           ), style=>0)
    );
ECHO BOTH $IF $EQU $LAST[3] 'TEST1' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DBSCHEMA_TABLES : " $LAST[3] "\n";

xmla_check_result (
  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Discover',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Discover',
	 parameters=>
	    vector ('RequestType', 'DBSCHEMA_COLUMNS',
	            'Restrictions', soap_box_structure ('RestrictionList' ,
		      soap_box_structure ('TABLE_CATALOG', 'zzzzz', 'TABLE_NAME', 'TEST1')),
		    'Properties',
		    	soap_box_structure ('PropertyList',
			  soap_box_structure ('DataSourceInfo', xmla_service_name (), 'UserName', 'dba', 'Password', 'dba')
			  )
	           ), style=>0)
    );

xmla_check_result (
  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Discover',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Discover',
	 parameters=>
	    vector ('RequestType', 'DBSCHEMA_COLUMNS',
	            'Restrictions', soap_box_structure ('RestrictionList' , soap_box_structure ('TABLE_CATALOG', 'zzzzz', 'TABLE_NAME', 'TEST1')),
		    'Properties', soap_box_structure ('PropertyList',
			  soap_box_structure ('DataSourceInfo', xmla_service_name (), 'UserName', 'dba', 'Password', 'dba')
		      )
	           ), style=>0)
    );
ECHO BOTH $IF $EQU $LAST[4] 'ID' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DBSCHEMA_COLUMNS : " $LAST[4] "\n";

xmla_check_result (
  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Discover',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Discover',
	 parameters=>
	    vector ('RequestType', 'DBSCHEMA_PROVIDER_TYPES',
	            'Restrictions', soap_box_structure ('RestrictionList' , soap_box_structure ('DATA_TYPE', 129)),
		    'Properties', soap_box_structure ('PropertyList', soap_box_structure ('DataSourceInfo', xmla_service_name ()))
	           ), style=>0)
    );
ECHO BOTH $IF $EQU $LAST[1] 'long varchar' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DBSCHEMA_PROVIDER_TYPES : " $LAST[1] "\n";

xmla_check_result (
  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Discover',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Discover',
	 parameters=>
	    vector ('RequestType', 'DISCOVER_ENUMERATORS',
	            'Restrictions', NULL,
		    'Properties', soap_box_structure ('PropertyList', soap_box_structure ('DataSourceInfo', xmla_service_name ()))
	           ), style=>0)
    );
ECHO BOTH $IF $EQU $LAST[1] 'MDXSupportLevel' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DISCOVER_ENUMERATORS : " $LAST[1] "\n";

  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Discover',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Discover',
	 parameters=>
	    vector ('RequestType', 'DISCOVER_FAKE',
	            'Restrictions', NULL,
		    'Properties', soap_box_structure ('PropertyList', soap_box_structure ('DataSourceInfo', xmla_service_name ()))
	           ), style=>0)
    ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BAD DISCOVERY TYPE : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


xmla_check_result (
  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Execute',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Execute',
	 parameters=>
	    vector ('Command', soap_box_structure ('Statement', 'select * from TEST1'),
		    'Properties', soap_box_structure ('PropertyList',
		      soap_box_structure ('DataSourceInfo', xmla_service_name (), 'Catalog', 'zzzzz',
			'UserName', 'dba', 'Password', 'dba'))
	           ), style=>0)
    );
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Execute (count = schema + data) : " $ROWCNT "\n";

ECHO BOTH $IF $EQU $LAST[1] '12345' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Execute (data row) : " $LAST[1] "\n";


--xmla_check_result (
--  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
--	 operation=>'Execute',
--	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
--	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Execute',
--	 parameters=>
--	    vector ('Command', soap_box_structure ('Statement', 'select * from TEST1'),
--		    'Properties', soap_box_structure ('PropertyList',
--		      soap_box_structure ('DataSourceInfo', 'DSN=__local', 'Catalog', 'zzzzz', 'UserName', 'dba', 'Password', 'dba', 'Content', 'Data'))
--	           ), style=>0)
--   );
--ECHO BOTH $IF $EQU $LAST[1] '12345' "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": Execute data only : " $LAST[1] "\n";

xmla_check_result (
  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Execute',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Execute',
	 parameters=>
	    vector ('Command', soap_box_structure ('Statement', 'select * from TEST1'),
		    'Properties', soap_box_structure ('PropertyList',
		      soap_box_structure ('DataSourceInfo', xmla_service_name (), 'Catalog', 'zzzzz', 'UserName', 'dba', 'Password', 'dba', 'Content', 'Schema'))
	           ), style=>0)
    );
ECHO BOTH $IF $EQU $LAST[1] 'ID' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Execute (schema only) : " $LAST[1] "\n";

  soap_client (url=>'http://localhost:$U{HTTPPORT}/XMLA',
	 operation=>'Execute',
	 target_namespace=>'urn:schemas-microsoft-com:xml-analysis',
	 soap_action=>'urn:schemas-microsoft-com:xml-analysis:Execute',
	 parameters=>
	    vector ('Command', soap_box_structure ('Statement', 'select * from TEST1'),
		    'Properties', soap_box_structure ('PropertyList',
		      soap_box_structure ('DataSourceInfo', xmla_service_name (), 'Catalog', '"zzzzz"'))
	           ), style=>0)
    ;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Not authenticated in Execute : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: SOAP XMLA tests\n";
