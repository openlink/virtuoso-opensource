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
  <xsl:output method="xml" indent="yes" cdata-section-elements="style"/>
  <xsl:include href="comp/page.xsl"/>
  <xsl:include href="comp/dialog.xsl"/>
  <xsl:include href="comp/common.xsl"/>
  <xsl:include href="comp/login.xsl"/>
  <xsl:include href="comp/menubar.xsl"/>
  <xsl:include href="comp/title.xsl"/>
  <xsl:include href="comp/group_list.xsl"/>
  <xsl:include href="comp/group_view.xsl"/>
  <xsl:include href="comp/thread_view.xsl"/>
  <xsl:include href="comp/nntp_cal.xsl"/>
  <xsl:include href="comp/post.xsl"/>
  <xsl:include href="comp/search.xsl"/>
  <xsl:include href="comp/search_res.xsl"/>
  <xsl:include href="comp/rss_group.xsl"/>
  <xsl:include href="comp/adv_srh.xsl"/>
  <xsl:include href="comp/attach.xsl"/>
  <xsl:include href="comp/rss_list.xsl"/>
  <xsl:include href="comp/rss_del.xsl"/>
  <xsl:include href="comp/nntpf_tags.xsl"/>
<!-- FS include
  <xsl:include href="../samples/wa/comp/ods_bar.xsl"/>
-->    
  <xsl:include href="../wa/comp/ods_bar.xsl"/>
</xsl:stylesheet>
