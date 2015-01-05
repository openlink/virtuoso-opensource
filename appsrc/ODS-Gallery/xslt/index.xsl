<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2015 OpenLink Software
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
<xsl:stylesheet version='1.0' xmlns:v="http://www.openlinksw.com/vspx/" xmlns:vm="http://www.openlinksw.com/vspx/weblog/"  xmlns:xsl='http://www.w3.org/1999/XSL/Transform' xmlns:msxsl="urn:schemas-microsoft-com:xslt" xmlns:fmt="urn:p2plusfmt-xsltformats" xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:s="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/" xmlns:soap12="http://schemas.xmlsoap.org/wsdl/soap12/" >
  <xsl:output method="html" indent="yes" encoding="UTF-8" doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN" doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>

  <xsl:template match="/">
  <html xmlns:foaf="http://xmlns.com/foaf/0.1/" foaf:dummy="false" xmlns:dc="http://purl.org/dc/elements/1.1/" dc:dummy="false" xmlns:dct="http://purl.org/dc/terms/" dct:dummy="false" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" rdf:dummy="false" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" rdfs:dummy="false" xmlns:sioct="http://rdfs.org/sioc/types#" sioct:dummy="false" xmlns:sioc="http://rdfs.org/sioc/ns#" sioc:dummy="false">
      <head profile="http://internetalchemy.org/2003/02/profile">
      <base>
        <xsl:attribute name="href"><xsl:value-of select="root/base"/></xsl:attribute>
      </base>
        <title>Photo Gallery</title>
        <link rel="meta" type="application/rdf+xml" title="SIOC" href="root/host" >
          <xsl:attribute name="href">http://<xsl:value-of select="root/host"/>/dataspace/<xsl:value-of select="root/instance_owner"/>/<xsl:value-of select="root/app_type"/>/<xsl:value-of select="root/instance"/>/sioc.rdf</xsl:attribute>
        </link>

        <link rel="alternate" type="application/atom+xml">
          <xsl:attribute name="title"><xsl:value-of select="root/instance_owner"/>&#39;s Photos Atom</xsl:attribute>
          <xsl:attribute name="href">http://<xsl:value-of select="root/host"/><xsl:value-of select="root/home_url"/>atom.xml</xsl:attribute>
        </link>

        <link rel="alternate" type="application/rss+xml">
          <xsl:attribute name="title"><xsl:value-of select="root/instance_owner"/>&#39;s Photos RSS</xsl:attribute>
          <xsl:attribute name="href">http://<xsl:value-of select="root/host"/><xsl:value-of select="root/home_url"/>rss.xml</xsl:attribute>
        </link>

        <link rel="pingback" href="http://localhost:84/mt-tb" ></link>

      <xsl:if test="/root/user/@lat != ''">
        <meta name="geo.position" >
          <xsl:attribute name="content"><xsl:value-of select="/root/user/@lat"/>;<xsl:value-of select="/root/user/@lng"/></xsl:attribute>
        </meta>
        <meta name="ICBM">
          <xsl:attribute name="content"><xsl:value-of select="/root/user/@lat"/>;<xsl:value-of select="/root/user/@lng"/></xsl:attribute>
        </meta>
        <meta name="dc.title">
          <xsl:attribute name="content"><xsl:value-of select="/root/dc_instance_name"/></xsl:attribute>
        </meta>
        <meta name="dc.description">
          <xsl:attribute name="content"><xsl:value-of select="/root/dc_instance_description"/></xsl:attribute>
        </meta>
      </xsl:if>
      <link rel="foaf" type="application/rdf+xml" title="FOAF">
        <xsl:attribute name="href">http://<xsl:value-of select="root/host"/>/dataspace/person/<xsl:value-of select="root/instance_owner"/>/foaf.rdf</xsl:attribute>
        </link>
        <script type="text/javascript">
      		var toolkitPath = "/ods/oat";
      		var featureList = ["dom","rotator","slider","xml","ajax","timeline","calendar","quickedit","ajax","ws","anchor"];
      	</script>
      	<script type="text/javascript" src="/ods/oat/loader.js"></script>
      	<script type="text/javascript" src="/ods/app.js"></script>
        <script type="text/javascript" src="/photos/res/js/ajax.js"></script>
        <script type="text/javascript" src="/photos/res/js/dataset.js"></script>
        <script type="text/javascript" src="/photos/res/js/ui.js"></script>
        <script type="text/javascript" src="/photos/res/js/gallery.js"></script>
        <script type="text/javascript" src="/photos/res/js/timeline.js"></script>
        <script type="text/javascript" src="/photos/res/js/map.js"></script>
        <script type="text/javascript" src="/photos/res/js/calendar.js"></script>
        <script type="text/javascript" language="JavaScript" src="/photos/res/proxy.vsp"></script>
        <link rel="stylesheet" href="/photos/res/css/gallery.css" type="text/css"/>
        <link rel="stylesheet" href="/photos/res/css/timeline.css" type="text/css"/>
      </head>
        <xsl:apply-templates/>
    </html>
  </xsl:template>


<!-- ======================================================================= -->
  <xsl:template match="root">
    <body>
      <xsl:apply-templates select="bar"/>
            <br />
      <div id="wrapper">
      <div id="head">
          <img src="/photos/res/i/gallerybanner_sml.jpg" />
      </div>
      <div id="welcome">
        <h2>Welcome to oGallery!</h2>
        Already a member? <a href="/wa/login.vspx?URL=/gallery/">Login</a><br/>
        <a href="/wa/register.vspx">Register</a> for a free account
      </div>
      <xsl:call-template name="ajax_action"/>
      <div id="newest">
        <h3>Last 10 users galleries</h3>
        <ul>
          <xsl:apply-templates select="newest_user"/>
        </ul>
      </div>
    </div>
  </body>
  </xsl:template>



<!-- ======================================================================= -->
  <xsl:template match="root[@sid != '' or gallery]">
   <body>
      <xsl:attribute name="onLoad">gallery.init('<xsl:value-of select="gallery"/>')</xsl:attribute>
      <xsl:apply-templates select="bar"/>
      <div style="clear: both;"></div>
       <div id="wrapper">
      <form name="f1" style="display:inline;">

      <div id="head">
            <img src="/photos/res/i/gallerybanner_sml.jpg" />
            <br />
            <span id="instance_info" >
              <span property="dc:title"><xsl:value-of select="/root/instance_name"/></span>
              (<span property="dc:creator"><xsl:value-of select="instance_owner_fullname"/></span>)
            </span>
      <div id="nav">
        <ul>
          <xsl:choose>
            <xsl:when test="@sid != ''">
              <li id="hello">
              </li>
              <li id="my_albums_tab" class="on">
                My albums
              </li>
              <li id="new_album_tab">
                New album
              </li>
              <li id="settings_tab">
                Settings
              </li>
            </xsl:when>
            <xsl:otherwise>
              <li id="home">
                Home
              </li>
              <li id="wa">
                <xsl:value-of select="wa_home_title"/>
              </li>
            </xsl:otherwise>
          </xsl:choose>
          <script> var wa_home_link = '<xsl:value-of select="wa_home_link"/>'</script>
        </ul>
      </div>
      </div>

      <div id="error_box" style="display:none;">
        <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
      </div>

          <div style="clear: both;"></div>
      <table cellpadding="0" cellspacing="4" id="main_container">
        <tr>
         <td colspan="2">
	  	  	<div id="timeline"></div>
         </td>
        </tr>
        <tr>
        <td colspan="2">
          <div id="map" style="display:none;width:800px;height:450px;" class="view"/>
        </td>
        </tr>
        <tr>
          <td id="left_col" valign="top">

            <div id="care_my_albums" class="toolbar">
              <h3><span id="myAlbumsTxt">My Albums</span></h3>
              <ul id="my_albums_list"/>
              <h4 id="my_albums_list_more">see all albums...</h4>
              <ul id="my_albums_man" style="display:none">
                <li id="new_album_tab">
                  Create new album
                </li>
              </ul>
            </div>
            <div id="care_edit_album" class="toolbar" style="display:none">
              <h3>Edit album</h3>
              <ul>
                <li id="link_images_upload">Add images</li>
                <li id="link_images_import">Import images</li>
                <li id="link_images_export">Export images</li>
                <!--<li id="tag_images_tab">Tag images</li>-->
                <li id="link_edit_album">Edit album</li>
                <li id="link_delete_album">Delete album</li>
                <li id="link_delete_images">Delete images</li>
              </ul>
            </div>
            <div id="care_nav_image" class="toolbar" style="display:none">
              <h3>Album</h3>
              <ul>
                <li id="link_show_images">All images</li>
              </ul>
            </div>
            <div id="care_view_album" class="toolbar" style="display:none">
              <h3>View mode</h3>
              <ul>
                <li id="btn_slideshow">Slideshow</li>
              </ul>
            </div>
            <div id="care_edit_image" class="toolbar" style="display:none">
              <h3>Edit image</h3>
              <ul>
                <li id="link_image_edit">Edit caption</li>
                <li id="link_delete_image">Delete image</li>
              </ul>
            </div>
            <div id="care_view_mode" class="toolbar" style="display:none">
              <h3>View mode</h3>
              <ul>
                <li id="btn_slideshow">Slideshow</li>
                <li id="link_show_exif">EXIF information</li>
              </ul>
            </div>
            <div id="care_slideshow" class="toolbar" style="display:none">
              <h3>Slideshow</h3>
              <div id="buttons">
                  <img src="/photos/res/i/skipb_24.gif" width="24" height="24" id="SlideShow_back" alt="Previus Picture"/>
                  <img src="/photos/res/i/pause_24.gif" width="24" height="24" id="SlideShow_stop" alt="Start/Pause"/>
                  <img src="/photos/res/i/skipf_24.gif" width="24" height="24" id="SlideShow_next" alt="Next picture"/>
              </div>
          		<div id="sliderbg">
          			<div id="slider_btn"></div>
          		</div>
              <div id="label_slideshow_status">
              </div>
            </div>

            <div id="feeds" class="toolbar">
              <h3>Feeds</h3>
              <ul>
                    <li id="feed_atom"><span class="atom-link">Atom 1.0</span></li>
                    <li id="feed_rss"><span class="rss-link">RSS 2.0</span></li>
                    <li id="feed_rdf"><span class="rdf-link">RDF</span></li>
                    <li id="feed_xbel"><span class="xbel-link">XBEL</span></li>
                    <li id="feed_mrss"><span class="podcast-link">mRSS</span></li>
                    <li id="feed_siocxml"><span class="sioc-link">SIOC (RDF/XML)</span></li>
                    <li id="feed_siocn3turtle"><span class="sioc-link">SIOC (N3/Turtle)</span></li>
              </ul>
            </div>
          </td>

              <td id="right_col" valign="top">
            <div id="info">
              <div id="title">
                <div id="path">
                  <span id="path_my_albums"></span>
                  <span id="path_pub_date"></span>
                  <span id="path_album_name"></span>
                  <span id="path_image_name"></span>
                </div>
                <div id="info_discription">
                </div>
                <h3 id="caption"></h3>
                <div id="filter" style="display:none">
                 Filter by: <span id="filter_subtype" class="qe"></span><span id="filter_custom" class="qe"></span>
                </div>
              </div>
              
              <div id="preview_nav">
                <div id="preview_left"/>
                <div id="preview_right">
                </div>
              </div>
            </div>

            <div id="albums">

            </div>

            <xsl:call-template name="new_album"/>
            <xsl:call-template name="edit_album"/>
            <xsl:call-template name="edit_album_settings"/>

            <div id="group_images">
              <div id="images_upload" style="display:none;">
              <iframe width="100%" height="750" src="" border="0" frameborder="0" ></iframe>
            </div>
              <div id="images_import" style="display:none;">
                    <div id="images_import_flickr" class="link">Sign in</div>
                <div id="images_import_flickr_list" class="link_disabled">View and select images</div>
                <div id="images_import_flickr_save" class="link_disabled">Import</div>
              </div>
              <div id="images_export" style="display:none;">
                    <div id="images_export_flickr" class="link">Sign in Flickr</div>
                <div id="images_export_flickr_send" class="link_disabled">Upload selected images to Flickr</div>
              </div>
            <div id="images" style="display:none;">
              <xsl:call-template name="nbsp"/>
            </div>
            </div>

            <div id="group_image">
              <div id="image" style="display:none;">
                Loading ...<xsl:call-template name="nbsp"/>
              </div>
              <div id="image_info" style="display:none;">
                Loading ...
              </div>
              <xsl:call-template name="image_edit"/>

              <xsl:call-template name="comments"/>
              <xsl:call-template name="slideshow"/>
            </div>
            </td>
          </tr>
        </table>
    </form>
    </div>
    <xsl:call-template name="ajax_action"/>
    <div id="wait" style="display:none;">
      <img id="throbber" src="/photos/res/i/throbber.gif" border="0" /> Please, wait ...
    </div>
  </body>
  </xsl:template>

<!-- ========================================================================= -->
<xsl:template name="comments">
    <div id="tags" style="display:none;" class="block">
      <table class="frame" cellpadding="10">
      <tr>
        <td valign="top" class="left">
            <h2 class="ctr">Tags</h2>
          <div id="tags_list">
            Loading ...
          </div>
        </td>
          <td valign="top" class="right" id="tags_edit" style="display:none;">
            <h2>Add new tags (comma-separated)</h2>
            <textarea name="new_tag" id="new_tag" style="width: 400; height: 70;"></textarea>
          <br/>
          <button type="button" name="bnt_new_tag" id="bnt_new_tag">Save</button>
            <button type="button" name="bnt_new_tag_cancel" id="bnt_new_tag_cancel">Cancel</button>
        </td>
      </tr>
    </table>
    </div>
    <div id="comments" style="display:none;" class="block">
      <table class="frame" cellpadding="10">
      <tr>
        <td valign="top" class="left">
            <h2 class="ctr">Comments</h2>
          <div id="comments_list">
            Loading ...
          </div>
        </td>
        <td valign="top" class="right">
            <div id="comment_block">
              <h2 id="comment_header">New comment</h2>
              <div id="rte">
                <textarea id="comment2" name="comment2" style="width: 400; height: 170;"></textarea>
                <script type="text/javascript" src="/ods/ckeditor/ckeditor.js"></script>
                <script type="text/javascript">
                  var oEditor = CKEDITOR.replace('comment2');
                </script>
            </div>
              <button type="button" name="comment_save" id="comment_save">Save</button>
              <button type="button" name="commnet_cancel" id="comment_cancel">Cancel</button>
            </div>
        </td>
      </tr>
    </table>
  </div>
  </xsl:template>

<!-- ========================================================================= -->
<xsl:template name="slideshow">
  <div id="slideshow">
  	<div id="rotator">
  		<div id="rotator_content">
  			<div id="rotator_viewport"></div>
  			<div id="rotator_filter"></div>
    </div>
  </div>
</div>
  </xsl:template>

<!-- ========================================================================= -->
<xsl:template name="ajax_action">
 <script type="text/javascript">
      var sid = '<xsl:value-of select="@sid"/>';
    var isOwner = <xsl:value-of select="user/@owner"/>;
      var userRole = '<xsl:value-of select="user/user_role"/>';
      var realm = '<xsl:value-of select="@realm"/>';
      var home_path = '<xsl:value-of select="gallery"/>';
    var home_url = '<xsl:value-of select="home_url"/>';
    var gallery_id = '<xsl:value-of select="gallery_id"/>';
    var gallery_inst_name = "<xsl:value-of select='instance' />";
    var aplus = <xsl:value-of select='aplus' />;
    var aplus_id = 0;
    </script>
  </xsl:template>

<!-- ======================================================================= -->
  <xsl:template name="new_album">
      <div id="new_album" style="display:none;">
    <table id="forma" class="box">
      <caption>Create new album</caption>
                <tr>
                  <td><label for="new_album_name">Name</label></td>
                  <td>
                    <input type="text" name="new_album_name" id="new_album_name" value="new album"/>
                  </td>
                </tr>
                <tr>
                  <td>Description</td>
                  <td><textarea type="text" name="new_album_description" id="new_album_description"></textarea></td>
                </tr>
      <tr>
        <td>Start Date</td>
        <td>
            <select name="new_album_start_date_year" id="new_album_start_date_year">
              <option value="2000">2000</option>
              <option value="2001">2001</option>
              <option value="2002">2002</option>
              <option value="2003">2003</option>
              <option value="2004">2004</option>
              <option value="2005">2005</option>
              <option value="2006">2006</option>
              <option value="2007">2007</option>
              <option value="2008">2008</option>
              <option value="2009">2009</option>
              <option value="2010">2010</option>
              <option value="2011">2011</option>
              <option value="2012">2012</option>
              <option value="2013">2013</option>
              <option value="2014">2014</option>
              <option value="2015">2015</option>
              <option value="2016">2016</option>
              <option value="2017">2017</option>
              <option value="2018">2018</option>
              <option value="2019">2019</option>
              <option value="2020">2020</option>
            </select>
            <xsl:text>/</xsl:text>
            <select name="new_album_start_date_month" id="new_album_start_date_month">
              <option value="1">1</option>
              <option value="2">2</option>
              <option value="3">3</option>
              <option value="4">4</option>
              <option value="5">5</option>
              <option value="6">6</option>
              <option value="7">7</option>
              <option value="8">8</option>
              <option value="9">9</option>
              <option value="10">10</option>
              <option value="11">11</option>
              <option value="12">12</option>
            </select>
            <xsl:text>/</xsl:text>
            <select name="new_album_start_date_day" id="new_album_start_date_day">
              <option value="1">1</option>
              <option value="2">2</option>
              <option value="3">3</option>
              <option value="4">4</option>
              <option value="5">5</option>
              <option value="6">6</option>
              <option value="7">7</option>
              <option value="8">8</option>
              <option value="9">9</option>
              <option value="10">10</option>
              <option value="11">11</option>
              <option value="12">12</option>
              <option value="13">13</option>
              <option value="14">14</option>
              <option value="15">15</option>
              <option value="16">16</option>
              <option value="17">17</option>
              <option value="18">18</option>
              <option value="19">19</option>
              <option value="20">20</option>
              <option value="21">21</option>
              <option value="22">22</option>
              <option value="23">23</option>
              <option value="24">24</option>
              <option value="25">25</option>
              <option value="26">26</option>
              <option value="27">27</option>
              <option value="28">28</option>
              <option value="29">29</option>
              <option value="30">30</option>
              <option value="31">31</option>
            </select>
            <a  href="javascript:void(0)">
            <img src="/photos/res/i/date_selector.png" width="22" height="22" border="0" id="new_album_start_date_selector" alt="Select Start Date" onClick="GCallendar.show(this.id);"/>
            </a>            
          </td>
      </tr>
      <tr>
        <td>End Date</td>
        <td>
            <select name="new_album_end_date_year" id="new_album_end_date_year">
              <option value="2000">2000</option>
              <option value="2001">2001</option>
              <option value="2002">2002</option>
              <option value="2003">2003</option>
              <option value="2004">2004</option>
              <option value="2005">2005</option>
              <option value="2006">2006</option>
              <option value="2007">2007</option>
              <option value="2008">2008</option>
              <option value="2009">2009</option>
              <option value="2010">2010</option>
              <option value="2011">2011</option>
              <option value="2012">2012</option>
              <option value="2013">2013</option>
              <option value="2014">2014</option>
              <option value="2015">2015</option>
              <option value="2016">2016</option>
              <option value="2017">2017</option>
              <option value="2018">2018</option>
              <option value="2019">2019</option>
              <option value="2020">2020</option>
            </select>
            <xsl:text>/</xsl:text>
            <select name="new_album_end_date_month" id="new_album_end_date_month">
              <option value="1">1</option>
              <option value="2">2</option>
              <option value="3">3</option>
              <option value="4">4</option>
              <option value="5">5</option>
              <option value="6">6</option>
              <option value="7">7</option>
              <option value="8">8</option>
              <option value="9">9</option>
              <option value="10">10</option>
              <option value="11">11</option>
              <option value="12">12</option>
            </select>
            <xsl:text>/</xsl:text>
            <select name="new_album_end_date_day" id="new_album_end_date_day">
              <option value="1">1</option>
              <option value="2">2</option>
              <option value="3">3</option>
              <option value="4">4</option>
              <option value="5">5</option>
              <option value="6">6</option>
              <option value="7">7</option>
              <option value="8">8</option>
              <option value="9">9</option>
              <option value="10">10</option>
              <option value="11">11</option>
              <option value="12">12</option>
              <option value="13">13</option>
              <option value="14">14</option>
              <option value="15">15</option>
              <option value="16">16</option>
              <option value="17">17</option>
              <option value="18">18</option>
              <option value="19">19</option>
              <option value="20">20</option>
              <option value="21">21</option>
              <option value="22">22</option>
              <option value="23">23</option>
              <option value="24">24</option>
              <option value="25">25</option>
              <option value="26">26</option>
              <option value="27">27</option>
              <option value="28">28</option>
              <option value="29">29</option>
              <option value="30">30</option>
              <option value="31">31</option>
            </select>
            <a  href="javascript:void(0)">
            <img src="/photos/res/i/date_selector.png" width="22" height="22" border="0" id="new_album_end_date_selector" alt="Select end Date" onClick="GCallendar.show(this.id);" />
            </a>
          </td>
      </tr>

      <tr>
        <td><label for="new_album_lng">Geolocation</label></td>
        <td>
          <input type="text" name="new_album_lng" id="new_album_lng" value=""/>  
          <xsl:call-template name="nbsp"/><xsl:text>/</xsl:text><xsl:call-template name="nbsp"/>
          <input type="text" name="new_album_lat" id="new_album_lat" value=""/> Longitude / Latitude
        </td>
      </tr>
      <tr>
        <td><label for="new_album_showonmap">Show on map</label></td>
        <td>
          <input type="checkbox" name="new_album_showonmap" id="new_album_showonmap" value=""/>  
        </td>
      </tr>

                <tr>
                  <td><label for="edit_album_name">Visible</label></td>
                  <td>
                    <input type="radio" name="visibility" value="1" checked="1"/>for all (public)
                    <input type="radio" name="visibility" value="0"/>only for me (private )
                  </td>
                </tr>
                <tfoot>
                  <tr>
          <td style="padding-top:20px;" colspan="2">
                      <button type="button" name="btn_new_album" OnClick="gallery.new_album_action()">Create</button>
            <button type="button" id="new_album_close" name="btn_new_album" >Cancel</button>
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>
</xsl:template>

<!-- ======================================================================= -->
  <xsl:template name="edit_album">

<div id="edit_album" style="display:none;">

                <table id="forma" class="box">
                <caption>Edit current album</caption>
                <tr>
                  <td><label for="edit_album_name">Name</label></td>
                  <td>
                    <input type="hidden" name="edit_album_name_old" id="edit_album_name_old" value=""/>
                    <input type="text" name="edit_album_name" id="edit_album_name" value=""/>
                  </td>
                </tr>
                <tr>
                  <td>Description</td>
                  <td><textarea type="text" name="edit_album_description" id="edit_album_description"></textarea></td>
                </tr>
      <tr>
        <td>Start Date</td>
        <td>
            <select name="edit_album_start_date_year" id="edit_album_start_date_year">
              <option value="2000">2000</option>
              <option value="2001">2001</option>
              <option value="2002">2002</option>
              <option value="2003">2003</option>
              <option value="2004">2004</option>
              <option value="2005">2005</option>
              <option value="2006">2006</option>
              <option value="2007">2007</option>
              <option value="2008">2008</option>
              <option value="2009">2009</option>
              <option value="2010">2010</option>
              <option value="2011">2011</option>
              <option value="2012">2012</option>
              <option value="2013">2013</option>
              <option value="2014">2014</option>
              <option value="2015">2015</option>
              <option value="2016">2016</option>
              <option value="2017">2017</option>
              <option value="2018">2018</option>
              <option value="2019">2019</option>
              <option value="2020">2020</option>
            </select>
            <xsl:text>/</xsl:text>
            <select name="edit_album_start_date_month" id="edit_album_start_date_month">
              <option value="1">1</option>
              <option value="2">2</option>
              <option value="3">3</option>
              <option value="4">4</option>
              <option value="5">5</option>
              <option value="6">6</option>
              <option value="7">7</option>
              <option value="8">8</option>
              <option value="9">9</option>
              <option value="10">10</option>
              <option value="11">11</option>
              <option value="12">12</option>
            </select>
            <xsl:text>/</xsl:text>
            <select name="edit_album_start_date_day" id="edit_album_start_date_day">
              <option value="1">1</option>
              <option value="2">2</option>
              <option value="3">3</option>
              <option value="4">4</option>
              <option value="5">5</option>
              <option value="6">6</option>
              <option value="7">7</option>
              <option value="8">8</option>
              <option value="9">9</option>
              <option value="10">10</option>
              <option value="11">11</option>
              <option value="12">12</option>
              <option value="13">13</option>
              <option value="14">14</option>
              <option value="15">15</option>
              <option value="16">16</option>
              <option value="17">17</option>
              <option value="18">18</option>
              <option value="19">19</option>
              <option value="20">20</option>
              <option value="21">21</option>
              <option value="22">22</option>
              <option value="23">23</option>
              <option value="24">24</option>
              <option value="25">25</option>
              <option value="26">26</option>
              <option value="27">27</option>
              <option value="28">28</option>
              <option value="29">29</option>
              <option value="30">30</option>
              <option value="31">31</option>
            </select>
            <xsl:call-template name="nbsp"/>
            <a  href="javascript:void(0)">
            <img src="/photos/res/i/date_selector.png" width="22" height="22" border="0" id="edit_album_start_date_selector" alt="Select end Date" onClick="GCallendar.show(this.id);"/>
            </a>
          </td>
      </tr>
      <tr>
        <td>End Date</td>
        <td>
            <select name="edit_album_end_date_year" id="edit_album_end_date_year">
              <option value="2000">2000</option>
              <option value="2001">2001</option>
              <option value="2002">2002</option>
              <option value="2003">2003</option>
              <option value="2004">2004</option>
              <option value="2005">2005</option>
              <option value="2006">2006</option>
              <option value="2007">2007</option>
              <option value="2008">2008</option>
              <option value="2009">2009</option>
              <option value="2010">2010</option>
              <option value="2011">2011</option>
              <option value="2012">2012</option>
              <option value="2013">2013</option>
              <option value="2014">2014</option>
              <option value="2015">2015</option>
              <option value="2016">2016</option>
              <option value="2017">2017</option>
              <option value="2018">2018</option>
              <option value="2019">2019</option>
              <option value="2020">2020</option>
            </select>
            <xsl:text>/</xsl:text>
            <select name="edit_album_end_date_month" id="edit_album_end_date_month">
              <option value="1">1</option>
              <option value="2">2</option>
              <option value="3">3</option>
              <option value="4">4</option>
              <option value="5">5</option>
              <option value="6">6</option>
              <option value="7">7</option>
              <option value="8">8</option>
              <option value="9">9</option>
              <option value="10">10</option>
              <option value="11">11</option>
              <option value="12">12</option>
            </select>
            <xsl:text>/</xsl:text>
            <select name="edit_album_end_date_day" id="edit_album_end_date_day">
              <option value="1">1</option>
              <option value="2">2</option>
              <option value="3">3</option>
              <option value="4">4</option>
              <option value="5">5</option>
              <option value="6">6</option>
              <option value="7">7</option>
              <option value="8">8</option>
              <option value="9">9</option>
              <option value="10">10</option>
              <option value="11">11</option>
              <option value="12">12</option>
              <option value="13">13</option>
              <option value="14">14</option>
              <option value="15">15</option>
              <option value="16">16</option>
              <option value="17">17</option>
              <option value="18">18</option>
              <option value="19">19</option>
              <option value="20">20</option>
              <option value="21">21</option>
              <option value="22">22</option>
              <option value="23">23</option>
              <option value="24">24</option>
              <option value="25">25</option>
              <option value="26">26</option>
              <option value="27">27</option>
              <option value="28">28</option>
              <option value="29">29</option>
              <option value="30">30</option>
              <option value="31">31</option>
            </select>
            <xsl:call-template name="nbsp"/>
            <a  href="javascript:void(0)">
            <img src="/photos/res/i/date_selector.png" width="22" height="22" border="0" alt="Select End Date" id="edit_album_end_date_selector"  onClick="GCallendar.show(this.id);" />
            </a>

          </td>
      </tr>

        <tr>
          <td><label for="edit_album_lng">Geolocation</label></td>
          <td>
            <input type="text" name="edit_album_lng" id="edit_album_lng" value=""/>  
            <xsl:call-template name="nbsp"/><xsl:text>/</xsl:text><xsl:call-template name="nbsp"/>
            <input type="text" name="edit_album_lat" id="edit_album_lat" value=""/> Longitude / Latitude
          </td>
        </tr>
        <tr>
          <td><label for="edit_album_showonmap">Show on map</label></td>
          <td>
            <input type="checkbox" name="edit_album_showonmap" id="edit_album_showonmap" value=""/>  
          </td>
        </tr>
                  <tr>
                    <td><label for="edit_album_name">Visible</label></td>
                    <td>
            <input type="radio" name="album_visibility" id="album_visibility_all" value="1" />for all (public)<br/>
            <input type="radio" name="album_visibility" id="album_visibility_me" value="0"/>only for me (private )
                    </td>
                  </tr>
        <tr>
          <td><label for="edit_album_obsolete">Obsolete</label></td>
          <td>
            <input type="checkbox" name="edit_album_obsolete" id="edit_album_obsolete" value=""/>  
          </td>
        </tr>

                  <tfoot>
                    <tr>
            <td style="padding-top:20px;" colspan="2">
              <button type="button" name="btn_edit_album_save" OnClick="gallery.edit_album_action()">Save</button>
                        <button type="button" name="btn_edit_album_cancel" OnClick="gallery.edit_album_cancel();">Cancel</button>
                      </td>
                    </tr>
                  </tfoot>
                </table>
              </div>
  </xsl:template>
<!-- ======================================================================= -->
<xsl:template name="edit_album_settings">
  <div id="edit_album_settings" style="display:none;">
    <table id="forma" class="box">
      <caption>Settings</caption>
      <tr>
        <td colspan="3">
          <h4>Preferences</h4>
        </td>
      </tr>
      <tr>
        <td/>
        <td>
          <input type="hidden" name="edit_album_showmap_old" id="edit_album_showmap_old" value=""/>
          <input type="checkbox" name="edit_album_showmap" id="edit_album_showmap" value=""/>
        </td>
        <td><label for="edit_album_showmap">Show map</label></td>
      </tr>
      <tr>
        <td/>
        <td>
          <input type="hidden" name="edit_album_showtimeline_old" id="edit_album_showtimeline_old" value=""/>
          <input type="checkbox" name="edit_album_showtimeline" id="edit_album_showtimeline" value=""/>
        </td>
        <td><label for="edit_album_showtimeline">Show timeline</label></td>
      </tr>
      <tr>
        <td><label for="albums_per_page">Number of albums per page</label></td>
        <td>
          <select name="albums_per_page" id="albums_per_page">
            <option value="5">5</option>
            <option value="10">10</option>
            <option value="20">20</option>
            <option value="50">50</option>
            <option value="100">100</option>
          </select>
        </td>
        <td/>
      </tr>
      <tr>
        <td colspan="3">
          <h4>Discussion</h4>
        </td>
      </tr>
      <xsl:if test="/root/is_discussion = 0">
        <tr>
          <td class="error_text" colspan="3">
            The Discussion feature is disabled.
            <br/>
            You need to install the ODS Discussion package in order to use it.
          </td>
        </tr>
      </xsl:if>
      <xsl:if test="/root/is_discussion = 1">
        <tr>
          <td/>
          <td>
            <input type="checkbox" name="edit_album_nntp" id="edit_album_nntp" value=""/>
          </td>
          <td><label for="edit_album_nntp">Enable discussions on this instance</label></td>
        </tr>
        <tr>
          <td/>
          <td>
            <input type="checkbox" name="edit_album_nntp_init" id="edit_album_nntp_init" value=""/>
          </td>
          <td><label for="edit_album_nntp_init">Initialize the news group with existing comments</label></td>
        </tr>
      </xsl:if>
        <tfoot>
          <tr>
            <td style="padding-top:20px;" colspan="2">
              <button type="button" name="btn_edit_albumsettings_save" OnClick="gallery.edit_albumsettings_action()">Save</button>
              <button type="button" name="btn_edit_albumsettings_cancel" OnClick="gallery.edit_albumsettings_cancel();">Cancel</button>
            </td>
          </tr>
        </tfoot>
    </table>
  </div>
</xsl:template>

<!-- ======================================================================= -->
  <xsl:template name="image_edit">
      <div id="image_edit" style="display:none;">
                <table id="forma" class="box">
                  <caption>Edit image data</caption>
                  <tr>
                    <td>Caption</td>
                    <td>
                      <input type="text" name="edit_image_description" id="edit_image_description"/>
                    </td>
                  </tr>
                  <tr>
                    <td>File Name</td>
                    <td>
                      <input type="hidden" name="edit_image_path" id="edit_image_path" value=""/>
                      <input type="hidden" name="edit_image_name_old" id="edit_image_name_old" value=""/>
                      <input type="text" name="edit_image_name"/>
                    </td>
                  </tr>
                  <tr>
                    <td><label for="edit_image_name">Visible</label></td>
                    <td>
                      <input type="radio" name="image_visibility" value="1" />for all (public)<br/>
                      <input type="radio" name="image_visibility" value="0"/>only for me (private )
                    </td>
                  </tr>
                  <tr>
                    <td></td>
                    <td style="padding-top:20px;">
                      <button type="button" name="bnt_image_edit" id="btn_image_edit">Save</button>
                      <button type="button" name="bnt_image_edit_cancel" id="btn_image_edit_cancel">Cancel</button>
                    </td>
                  </tr>
                </table>
              </div>
</xsl:template>

<!-- ======================================================================= -->
  <xsl:template match="newest_user">
    <li>
      <a>
        <xsl:attribute name="href">/gallery/<xsl:value-of select="@user_name"/>/<xsl:call-template name="sid"/></xsl:attribute>
        <xsl:value-of select="@user_name"/>
      </a>
    </li>
  </xsl:template>

<!-- ======================================================================= -->
  <xsl:template match="bar">
    <xsl:value-of select="." disable-output-escaping="yes" />
  </xsl:template>

<!-- ======================================================================= -->
  <xsl:template name="nbsp"><xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text></xsl:template>

<!-- ======================================================================= -->
  <xsl:template name="sid">
    <xsl:if test="/root/@sid != ''">?sid=<xsl:value-of select="/root/@sid"/>&amp;realm=wa</xsl:if>
  </xsl:template>
<!-- ======================================================================= -->

</xsl:stylesheet>

