<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2014 OpenLink Software
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
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
	        xmlns:v="http://www.openlinksw.com/vspx/"
                xmlns:vm="http://www.openlinksw.com/vspx/weblog/">
  <xsl:template match="vm:nntpf-search">
    <script type="text/javascript"><![CDATA[
    <!--
    function submitenter_local(myfield,e)
    {
      var keycode;
      if (window.event) keycode = window.event.keyCode;
      else if (e) keycode = e.which;
      else return true;

      if (keycode == 13)
        {
          if(document.getElementById('searchkeywords').value.trim()!='')
    {
//            document.location.href='nntpf_addtorss.vspx?sid=<?Vself.sid?>&realm=<?Vself.realm?>&search='+document.getElementById('searchkeywords').value;
            document.location.href='<?V sprintf ('%ssearch.vspx', self.odsbar_ods_gpath) ?>?q='+$('searchkeywords').value+'&ontype=discussion&sid=<?Vself.sid?>&realm=<?Vself.realm?>';
          }
          return false;
        }
      else
       return true;
    }
    //-->
    ]]></script>

    <v:form type="simple" method="POST" name="search">

      <a href="<?V self.odsbar_ods_gpath ?>search.vspx?ontype=discussion&sid=<?Vself.sid?>&realm=<?Vself.realm?>">
        <img src="<?V self.odsbar_ods_gpath ?>images/search.png" style="border:none;  vertical-align: middle;"/>
      </a>

       <v:button style="url" name="nntpf_search_adv" action="submit" value="Search" xhtml_style="display:none;">
         <v:on-post>
           <![CDATA[
             http_request_status ('HTTP/1.1 302 Found');
             http_header (sprintf ('Location: nntpf_addtorss.vspx?sid=%s&realm=%s&search=%V\r\n',
                          self.sid, 
                          self.realm, 
                          get_keyword ('searchkeywords', 
                          self.vc_page.vc_event.ve_params)));
           ]]> 
         </v:on-post>
       </v:button>
       <![CDATA[&nbsp;]]>


      <v:text xhtml_size="10" name="searchkeywords" value="" xhtml_id="searchkeywords" xhtml_class="textbox" xhtml_onkeypress="return submitenter_local(this,event)"/>
      <v:button xhtml_id="search_button" action="simple" value="images/go_16.png" style="image" name="GO" xhtml_title="Search" xhtml_alt="Search" xhtml_style="display:none"/>
      <v:on-post>
        <![CDATA[
          if(e.ve_button.vc_name <> 'GO' or length (trim(self.searchkeywords.ufl_value)) = 0) {
            return;
          }
          self.vc_redirect (sprintf ('nntpf_addtorss.vspx?sid=%s&realm=%s&search=%s',
               self.sid, 
               self.realm, 
                            get_keyword ('searchkeywords',self.vc_page.vc_event.ve_params)));
          return;
        ]]> 
      </v:on-post>
    </v:form>

  </xsl:template>
</xsl:stylesheet>
