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

-- Sample facet queries


<query> <class iri="http://xmlns.com/foaf/0.1/Person" /><view type="list" limit="10" /></query>


select fct_query (xtree_doc ('
<query> <class iri="http://xmlns.com/foaf/0.1/Person" />
<property iri="foaf:knows"><property iri="foaf:name"><value>"Joe"</value>  </property>
</property>
<view type="list" limit="10" /></query>
 '));

select fct_query (xtree_doc ('
<query> <class iri="http://xmlns.com/foaf/0.1/Person" />
<property iri="foaf:knows"><property iri="foaf:name"><value>"Joe"</value></property>
</property>
<view type="properties" limit="10" /></query>
 '));

select fct_query (xtree_doc ('
<query><text>semantic</text> <view type="text" limit="10" />
</query>'));

select fct_test ('
<query>
  <class iri="http://xmlns.com/foaf/0.1/Person" />
<view type="properties" limit="10" /></query>
 ', 1000);



select fct_query (xtree_doc ('<query><class iri="http://xmlns.com/foaf/0.1/Person"/> <view type="list" limit="10"/></query>'));

select fct_test ('<query> <text>semantic web</text><view type="text" limit="20"/></query>');

select fct_test ('<query> <text>hottie</text><view type="text-properties" limit="20"/></query>');

select fct_test ('<query> <text property="http://purl.org/dc/elements/1.1/description">hottie</text><view type="text" limit="20"/></query>');

select xslt ('file://fct/fct_vsp.xsl',
             xtree_doc ('<facets><result><row><column>http://xyz.com/xyz.htm</column></row></result></facets>'),
             vector ('sid', 2, 'type', 'properties'))

create procedure fct_exp (in str varchar)
{
  declare txt any;
  declare max_s int;
  txt := string_output ();
  	max_s := 0;
  fct_query_info (xpath_eval ('/query', xtree_doc (str)), 0, max_s, 0, 1, txt);
  http_value (xtree_doc ('<test />'), null, txt);
  return string_output_string (txt);
}
;
