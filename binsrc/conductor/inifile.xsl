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
<xsl:template match="/">
<v:page name="inifile_editor_page" decor="yacutia_decor.vspx" style="yacutia_style.xsl" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:vm="http://www.openlinksw.com/vspx/macro">
  <vm:pagetitle>Virtuoso System Parameters</vm:pagetitle>
  <vm:pagewrapper>
    <vm:variables>
      <v:variable persist="1" name="inifile_array" type="any" default="null"/>
      <v:variable persist="1" name="xml_source_tree" type="varchar" default="null"/>
      <v:variable persist="1" name="Database_array" type="any" default="null"/>
      <v:variable persist="1" name="Parameters_array" type="any" default="null"/>
      <v:variable persist="1" name="HTTPServer_array" type="any" default="null"/>
      <v:variable persist="1" name="Autorepair_array" type="any" default="null"/>
      <v:variable persist="1" name="Client_array" type="any" default="null"/>
      <v:variable persist="1" name="Vdb_array" type="any" default="null"/>
      <v:variable persist="1" name="Replication_array" type="any" default="null"/>
      <v:variable persist="1" name="load_from_mode" type="varchar" default="'3'"/>
      <v:variable persist="1" name="load_from_type" type="varchar" default="'text'"/>
      <v:variable persist="1" name="load_from_file" type="varchar" default="null"/>
      <v:variable persist="1" name="error_message" type="varchar" default="null"/>
    </vm:variables>
  <vm:menu>
    <vm:menuitem  value="Initial parameters"/>
<!--    <vm:menuitem name="database_url" value="Database" ref="case  get_keyword('page', control.vc_page.vc_event.ve_params) when 'Database' then   '#'  else 'inifile.vspx?page=Database'  end"/>
    <vm:menuitem name="engine_url" value="Engine" ref="case  get_keyword('page', control.vc_page.vc_event.ve_params) when 'Parameters' then   '#'  else 'inifile.vspx?page=Parameters'  end"/>
    <vm:menuitem name="http_url" value="HTTP Server" ref="case  get_keyword('page', control.vc_page.vc_event.ve_params) when 'HTTPServer' then   '#'  else 'inifile.vspx?page=HTTPServer'  end"/>
    <vm:menuitem name="autorepair_url" value="Autorepair" ref="case  get_keyword('page', control.vc_page.vc_event.ve_params) when 'Autorepair' then   '#'  else 'inifile.vspx?page=Autorepair'  end" />
    <vm:menuitem name="client_url" value="Client"   ref="case  get_keyword('page', control.vc_page.vc_event.ve_params) when 'Client' then   '#'  else 'inifile.vspx?page=Client'  end"/>
    <vm:menuitem name="vdb_url" value="VDB" ref="case  get_keyword('page', control.vc_page.vc_event.ve_params) when 'Vdb' then   '#'  else 'inifile.vspx?page=Vdb'  end" />
    <vm:menuitem name="repl_url" value="Replication"  ref="case  get_keyword('page', control.vc_page.vc_event.ve_params) when 'Replication' then   '#'  else 'inifile.vspx?page=Replication'  end"/>
--> </vm:menu>
  <vm:header caption="Virtuoso server initial parameters">
      <vm:raw>
      <td class="AttentionText">(changes will not take effect until next restart)</td>
      </vm:raw>

  </vm:header>
    <vm:pagebody>
      <table width="100%" border="0" cellspacing="3" cellpadding="5" class="MainData" xmlns:v="http://www.openlinksw.com/vspx/" xmlns:xhtml="http://www.w3.org/1999/xhtml">

   <v:template name="editor_template" type="simple" condition="(get_keyword('mode', control.vc_page.vc_event.ve_params) is null ) ">
    <v:before-data-bind>
        <v:script><![CDATA[ -- here we need to check the file type (xml/text - by its content analysis)
            if (self.load_from_type ='xml') {
          	    self.xml_source_tree := null;
             	     if (self.load_from_mode='1') {
	           	   self.xml_source_tree := file_to_string (self.load_from_file);
		     } else if (self.load_from_mode='2') {
		            if ( exists(select 1 from WS.WS.SYS_DAV_RES  where RES_FULL_PATH = self.load_from_file) ) {
       			       declare xml_file varchar;
			              select blob_to_string (RES_CONTENT) into xml_file from WS.WS.SYS_DAV_RES where RES_FULL_PATH = self.load_from_file;
		       	       self.xml_source_tree := xml_file;
		           }
	          }
           }
	      if (self.load_from_mode = '3') {
		        self.load_from_file := virtuoso_ini_path();
		        self.load_from_type := 'text';
	      }

           if ( get_keyword('mode', control.vc_page.vc_event.ve_params) is null  and get_keyword('what', control.vc_page.vc_event.ve_params) is null ) {
                      declare file_name_to_read_from  varchar;
	               declare var, load_type  varchar;
                 	  declare datavector any;
            		   declare  parameter varchar;
	               file_name_to_read_from := self.load_from_file;
	               load_type :=  self.load_from_type;
         ]]>
         <xsl:apply-templates select="inifile/section" mode="load_values"/>
         <![CDATA[
         }
         ]]>
         </v:script>
    </v:before-data-bind>

   <tr>
    <td class="SubInfo" colspan="3">
    <?vsp
      if (self.load_from_mode = '1') {
        http(sprintf('Editing %s. %s format', self.load_from_file, self.load_from_type));
      } else if (self.load_from_mode = '2') {
        http(sprintf('Editing %s. %s format', self.load_from_file,self.load_from_type));
      } else if (self.load_from_mode = '3') {
        -- self.load_from_file := concat(virtuoso_ini_path());
        http(sprintf('Current DB configuration in %s', virtuoso_ini_path()));
      }
    ?>
    </td>
   </tr>

   <!--  ]]><xsl:apply-templates select="inifile/section" mode="post"/><![CDATA[ -->

  <v:form name="inifile_editor_page_form" type="simple"  method="POST" action="">
    <input type="hidden" name="what" value="post"/>
    <input type="hidden" name="page" value="<?= get_keyword ('page', self.vc_page.vc_event.ve_params) ?>"/>

          <v:on-post>
            <v:script>
              <![CDATA[
                declare comp vspx_field;
               declare temp  vspx_template;
               declare section_array, inifile_array   any;
               declare section_name,  param_name , param_value  varchar;
      if (get_keyword('load', params) is not null) {
                  http_request_status ('HTTP/1.1 302 Found');
          http_header (sprintf('Location: inifile.vspx?mode=load&section=%s&sid=%s&realm=%s\r\n',get_keyword('page', params), self.sid ,self.realm));
          return;
      }
               inifile_array := vector();
               inifile_array := vector_concat(inifile_array , vector('Database', self.Database_array));
               inifile_array := vector_concat(inifile_array , vector('Parameters', self.Parameters_array));
               inifile_array := vector_concat(inifile_array , vector('HTTPServer', self.HTTPServer_array));
               inifile_array := vector_concat(inifile_array , vector('Autorepair', self.Autorepair_array));
               inifile_array := vector_concat(inifile_array , vector('Client', self.Client_array));
               inifile_array := vector_concat(inifile_array , vector('Vdb', self.Vdb_array));
               inifile_array := vector_concat(inifile_array , vector('Replication', self.Replication_array));

                -- here done
                 self.inifile_array := inifile_array;

      if (get_keyword('saveas', params) is not null) {
                  http_request_status ('HTTP/1.1 302 Found');
          http_header (sprintf('Location: inifile.vspx?mode=saveas&section=%s&sid=%s&realm=%s\r\n',get_keyword('page', params), self.sid ,self.realm));
          return;
      }
      if (get_keyword('save', params) is not null) {
                  http_request_status ('HTTP/1.1 302 Found');
          http_header (sprintf('Location: inifile.vspx?mode=save&section=%s&sid=%s&realm=%s\r\n',get_keyword('page', params), self.sid ,self.realm));
          return;
      }
      if (get_keyword('revert', params) is not null) {
                  http_request_status ('HTTP/1.1 302 Found');
          http_header (sprintf('Location: inifile.vspx?page=%s&sid=%s&realm=%s\r\n',get_keyword('page', params), self.sid ,self.realm));
          return;
      }

              ]]>
            </v:script>
          </v:on-post>
        <tr valign='top'>
            <td>
                <table cellpadding='10' cellspacing='0' border='0' width='100%'>
                    <tr>
                        <td>
                            <table cellpadding="0" cellspacing="0" border="0">
                                <colgroup>
                                <col/>
                                <col/>
                                <col/>
                                <col/>
                                <col/>
                                </colgroup>
                            <tr>
           <v:template name="tabTemplate1" type="simple" condition="( get_keyword('page', control.vc_page.vc_event.ve_params) ='Database' )">
                                <td class="tabSelected" align="center"><nobr>&nbsp;&nbsp;Database&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url12" value="--'Engine'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Parameters\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url13" value="--'HTTP Server'" format="%s" url="--'#'" xhtml_class="uddi"  xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'HTTPServer\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url14" value="--'Autorepair'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Autorepair\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url15" value="--'Client'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Client\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url16" value="--'Vdb'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Vdb\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url17" value="--'Replication'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Replication\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                <td class="tabEmpty" align="center" width="100%"><table cellpadding="0" cellspacing="0"><tr><td width="100%" ></td></tr></table></td>
                               </v:template>
           <v:template name="tabTemplate2" type="simple" condition="( get_keyword('page', control.vc_page.vc_event.ve_params) ='Parameters' )">
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url21" value="--'Database'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Database\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tabSelected" align="center"><nobr>&nbsp;&nbsp;Engine&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url23" value="--'HTTP Server'" format="%s" url="--'#'" xhtml_class="uddi"  xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'HTTPServer\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url24" value="--'Autorepair'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Autorepair\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url25" value="--'Client'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Client\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url26" value="--'Vdb'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Vdb\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url27" value="--'Replication'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Replication\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                <td class="tabEmpty" align="center" width="100%"><table cellpadding="0" cellspacing="0"><tr><td width="100%" ></td></tr></table></td>
                               </v:template>
           <v:template name="tabTemplate3" type="simple" condition="( get_keyword('page', control.vc_page.vc_event.ve_params) ='HTTPServer' )">
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url31" value="--'Database'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Database\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url32" value="--'Engine'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Parameters\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tabSelected" align="center"><nobr>&nbsp;&nbsp;HTTP Server&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url34" value="--'Autorepair'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Autorepair\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url35" value="--'Client'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Client\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url36" value="--'Vdb'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Vdb\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url37" value="--'Replication'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Replication\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                <td class="tabEmpty" align="center" width="100%"><table cellpadding="0" cellspacing="0"><tr><td width="100%" ></td></tr></table></td>
                               </v:template>
           <v:template name="tabTemplate4" type="simple" condition="( get_keyword('page', control.vc_page.vc_event.ve_params) ='Autorepair' )">
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url41" value="--'Database'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Database\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url42" value="--'Engine'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Parameters\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url43" value="--'HTTP Server'" format="%s" url="--'#'" xhtml_class="uddi"  xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'HTTPServer\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tabSelected" align="center"><nobr>&nbsp;&nbsp;Autorepair&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url45" value="--'Client'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Client\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url46" value="--'Vdb'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Vdb\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url47" value="--'Replication'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Replication\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                <td class="tabEmpty" align="center" width="100%"><table cellpadding="0" cellspacing="0"><tr><td width="100%" ></td></tr></table></td>
                               </v:template>
           <v:template name="tabTemplate5" type="simple" condition="( get_keyword('page', control.vc_page.vc_event.ve_params) ='Client' )">
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url51" value="--'Database'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Database\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url52" value="--'Engine'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Parameters\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url53" value="--'HTTP Server'" format="%s" url="--'#'" xhtml_class="uddi"  xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'HTTPServer\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url54" value="--'Autorepair'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Autorepair\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tabSelected" align="center"><nobr>&nbsp;&nbsp;Client&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url56" value="--'Vdb'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Vdb\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url57" value="--'Replication'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Replication\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                <td class="tabEmpty" align="center" width="100%"><table cellpadding="0" cellspacing="0"><tr><td width="100%" ></td></tr></table></td>
                               </v:template>
           <v:template name="tabTemplate6" type="simple" condition="( get_keyword('page', control.vc_page.vc_event.ve_params) ='Vdb' )">
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url61" value="--'Database'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Database\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url62" value="--'Engine'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Parameters\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url63" value="--'HTTP Server'" format="%s" url="--'#'" xhtml_class="uddi"  xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'HTTPServer\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url64" value="--'Autorepair'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Autorepair\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url65" value="--'Client'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Client\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tabSelected" align="center"><nobr>&nbsp;&nbsp;Vdb&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url67" value="--'Replication'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Replication\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                <td class="tabEmpty" align="center" width="100%"><table cellpadding="0" cellspacing="0"><tr><td width="100%" ></td></tr></table></td>
                               </v:template>
           <v:template name="tabTemplate7" type="simple" condition="( get_keyword('page', control.vc_page.vc_event.ve_params) ='Replication' )">
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url71" value="--'Database'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Database\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url72" value="--'Engine'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Parameters\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url73" value="--'HTTP Server'" format="%s" url="--'#'" xhtml_class="uddi"  xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'HTTPServer\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url74" value="--'Autorepair'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Autorepair\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url75" value="--'Client'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Client\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tab" align="center"><nobr>&nbsp;&nbsp;<v:url name="b_url76" value="--'Vdb'" format="%s" url="--'#'" xhtml_class="uddi" xhtml_onClick="javascript: doPostValue (\'inifile_editor_page_form\', \'softSubmit\',\'Vdb\'); return false"/>&nbsp;&nbsp;</nobr></td>
                                 <td class="tabSelected" align="center"><nobr>&nbsp;&nbsp;Replication&nbsp;&nbsp;</nobr></td>
                                <td class="tabEmpty" align="center" width="100%"><table cellpadding="0" cellspacing="0"><tr><td width="100%" ></td></tr></table></td>
                               </v:template>

                            </tr>
                  </table>

                <table cellpadding="10" cellspacing="0" width="100%" class="tabPage">

        <xsl:apply-templates select="inifile/section" mode="controls"/>
      </table>
          </td>
           </tr>
    <!--table border="0"-->
      <tr><td colspan="3" align="center">

        <v:button  action="submit" name="load" value="Load" xhtml_style="width:100"/>
        <v:button  action="submit" name="save" value="Save" xhtml_style="width:100" />
        <v:button  action="submit" name="saveas" value="Save As" xhtml_style="width:100"/>
        <v:button  action="submit" name="revert" value="Revert" xhtml_style="width:100"/>

      </td></tr>
    <!--/table-->


           </table>
           </td>
           </tr>
  </v:form>

  </v:template>
   <v:template name="redirect_template" type="simple" condition="(get_keyword('mode', control.vc_page.vc_event.ve_params) is null  and get_keyword('softSubmit', control.vc_page.vc_event.ve_params) is not null ) ">
    <v:after-data-bind>
        <v:script><![CDATA[ -- here we need to assign the file name to be loaded from  and check the file type (xml/text be its contnt analysis)
        if (get_keyword('softSubmit', params) is not null) {
                  http_request_status ('HTTP/1.1 302 Found');
          http_header (sprintf('Location: inifile.vspx?what=redirect&page=%s&sid=%s&realm=%s\r\n', get_keyword('softSubmit', params), self.sid ,self.realm));
          return;
        }

         ]]></v:script>
    </v:after-data-bind>
  </v:template>



   <v:template name="load_template" type="simple" condition="(get_keyword('mode', control.vc_page.vc_event.ve_params) ='load')">
    <v:form name="inifile_load_form" type="simple"  method="POST" action="">
    <input type="hidden" name="section" value="<?= get_keyword ('section', self.vc_page.vc_event.ve_params) ?>"/>

          <v:on-post>
            <v:script>
              <![CDATA[ {
                  declare  xpath_result, from_mode, from_file  varchar;
                  if (get_keyword('go_load', params) is not null) {
                    from_mode :=  get_keyword('load_src', params);
                       if (from_mode ='1') {
			            declare xml_file varchar;
			            declare xml_tree any;
		                   from_file :=  get_keyword('file_src', params);
	                        if ( file_stat (from_file, 1) = 0)  {
				              self.error_message:= sprintf(' from the server file system. Local file  %s does not exist.',from_file);
				               http_request_status ('HTTP/1.1 302 Found');
				              http_header (sprintf('Location: inifile.vspx?mode=error&what=load&section=%s&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
				              return;
	                        }

            {
              declare exit handler for sqlstate '*'
                {
                  if (cfg_item_value (from_file  ,'Database' ,'DatabaseFile' ) is not null)  {
                    self.load_from_file :=  from_file;
                              self.load_from_mode := from_mode;
                    self.load_from_type:= 'text';
                            http_request_status ('HTTP/1.1 302 Found');
                    http_header (sprintf('Location: inifile.vspx?page=%s&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
                    return;
                  } else  {
                    self.error_message:= sprintf(' from the server file system. Local file %s has  no valid  ini file format.',from_file);
                            http_request_status ('HTTP/1.1 302 Found');
                    http_header (sprintf('Location: inifile.vspx?mode=error&what=load&section=%s&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
                    return;
                  }
                };
                  xml_tree := xtree_doc (file_to_string (from_file));
            }

            {
              declare exit handler for sqlstate '*'
                {
                  self.error_message:= sprintf(' from the local file system. Local file %s has  no valid  either ini file or xml format.',from_file);
                          http_request_status ('HTTP/1.1 302 Found');
                  http_header (sprintf('Location: inifile.vspx?mode=error&what=load&section=%s&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
                  return;
                };
                  xpath_result:= cast ( xpath_eval('/inifile/section/@name',xml_tree) as varchar);
            }
              self.load_from_file :=  from_file;
                        self.load_from_mode := from_mode;
              if (  xpath_result  is not null  )
                self.load_from_type := 'xml';
               else
                self.load_from_type:= 'text';



           } else if (from_mode ='2' ) { -- DAV
            declare xml_file varchar;
            declare xml_tree any;
            from_file :=  get_keyword('dav_src', params);
             if ( not exists(select 1 from WS.WS.SYS_DAV_RES  where RES_FULL_PATH = from_file) ) {
              self.error_message:= sprintf(' from dav. DAV resource %s does not exist.',from_file);
                      http_request_status ('HTTP/1.1 302 Found');
              http_header (sprintf('Location: inifile.vspx?mode=error&what=load&section=%s&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
              return;
             }

            select blob_to_string (RES_CONTENT) into xml_file from WS.WS.SYS_DAV_RES where RES_FULL_PATH = from_file;
            {
              declare exit handler for sqlstate '*'
                {
                    self.error_message:= sprintf(' from dav. DAV resource %s has  no valid  xml  format.', from_file);

                            http_request_status ('HTTP/1.1 302 Found');
                    http_header (sprintf('Location: inifile.vspx?mode=error&what=load&section=%s&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
                    return;
                };

                xml_tree := xtree_doc (xml_file );

            }

            {
              declare exit handler for sqlstate '*'
                {

                  self.error_message:= sprintf(' from dav. DAV resource %s has  no valid  xml format.',from_file);

                          http_request_status ('HTTP/1.1 302 Found');
                  http_header (sprintf('Location: inifile.vspx?mode=error&what=load&section=%s&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
                  return;
                };
                  xpath_result:= cast ( xpath_eval('/inifile/section/@name',xml_tree) as varchar);

            }
            if (xpath_result  is not null  )  {
                self.load_from_file :=  from_file;
                        self.load_from_mode := from_mode;
                self.load_from_type := 'xml';
             } else {
                  self.error_message:= sprintf(' from dav. DAV resource %s has  no valid  xml format.',from_file);
                          http_request_status ('HTTP/1.1 302 Found');
                  http_header (sprintf('Location: inifile.vspx?mode=error&what=load&section=%s&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
                  return;
            }
                         } else if (from_mode ='3') {
                      self.load_from_mode := from_mode;
                          self.load_from_type:= 'text';
                     }
                 }
            http_request_status ('HTTP/1.1 302 Found');
        http_header (sprintf('Location: inifile.vspx?page=%s&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
        return;
              } ]]>
            </v:script>
          </v:on-post>

    <tr><td align="center">
    <table border="1"  bordercolor="black" cellspacing="0" cellpadding="3"  rules="groups" >
    <caption class="SubInfo">Source to load from</caption>
    <tr>
      <td><v:radio-button name="load_src_1" value="1"  group-name="load_src" initial-checked="0"/>  </td>
      <td class="SubInfo" >Local File</td>
      <td >
<table border="0" cellpadding="1" cellspacing="0">
         <tr><td><v:text name="file_src" xhtml:size="40"/></td>
          <td><v:browse-button name="file_path_src" xhtml_style="width:80" action="browse" selector="/vspx/browser/dav_browser.vsp" child-window-options="resizable=yes, status=no, menubar=no, scrollbars=no, width=640, height=400" value="Browse..." browser-type="os" browser-mode="RES" browser-xfer="DOM" browser-list="1" browser-current="1" browser-filter="*">
              <v:field type="PATH" name="file_src"/>
          </v:browse-button></td>
        </tr>
        </table>

      </td>
    </tr>
    <tr>
      <td><v:radio-button name="load_src_2" value="2"  group-name="load_src" initial-checked="0"/>  </td>
      <td  class="SubInfo">DAV Repository</td>
      <td ><table border="0" cellpadding="1" cellspacing="0">
         <tr><td><v:text name="dav_src" xhtml:size="40"/></td>
          <td><v:browse-button name="dav_path" xhtml_style="width:80" action="browse" selector="/vspx/browser/dav_browser.vsp" child-window-options="resizable=yes, status=no, menubar=no, scrollbars=no, width=640, height=400" value="Browse..." browser-type="dav" browser-mode="RES" browser-xfer="DOM" browser-list="1" browser-current="1" browser-filter="*">
              <v:field type="PATH" name="dav_src"/>
          </v:browse-button></td>
        </tr>
        </table>
      </td>
    </tr>
    <tr>
      <td><v:radio-button  name="load_src_3" value="3"  group-name="load_src" initial-checked="1"/>  </td>
      <td  class="SubInfo" colspan="2">Current Inifile Configuration</td>
    </tr>
    </table></td></tr>

    <tr><td align="center">
      <v:button  action="submit" name="load_cancel" value="Cancel" xhtml_style="width:100"/>
      <v:button  action="submit" name="go_load" value="Load" xhtml_style="width:100"/>
    </td>
    </tr>

    </v:form>
  </v:template>

   <v:template name="saveas_template" type="simple" condition="(get_keyword('mode', control.vc_page.vc_event.ve_params) ='saveas'  )">
    <v:form name="inifile_saveas_form" type="simple"  method="POST" action="">
    <input type="hidden" name="section" value="<?= get_keyword ('section', self.vc_page.vc_event.ve_params) ?>"/>
    <input type="hidden" name="mode" value="<?= get_keyword ('mode', self.vc_page.vc_event.ve_params) ?>"/>
    <input type="hidden" name="page" value="<?= get_keyword ('page', self.vc_page.vc_event.ve_params) ?>"/>

          <v:on-post>
            <v:script>
              <![CDATA[
                    if ( get_keyword('go_saveas', params) is not null) {
                      declare cnt, i, parcnt, par_i integer;
                      declare pars, tmp_vec any;
                      declare txt_file, xml_file, section_buf, par_buf, tmp_buf, file_type varchar;
                      cnt := length (self.inifile_array);
                      i := 0;
                      xml_file := '';
                      txt_file := '';
                      file_type  := get_keyword('save_type', params);
                      if (file_type = '1')
                        self.load_from_type:='text';
                      else
                         self.load_from_type:='xml';
                      while (i < cnt) {
                        declare section_name, parameter_name, parameter_value varchar;
                        section_name := aref(self.inifile_array, i);
                        txt_file := concat(txt_file, '[',section_name,']\n');
                        section_buf := '<section name="';
                        section_buf := concat(section_buf,  section_name) ;
                        section_buf := concat(section_buf,'">\n');
                        pars := aref(self.inifile_array, i +1);

                        parcnt := length(pars);
                         par_i := 0;
                         par_buf := '';
                         while (parcnt > par_i) {
                          parameter_name := aref(pars, par_i);
                          if (aref(pars, par_i +1) = 0) {
                            parameter_value := aref(pars, par_i +2);
                          } else if (aref(pars, par_i +1) = 1) {
                            declare n, num integer;

                            tmp_vec := aref(pars, par_i +2);
                            num :=  length(tmp_vec);

                            n := 0;
                            tmp_buf := '';
                            while (n < num) {
                              if (aref(tmp_vec, n + 1) =1) {
                      if (length(tmp_buf) > 0)
                        tmp_buf := concat(tmp_buf , ', ');
                      tmp_buf := concat(tmp_buf  , aref(tmp_vec, n ));
                              }
                              n := n + 2;
                            }
                            parameter_value := tmp_buf;
                          }
                          txt_file := concat(txt_file, parameter_name , '=' ,parameter_value, '\n');

                          par_buf := concat(par_buf, '\t<parameter name="');
                        par_buf := concat(par_buf, parameter_name ,'" value="') ;
                          par_buf := concat(par_buf, parameter_value , '"/>\n');
                          par_i := par_i  +3;
                         }
                        txt_file := concat(txt_file, '\n');


                         section_buf := concat(section_buf,par_buf);
                        section_buf := concat(section_buf,'</section>\n');
                        xml_file := concat(xml_file, section_buf);
                        i := i +2;
                      }
                      if (  get_keyword('save_dst', params) = '1') {
                        declare file_name varchar;
                        self.load_from_mode :='1';
                        file_name := get_keyword('file_dst', params);
                        self.load_from_file := file_name;
                        if (file_name is not null and file_name <> '') {
                          if (self.load_from_type='text')
                            string_to_file( file_name , txt_file ,-2);
                          else
                  string_to_file( file_name , concat('<inifile>',xml_file,'</inifile>')  ,-2);
              }
                      }  else if (  get_keyword('save_dst', params) = '2') {
                        declare file_name varchar;
                        self.load_from_mode :='2';
                        file_name := get_keyword('dav_dst', params);
                        self.load_from_file := file_name;
                        if (file_name is not null and file_name <> '') {
                          if (self.load_from_type='text')
                            DAV_RES_UPLOAD (file_name , txt_file , 'text/xml','111000001R', 'dav', 'dav','dav','dav');
                          else
                              DAV_RES_UPLOAD (file_name , concat('<inifile>',xml_file,'</inifile>') , 'text/xml','111000001R', 'dav', 'dav','dav','dav');
                          }
                       } else if (  get_keyword('save_dst', params) = '3') {
                        self.load_from_mode :='3';
                        self.load_from_type:='text';
                        string_to_file( concat(virtuoso_ini_path()) , txt_file ,-2);
                       }
                    http_request_status ('HTTP/1.1 302 Found');
            http_header (sprintf('Location: inifile.vspx?page=%s&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
            return;
                    } else  if ( get_keyword('save_cancel', params) is not null) {
                    http_request_status ('HTTP/1.1 302 Found');
            http_header (sprintf('Location: inifile.vspx?page=%s&what=redirect&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
            return;
                    }


              ]]>
            </v:script>
          </v:on-post>
    <tr><td align="center">
    <table border="1"  bordercolor="black" cellspacing="0" cellpadding="3"  rules="groups" >
    <caption class="SubInfo">Destination to save as</caption>
    <tr><td colspan="3">
      <table border="0" width="100%">
        <tr><td class="SubInfo"><nobr>Type of file</nobr></td>
        <td><v:radio-button name="save_type_1" value="1"  group-name="save_type" initial-checked="1"/> </td><td class="SubInfo">text</td>
        <td><v:radio-button name="save_type_2" value="2"  group-name="save_type" initial-checked="0"/> </td><td class="SubInfo">xml</td>
        </tr>
      </table>
    </td></tr>
    <tr>
      <td><v:radio-button name="save_dst_1" value="1"  group-name="save_dst" initial-checked="0"/>  </td>
      <td class="SubInfo">Local File</td>
      <td ><table border="0" cellpadding="1" cellspacing="0">
         <tr><td><v:text name="file_dst" xhtml:size="40"/></td>
          <td><v:browse-button name="file_path_dst" xhtml_style="width:80" action="browse" selector="/vspx/browser/dav_browser.vsp" child-window-options="resizable=yes, status=no, menubar=no, scrollbars=no, width=640, height=400" value="Browse..." browser-type="os" browser-mode="RES" browser-xfer="DOM" browser-list="1" browser-current="1" browser-filter="*">
              <v:field type="PATH" name="file_dst"/>
          </v:browse-button></td>
        </tr>
        </table></td>
    </tr>
    <tr>
      <td><v:radio-button name="save_dst_2" value="2"  group-name="save_dst" initial-checked="0"/>  </td>
      <td  class="SubInfo">DAV Repository</td>
      <td ><table border="0" cellpadding="1" cellspacing="0">
         <tr><td><v:text name="dav_dst" xhtml:size="40"/></td>
          <td><v:browse-button name="dav_path_dst" xhtml_style="width:80" action="browse" selector="/vspx/browser/dav_browser.vsp" child-window-options="resizable=yes, status=no, menubar=no, scrollbars=no, width=640, height=400" value="Browse..." browser-type="dav" browser-mode="RES" browser-xfer="DOM" browser-list="1" browser-current="1" browser-filter="*">
              <v:field type="PATH" name="dav_dst"/>
          </v:browse-button></td>
        </tr>
        </table>
      </td>
    </tr>
    <tr>
      <td><v:radio-button  name="load_dst_3" value="3"  group-name="save_dst" initial-checked="1"/></td>
      <td  class="SubInfo" colspan="2">Current Inifile Configuration
    <?vsp
        http(sprintf(' %s', virtuoso_ini_path()));
    ?>
      </td>
    </tr>
    </table></td></tr>

    <tr><td align="center">
      <v:button  action="submit" name="save_cancel" value="Cancel" xhtml_style="width:100"/>
      <v:button  action="submit" name="go_saveas" value="Save" xhtml_style="width:100"/>
    </td>
    </tr>

    </v:form>
  </v:template>

   <v:template name="save_template" type="simple" condition="(get_keyword('mode', control.vc_page.vc_event.ve_params) ='save'  )">
    <v:form name="inifile_save_form" type="simple"  method="POST" action="">
    <input type="hidden" name="section" value="<?= get_keyword ('section', self.vc_page.vc_event.ve_params) ?>"/>
    <input type="hidden" name="mode" value="<?= get_keyword ('mode', self.vc_page.vc_event.ve_params) ?>"/>
          <v:on-post>
            <v:script>
              <![CDATA[
                    if ( get_keyword('go_save', params) is not null) {
                      declare cnt, i, parcnt, par_i integer;
                      declare pars, tmp_vec any;
                      declare txt_file, xml_file, section_buf, par_buf, tmp_buf, file_type varchar;
                      cnt := length (self.inifile_array);
                      i := 0;
                      xml_file := '';
                      txt_file := '';
                      while (i < cnt) {
                        declare section_name, parameter_name, parameter_value varchar;
                        section_name := aref(self.inifile_array, i);
                        txt_file := concat(txt_file, '[',section_name,']\n');
                        section_buf := '<section name="';
                        section_buf := concat(section_buf,  section_name) ;
                        section_buf := concat(section_buf,'">\n');
                        pars := aref(self.inifile_array, i +1);
                        parcnt := length(pars);

                         par_i := 0;
                         par_buf := '';
                         while (parcnt > par_i) {
                          parameter_name := aref(pars, par_i);
                          if (aref(pars, par_i +1) = 0) {
                            parameter_value := aref(pars, par_i +2);

                          } else if (aref(pars, par_i +1) = 1) {
                            declare n, num integer;

                            tmp_vec := aref(pars, par_i +2);

                            num :=  length(tmp_vec);

                            n := 0;

                            tmp_buf := '';
                            while (n < num) {
                              if (aref(tmp_vec, n + 1) =1) {
		                      if (length(tmp_buf) > 0)
             		          		 tmp_buf := concat(tmp_buf , ', ');
		                      tmp_buf := concat(tmp_buf  , aref(tmp_vec, n ));
                              }
                              n := n + 2;
                            }
                            parameter_value := tmp_buf;
                          }
                          txt_file := concat(txt_file, parameter_name , '=' ,parameter_value, '\n');

                          par_buf := concat(par_buf, '\t<parameter name="');
                        par_buf := concat(par_buf, parameter_name ,'" value="') ;
                          par_buf := concat(par_buf, parameter_value , '"/>\n');
                          par_i := par_i  +3;
                         }
                        txt_file := concat(txt_file, '\n');


                         section_buf := concat(section_buf,par_buf);

                        section_buf := concat(section_buf,'</section>\n');

                        xml_file := concat(xml_file, section_buf);
                        i := i +2;
                      }

                      if (  self.load_from_mode ='1') {
                        declare file_name varchar;
                        file_name :=  self.load_from_file;

                        if (file_name is not null and file_name <> '') {
                          if (self.load_from_type='text')
                            string_to_file( file_name , txt_file ,-2);
                          else
                  string_to_file( file_name , concat('<inifile>',xml_file,'</inifile>')  ,-2);
              }
                      }  else if (  self.load_from_mode ='2') {
                        declare file_name varchar;
                        file_name := self.load_from_file;

                        if (file_name is not null and file_name <> '') {
                          if (self.load_from_type='text')
                            DAV_RES_UPLOAD (file_name , txt_file , 'text/xml','111000001R', 'dav', 'dav','dav','dav');
                          else
                              DAV_RES_UPLOAD (file_name , concat('<inifile>',xml_file,'</inifile>') , 'text/xml','111000001R', 'dav', 'dav','dav','dav');
                          }
                       } else if (   self.load_from_mode = '3') {
                        self.load_from_type:='text';
                        string_to_file( concat(virtuoso_ini_path()) , txt_file ,-2);
                       }
                    http_request_status ('HTTP/1.1 302 Found');
            http_header (sprintf('Location: inifile.vspx?section=%s&mode=result&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
            return;
                    } else  if ( get_keyword('tosave_cancel', params) is not null) {
                    http_request_status ('HTTP/1.1 302 Found');
            http_header (sprintf('Location: inifile.vspx?page=%s&what=redirect&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
            return;
                    }


              ]]>
            </v:script>
          </v:on-post>
    <tr><td align="center">
    <?vsp
        http(sprintf('Parameters would be stored into %s file.', self.load_from_file));
    ?>
    </td></tr>

    <tr><td align="center">
      <v:button  action="submit" name="tosave_cancel" value="Cancel" xhtml_style="width:100"/>
      <v:button  action="submit" name="go_save" value="Save" xhtml_style="width:100"/>
    </td>
    </tr>

    </v:form>
  </v:template>
<!-- Result message dialog-->
   <v:template name="result_message_template" type="simple" condition="(get_keyword('mode', control.vc_page.vc_event.ve_params) ='result'  )">
    <v:form name="inifile_result_form" type="simple"  method="POST" action="">
    <input type="hidden" name="section" value="<?= get_keyword ('section', self.vc_page.vc_event.ve_params) ?>"/>
    <input type="hidden" name="mode" value="<?= get_keyword ('mode', self.vc_page.vc_event.ve_params) ?>"/>
          <v:on-post>
            <v:script>
              <![CDATA[  {
                    http_request_status ('HTTP/1.1 302 Found');
            http_header (sprintf('Location: inifile.vspx?page=%s&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
            return;
                    }
              ]]>
            </v:script>
          </v:on-post>
    <tr><td align="center">
    <?vsp
        http(sprintf('Parameters have been stored  into %s file with %s format.', self.load_from_file, self.load_from_type ));
    ?>
    </td></tr>

    <tr><td align="center">
      <v:button  action="submit" name="apply" value="OK" xhtml_style="width:100"/>
    </td>
    </tr>

    </v:form>
  </v:template>

<!-- Error message dialog-->
   <v:template name="error_message_template" type="simple" condition="(get_keyword('mode', control.vc_page.vc_event.ve_params) ='error'  )">
    <v:form name="inifile_error_form" type="simple"  method="POST" action="">
    <input type="hidden" name="section" value="<?= get_keyword ('section', self.vc_page.vc_event.ve_params) ?>"/>
    <input type="hidden" name="mode" value="<?= get_keyword ('mode', self.vc_page.vc_event.ve_params) ?>"/>
          <v:on-post>
            <v:script>
              <![CDATA[  {
                    http_request_status ('HTTP/1.1 302 Found');
            http_header (sprintf('Location: inifile.vspx?page=%s&sid=%s&realm=%s\r\n',get_keyword('section', params), self.sid ,self.realm));
            return;
                    }
              ]]>
            </v:script>
          </v:on-post>
    <tr><td align="center">
    <?vsp
      if (get_keyword ('what', self.vc_page.vc_event.ve_params) ='save' )
        http(sprintf('Parameters have not been stored into %s file with %s format.', self.load_from_file, self.load_from_type ));
      else if ( get_keyword ('what', self.vc_page.vc_event.ve_params) = 'load') {
        http(sprintf('File with parameters cannot be loaded %s', self.error_message ));
      }

    ?>
    </td></tr>

    <tr><td align="center">
      <v:button  action="submit" name="go_back" value="Return" xhtml_style="width:100"/>
    </td>
    </tr>

    </v:form>
  </v:template>



      </table>

    </vm:pagebody>
  </vm:pagewrapper>
</v:page>
</xsl:template>

<xsl:template match="section" mode="load_values">
    <xsl:apply-templates select="*" mode="load_values"/>
</xsl:template>


<xsl:template match="parameter" mode="load_values">
<xsl:variable name="section_name" select="../@name"/>
<xsl:variable name="parname" select="@name"/>
<xsl:variable name="default" select="@default"/>

              <![CDATA[

              ]]>
<xsl:choose>
  <xsl:when test="control[@type='text']">
         <![CDATA[
                    var := null;
		      parameter := ']]><xsl:value-of select="$parname"/><![CDATA[';

                   if (load_type ='text')
		                    var := cfg_item_value (file_name_to_read_from  ,']]><xsl:value-of select="$section_name"/><![CDATA[' ,']]><xsl:value-of select="$parname"/><![CDATA[' );
                   else if (self.xml_source_tree is not null) {
                           var := cast ( xpath_eval('/inifile/section[@name='']]><xsl:value-of select="$section_name"/><![CDATA['']/parameter[@name='']]><xsl:value-of select="$parname"/><![CDATA['']/@value',xtree_doc (self.xml_source_tree)) as varchar);
                   }

                    if (var is null or ( var is not null and  length(var) = 0) ) {
                          var := ']]><xsl:value-of select="$default"/><![CDATA[';
                    }

                   datavector := self.]]><xsl:value-of select="$section_name"/><![CDATA[_array;
                   if ( datavector is null) {
	                    datavector := vector(parameter, 0 ,var);
                   } else { -- now search own parameter and  designate its value
       	             declare i, par_found, len integer;
             		       declare parname varchar;
                    	i := 0;
	                    par_found :=0;
       	             len := length(datavector);
             		      while (i < len) {
		                      parname := aref(datavector, i);
		                      if (parname = parameter and (par_found = 0))  {
             				           aset(datavector, i +2, var);
			                        par_found := 1;
		                      }
             			         i := i +3;
	                   }
                          if (par_found = 0) {
                                       datavector := vector_concat(datavector , vector(parameter, 0 ,var) );
                         }
                   }
                   self.]]><xsl:value-of select="$section_name"/><![CDATA[_array := datavector ;
         ]]>
  </xsl:when>
  <xsl:when test="control[@type='radio']">
         <![CDATA[  {
                  var := null;
                   if (load_type ='text')
		                    var := cfg_item_value (file_name_to_read_from  ,']]><xsl:value-of select="$section_name"/><![CDATA[' ,']]><xsl:value-of select="$parname"/><![CDATA[' );
                   else if (self.xml_source_tree is not null) {
                           var := cast ( xpath_eval('/inifile/section[@name='']]><xsl:value-of select="$section_name"/><![CDATA['']/parameter[@name='']]><xsl:value-of select="$parname"/><![CDATA['']/@value',xtree_doc (self.xml_source_tree)) as varchar);
                   }

                    if (var is null or ( var is not null and  length(var) = 0) )
                          var := ']]><xsl:value-of select="$default"/><![CDATA[';

		      parameter := ']]><xsl:value-of select="$parname"/><![CDATA[';

       	        datavector := self.]]><xsl:value-of select="$section_name"/><![CDATA[_array;
             		 if ( datavector is null) {
                    		 datavector := vector(parameter, 0, var);
	              } else { -- now search own parameter and  designate its value
       		               declare i, par_found, len integer;
                    		  declare parname varchar;
		                      i := 0;
             			         par_found :=0;
		                      len := length(datavector);
		                      while (i < len) {
			                       parname := aref(datavector, i);
			                        if (parname = parameter and (par_found = 0))  {
				                          aset(datavector, i +2, var);
			       	                   par_found := 1;
		                    	    }
			                        i := i +3;
		                      }
             			         if (par_found = 0) {
			                        datavector := vector_concat(datavector , vector(parameter, 0,var) );
		                      }
                      }
                      self.]]><xsl:value-of select="$section_name"/><![CDATA[_array := datavector ;
}         ]]>
   </xsl:when>
  <xsl:when test="control[@type='checkbox']">
         <![CDATA[   {
                     declare cur, prev, pos, check_items_len  integer;
                     declare  tmp varchar;
                     declare check_items any;
                     check_items := vector();
                     check_items_len := 0;
		      parameter := ']]><xsl:value-of select="$parname"/><![CDATA[';
                      var := null;
                   if (load_type ='text')
		                    var := cfg_item_value (file_name_to_read_from  ,']]><xsl:value-of select="$section_name"/><![CDATA[' ,']]><xsl:value-of select="$parname"/><![CDATA[' );
                   else if (self.xml_source_tree is not null) {
                           var := cast ( xpath_eval('/inifile/section[@name='']]><xsl:value-of select="$section_name"/><![CDATA['']/parameter[@name='']]><xsl:value-of select="$parname"/><![CDATA['']/@value',xtree_doc (self.xml_source_tree)) as varchar);
                   }
                    if (var is null or ( var is not null and  length(var) = 0) )
                            var := ']]><xsl:value-of select="$default"/><![CDATA[';

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
			                  check_items := vector_concat(check_items, vector(tmp) );
             			  }
             			  check_items_len := length(check_items);
                    }

         ]]>
  <xsl:for-each select="control/row">
     <xsl:for-each select="item">
         <![CDATA[   {

                  declare  value varchar;
                  declare is_checked, pos  integer;
   		     parameter := ']]><xsl:value-of select="$parname"/><![CDATA[';
                  value:= ']]><xsl:value-of select="@value"/><![CDATA[';
                  is_checked := 0;
                  pos := 0;
                  while (pos < check_items_len and is_checked = 0) {
                  		if (value = aref  ( check_items, pos ) )
                  			is_checked := 1;
                  		pos := pos +1;
                  }
                       datavector := self.]]><xsl:value-of select="$section_name"/><![CDATA[_array;
                       if ( datavector is null) {
                    	    datavector := vector(parameter, 1,  vector(value, is_checked ) );
                       } else { -- now search own parameter and  designate its value
       	                   declare i, par_found, len integer;
	                          declare parname varchar;
             		            i := 0;
		                   par_found :=0;
	                         len := length(datavector);
	                        while (i < len) {
	                            parname := aref(datavector, i);
	                            if (parname = parameter and (par_found = 0) and aref(datavector, i+1) = 1 )  {
		                            declare tmp_array any;
             			               declare  n, num, a_found  integer;
		                            par_found := 1;
		                            tmp_array := aref(datavector, i +2);
		                            num := length(tmp_array);
		                            a_found :=0;
		                            n:=0;
		                            while (n < num) {
		                       	     if (value = aref(tmp_array, n) and (a_found = 0) ) {
			                                aset(tmp_array, n +1, is_checked);
			                                a_found := 1;
		                              }
		                              n := n +2;
		                           }
		                            if (a_found = 0) {
             				                 tmp_array := vector_concat(tmp_array, vector(value, is_checked));
		                            }
		                            aset(datavector, i +2, tmp_array);
	                           }
	                            i := i +3;
       	                 }
                              if (par_found = 0) {
                                      datavector := vector_concat(datavector , vector(parameter, 1,  vector(value,  is_checked)) );
                              }
                      }
                      self.]]><xsl:value-of select="$section_name"/><![CDATA[_array := datavector ;
}         ]]>
    </xsl:for-each>
   </xsl:for-each>
<![CDATA[
}
 ]]>
  </xsl:when>
  <xsl:when test="control[@type='textarea']">
         <![CDATA[
                    var := null;
		      parameter := ']]><xsl:value-of select="$parname"/><![CDATA[';
                   if (load_type ='text')
		                    var := cfg_item_value (file_name_to_read_from  ,']]><xsl:value-of select="$section_name"/><![CDATA[' ,']]><xsl:value-of select="$parname"/><![CDATA[' );
                   else if (self.xml_source_tree is not null) {
                           var := cast ( xpath_eval('/inifile/section[@name='']]><xsl:value-of select="$section_name"/><![CDATA['']/parameter[@name='']]><xsl:value-of select="$parname"/><![CDATA['']/@value',xtree_doc (self.xml_source_tree)) as varchar);
                   }
                    if (var is null or ( var is not null and  length(var) = 0) ) {
                          var := ']]><xsl:value-of select="$default"/><![CDATA[';
                    }

                   datavector := self.]]><xsl:value-of select="$section_name"/><![CDATA[_array;
                   if ( datavector is null) {
	                    datavector := vector(parameter, 0 ,var);
                   } else { -- now search own parameter and  designate its value
       	             declare i, par_found, len integer;
             		       declare parname varchar;
                    	i := 0;
	                    par_found :=0;
       	             len := length(datavector);
             		      while (i < len) {
		                      parname := aref(datavector, i);
		                      if (parname = parameter and (par_found = 0))  {
             				           aset(datavector, i +2, var);
			                        par_found := 1;
		                      }
             			         i := i +3;
	                   }
                          if (par_found = 0) {
                                       datavector := vector_concat(datavector , vector(parameter, 0 ,var) );
                         }
                   }
                   self.]]><xsl:value-of select="$section_name"/><![CDATA[_array := datavector ;
         ]]>
  </xsl:when>
</xsl:choose>
</xsl:template>


<xsl:template match="section" mode="controls">
<xsl:variable name="section_name" select="@name"/>
   <v:template name="{concat('section_template_',@name)}" type="simple" condition="{concat('( (get_keyword(\'mode\', control.vc_page.vc_event.ve_params) is null) and  get_keyword(\'page\', control.vc_page.vc_event.ve_params) =\'',@name,'\')')}">
    <xsl:apply-templates select="*" mode="controls"/>
  </v:template>
</xsl:template>


<xsl:template match="parameter" mode="controls">
<xsl:variable name="section_name" select="../@name"/>
<xsl:variable name="parname" select="@name"/>
<xsl:variable name="default" select="@default"/>
<xsl:variable name="required" select="@required"/>
<tr>
  <td>
  <xsl:value-of select="label"/>
  <xsl:if test="@required ='Yes'">
  <span class="AttentionText">*</span>
  </xsl:if>
  <![CDATA[
  <?vsp
    {
                 declare var  varchar;
                 if (get_keyword('mode', control.vc_page.vc_event.ve_params)  is null) {
                  var := cfg_item_value (concat(virtuoso_ini_path()) ,']]><xsl:value-of select="$section_name"/><![CDATA[' ,']]><xsl:value-of select="$parname"/><![CDATA[' );
         if (var is null or ( var is not null and  length(var) = 0) )
                   http('<span class="AttentionText">(default)</span>');
      }
    }
  ?>]]>
  </td>
<td  class="SubInfo" colspan="1">
<xsl:choose>
  <xsl:when test="control[@type='text']">
  <v:text name="{concat($section_name,'_' ,$parname)}" default_value= "{$default}" xhtml_style="width:200;">
  <xsl:for-each select="control/validator">
  <v:validator name="{concat($section_name,'_' ,$parname,'_val',position())}" min="{@min}" max="{@max}"  empty-allowed="{number(boolean($required!='Yes'))}" test="{@test}" regexp="{@regexp}" message="{@message}"/>
  </xsl:for-each>
          <v:before-data-bind>
            <v:script>
              <![CDATA[
                  if (get_keyword('page', params) <> ']]><xsl:value-of select="$section_name"/><![CDATA[') {
                    control.vc_enabled := 0;
                  }

              ]]>
            </v:script>
          </v:before-data-bind>

          <v:after-data-bind>
            <v:script>
              <![CDATA[
         {
                 declare datavector any;
	            declare controlname, parameter varchar;
      			controlname := ']]><xsl:value-of select="{concat($section_name,'_' ,$parname)}"/><![CDATA[';
		      parameter := ']]><xsl:value-of select="$parname"/><![CDATA[';
             if (self.vc_event.ve_is_post=0 ) {
              -- if (get_keyword('what',params) is not null )  { -- here we are when WHAT is not null - to load the values from the array;
                    declare i, par_found, len integer;
                    declare parname varchar;
                  datavector := self.]]><xsl:value-of select="$section_name"/><![CDATA[_array;
                    i := 0;
                    par_found :=0;
                    len := length(datavector);
                    while (i < len) {
                      parname := aref(datavector, i);
                      if (parname = parameter and (par_found = 0))  {
                        control.ufl_value := aref(datavector, i +2 );
                        control.vc_data_bound := 1;
                        par_found := 1;
                      }
                      i := i +3;
                    }
              -- }

             } else  if (get_keyword(controlname,params) is not null ) {
                   control.ufl_value := get_keyword(controlname,params);
                   control.vc_data_bound := 1;
                   datavector := self.]]><xsl:value-of select="$section_name"/><![CDATA[_array;
                   if ( datavector is null) {
                    	datavector := vector(parameter, control.ufl_value);
                   } else { -- now search own parameter and  designate its value
	                    declare i, par_found, len integer;
       	             declare parname varchar;
             		       i := 0;
	                    par_found :=0;
       	             len := length(datavector);
	                    while (i < len) {
       		               parname := aref(datavector, i);
		                      if (parname = parameter and (par_found = 0))  {
			                        aset(datavector, i +2, control.ufl_value);
			                        par_found := 1;
		                      }
             			         i := i +3;
	                    }
       	             if (par_found = 0) {
             			         datavector := vector_concat(datavector , vector(parameter, 0,control.ufl_value) );
	                    }
           	    }
                  self.]]><xsl:value-of select="$section_name"/><![CDATA[_array := datavector ;
                  if (get_keyword('page', params) = ']]><xsl:value-of select="$section_name"/><![CDATA[') {
                    control.vc_enabled := 1;
                  }
           }
      }
              ]]>
            </v:script>
          </v:after-data-bind>
  </v:text>
  </xsl:when>

  <xsl:when test="control[@type='radio']">
  <table>
  <xsl:for-each select="control/row">
  <xsl:variable name="rowpos" select="position()"/>
  <tr>
     <xsl:for-each select="item">
       <td>
      <v:radio-button name="{concat($section_name,'_' ,$parname,'_',$rowpos,'_',position())}"  group-name="{$parname}"  value="{@value}">
              <v:after-data-bind>
                <v:script>
                  <![CDATA[   {
                 declare datavector any;
	            declare controlname, parameter varchar;
		      controlname := ']]><xsl:value-of select="{concat($section_name,'_' ,$parname)}"/><![CDATA[';
		      parameter := ']]><xsl:value-of select="$parname"/><![CDATA[';
                 if (self.vc_event.ve_is_post=0 ) {
                   -- if (get_keyword('what',params) is not null ) { -- here we are when WHAT is not null - to load the values from the array;
	                    declare i, par_found, len integer;
       	             declare parname varchar;
             		     datavector := self.]]><xsl:value-of select="$section_name"/><![CDATA[_array;
	                    i := 0;
       	             par_found :=0;
             		       len := length(datavector);
	                    while (i < len) {
       		               parname := aref(datavector, i);
		                      if (parname = parameter and (par_found = 0))  {
		       	                 if ( control.ufl_value = aref(datavector, i +2 ) )
             					             control.ufl_selected:= 1;
			                        else
       	      				             control.ufl_selected:= 0;

		                    	    control.vc_data_bound := 1;
		             		           par_found := 1;
             			         }
		                      i := i +3;
	                    }
                --}
           } else  if (get_keyword(']]><xsl:value-of select="$parname"/><![CDATA[',params) is not null ) {
	           if (control.ufl_value = get_keyword(']]><xsl:value-of select="$parname"/><![CDATA[', params)  ) {
       	                control.ufl_selected:= 1;
             			   datavector := self.]]><xsl:value-of select="$section_name"/><![CDATA[_array;
		                   if ( datavector is null) {
             				       datavector := vector(parameter, control.ufl_value);
		                   } else { -- now search own parameter and  designate its value
			                    declare i, par_found, len integer;
			                    declare parname varchar;
			                    i := 0;
			                    par_found :=0;
			                    len := length(datavector);
			                    while (i < len) {
				                      parname := aref(datavector, i);
				                      if (parname = parameter and (par_found = 0))  {
					                        aset(datavector, i +2, control.ufl_value);
					                        par_found := 1;
				                      }
				                      i := i +3;
			                    }
			                    if (par_found = 0) {
				                      datavector := vector_concat(datavector , vector(parameter, 0,control.ufl_value) );
			                    }
		                }
		               self.]]><xsl:value-of select="$section_name"/><![CDATA[_array := datavector ;
	          }   else {
       	              control.ufl_selected:= 0;
		    }
               control.vc_data_bound := 1;
           }
            if (get_keyword('page', params) = ']]><xsl:value-of select="$section_name"/><![CDATA[') {
                    control.vc_enabled := 1;
            }
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
    <v:check-box name="{concat($section_name,'_' ,$parname,'_',$rowpos,'_',position())}" group-name="{$parname}" value="{@value}">
              <v:after-data-bind>
                <v:script>
                  <![CDATA[   {
                          declare datavector any;
		            declare controlname, parameter, value  varchar;
			      controlname := ']]><xsl:value-of select="{concat($section_name,'_' ,$parname)}"/><![CDATA[';
			      parameter := ']]><xsl:value-of select="$parname"/><![CDATA[';
	                  value:= ']]><xsl:value-of select="@value"/><![CDATA[';

	                 control.ufl_selected:= 0;

                     if (self.vc_event.ve_is_post=0) {
	                     --  if ( get_keyword('what', params) is not null )  {  -- here we are when WHAT is not null - to load the values from the array;
       		                 declare i, par_found, len integer;
		                        declare parname varchar;
		                      datavector := self.]]><xsl:value-of select="$section_name"/><![CDATA[_array;
             			           i := 0;
		                        par_found :=0;
		                        len := length(datavector);
		                        while (i < len) {
			                          parname := aref(datavector, i);
			                          if (parname = parameter and (par_found = 0))  {
				                            declare tmp_array any;
				                            declare  n, num, a_found  integer;
				                            par_found := 1;
				                            tmp_array := aref(datavector, i +2);
				                            num := length(tmp_array);
				                            a_found :=0;
				                            n:=0;
				                            while (n < num) {
					                              if (control.ufl_value = aref(tmp_array, n)) {
						                                control.ufl_selected := aref(tmp_array, n +1);
						                                control.vc_data_bound := 1;
					                              }
					                              n := n +2;
				                            }
			                          }
                    			      i := i +3;
		                       }
                        -- }
                     } else  if (get_keyword('page', params) =']]><xsl:value-of select="$section_name"/><![CDATA[' ) {
	                        declare len, pos  integer;
	                        declare var varchar;
       	                 len := length(params);
             		           pos := 0;
		                 control.ufl_selected:= 0;
             		           var := ']]><xsl:value-of select="$parname"/><![CDATA[';
			           while(pos < len ) {
			                   if (aref(params, pos) = var and  aref(params,pos + 1) = value   ) {
				                    control.ufl_selected:= 1;
			                            control.vc_data_bound := 1;
			                  }
			                   pos:= pos+2;
			            }
	                        -- now to put parameter it into array
                       		datavector := self.]]><xsl:value-of select="$section_name"/><![CDATA[_array;
	                       if ( datavector is null) {
        		                datavector := vector(parameter, 1,  vector(control.ufl_value, control.ufl_selected) );
                    	   } else { -- now search own parameter and  designate its value
		                          declare i, par_found, len integer;
		                          declare parname varchar;
		                          i := 0;
		                        par_found :=0;
		                        len := length(datavector);
		                        while (i < len) {
		                            parname := aref(datavector, i);
		                            if (parname = parameter and (par_found = 0))  {
			                            declare tmp_array any;
			                            declare  n, num, a_found  integer;
			                            par_found := 1;
			                            tmp_array := aref(datavector, i +2);
			                            num := length(tmp_array);
			                            a_found :=0;
			                            n:=0;
			                            while (n < num) {
				                              if (control.ufl_value = aref(tmp_array, n) and (a_found = 0) ) {
					                                aset(tmp_array, n +1, control.ufl_selected);
					                                a_found := 1;
				                              }
				                              n := n +2;
			                            }
                    			        if (a_found = 0) {
				                              tmp_array := vector_concat(tmp_array, vector(control.ufl_value, control.ufl_selected));
			                            }
                    			        aset(datavector, i +2, tmp_array);
		                          }
             			             i := i +3;
	                        }
       	                 if (par_found = 0) {
             		             datavector := vector_concat(datavector , vector(parameter, 1,  vector(control.ufl_value, control.ufl_selected)) );
	                        }
                      }
                       self.]]><xsl:value-of select="$section_name"/><![CDATA[_array := datavector ;
                  }

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
  <v:textarea name="{concat($section_name,'_' ,$parname)}" default_value= "{$default}" xhtml_style="width:200;">
          <v:before-data-bind>
            <v:script>
              <![CDATA[
                  if (get_keyword('page', params) <> ']]><xsl:value-of select="$section_name"/><![CDATA[') {
                    control.vc_enabled := 0;
                  }

              ]]>
            </v:script>
          </v:before-data-bind>

          <v:after-data-bind>
            <v:script>
              <![CDATA[
              {
                 declare datavector any;
	            declare controlname, parameter varchar;
      			controlname := ']]><xsl:value-of select="{concat($section_name,'_' ,$parname)}"/><![CDATA[';
		      parameter := ']]><xsl:value-of select="$parname"/><![CDATA[';
             if (self.vc_event.ve_is_post=0 ) {
              -- if (get_keyword('what',params) is not null )  { -- here we are when WHAT is not null - to load the values from the array;
                    declare i, par_found, len integer;
                    declare parname varchar;
                  datavector := self.]]><xsl:value-of select="$section_name"/><![CDATA[_array;
                    i := 0;
                    par_found :=0;
                    len := length(datavector);
                    while (i < len) {
                      parname := aref(datavector, i);
                      if (parname = parameter and (par_found = 0))  {
                        control.ufl_value := aref(datavector, i +2 );
                        control.vc_data_bound := 1;
                        par_found := 1;
                      }
                      i := i +3;
                    }
              -- }

             } else  if (get_keyword(controlname,params) is not null ) {
                   control.ufl_value := get_keyword(controlname,params);
                   control.vc_data_bound := 1;
                   datavector := self.]]><xsl:value-of select="$section_name"/><![CDATA[_array;
                   if ( datavector is null) {
                    	datavector := vector(parameter, control.ufl_value);
                   } else { -- now search own parameter and  designate its value
	                    declare i, par_found, len integer;
       	             declare parname varchar;
             		       i := 0;
	                    par_found :=0;
       	             len := length(datavector);
	                    while (i < len) {
       		               parname := aref(datavector, i);
		                      if (parname = parameter and (par_found = 0))  {
			                        aset(datavector, i +2, control.ufl_value);
			                        par_found := 1;
		                      }
             			         i := i +3;
	                    }
       	             if (par_found = 0) {
             			         datavector := vector_concat(datavector , vector(parameter, 0,control.ufl_value) );
	                    }
           	    }
                  self.]]><xsl:value-of select="$section_name"/><![CDATA[_array := datavector ;
                  if (get_keyword('page', params) = ']]><xsl:value-of select="$section_name"/><![CDATA[') {
                    control.vc_enabled := 1;
                  }
           }

                }
              ]]>
            </v:script>
          </v:after-data-bind>
  </v:textarea>
  </xsl:when>
</xsl:choose>
</td>
<td>
	<xsl:value-of select="unit">
	</xsl:value-of>
</td>
<td class="Attention">
<xsl:value-of select="description">
</xsl:value-of>
</td>
</tr>
</xsl:template>

</xsl:stylesheet>

