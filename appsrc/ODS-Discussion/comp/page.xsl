<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2013 OpenLink Software
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
<!-- simple page widgets -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:v="http://www.openlinksw.com/vspx/"
    xmlns:vm="http://www.openlinksw.com/vspx/weblog/"
    xmlns:ods="http://www.openlinksw.com/vspx/ods/">
    <xsl:template match="vm:page">
      <xsl:call-template name="vars" />
	  <v:on-init><![CDATA[
	   set http_charset='UTF-8';
	{
	  declare exit handler for not found;
	  --select U_FULL_NAME into self.e_title from SYS_USERS where U_ID = http_dav_uid ();
	  --self.e_title := self.e_title || '\'s Discussions';
	  self.e_title := (select top 1 WS_WEB_TITLE from WA_SETTINGS);
	  if (0 = length (self.e_title))
	    self.e_title := sys_stat ('st_host_name');
	  self.e_title := self.e_title || ' Discussions';
	  select WAUI_LAT, WAUI_LNG into self.e_lat, self.e_lng from DB.DBA.WA_USER_INFO where WAUI_U_ID = http_dav_uid ();
	}
        self.host := http_request_header (lines, 'Host');
        
	   ]]></v:on-init>
      <div id="HD">
     <ods:ods-bar app_type='nntpf'/>
      <script type="text/javascript">
       <![CDATA[

function dd(txt){
  if(typeof console == 'object'){
    console.debug(txt);
  }
}
	   ODSInitArray.push(discussionsOatControlsInit);
	   function discussionsOatControlsInit()
	   {
	
	      if (typeof(window.davbrowseInit) == "function")
        {
          OAT.Loader.load(["dav","mswin","macwin"], function(){davbrowseInit()});
        };

	      if (typeof(window.calendarInit) == "function")
        {
          OAT.Loader.load(["calendar"], function(){calendarInit()});
        };

	      if (typeof(window.showTagsDiv) == "function")
        {
          OAT.Loader.load(["ws"], function(){tagsInit()});
        };

      return;

	   }
	   
        ]]>
      </script>
      </div>
      <div id="MD">
      <!--html-->

	<xsl:apply-templates />
        <vm:nntpf-copyright/>
      <!--/html-->
      <?vsp
        declare ht_stat varchar;
        ht_stat := http_request_status_get ();
        if (ht_stat is not null and ht_stat like 'HTTP/1._ 30_ %')
	  {
	    http_rewrite ();
	  }
      ?>
      </div> <!-- MD -->
    </xsl:template>
    <xsl:template match="vm:header">
      <header>
        <v:include url="virtuoso_app_links.xhtml"/>
	<link rel="stylesheet" type="text/css" href="nntpf.css" />
	<link rel="schema.dc" href="http://purl.org/dc/elements/1.1/" />
	<link rel="schema.geo" href="http://www.w3.org/2003/01/geo/wgs84_pos#" />
	<meta name="dc.title" content="<?V db.dba.wa_utf8_to_wide (self.e_title) ?>" />
      <?vsp
        if (self.e_lat is not null and self.e_lng is not null) {
      ?>
	<meta name="geo.position" content="<?V sprintf ('%.06f', self.e_lat) ?>;<?V sprintf ('%.06f', self.e_lng) ?>" />
	<meta name="ICBM" content="<?V sprintf ('%.06f', self.e_lat) ?>, <?V sprintf ('%.06f', self.e_lng) ?>" />
      <?vsp } ?>
      
      
	<xsl:apply-templates />
      </header>
    </xsl:template>
    <xsl:template match="vm:body">
      <body>
	<v:form name="page_form" type="simple" method="POST">
	  <xsl:apply-templates />
	</v:form>
      </body>
    </xsl:template>
    <xsl:template match="vm:js">
    <script type="text/javascript">
      function doPostN (frm_name, name)
        {
          var frm = document.forms[frm_name];
          frm.__submit_func.value = '__submit__';
          frm.__submit_func.name = name;
          frm.submit ();
        }
      function doPostValueN (frm_name, name, value)
	{
	  var frm = document.forms[frm_name];
	  frm.__submit_func.value = value;
	  frm.__submit_func.name = name;
	  frm.action="#1";
	  frm.submit ();
	}
      function doPostValueNT (frm_name, name, value)
	{
	  var frm = document.forms[frm_name];
	  frm.action="nntpf_nthread_view.vspx";
	  frm.group.value = value;
	  frm.submit ();
	}
      function doPostValueT (frm_name, name, value)
	{
	  var frm = document.forms[frm_name];
	  frm.action="nntpf_thread_view.vspx";
	  frm.group.value = value;
	  frm.submit ();
	}
      function doPostValueRSS (frm_name, name, value)
	{
	  var frm = document.forms[frm_name];
	  frm.action="nntpf_rss_group.vspx";
	  frm.group.value = value;
	  frm.submit ();
	}
    </script>
    <noscript>
	   Warning: The browser not support or not enabled JavaScript. Some controls may not work properly.
    </noscript>

    </xsl:template>

    <xsl:template match="head[not (link[@rel='schema.dc'])]">
	<head  profile="http://internetalchemy.org/2003/02/profile">
	    <xsl:apply-templates />
	    <link rel="schema.dc" href="http://purl.org/dc/elements/1.1/" />
	    <xsl:text>&#10;</xsl:text>
	    <link rel="schema.geo" href="http://www.w3.org/2003/01/geo/wgs84_pos#" />
	    <xsl:text>&#10;</xsl:text>
	    <meta name="dc.title" content="<?V db.dba.wa_utf8_to_wide (self.e_title) ?>" />
	    <xsl:text>&#10;</xsl:text>
	    <?vsp
	    if (self.e_lat is not null and self.e_lng is not null) {
	    ?>
	    <meta name="geo.position" content="<?V sprintf ('%.06f', self.e_lat) ?>;<?V sprintf ('%.06f', self.e_lng) ?>" />
	    <xsl:text>&#10;</xsl:text>
	    <meta name="ICBM" content="<?V sprintf ('%.06f', self.e_lat) ?>, <?V sprintf ('%.06f', self.e_lng) ?>" />
	    <xsl:text>&#10;</xsl:text>
	    <?vsp }

	    if ( 1=0 and self.u_name is not null and self.u_name<>'') {

	    ?>
      <link rel="foaf" type="application/rdf+xml" title="FOAF"  
      href="<?V replace (sprintf ('http://%s/dataspace/%U/about.rdf', DB.DBA.WA_GET_HOST(), 'dba'), '+', '%2B')?>" />
      

	    <?vsp }
	    
	    declare _grp_name varchar;
	    _grp_name:=nntpf_get_group_name (get_keyword ('group', params,''));

	    if(length(_grp_name)>0)
	    {
	      ?>
      <link rel="meta" type="application/rdf+xml" title="SIOC" 
      href="<?V replace (sprintf ('%s/dataspace/discussion/%s/sioc.rdf', 'http://'||DB.DBA.WA_GET_HOST(),_grp_name), '+', '%2B') ?>"/>

	    <?vsp
	    }
	    else
	    {
	    ?>
      <link rel="meta" type="application/rdf+xml" title="SIOC" 
      href="<?V replace (sprintf ('%s/dataspace/discussion/sioc.rdf', 'http://'||DB.DBA.WA_GET_HOST()), '+', '%2B') ?>"/>
	    
	    <?vsp
	    }
	    ?>
	</head>
    </xsl:template>

    <xsl:template match="vm:title">
      <title>
	<xsl:apply-templates />
      </title>
    </xsl:template>
    <xsl:template match="vm:search">
	<xsl:apply-templates />
    </xsl:template>
    <xsl:template match="vm:register">
      <vm:template enabled="1">
	<a href="../ods/register.vspx?ret=/nntpf/">Register</a>
      </vm:template>
    </xsl:template>
    <xsl:template match="vm:variable" />
    <xsl:template name="vars">
      <v:variable name="u_id" type="int" default="null" persist="session" />
      <v:variable name="u_name" type="varchar" default="null" persist="session" />
      <v:variable name="u_full_name" type="varchar" default="null" persist="session" />
      <v:variable name="u_e_mail" type="varchar" default="null" persist="session" />
      <v:variable name="search_trm" type="varchar" default="null" persist="session" />
      <v:variable name="url" type="varchar" default="'nntpf_main.vspx'" persist="pagestate" param-name="URL" />
      <v:variable name="users_length" persist="1" type="integer" default="10" />
      <v:variable name="login_attempts" type="integer" default="0" persist="1" />
      <v:variable name="grp_sel_no_thr" type="integer" default="0" persist="1" />
      <v:variable name="ndays" type="any" default="null" />
      <v:variable name="grp_sel_thr" type="integer" default="0" persist="1" />
      <v:variable name="size_is_changed" type="integer" default="0" persist="1" />
      <v:variable name="list_len" type="integer" default="10" persist="1" />
      <!--v:variable name="article_list" type="any" default="1" persist="1" /-->
      <v:variable name="article_list_lenght" type="integer" default="10" persist="1" />
      <v:variable name="fordate" type="date" default="null"/>
      <v:variable name="dprev" type="date" default="null"/>
      <v:variable name="dnext" type="date" default="null"/>
      <v:variable name="post_body" type="any" default="null"/>
      <v:variable name="post_from" type="any" default="null"/>
      <v:variable name="post_subj" type="any" default="null"/>
      <v:variable name="post_old_hdr" type="any" default="null"/>
      <v:variable name="nntp_cal_day" type="datetime" default="null" param-name="date" persist="session"/>
      <v:variable name="external_home_url" type="varchar" default="'../nntpf/nntpf_main.vspx'" persist="session"/>
      <v:variable name="grp_list" persist="0" type="any" default="NULL"/>
      <v:variable name="cur_art" persist="0" type="integer" default="NULL"/>

      <v:variable name="host" type="varchar" default="null" persist="temp" />
      <!-- eRDF data -->

      <v:variable name="e_title" type="varchar" default="null" persist="temp" />
      <v:variable name="e_author" type="varchar" default="null" persist="temp" />
      <v:variable name="e_lat" type="real" default="null" persist="temp" />
      <v:variable name="e_lng" type="real" default="null" persist="temp" />

      <!-- end -->

      <xsl:for-each select="//vm:variable">
	<v:variable>
	  <xsl:copy-of select="@*"/>
	</v:variable>
      </xsl:for-each>
    </xsl:template>
    <xsl:template match="vm:template">
      <v:template type="simple">
	<xsl:attribute name="name">tm_<xsl:value-of select="generate-id()"/></xsl:attribute>
	<xsl:copy-of select="@*"/>
	<xsl:apply-templates />
      </v:template>
    </xsl:template>
    <xsl:template match="vm:label">
      <v:label>
	<xsl:attribute name="name">ll_<xsl:value-of select="generate-id()"/></xsl:attribute>
	<xsl:copy-of select="@*"/>
	<xsl:apply-templates />
      </v:label>
    </xsl:template>
    <xsl:template match="vm:url">
      <v:url>
	<xsl:attribute name="name">url_<xsl:value-of select="generate-id()"/></xsl:attribute>
	<xsl:copy-of select="@*"/>
	<xsl:apply-templates />
      </v:url>
    </xsl:template>
    <xsl:template match="vm:home-link">
      <vm:url url="nntpf_main.vspx">
	<xsl:attribute name="value"><xsl:apply-templates/></xsl:attribute>
      </vm:url>
    </xsl:template>
    <xsl:template match="vm:nntpf-title">
      <xsl:call-template name="title"/>
      <v:template type="simple" condition="self.vc_authenticated">
<!--
        <table class="user_id">
          <tr class="user_id">
            <td class="user_id">
                Logged in as <?V case when self.u_full_name <> '' then wa_utf8_to_wide (self.u_full_name) else self.u_name end ?>
                <v:url value="--'&nbsp;Logout'"
                       format="%s"
                       url="--'nntpf_logout.vspx'" />
            </td>
          </tr>
        </table>
 -->
      </v:template>
    </xsl:template>

    <xsl:template match="vm:nntpf-search">
      <xsl:call-template name="search"/>
    </xsl:template>


    <xsl:template match="vm:nntpf-copyright">
      <div class="copyright" id="FT">

        <div id="FT_L"><a href="http://www.openlinksw.com/virtuoso"><img border="0" src="images/virt_power_no_border.png" alt="Powered by OpenLink Virtuoso Universal Server"/></a></div>
        <div id="FT_R">

        <xsl:text disable-output-escaping="yes">
           &lt;?vsp
                declare _copyright varchar;
    
                select top 1  WS_COPYRIGHT into _copyright from WA_SETTINGS;
                
                http (coalesce (wa_utf8_to_wide (_copyright),''));
           ?&gt;
        </xsl:text>
        </div>
      </div>
    </xsl:template>
    <xsl:template match="vm:geo-link">
      <?vsp
        if ( 1=0 and self.e_lat is not null and self.e_lng is not null) {
      ?>
	<div>
	    <a href="http://geourl.org/near?p=<?U sprintf ('http://%s/nntpf', self.host) ?>" class="{local-name()}">
		<xsl:apply-templates />
	    </a>
	</div>
      <?vsp
        }
      ?>
    </xsl:template>

    <xsl:template match="vm:*">
      <p class="error">Control not implemented: "<xsl:value-of select="local-name (.)"/>"</p>
    </xsl:template>


  <xsl:template match="vm:ds-navigation">
      <v:variable name="nav_next" type="integer" default="1" persist="1" />
      <v:variable name="nav_prev"  type="integer" default="1" persist="1" />
    &lt;?vsp
     {
      declare _prev, _next, _last, _first vspx_button;
      declare d_prev, d_next, d_last, d_first, index_arr int;
      d_prev := d_next := d_last := d_first := index_arr := 0;
      _first := control.vc_find_control ('<xsl:value-of select="@data-set"/>_first');
      _last := control.vc_find_control ('<xsl:value-of select="@data-set"/>_last');
      _next := control.vc_find_control ('<xsl:value-of select="@data-set"/>_next');
      _prev := control.vc_find_control ('<xsl:value-of select="@data-set"/>_prev');
      if (_next is not null and not _next.vc_enabled and _prev is not null and not _prev.vc_enabled)
        goto skipit;
      index_arr := 1;
      if (_first is not null and not _first.vc_enabled)
      {
        d_first := 1;
      }
      if (_next is not null and not _next.vc_enabled)
      {
        d_next := 1;
      }
      if (_prev is not null and not _prev.vc_enabled)
      {
        d_prev := 1;
      }
      if (_last is not null and not _last.vc_enabled)
      {
        d_last := 1;
      }
      skipit:;
    ?&gt;
    <!-- an version of page numbering -->
    <xsl:if test="not(@type) or @type = 'set'">
      <v:text name="{@data-set}_offs" type="hidden" value="0" />
      <?vsp

      if (index_arr)
      {
        declare dsname, idx_offs, frm_name any;
        declare frm vspx_control;

        frm := control.vc_find_parent_form (control);
        frm_name := '';


        if (frm is not null)
            frm_name := frm.vc_name;

        
        -- this button is just to trigger the post, no render at all
        if (0)
        {
        ?>
        <v:button name="{@data-set}_idx" action="simple" style="url" value="Submit">
          <v:on-post><![CDATA[
          declare ds vspx_data_set;
          declare dss vspx_data_source;
          declare offs int;
          offs := atoi(get_keyword (replace (control.vc_name, '_idx', '_offs'), e.ve_params, '0'));
          ds := control.vc_find_parent (control, 'vspx_data_set');
          if (ds.ds_data_source is not null)
          {
            ds.ds_rows_offs := ds.ds_nrows * offs;
            ds.vc_data_bind (e);
          }else if(ds.ds_rows_total>0 and (ds.ds_rows_total>ds.ds_nrows * offs)){
            
            ds.ds_rows_offs := ds.ds_nrows * offs;
            ds.vc_data_bind (e);
          }
          
          
          ]]></v:on-post>
        </v:button>
        <?vsp
        }
        ?>
        <xsl:processing-instruction name="vsp">
         dsname := '<xsl:value-of select="@data-set"/>';
        </xsl:processing-instruction>
        <?vsp


         declare i, n, t, c,dc integer;
         declare _class varchar;
         declare dss vspx_data_source;
         declare ds vspx_data_set;
         ds := control.vc_parent;


         dss := null;
         if (ds.ds_data_source is not null)
             dss := ds.ds_data_source;
         i := 0;
         n := ds.ds_nrows;
         t := 0;
         self.nav_next:=1;
         self.nav_prev:=1;
         if (dss is not null)
         {
             t := dss.ds_total_rows;
         }else
         {
             t := ds.ds_rows_total;
         }
         c := ds.ds_rows_offs/10;

--dbg_obj_print ('n=',n, ' t=',t,' c=', c);

         dc:=ceiling (t/n)+1-c;

         if ((t/n) > 20)
         { 
           if( c>10 and c<ceiling(t/n) - 10)
           {
              i := c - 10;
              dc := 11;
           }
           if(c<=10)
              dc :=20-c;
           if(c>=ceiling(t/n) - 10)
           {
              i  :=c - 10;
              dc :=ceiling(t/n)-c+1;
           }
        }
         
--         dbg_obj_print('c+1=ceiling (t/n)',c,ceiling (t/n));

         if(c=0)     
            self.nav_prev:=0;

         if(c=ceiling (t/n))     
            self.nav_next:=0;


         http('&#160;');
         if (d_prev)
         {
           http ('<a href="javascript:void(0)">&lt;&lt;</a>');
         }
   
   
         if(self.nav_prev)
        {
        ?>

         <v:button name="{@data-set}_prev" action="simple" style="url" value="&amp;lt;&amp;lt;"
           xhtml_alt="Previous" xhtml_title="Previous" text="&nbsp;Previous">
         </v:button>
           <![CDATA[&nbsp;]]>
           <![CDATA[&nbsp;]]>
        <?vsp            
        }  
        
        
        while (i < c+dc )
        {
        ?>
        | <a href="javascript:void(0)" onclick="javascript: document.forms['<?V frm_name ?>'].<?V dsname ?>_offs.value = <?V i ?>; doPost ('<?V frm_name ?>', '<?V dsname ?>_idx'); return false;"><?vsp http_value (i + 1, case when c = i then 'b' else null end); ?></a>
        <?vsp
            i := i + 1;
         }
         if (i > 0)
            http (' | ');
      }
      ?>
    </xsl:if>
      <![CDATA[&nbsp;]]>
      <![CDATA[&nbsp;]]>
    <?vsp
      if (d_next)
      {
      http ('<a href="javascript:void(0)">&gt;&gt;</a>');
      }

      if(self.nav_next)
      {
    ?>
    <v:button name="{@data-set}_next" action="simple" style="url" value="&amp;gt;&amp;gt;"
      xhtml_title="Next" text="&nbsp;Next">
    </v:button>
    <?vsp
      }
    }
    ?>
  </xsl:template>


  <xsl:template match="vm:ds-navigation-new">
    &lt;?vsp
     {
     
      declare _prev, _next, _last, _first vspx_button;
      declare d_prev, d_next, d_last, d_first, index_arr int;
      d_prev := d_next := d_last := d_first := index_arr := 0;
      _first := control.vc_find_control ('<xsl:value-of select="@data-set"/>_first');
      _last := control.vc_find_control ('<xsl:value-of select="@data-set"/>_last');
      _next := control.vc_find_control ('<xsl:value-of select="@data-set"/>_next');
      _prev := control.vc_find_control ('<xsl:value-of select="@data-set"/>_prev');
      if (_next is not null and not _next.vc_enabled and _prev is not null and not _prev.vc_enabled)
        goto skipit;
      index_arr := 1;
      if (_first is not null and not _first.vc_enabled)
      {
        d_first := 1;
      }
      if (_next is not null and not _next.vc_enabled)
      {
        d_next := 1;
      }
      if (_prev is not null and not _prev.vc_enabled)
      {
        d_prev := 1;
      }
      if (_last is not null and not _last.vc_enabled)
      {
        d_last := 1;
      }
      skipit:;
    ?&gt;
    <!-- an version of page numbering -->
    <xsl:if test="not(@type) or @type = 'set'">
      <v:text name="{@data-set}_offs" type="hidden" value="0" />
      <?vsp
       declare _nav_next,_nav_prev integer;
       _nav_next:=1;
       _nav_prev:=1;

      if (index_arr)
      {
        declare dsname, idx_offs, frm_name any;
        declare frm vspx_control;

        frm := control.vc_find_parent_form (control);
        frm_name := '';


        if (frm is not null)
            frm_name := frm.vc_name;


        -- this button is just to trigger the post, no render at all
        if (0)
        {
        ?>
        <v:button name="{@data-set}_idx" action="simple" style="url" value="Submit">
          <v:on-post><![CDATA[
          declare ds vspx_data_set;
          declare dss vspx_data_source;
          declare offs int;
          offs := atoi(get_keyword (replace (control.vc_name, '_idx', '_offs'), e.ve_params, '0'));
          ds := control.vc_find_parent (control, 'vspx_data_set');
          if (ds.ds_data_source is not null)
          {
            ds.ds_rows_offs := ds.ds_nrows * offs;
            ds.vc_data_bind (e);
          }else if(ds.ds_rows_total>0 and (ds.ds_rows_total>ds.ds_nrows * offs)){
            
            ds.ds_rows_offs := ds.ds_nrows * offs;
            ds.vc_data_bind (e);
          }
          
          
          ]]></v:on-post>
        </v:button>
        <?vsp
        }
        ?>
        <xsl:processing-instruction name="vsp">
         dsname := '<xsl:value-of select="@data-set"/>';
        </xsl:processing-instruction>
        <?vsp


         declare i, n, t, tp, c, dc integer;
         declare _class varchar;
         declare dss vspx_data_source;
         declare ds vspx_data_set;
         ds := control.vc_parent;

         dss := null;
         if (ds.ds_data_source is not null)
             dss := ds.ds_data_source;
         i := 0;
         n := ds.ds_nrows;
         t := 0;


         if (dss is not null)
         {
             t := dss.ds_total_rows;
         }else
         {
             t := ds.ds_rows_total;
         }

         c := ds.ds_rows_offs/n;

         tp:=ceiling (cast(t as float)/cast(n as float));
         dc:=tp-c;

--         dbg_obj_print ('rows per page',n, ' total rows',t,'total pages',tp,' current page', c,'delta of shown pages ',dc,'start from page',i,'total pages',tp);

         if (tp > 20)
         { 
           if( c>10 and c<ceiling(t/n) - 10)
           {
              i := c - 10;
              dc := 11;
           }
           if(c<=10)
              dc :=20-c;
           if(c>=ceiling(t/n) - 10)
           {
              i  :=c - 10;
              dc :=ceiling(t/n)-c+1;
           }
        }
         
         if(c=0)     
            _nav_prev:=0;


         if(c=tp)
            _nav_next:=0;

         http('&#160;');
   
         if(_nav_prev)
        {
        ?>

         <v:button name="{@data-set}_prev" action="simple" style="url" value="&amp;lt;"
           xhtml_alt="Previous" xhtml_title="Previous" text="&nbsp;Previous">
         </v:button>
           <![CDATA[&nbsp;]]>
           <![CDATA[&nbsp;]]>
        <?vsp            
        }  
        
        while (i < c+dc )
        {
        ?>
        | <a href="javascript:void(0)" onclick="javascript: document.forms['<?V frm_name ?>'].<?V dsname ?>_offs.value = <?V i ?>; doPost ('<?V frm_name ?>', '<?V dsname ?>_idx'); return false;"><?vsp http_value (i + 1, case when c = i then 'b' else null end); ?></a>
        <?vsp
            i := i + 1;
         }
         if (i > 0)
            http (' | ');
      }

      ?>
      <![CDATA[&nbsp;]]>
      <![CDATA[&nbsp;]]>
    <?vsp
      if(_nav_next)
      {
    ?>
    <v:button name="{@data-set}_next" action="simple" style="url" value="&amp;gt;"
      xhtml_title="Next" text="&nbsp;Next">
    </v:button>
    <?vsp
      }
    }
    ?>
    </xsl:if>
  </xsl:template>

  <xsl:template match="vm:posts-settings">
    <v:variable name="posts_enabled" type="any"/>
    <v:variable name="openid_enabled" type="any"/>
      <v:before-data-bind>
        <![CDATA[
        declare _e_posts,_e_openid integer;
        _e_posts:=1;
        _e_openid:=1;

--        declare exit handler for sqlstate '*'{goto _skip;};
--        select  1,1 into _e_posts,_e_openid from ???;
--        
--        _skip:;

        if(registry_get('nntpf_posts_enabled')='0')
           _e_posts:=0;
        if(registry_get('nntpf_openid_enabled')='0')
           _e_openid:=0;

         self.posts_enabled:=_e_posts;
         self.openid_enabled:=_e_openid;

        ]]>
      </v:before-data-bind>
      <div style="padding:10px;">
      <v:check-box name="posts_enabled_cbx"
                   value="--self.posts_enabled"
                   initial-checked="--self.posts_enabled"  /> Posts allowed
      <br/>             
      <v:check-box name="openid_enabled_cbx"
                   value="--self.openid_enabled"
                   initial-checked="--self.openid_enabled"  /> Posts verification via OpenID URL
      <br/><br/>
      <v:button name="settings_save"
              action="simple"
              style="submit"
              value="--' Save '">
        <v:on-post>

        declare _e_post,_e_openid varchar;
        _e_post:='0';
        _e_openid:='0';
        
        if(self.posts_enabled_cbx.ufl_selected)
           _e_post:='1';
        if(self.openid_enabled_cbx.ufl_selected)
           _e_openid:='1';
        
        registry_set('nntpf_posts_enabled', _e_post);
        registry_set('nntpf_openid_enabled', _e_openid);
        </v:on-post>
      </v:button>
      </div>
      
  </xsl:template>


</xsl:stylesheet>
