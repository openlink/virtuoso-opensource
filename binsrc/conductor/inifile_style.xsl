<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2018 OpenLink Software
 -
 -  This project is free software; you can redistribute it and/or modify it
 -  under the terms of the GNU General Public License as published by the
 -  Free Software Foundation; only version 2 of the License, dated June 1991.
 -
 -  This program is distributed in the hope that it will be useful, but
 -  WITHOUT ANY WARRANTY; without even the implied warranty of
 -  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 -  General Public License for more details.
 -
 -  You should have received a copy of the GNU General Public License along
 -  with this program; if not, write to the Free Software Foundation, Inc.,
 -  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 -
 -
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:xhtml="http://www.w3.org/1999/xhtml">
	<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>
<xsl:param name="section_name"/>
<xsl:template match="/">
<v:page name="{concat('inifile_editor_page_', $section_name)}" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:xhtml="http://www.w3.org/1999/xhtml">
<table width="100%" border="0" cellspacing="0" cellpadding="5" class="MainData" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:xhtml="http://www.w3.org/1999/xhtml">
<xsl:apply-templates select="inifile/section[@name=$section_name]"/>
</table>
</v:page>
</xsl:template>

<xsl:template match="section">
	<v:form name="{@name}" type="simple"  method="POST" action="">
          <v:on-post>
            <v:script>
              <![CDATA[
                declare path, rel_path, res_xml, tmp, tmp_value varchar;
                declare tree any;
                declare len, n integer;

		  declare src_xml, src_xslt,res, path  varchar;
		  declare xml_tree,xslt_tree,pars, xml_tree_doc any;
		  declare vspx any;

		  if (self.vc_is_valid = 0 ) return;
 		  rel_path:='/';
 		  len:= length(e.ve_path)-1;
 		  n:=0;
 		  while (n < len) {
 		      rel_path := concat(rel_path,aref(e.ve_path,n),'/');
 		      n:= n+1;
 		  }
                path:= concat(rel_path,'inifile_]]><xsl:value-of select="$section_name"/><![CDATA[.xml');

                len := length(params)-2 ;
                n:=6;
                tmp:= aref(params,n); -- initiate the name
                tmp_value:='';
                res_xml := '<section name="]]><xsl:value-of select="$section_name"/><![CDATA[">';
                while (n < len) {
                  if (tmp = aref(params,n)) {
                    if (length(tmp_value) > 0)
                        tmp_value:= concat(tmp_value,', ');
                    tmp_value:= concat(tmp_value,aref(params,n+1));
                  } else {
	                  res_xml := sprintf('%s<parameter name="%s" value="%s"/>', res_xml,tmp,tmp_value);
       	           tmp:= aref(params,n);
             		     tmp_value:=aref(params,n+1);
                  }
                  n:= n+2;
                }

                res_xml := sprintf('%s</section>',res_xml);
		   string_to_file(concat(http_root(),path),res_xml,-2);



		  xml_tree := xml_tree (file_to_string (concat(get_ini_location(),'inifile.xml')));
		  src_xslt := file_to_string (concat(http_root(),rel_path,'merge.xsl'));
		  xslt_sheet(src_xslt, xml_tree_doc (src_xslt));

		  vspx:=string_output();

		 xml_tree_doc:= xml_tree_doc (xml_tree);
		 pars  := vector('section_name', ']]><xsl:value-of select="$section_name"/><![CDATA[','ext_doc',concat('file:', path));
		 res := xslt (src_xslt, xml_tree_doc,pars);
		http_value(res,0,vspx);

              path:= concat(get_ini_location(),'inifile.xml');
  	       src_xml := file_to_string (path);
		string_to_file(concat(path,'.bak'),src_xml,-2);
		string_to_file(path,string_output_string(vspx),-2);

		  vspx:=string_output();
		http_value(res,0,vspx);


		  src_xslt := file_to_string (concat(http_root(),rel_path,'make.xsl'));
		  xslt_sheet(src_xslt, xml_tree_doc (src_xslt));
		xml_tree_doc:= xml_tree_doc (xml_tree (vspx) );
		  vspx:=string_output();

		 res := xslt (src_xslt, xml_tree_doc);
		http_value(res,0,vspx);
		string_to_file(concat(virtuoso_ini_path(),'__') ,string_output_string(vspx),-2);

              ]]>
            </v:script>
          </v:on-post>

	    <tr>
	      <td class="SubInfo">   	Initialization File Location <span class="AttentionText">*</span>  </td>
	      <td colspan="1">        <v:text name="InitializationFileLocation" />      </td>
	      <td>   </td>
	    </tr>
	    <tr>
	      <td class="SubInfo">   	Read Values From XML File    </td>
	      <td colspan="1">        <v:text name="ReadFromXMLFile" />      </td>
	      <td class="SubInfo" > (overwrites current values)  </td>
	    </tr>

		<xsl:apply-templates select="*" />
		<tr align="center">
			<td colspan="3">
				<input type="button"  action="" name="reset" value="Reset"/>
				<v:button  action="submit" name="save" value="Save"/>
				<v:button  action="submit" name="save_restart" value="Save and Restart Virtuoso"/>
			</td>
		</tr>
	</v:form>
</xsl:template>



<xsl:template match="parameter">
<tr>
	<td class="SubInfo">
	<xsl:value-of select="label"/>
	<xsl:if test="@required ='Yes'">
	<span class="AttentionText">*</span>
	</xsl:if>
	</td>
<td  class="SubInfo" colspan="1">
<xsl:variable name="parname" select="@name"/>
<xsl:variable name="default" select="@default"/>
<xsl:variable name="required" select="@required"/>
<xsl:choose>
	<xsl:when test="control[@type='text']">
	<v:text name="{@name}" value= "{$default}" xhtml:size="32">
	<xsl:for-each select="control/validator">
	<v:validator name="{concat($parname,'_val',position())}" min="{@min}" max="{@max}"  empty-allowed="{number(boolean($required!='Yes'))}" test="{@test}" regexp="{@regexp}" message="{@message}"/>
	</xsl:for-each>
          <v:before-data-bind>
            <v:script>
              <![CDATA[
                declare var,path varchar;
                declare tree any;
                if (get_keyword('save', params) is NULL) {
	                path:= concat(get_ini_location(),'inifile.xml');
		  	   tree := xtree_doc (file_to_string (path));
             		  var := cast ( xpath_eval('/inifile/section[@name='']]><xsl:value-of select="$section_name"/><![CDATA['']/parameter[@name='']]><xsl:value-of select="$parname"/><![CDATA['']/@value',tree) as varchar);
	                control.ufl_value := var;
       	         control.vc_data_bound := 1;
                }
              ]]>
            </v:script>
          </v:before-data-bind>
	</v:text>
	</xsl:when>
	<xsl:when test="control[@type='radio']">
	<table>
	<xsl:for-each select="control/row">
	<xsl:variable name="rowpos" select="position()"/>
	<tr>
	   <xsl:for-each select="item">
	     <td>
			<v:radio-button name="{concat($parname,$rowpos,'_',position())}"  group-name="{$parname}"  value="{@value}">
		          <v:after-data-bind>
		            <v:script>
		              <![CDATA[
			                declare var,path varchar;
			                declare tree any;
			                 if (get_keyword('save', params) is NULL) {

				                path:= concat(get_ini_location(),'inifile.xml');
					  	   tree := xtree_doc (file_to_string (path));
				                var := cast ( xpath_eval('/inifile/section[@name='']]><xsl:value-of select="$section_name"/><![CDATA['']/parameter[@name='']]><xsl:value-of select="$parname"/><![CDATA['']/@value',tree) as varchar);
			       	         if (control.ufl_value = var )
			             		     control.ufl_selected:= 1;
				                 else
				                 control.ufl_selected:= 0;
				                control.vc_data_bound := 1;
				         }
		              ]]>
	            </v:script>
       	   </v:after-data-bind>
		 </v:radio-button>
		 </td><td   nowrap="Yes"  class="SubInfo"><xsl:value-of select="@label"/></td>
		</xsl:for-each>
		</tr>
	</xsl:for-each>
	</table>
	</xsl:when>
	<xsl:when test="control[@type='checkbox']">
	<table>
	<xsl:for-each select="control/row">
	<xsl:variable name="rowpos" select="position()"/>
	<tr>
	   <xsl:for-each select="item">
	     <td class="SubInfo">
		<v:check-box name="{concat($parname,$rowpos,'_',position())}" group-name="{$parname}" value="{@value}">
		          <v:after-data-bind>
		            <v:script>
		              <![CDATA[
			                declare tmp, value, var,path varchar;
			                declare tree any;
			                declare pos, prev, cur  integer;
			                 if (get_keyword('save', params) is NULL) {

			                path:= concat(get_ini_location(),'inifile.xml');
				  	   tree := xtree_doc (file_to_string (path));
			                value:= ']]><xsl:value-of select="@value"/><![CDATA[';
     			                var := cast ( xpath_eval('/inifile/section[@name='']]><xsl:value-of select="$section_name"/><![CDATA['']/parameter[@name='']]><xsl:value-of select="$parname"/><![CDATA['']/@value',tree) as varchar);
				          control.ufl_selected:= 0;
     			                if (length(var) > 0 ) {
						   pos:=1;
						   prev:=1;
						   while (pos > 0) {
						      pos := locate(',', var, pos);
						      if (pos = 0)
						         cur:=  length(var)+1;
						      else {
							      cur:= pos;
							      pos:= pos +1;
							}
						      tmp := trim(substring(var, prev, cur - prev));
						      prev:= pos;
	 			                   if (tmp = value)
						                  control.ufl_selected:= 1;
						   }
			               }
		             		  control.vc_data_bound := 1;
		             		  }
		              ]]>
	            </v:script>
       	   </v:after-data-bind>
		</v:check-box></td><td  nowrap="Yes"  class="SubInfo"><xsl:value-of select="@label"/></td>
		</xsl:for-each>
		</tr>
	</xsl:for-each>
	</table>
	</xsl:when>
	<xsl:when test="control[@type='textarea']">
	<v:textarea name="{@name}"  value="{@name}" xhtml:cols="25"/>
	</xsl:when>
</xsl:choose>
</td>
<td class="Attention">
<xsl:value-of select="description">
</xsl:value-of>
</td>
</tr>
</xsl:template>

</xsl:stylesheet>
<!--
			                res := cast ( xpath_eval('boolean(/inifile/section[@name='']]><xsl:value-of select="$section_name"/><![CDATA['']/parameter[@name='']]><xsl:value-of select="$parname"/><![CDATA['' and @value='']]><xsl:value-of select="@value"/><![CDATA['']/@value)',tree) as integer);
			                res := cast ( xpath_eval('boolean(/inifile/section[@name='']]><xsl:value-of select="$section_name"/><![CDATA['']/parameter[@name='']]><xsl:value-of select="$parname"/><![CDATA['' and @value='']]><xsl:value-of select="@value"/><![CDATA['']/@value)',tree) as integer);

{number($required!='Yes')}
 -->
