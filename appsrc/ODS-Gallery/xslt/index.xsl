<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2006 OpenLink Software
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

  <xsl:output method="html" indent="yes"/>

  <xsl:template match="/">
    <html>
      <head>
        <title>Photo Gallery</title>

        <script language="JavaScript" src="/photos/res/js/ajax.js"></script>
        <script language="JavaScript" src="/photos/res/js/dataset.js"></script>
        <script language="JavaScript" src="/photos/res/js/ui.js"></script>

        <script language="JavaScript" src="/photos/res/js/gallery.js"></script>
        <script language="JavaScript" src="/photos/res/proxy.vsp"></script>
        <script language="JavaScript" src="/photos/res/js/slideshow.js"></script>
        <script type="text/javascript" src="/photos/res/js/range.js"></script>
        <script type="text/javascript" src="/photos/res/js/timer.js"></script>
        <script language="JavaScript" src="/photos/res/js/slider.js"></script>
        <link rel="stylesheet" href="/photos/res/css/gallery.css" type="text/css"/>
        <link rel="stylesheet" href="/photos/res/css/winclassic.css" type="text/css"/>
      </head>
        <xsl:apply-templates/>
    </html>
  </xsl:template>


<!-- ======================================================================= -->
  <xsl:template match="root">
    <body>
      <div id="wrapper">
      <div id="head">
        <h1>
          oGallery
        </h1>
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
       <div id="wrapper">
      <form name="f1" style="display:inline;">
      <div id="head">
        <h1>
          oGallery
        </h1>
      </div>
      <div id="nav">
        <ul>
          <xsl:choose>
            <xsl:when test="@sid != ''">
              <li id="hello">
                Hello, <xsl:value-of select="user/first_name"/>
              </li>
              <li id="my_albums_tab">
                My albums
              </li>
              <li id="new_album_tab">
                New album
              </li>
              <!--
              <li id="settings_tab">
                Settings
              </li>
              -->
              <li id="wa">
                <xsl:value-of select="wa_home_title"/>
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
      <div id="grad">
        <xsl:call-template name="nbsp"/>
      </div>
      <div id="error_box" style="display:none;">
        <xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text>
      </div>

      <table cellpadding="0" cellspacing="4">
        <tr>
          <td id="left_col" valign="top">

            <div id="albums_list" class="toolbar">
              <h3>My Albums</h3>
            </div>

            <div id="albums_man" class="toolbar">
              <h3>Manage</h3>
              <ul>
                <li id="new_album_tab">
                  Create new album
                </li>
              </ul>
            </div>

            <div id="toolbar" class="toolbar">
              <ul>
                <li/>
              </ul>
            </div>
            <div id="feeds" class="toolbar">
              <h3>Feeds</h3>
              <ul>
                <li id="feed_atom">
                  Atom
                </li>
                <li id="feed_rss">
                  RSS 2.0
                </li>
                <li id="feed_rdf">
                  RDF
                </li>
                <li id="feed_xbel">
                  XBEL
                </li>
                <li id="feed_mrss">
                  mRSS
                </li>
              </ul>
            </div>

          </td>
          <td id="right_col" valign="top">

            <div id="info" style="display:none;">
              <xsl:call-template name="nbsp"/>
            </div>

            <div id="albums">

            </div>

            <xsl:call-template name="new_album"/>
            <xsl:call-template name="edit_album"/>

            <div id="upload_image" style="display:none;">
              <iframe width="100%" height="750" src="" border="0" frameborder="0" ></iframe>
            </div>

            <div id="images" style="display:none;">
              <xsl:call-template name="nbsp"/>
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
  </body>
  </xsl:template>


<!-- ========================================================================= -->
<xsl:template name="comments">
  <div id="comments" style="display:none;">
    <table class="ramka" cellpadding="10">
      <tr>
        <td valign="top" class="left">
          <h2 class="l">Comments</h2>
          <div id="comments_list">
            Loading ...
          </div>
        </td>
        <td valign="top" class="right">
          <h2>Add new comment</h2>
          Comment:<br/>
          <textarea name="new_comment" id="new_comment"><xsl:call-template name="nbsp"/></textarea>
          <br/>
          <button type="button" name="bnt_new_comment" id="">Cancel</button>
          <button type="button" name="bnt_new_comment" id="bnt_new_comment">Save</button>
        </td>
      </tr>
    </table>
  </div>
  </xsl:template>

<!-- ========================================================================= -->
<xsl:template name="slideshow">
  <div style="position:relative;visibility: hidden;border:1px solid #000;" id="slideshow">
    <div id="canvas0" style="position:absolute;top:0;left:12px;filter:alpha(opacity=10);-moz-opacity:10;">
      <xsl:call-template name="nbsp"/>
    </div>
    <div id="canvas1" style="position:absolute;top:0;left:12px;filter:alpha(opacity=10);-moz-opacity:10;visibility: hidden;">
      <xsl:call-template name="nbsp"/>
    </div>
  </div>
  <div style="position:relative;">
</div>

  </xsl:template>

<!-- ========================================================================= -->
<xsl:template name="ajax_action">

        <script defer="defer" type="text/javascript">
      var sid = '<xsl:value-of select="@sid"/>';
      var realm = '<xsl:value-of select="@realm"/>';
      var home_path = '<xsl:value-of select="gallery"/>';

      var gallery_load_albums = {
        delay: 200,
        prepare: function(path) { return Array(sid,path); },
        call: proxies.SOAP.dav_browse,
        finish: gallery.showCollections,
        onException: gallery.showError
      }

      var gallery_load_images = {
        delay: 200,
        prepare: function(current_id) {ds_albums.setCurrent(current_id); return Array(sid,ds_albums.list[current_id].fullpath); },
        call: proxies.SOAP.dav_browse,
        finish: function (p) {ds_current_album.loadList(p.albums); gallery.showImages()},
        onException: gallery.showError
      }

      var gallery_new_album = {
        delay: 200,
        prepare:function() {
                  if(document.f1.visibility[0].checked){
                    v=1
                  }else{
                    v=0
                  };

                  return Array(sid,
                               home_path,
                               document.getElementById('new_album_name').value,
                               v,
                               document.getElementById('new_album_pub_date_year').value + '-' + document.getElementById('new_album_pub_date_month').value + '-' + document.getElementById('new_album_pub_date_day').value + 'T00:00:00',
                               document.getElementById('new_album_description').value);
                },

        call: proxies.SOAP.create_new_album,
        finish: gallery.addCollections,
        onException: gallery.showError
      }

      var gallery_edit_album = {
        delay: 200,
        prepare: function(current_id) {
                  if(document.f1.album_visibility[0].checked){
                    v=1
                  }else{
                    v=0
                  };
                  return Array(sid,
                               home_path,
                               document.getElementById('edit_album_name_old').value,
                               document.getElementById('edit_album_name').value,
                               v,
                               document.getElementById('edit_album_pub_date_year').value + '-' + document.getElementById('edit_album_pub_date_month').value + '-' + document.getElementById('edit_album_pub_date_day').value + 'T00:00:00',
                               document.getElementById('edit_album_description').value);
                 },
        call: proxies.SOAP.edit_album,
        finish: gallery.editCollections,
        onException: gallery.showError
      }

      var gallery_delete_images = {
        delay: 200,
        prepare: function(ids) { return Array(sid,'r',ids)},
        call: proxies.SOAP.dav_delete,
        finish: function(p) {ds_current_album.removeImageFromList(p)},
        onException: gallery.showError
      }

      var gallery_delete_album = {
        delay: 200,
        prepare: function(ids) { return Array(sid,'c',ids)},
        call: proxies.SOAP.dav_delete,
        finish: gallery.removeCollection,
        onException: gallery.showError
      }

      var gallery_image_get_comments = {
        delay: 200,
        prepare: function(id) { return Array(sid,id)},
        call: proxies.SOAP.get_comments,
        finish: function(p) {gallery.showComments(p)},
        onException: gallery.showError
      }

      var gallery_image_add_comments = {
        delay: 200,
        prepare: function(comment) {  return Array(sid,comment)},
        call: proxies.SOAP.add_comment,
        finish: function(p) {gallery.addComment(p)},
        onException: gallery.showError
      }

      var gallery_image_get_exif = {
        delay: 200,
        prepare: function(id) { return Array(sid,id)},
        call: proxies.SOAP.get_attributes,
        finish: function(p) {gallery.addExif(p)},
        onException: gallery.showError
      }

      var gallery_image_get_image = {
        delay: 200,
        prepare: function(id) { return Array(sid,id)},
        call: proxies.SOAP.get_image,
        finish: function(p) {
                  ds_current_album.addImageToList(p);
                  gallery.showImagesInside();
                },
        onException: gallery.showError
      }

      var gallery_image_edit = {
        delay: 200,
        prepare: function(id) {
                  if(document.f1.image_visibility[0].checked){
                    v=1
                  }else{
                    v=0
                  };

                  return Array(sid,
                               document.f1.edit_image_path.value,
                               document.f1.edit_image_name_old.value,
                               document.f1.edit_image_name.value,
                               document.f1.edit_image_description.value,
                               v)
                 },
        call: proxies.SOAP.edit_image,
        finish: function(p) {gallery.image_edit_finish(p)},
        onException: gallery.showError
      }

    </script>

  </xsl:template>




<!-- ======================================================================= -->
  <xsl:template name="new_album">
      <div id="new_album" style="display:none;">
              <h3>Create new album</h3>
              <table id="forma">
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
                  <td>Date</td>
                  <td>
                      <select name="new_album_pub_date_month" id="new_album_pub_date_month">
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
                      <select name="new_album_pub_date_day" id="new_album_pub_date_day">
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
                      <xsl:text>/</xsl:text>
                      <select name="new_album_pub_date_year" id="new_album_pub_date_year">
                        <option value="2001">2001</option>
                        <option value="2002">2002</option>
                        <option value="2003">2003</option>
                        <option value="2004">2004</option>
                        <option value="2005">2005</option>
                        <option value="2006">2006</option>
                      </select>
                      <script>
                        var d = new Date();
                        var year = d.getFullYear();
                        var month = d.getMonth()
                        var month = d.getDay()

                        document.f1.new_album_pub_date_day.selectedIndex = d.getDate()-1;
                        document.f1.new_album_pub_date_month.selectedIndex = d.getMonth();
                        document.f1.new_album_pub_date_year.selectedIndex = String(d.getFullYear()).substring(3)-1;
                      </script>
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
                    <td></td>
                    <td>
                        <button type="button" id="new_album_close" name="btn_new_album" >Cancel</button>
                      </td>
                    <td>
                      <button type="button" name="btn_new_album" OnClick="gallery.new_album_action()">Create</button>
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
                  <td>Date</td>
                  <td>
                      <select name="edit_album_pub_date_month" id="edit_album_pub_date_month">
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
                      <select name="edit_album_pub_date_day" id="edit_album_pub_date_day">
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
                      <xsl:text>/</xsl:text>
                      <select name="edit_album_pub_date_year" id="edit_album_pub_date_year">
                        <option value="2000">2000</option>
                        <option value="2001">2001</option>
                        <option value="2002">2002</option>
                        <option value="2003">2003</option>
                        <option value="2004">2004</option>
                        <option value="2005">2005</option>
                        <option value="2006">2006</option>
                      </select>
                    </td>
                  </tr>
                  <tr>
                    <td><label for="edit_album_name">Visible</label></td>
                    <td>
                      <input type="radio" name="album_visibility" value="1" />for all (public)<br/>
                      <input type="radio" name="album_visibility" value="0"/>only for me (private )
                    </td>
                  </tr>
                  <tfoot>
                    <tr>
                      <td></td>
                      <td style="padding-top:20px;">
                        <button type="button" name="btn_edit_album" OnClick="gallery.edit_album_action()">Save</button>
                        <button type="button" name="btn_edit_album_cancel" OnClick="gallery.edit_album_cancel();">Cancel</button>
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
  <xsl:template name="nbsp"><xsl:text disable-output-escaping="yes">&amp;nbsp;</xsl:text></xsl:template>

<!-- ======================================================================= -->
  <xsl:template name="sid">
    <xsl:if test="/root/@sid != ''">?sid=<xsl:value-of select="/root/@sid"/>&amp;realm=wa</xsl:if>
  </xsl:template>
</xsl:stylesheet>

