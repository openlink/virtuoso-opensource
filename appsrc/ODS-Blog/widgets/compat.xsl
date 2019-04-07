<?xml version="1.0"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2019 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" xmlns:v="http://www.openlinksw.com/vspx/" exclude-result-prefixes="v" xmlns:vm="http://www.openlinksw.com/vspx/weblog/">

  <xsl:template match="vm:default-post-gen">
    <xsl:call-template name="posts-default"/>
  </xsl:template>

  <xsl:template name="posts-default">
      <!--xsl:message terminate="no">default post template: mode=[<xsl:value-of select="@mode"/>]</xsl:message-->
      <xsl:choose>
	  <xsl:when test="@mode = 'link'">
		<vm:group-heading>
		    <tr>
			<td class="date_separator"><vm:date /></td>
			<td class="date_separator">Category</td>
			<td class="date_separator">Tags</td>
		    </tr>
		</vm:group-heading>
		<vm:linkblog-links>
		    <tr>
			<td class="linkblog_url">
			    <vm:linkblog-url/>
			</td>
			<td class="linkblog_cat">
			    <table cellspacing="0" cellpadding="0" class="linkblog_tags">
				<tr>
				    <vm:linkblog-categories>
					<td>
					    <vm:linkblog-category/>
					</td>
				    </vm:linkblog-categories>
				</tr>
			    </table>
			</td>
			<td class="linkblog_tags">
			    <table cellspacing="0" cellpadding="0" class="linkblog_tags">
				<tr>
				    <vm:linkblog-tags>
					<td>
					    <vm:linkblog-tag/>
					</td>
				    </vm:linkblog-tags>
				</tr>
			    </table>
			</td>
		    </tr>
		</vm:linkblog-links>
	  </xsl:when>
	  <xsl:when test="@mode = 'summary'">
	    <vm:summary-group-heading>
		<div class="date_separator"><vm:date /></div>
	    </vm:summary-group-heading>
	    <div class="summary_post">
		<div class="post">
		    <vm:summary-post-header/>
		</div>
		<div class="post-excerpt" >
		    <vm:summary-post/>
		</div>
		<vm:summary-post-tags/>
	    </div>
	  </xsl:when>
	  <xsl:when test="@mode = 'archive'">
		<vm:summary-group-heading>
		    <div class="date_separator"><vm:date /></div>
		</vm:summary-group-heading>
		<div style="margin-bottom: 5px;">
		    <div class="post">
			<vm:archive-post-title/>
		    </div>
		    <vm:archive-post/>
		</div>
	  </xsl:when>
	  <xsl:otherwise>
		  <div class="message">
		      <div class="post-title">
			  <vm:post-enclosure title=""/>
			  <vm:post-title />
			  <vm:if test="have_community">
			      [<small><vm:post-author format="" /></small>]
			  </vm:if>
		      </div>
		      <div class="post-content">
			  <vm:trackback-discovery/>
			  <vm:post-body />
		      </div>
		      <vm:if test="summary-post-view">
			  <vm:if test="have_tags">
			      <div class="tags">
				  <vm:post-tags delimiter=" | " title="Tags: " />
			      </div>
			  </vm:if>
			  <div class="spread_links">
			      <vm:post-technorati-link title="Find related stories via Technorati">related</vm:post-technorati-link>
			      <vm:post-delicious-link title="Post to del.icio.us">bookmark it!</vm:post-delicious-link>
			      <vm:post-diggit-link title="submit digg.com">digg it!</vm:post-diggit-link>
			      <vm:post-reddit-link title="post reddit">reddit!</vm:post-reddit-link>
			  </div>
			  <div class="post-actions">
			      <vm:post-anchor title="#" />
			      <vm:post-link title="PermaLink" />
			      <vm:post-comments title="" format="Comments [%d]"/>
			      <vm:post-trackbacks title="" format="TrackBack [%d]" />
			      <vm:post-actions />
			  </div>
			  <div class="pubdate">
			      <table cellpadding="0" cellspacing="0" width="100%">
				  <tr>
				      <td>
					  <vm:post-date/>
					  <vm:post-state format="[%s]"/>
				      </td>
				      <td align="right" colspan="3">
					  <vm:post-modification-date title="Modified:"/>
				      </td>
				  </tr>
			      </table>
			  </div>
		      </vm:if>
		      <vm:if test="post-view">
		      <div id="individual">
			  <p><b>About this entry:</b></p>
			  <p>
			      Author: <vm:post-author format=""/><br />
			      <vm:if test="blog_author">
			      Post Status: <vm:post-state format="%s"/><br />
			      </vm:if>
			      Published: <vm:post-date /><br />
			      <vm:post-modification-date title="Modified: "><br /></vm:post-modification-date>
			      <vm:post-tags title="Tags: " delimiter=", "><br /></vm:post-tags>
			      <vm:post-categories title="Categories: " delimiter=", "><br /></vm:post-categories>
			      <vm:post-comments title="Comment Status: " format="%d Comments"><br /></vm:post-comments>
			      <vm:post-trackbacks title="TrackBack Status: " format="%d Trackbacks"><br /></vm:post-trackbacks>
			      <vm:post-enclosure title="Enclosure: "><br /></vm:post-enclosure>
			  </p>
		      </div>
		      <div class="spread_links">
			  <vm:post-technorati-link title="Find related stories via Technorati">related</vm:post-technorati-link>
			  <vm:post-delicious-link title="Post to del.icio.us">bookmark it!</vm:post-delicious-link>
			  <vm:post-diggit-link title="submit digg.com">digg it!</vm:post-diggit-link>
			  <vm:post-reddit-link title="post reddit">reddit!</vm:post-reddit-link>
		      </div>
		      <div class="post-actions">
			  <vm:post-actions />
		      </div>
		      </vm:if>
		  </div>
	  </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <xsl:template name="comments-view">
    <vm:if test="post-view">
      <xsl:copy-of select="*" />
    </vm:if>
  </xsl:template>

  <xsl:template name="trackbacks">
    <vm:if test="trackbacks">
      <div class="trackbacks-ctr">
	<a name="trackback"><h2>TrackBacks</h2></a>
	<div class="tb-url">
	  TrackBack URL for this entry:
	  <span class="url">
	    <vm:trackback-url type="text" />
	  </span>
	</div>
	<div class="tb-url">
	  PingBack URL for this entry:
	  <span class="url">
	    <vm:pingback-url type="text" />
	  </span>
	</div>
	<vm:trackbacks-list/>
      </div>
    </vm:if>
  </xsl:template>

  <xsl:template name="referrals">
    <v:if test="referral">
      <div class="referrals-ctr">
	<a name="referral" /><h2>Referrals</h2>
	<vm:referrals-list/>
      </div>
    </v:if>
  </xsl:template>

  <xsl:template name="related">
    <v:if test="referral">
      <div class="related-ctr">
	      <a name="related" /><h2>Related</h2>
	      <vm:related-list/>
      </div>
    </v:if>
  </xsl:template>

  <xsl:template name="comments">
    <vm:if test="comments-or-enabled">
      <div class="comments-ctr">
	<a name="comments"><h2>Comments</h2></a>
	<vm:comments-list />
	<vm:if test="comments">
	  <div class="tb-url">Comments URL for this entry:
	    <span class="url">
	      <vm:comment-url type="text"/>
	    </span>
	  </div>
	  <br/>
	</vm:if>
      </div>
    </vm:if>
  </xsl:template>

</xsl:stylesheet>
