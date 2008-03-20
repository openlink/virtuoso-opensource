<?xml version="1.0" encoding="UTF-8"?>
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
-->
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
  xmlns:dc="http://purl.org/dc/elements/1.1/"
  xmlns:skos="http://www.w3.org/2004/02/skos/core#"
  xmlns:foaf="http://xmlns.com/foaf/0.1/"
  xmlns:virtrdf="http://www.openlinksw.com/schemas/XHTML#"
  xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
  xmlns:wf="http://www.w3.org/2005/01/wf/flow#"
  xmlns:dcterms="http://purl.org/dc/terms/"
  xmlns:bugzilla="http://www.openlinksw.com/schemas/bugzilla#"
  version="1.0">
  <xsl:output method="xml" indent="yes"/>
  <xsl:param name="base" />
  <xsl:template match="/">
      <rdf:RDF>
	  	<xsl:apply-templates select="bugzilla/bug"/>
      </rdf:RDF>
  </xsl:template>
  <xsl:template match="bugzilla/bug">
	<wf:Task rdf:about="{$base}">
	    <xsl:apply-templates select="*"/>
	</wf:Task>
  </xsl:template>
    <xsl:template match="version">
	<bugzilla:version>
	  <xsl:value-of select="."/>
	</bugzilla:version>
  </xsl:template>  
    <xsl:template match="delta_ts">
	<bugzilla:delta>
	  <xsl:value-of select="."/>
	</bugzilla:delta>
        <bugzilla:modified>
	    <xsl:value-of select="."/>
	</bugzilla:modified>
  </xsl:template>
    <xsl:template match="bug_status">
	<bugzilla:state>
	    <xsl:value-of select="."/>
	</bugzilla:state>
    </xsl:template> 
    <xsl:template match="rep_platform">
	<bugzilla:reporterPlatform>
	    <xsl:value-of select="."/>
	</bugzilla:reporterPlatform>
    </xsl:template> 
    <xsl:template match="assigned_to">
	<bugzilla:assignee>
	    <xsl:value-of select="."/>
	</bugzilla:assignee>
  </xsl:template>
  <xsl:template match="reporter">
	<bugzilla:reporter>
	    <xsl:value-of select="."/>
	</bugzilla:reporter>
    </xsl:template> 
    <xsl:template match="product">
	<bugzilla:product>
	  <xsl:value-of select="."/>
	</bugzilla:product>
    </xsl:template> 
    <xsl:template match="component">
	<bugzilla:component>
	    <xsl:value-of select="."/>
	</bugzilla:component>
  </xsl:template>
  <xsl:template match="creation_ts">
	<bugzilla:created>
	    <xsl:value-of select="."/>
	</bugzilla:created>
    </xsl:template>
    <xsl:template match="target_milestone">
	<bugzilla:target_milestone>
	    <xsl:value-of select="."/>
	</bugzilla:target_milestone>
    </xsl:template> 
    <xsl:template match="bug_severity">
	<bugzilla:bug_severity>
	  <xsl:value-of select="."/>
	</bugzilla:bug_severity>
    </xsl:template> 
    <xsl:template match="bug_file_loc">
	<bugzilla:bug_file_loc>
	    <xsl:value-of select="."/>
	</bugzilla:bug_file_loc>
    </xsl:template>
    <xsl:template match="op_sys">
	<bugzilla:operationSystem>
	    <xsl:value-of select="."/>
	</bugzilla:operationSystem>
    </xsl:template> 
    <xsl:template match="estimated_time">
	<bugzilla:estimatedTime>
	    <xsl:value-of select="."/>
	</bugzilla:estimatedTime>
    </xsl:template> 
    <xsl:template match="remaining_time">
	<bugzilla:remainingTime>
	    <xsl:value-of select="."/>
	</bugzilla:remainingTime>
    </xsl:template> 
    <xsl:template match="everconfirmed">
	<bugzilla:everConfirmed>
	    <xsl:value-of select="."/>
	</bugzilla:everConfirmed>
    </xsl:template> 
    <xsl:template match="cclist_accessible">
	<bugzilla:ccListAccessible>
	    <xsl:value-of select="."/>
	</bugzilla:ccListAccessible>
    </xsl:template> 
    <xsl:template match="reporter_accessible">
	<bugzilla:reporterAccessible>
	    <xsl:value-of select="."/>
	</bugzilla:reporterAccessible>
    </xsl:template> 
    <xsl:template match="priority">
	<bugzilla:priority>
	    <xsl:value-of select="."/>
	</bugzilla:priority>
    </xsl:template> 
    <xsl:template match="short_desc">
	<bugzilla:shortDescription>
	    <xsl:value-of select="."/>
	</bugzilla:shortDescription>
  </xsl:template>
  <xsl:template match="*|text()"/>
</xsl:stylesheet>
