--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2019 OpenLink Software
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
create user "XMLA"
;

user_set_qualifier ('XMLA', 'XMLA')
;

VHOST_REMOVE (lpath=>'/XMLA')
;

VHOST_DEFINE (lpath=>'/XMLA', ppath=>'/SOAP/', soap_user=>'XMLA',
              soap_opts => vector ('ServiceName', 'XMLAnalysis', 'elementFormDefault', 'qualified'))
;

grant execute on DB.."Discover" to "XMLA"
;

grant execute on DB.."Execute" to "XMLA"
;

grant select on Demo.demo.Customers to "XMLA"
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
