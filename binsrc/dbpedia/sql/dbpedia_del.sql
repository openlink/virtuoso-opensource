--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2024 OpenLink Software
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

--
--  Clean up deprecated RULELISTS
--
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULELIST(''dbp_data_rule_list'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULELIST(''dbp_rule_list_2'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULELIST(''dbp_rule_list_3'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULELIST(''dbp_rule_list_7'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULELIST(''dbp_rule_list_category'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULELIST(''dbp_rule_list_owl'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULELIST(''dbp_rule_list_prop'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULELIST(''dbp_rule_list_type'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULELIST(''dbp_wc_rule_list1'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULELIST(''pvsp_rule_data3'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULELIST(''pvsp_rule_data4'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULELIST(''pvsp_rule_data6'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULELIST(''pvsp_rule_list7'', 1)', 0);

--
--  Clean up deprecated URLREWRITE rules
--
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_about_rule_1'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_data_rule0'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_data_rule1'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_data_rule2'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_data_rule3'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_data_rule3-1'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_data_rule3-2'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_data_rule4'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_data_rule5'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_data_rule6'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_data_rule7'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_data_rule8'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_rule_6'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_rule_7'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_rule_12'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_rule_13'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_rule_14'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_rule_18'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_rule_19'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_rule_category12'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_rule_category14'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_wc_rule1'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''dbp_wc_rule2'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''owl_rule_6'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''owl_rule_7'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''owl_rule_18'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''owl_rule_19'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''prop_rule_6'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''prop_rule_7'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''prop_rule_18'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''prop_rule_19'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''pvsp_data3_rule'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''pvsp_data3_rule_2'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''pvsp_data3_rule_3'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''pvsp_data4_rule'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''pvsp_data6_rule'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''pvsp_data_rule7'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''type_rule_6'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''type_rule_7'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''type_rule_18'', 1)', 0);
EXEC_STMT ('DB.DBA.URLREWRITE_DROP_RULE(''type_rule_19'', 1)', 0);


--
--  Clean up deprecated VARIANT maps
--
delete from DB.DBA.HTTP_VARIANT_MAP where VM_RULELIST = 'dbp_rule_list_2';
delete from DB.DBA.HTTP_VARIANT_MAP where VM_RULELIST = 'dbp_rule_list_category';


---
---  Drop old procedures
---
EXEC_STMT ('drop procedure DB.DBA.SPARQL_DESC_DICT_DBPEDIA_PHYSICAL', 0);


--
-- Remove old dbpedia.org:80
--
delete from DB.DBA.HTTP_PATH where HP_HOST = registry_get('dbp_vhost') and HP_LISTEN_HOST = registry_get('dbp_lhost');

--delete from SYS_HTTP_LISTENERS where HL_INTERFACE = registry_get('dbp_lhost');
