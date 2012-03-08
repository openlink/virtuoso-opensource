<?xml version="1.0" encoding="UTF-8"?>
<!--
 -
 -  $Id$
 -
 -  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 -  project.
 -
 -  Copyright (C) 1998-2012 OpenLink Software
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
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     version="1.0"
     xmlns:v="http://www.openlinksw.com/vspx/"
     xmlns:xhtml="http://www.w3.org/1999/xhtml"
     xmlns:vm="http://www.openlinksw.com/vspx/macro">
<xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes"/>

<xsl:template match="vm:form">
<table>
<xsl:apply-templates select="vm:cols"/>
<xsl:copy-of select="vm:attrs/@*"/>
<v:form>
	<xsl:copy-of select="@*"/>
	<xsl:copy-of select="input"/>
	<xsl:apply-templates select="vm:raw"/>
	<xsl:apply-templates select="vm:events"/>
	<xsl:apply-templates select="vm:row"/>
</v:form></table>
</xsl:template>
<xsl:template match="vm:row">
<tr><xsl:copy-of select="@class"/>
<xsl:apply-templates/></tr>
</xsl:template>

<xsl:template match="vm:cols">
<xsl:for-each select="vm:col">
	<colgroup width="{@width}"/>
</xsl:for-each>
</xsl:template>

<xsl:template match="vm:control[@type='edit']">
<xsl:choose>
	<xsl:when test="vm:caption/@pos='left'">
		<td>
			<xsl:copy-of select="@rowspan"/>
			<xsl:copy-of select="@valign"/>
			<span class="{vm:caption/@class}">
			<xsl:value-of select="vm:caption/@value"/></span>
		</td>
		<td>
			<xsl:copy-of select="@rowspan"/>
			<xsl:copy-of select="@valign"/>
			<v:text name="{@name}">
			<xsl:copy-of select="vm:attrs/@*"/>
			<xsl:apply-templates select="vm:events"/>
			</v:text><xsl:apply-templates select="vm:static"/>
		</td>
	</xsl:when>
	<xsl:when test="vm:caption/@pos='right'">
		<td>
			<xsl:copy-of select="@rowspan"/>
			<xsl:copy-of select="@valign"/>
			<v:text name="{@name}">
			<xsl:copy-of select="vm:attrs/@*"/>
			<xsl:apply-templates select="vm:events"/>
			</v:text><xsl:apply-templates select="vm:static"/>
		</td>
		<td>
			<xsl:copy-of select="@rowspan"/>
			<xsl:copy-of select="@valign"/>
			<span class="{vm:caption/@class}">
			<xsl:value-of select="vm:caption/@value"/></span>
		</td>
	</xsl:when>
	<xsl:when test="vm:caption/@pos='top'">
		<td>
			<xsl:copy-of select="@rowspan"/>
			<xsl:copy-of select="@valign"/>
		<table cellpadding="0" cellspacing="0" border="0">
			<tr>
				<td>
					<span class="{vm:caption/@class}">
					<xsl:value-of select="vm:caption/@value"/></span>
				</td>
			</tr>
			<tr>
				<td>
					<v:text name="{@name}">
					<xsl:copy-of select="vm:attrs/@*"/>
					<xsl:apply-templates select="vm:validators"/>
					<xsl:apply-templates select="vm:events"/>
					</v:text><xsl:apply-templates select="vm:static"/>
				</td>
			</tr>
		</table>
		</td>
	</xsl:when>
</xsl:choose>
</xsl:template>

<xsl:template match="vm:events">
		<xsl:apply-templates select="node()|processing-instruction()" />
</xsl:template>
<xsl:template match="vm:validators">
		<xsl:apply-templates select="node()|processing-instruction()" />
</xsl:template>


<xsl:template match="vm:static">
<xsl:choose>
	<xsl:when test="@cell='yes'">
		<td>
		<xsl:copy-of select="@class"/>
		<xsl:copy-of select="@style"/>
		<xsl:copy-of select="@colspan"/>
		<xsl:copy-of select="@rowspan"/>
		<xsl:value-of select="."/></td>
	</xsl:when>
	<xsl:otherwise>
		<span class="{@class}"><xsl:value-of select="."/></span>
	</xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="vm:control[@type='radiobutton']">
<td><v:radio-button>
		<xsl:copy-of select="@name"/>
		<xsl:copy-of select="@value"/>
		<xsl:copy-of select="@group-name"/>
		<xsl:copy-of select="@initial-checked"/>
</v:radio-button></td>
</xsl:template>

<xsl:template match="vm:control[@type='radiobox']">
<xsl:if test="vm:caption/@pos='left'">
<td style="border-width:0"><span class="{vm:caption/@class}"><xsl:value-of select="vm:caption/@value"/></span></td>
</xsl:if>
<td>
<xsl:copy-of select="@colspan"/>
<xsl:copy-of select="rowspan"/>
	<table border="1" frame="box" cellspacing="0" cellpadding="0">
	<xsl:copy-of select="attrs/@*"/>
	<xsl:if test="vm:caption/@pos='top'">
	<caption><span class="{vm:caption/@class}"><xsl:value-of select="vm:caption/@value"/></span></caption>
	</xsl:if>
	<xsl:if test="@dir='vert'">
		<xsl:apply-templates select="vm:items" mode="radio-vert"/>
	</xsl:if>
	<xsl:if test="@dir='horiz'">
		<xsl:apply-templates select="vm:items" mode="radio-horiz"/>
	</xsl:if>
	</table>
</td>
</xsl:template>

<xsl:template match="vm:items" mode="radio-vert">
<xsl:variable name="comp_name" select="../@name"/>
<xsl:variable name="class" select="@class"/>
<tr height="{@top-margin}"><td style="border-width:0" width="{@left-margin}"/><td colspan="2" style="border-width:0"/><td style="border-width:0" width="{@right-margin}"/></tr>
<xsl:for-each  select="vm:group">
	<xsl:variable name="group" select="@name"/>
	<xsl:variable name="each" select="@each"/>
	<xsl:variable name="group_pos" select="position()"/>
	<xsl:if test="string-length(@label)>0">
		<tr><td style="border-width:0" colspan="2"/><td style="border-width:0" class="{$class}"><xsl:value-of select="@label"/></td></tr>
	</xsl:if>
	<xsl:for-each select="vm:item">
		<tr><td style="border-width:0"></td>
		<td style="border-width:0" class="{$class}">
			<v:radio-button value="{@value}">
				<xsl:copy-of select="@initial-checked"/>
<xsl:choose>
	<xsl:when test="../@name">
		<xsl:choose>
			<xsl:when test="@name">
				<xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_',$group,'_',@name)"/></xsl:attribute>
			</xsl:when>
			<xsl:otherwise>
				<xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_',$group,'_',position())"/></xsl:attribute>
			</xsl:otherwise>
		</xsl:choose>
		<xsl:choose>
			<xsl:when test="$each='y'">
				<xsl:choose>
					<xsl:when test="@name">
						<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name,'_',$group,'_',@name)"/></xsl:attribute>
					</xsl:when>
					<xsl:otherwise>
						<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name,'_',$group,'_',position())"/></xsl:attribute>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<xsl:otherwise>
				<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name,'_',$group)"/></xsl:attribute>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:when>
	<xsl:otherwise>
		<xsl:choose>
			<xsl:when test="@name">
				<xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_',$group_pos,'_',@name)"/></xsl:attribute>
			</xsl:when>
			<xsl:otherwise>
				<xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_',$group_pos,'_',position())"/></xsl:attribute>
			</xsl:otherwise>
		</xsl:choose>
		<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name)"/></xsl:attribute>
	</xsl:otherwise>
	</xsl:choose>
	<xsl:apply-templates select="vm:events"/>
</v:radio-button>
</td>
<td style="border-width:0" class="{$class}"><xsl:value-of select="@label"/></td>
<td style="border-width:0"></td>
</tr>
</xsl:for-each>
</xsl:for-each>
<tr height="{@bottom-margin}"><td style="border-width:0" width="{@left-margin}"/><td colspan="2" style="border-width:0"/><td style="border-width:0" width="{@right-margin}"/></tr>
</xsl:template>

<xsl:template match="vm:items" mode="radio-horiz">
<xsl:variable name="comp_name" select="../@name"/>
<xsl:variable name="class" select="@class"/>
<tr height="{@top-margin}"><td style="border-width:0" width="{@left-margin}"/><td colspan="{count(vm:group/vm:item)*2}" style="border-width:0"/><td style="border-width:0" width="{@right-margin}"/></tr>
 <tr><td style="border-width:0"></td><xsl:for-each select="vm:group">
<xsl:variable name="group" select="@name"/>
<xsl:variable name="each" select="@each"/>
<xsl:variable name="group_pos" select="position()"/>
<td style="border-width:0" colspan="{count(vm:item)*2}" class="{$class}">
<xsl:if test="string-length(@label)>0"><xsl:value-of select="@label"/></xsl:if></td>
</xsl:for-each><td style="border-width:0"></td></tr>

<tr><td style="border-width:0"></td><xsl:for-each select="vm:group"><xsl:variable name="group" select="@name"/><xsl:for-each select="vm:item">
<td style="border-width:0"><v:radio-button value="{@value}"><xsl:copy-of select="@initial-checked"/>
<xsl:choose>
	<xsl:when test="../@name">
		<xsl:choose>
			<xsl:when test="@name">
				<xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_',$group,'_',@name)"/></xsl:attribute>
			</xsl:when>
			<xsl:otherwise>
				<xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_',$group,'_',position())"/></xsl:attribute>
			</xsl:otherwise>
		</xsl:choose>

		<xsl:choose>
			<xsl:when test="$each='y'">
				<xsl:choose>
					<xsl:when test="@name">
						<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name,'_',$group,'_',@name)"/></xsl:attribute>
					</xsl:when>
					<xsl:otherwise>
						<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name,'_',$group,'_',position())"/></xsl:attribute>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<xsl:otherwise>
				<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name,'_',$group)"/></xsl:attribute>
			</xsl:otherwise>
		</xsl:choose>

	</xsl:when>
	<xsl:otherwise>
		<xsl:choose>
			<xsl:when test="@name">
				<xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_',$group_pos,'_',@name)"/></xsl:attribute>
			</xsl:when>
			<xsl:otherwise>
				<xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_',$group_pos,'_',position())"/></xsl:attribute>
			</xsl:otherwise>
		</xsl:choose>
		<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name)"/></xsl:attribute>
	</xsl:otherwise>
	</xsl:choose>
	<xsl:apply-templates select="vm:events"/>
</v:radio-button>
</td>
<td style="border-width:0" class="{$class}"><xsl:value-of select="@label"/></td>
</xsl:for-each></xsl:for-each><td style="border-width:0"></td></tr>
<tr height="{@bottom-margin}"><td style="border-width:0" width="{@left-margin}"/><td colspan="{count(vm:group/vm:item)*2}" style="border-width:0"/><td style="border-width:0" width="{@right-margin}"/></tr>
</xsl:template>

<xsl:template match="vm:space">
<td style="border-width:0">
<xsl:copy-of select="@*"/>
</td>
</xsl:template>

<xsl:template match="vm:control[@type='checkbox']">
<xsl:if test="vm:caption/@align='left'">
<td style="border-width:0">
<xsl:if test="string-length(@rowspan) >0">
<xsl:copy-of select="@rowspan"/>
</xsl:if><span class="{vm:caption/@class}">
<xsl:value-of select="vm:caption/@value"/></span></td>
</xsl:if>
<td>
	<xsl:if test="string-length(@rowspan) >0">
	<xsl:copy-of select="@rowspan"/>
	</xsl:if>
	<table border="1" frame="box" cellspacing="0" cellpadding="0">
	<xsl:copy-of select="vm:attrs/@*"/>
	<xsl:if test="vm:caption/@align='top'">
	<caption><span class="{vm:caption/@class}"><xsl:value-of select="caption/@value"/></span></caption>
	</xsl:if>
	<xsl:if test="@dir='vert'">
		<xsl:apply-templates select="vm:items" mode="check-vert"/>
	</xsl:if>
	<xsl:if test="@dir='horiz'">
		<xsl:apply-templates select="vm:items" mode="check-horiz"/>
	</xsl:if>
	</table>
</td>
</xsl:template>

<xsl:template match="vm:items" mode="check-vert">
<tr height="{@top-margin}"><td style="border-width:0" width="{@left-margin}"/><td colspan="2" style="border-width:0"/><td style="border-width:0" width="{@right-margin}"/></tr>
<xsl:variable name="comp_name" select="../@name"/>
<xsl:variable name="class" select="@class"/>

<xsl:for-each select="vm:group">
<xsl:variable name="group" select="@name"/>
<xsl:variable name="group_pos" select="position()"/>
<xsl:variable name="each" select="@each"/>
<xsl:if test="string-length(@label)>0">
<tr><td style="border-width:0" colspan="2"/><td style="border-width:0" colspan="2" class="{$class}"><xsl:value-of select="@label"/></td></tr>
</xsl:if>
<xsl:for-each select="vm:item">
<tr><td style="border-width:0"></td>
<td style="border-width:0">
<v:check-box  value="{@value}"><xsl:copy-of select="@initial-checked"/>
				<xsl:choose>
					<xsl:when test="../@name">
						<xsl:choose>
							<xsl:when test="@name"><xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_', $group,'_',@name)"/></xsl:attribute></xsl:when>
							<xsl:otherwise><xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_', $group,'_',position())"/></xsl:attribute></xsl:otherwise>
						</xsl:choose>
						<xsl:choose>
							<xsl:when test="$each='y'">
								<xsl:choose>
									<xsl:when test="@name">
										<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name,'_',$group,'_',@name)"/></xsl:attribute>
									</xsl:when>
									<xsl:otherwise>
										<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name,'_',$group,'_',position())"/></xsl:attribute>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:when>
							<xsl:otherwise>
								<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name,'_',$group)"/></xsl:attribute>
							</xsl:otherwise>
						</xsl:choose>
					  </xsl:when>
					<xsl:otherwise>
						<xsl:choose>
							<xsl:when test="@name"><xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_', $group_pos, '_',@name)"/></xsl:attribute>							</xsl:when>
							<xsl:otherwise><xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_', $group_pos, '_',position())"/></xsl:attribute></xsl:otherwise>
						</xsl:choose>
						<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name)"/></xsl:attribute>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:apply-templates select="vm:events"/>
</v:check-box>
</td>
<td style="border-width:0" class="{$class}"><xsl:value-of select="@label"/></td>
<td style="border-width:0"></td>
</tr>
</xsl:for-each>
</xsl:for-each>

<tr height="{@bottom-margin}"><td style="border-width:0" width="{@left-margin}"/><td colspan="2" style="border-width:0"/><td style="border-width:0" width="{@right-margin}"/></tr>
</xsl:template>

<xsl:template match="vm:items" mode="check-horiz">
<xsl:variable name="comp_name" select="../@name"/>
<xsl:variable name="class" select="@class"/>
<tr height="{@top-margin}"><td style="border-width:0" width="{@left-margin}"/><td colspan="{count(vm:group/vm:item)}" style="border-width:0"/><td style="border-width:0" width="{@right-margin}"/></tr>
<tr><td style="border-width:0" width="{@left-margin}"/><xsl:for-each select="vm:group">
<td colspan="{count(vm:item)}" style="border-width:0" align="center" class="{$class}"><xsl:value-of select="@label"/></td>
</xsl:for-each><td style="border-width:0" width="{@right-margin}"/></tr>
<tr><td style="border-width:0" width="{@left-margin}"/><xsl:for-each select="vm:group">
	<xsl:for-each select="vm:item">
		<td  style="border-width:0" align="center" class="{$class}"><xsl:value-of select="@label"/></td>
	</xsl:for-each>
</xsl:for-each><td style="border-width:0" width="{@right-margin}"/></tr>
<tr><td style="border-width:0" width="{@left-margin}"/><xsl:for-each select="vm:group">
	<xsl:variable name="group" select="@name"/>
	<xsl:variable name="each" select="@each"/>
	<xsl:variable name="group_pos" select="position()"/>
	<xsl:for-each select="vm:item">
		<td  style="border-width:0" align="center">
			<v:check-box  value="{@value}"><xsl:copy-of select="@initial-checked"/>
				<xsl:choose>
					<xsl:when test="../@name">
						<xsl:choose>
							<xsl:when test="@name"><xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_', $group,'_',@name)"/></xsl:attribute></xsl:when>
							<xsl:otherwise><xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_', $group,'_',position())"/></xsl:attribute></xsl:otherwise>
						</xsl:choose>
						<xsl:choose>
							<xsl:when test="$each='y'">
								<xsl:choose>
									<xsl:when test="@name">
										<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name,'_',$group,'_',@name)"/></xsl:attribute>
									</xsl:when>
									<xsl:otherwise>
										<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name,'_',$group,'_',position())"/></xsl:attribute>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:when>
							<xsl:otherwise>
								<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name,'_',$group)"/></xsl:attribute>
							</xsl:otherwise>
						</xsl:choose>
					  </xsl:when>
					<xsl:otherwise>
						<xsl:choose>
							<xsl:when test="@name"><xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_', $group_pos, '_',@name)"/></xsl:attribute>							</xsl:when>
							<xsl:otherwise><xsl:attribute name="name"><xsl:value-of select="concat($comp_name,'_', $group_pos, '_',position())"/></xsl:attribute></xsl:otherwise>
						</xsl:choose>
						<xsl:attribute name="group-name"><xsl:value-of select="concat($comp_name)"/></xsl:attribute>
					</xsl:otherwise>
				</xsl:choose>
				<xsl:apply-templates select="vm:events"/>
			</v:check-box>
		</td>
	</xsl:for-each>
</xsl:for-each><td style="border-width:0" width="{@right-margin}"/></tr>
<tr height="{@bottom-margin}"><td style="border-width:0" width="{@left-margin}"/><td colspan="{count(vm:group/vm:item)}" style="border-width:0"/><td style="border-width:0" width="{@right-margin}"/></tr>
</xsl:template>

<xsl:template match="vm:control[@type='select']">
<xsl:if test="vm:caption/@align='left'">
<td style="border-width:0">
	<xsl:if test="string-length(@rowspan) >0">
	<xsl:copy-of select="@rowspan"/>
	</xsl:if>
	<xsl:if test="string-length(@valign) >0">
	<xsl:copy-of select="@valign"/>
	</xsl:if><span class="{vm:caption/@class}">
<xsl:value-of select="vm:caption/@value"/></span></td>

<td>
	<xsl:if test="string-length(@rowspan) >0">
	<xsl:copy-of select="@rowspan"/>
	</xsl:if>
	<xsl:if test="string-length(@colspan) >0">
	<xsl:copy-of select="@colspan"/>
	</xsl:if>
	<xsl:if test="string-length(@valign) >0">
	<xsl:copy-of select="@valign"/>
	</xsl:if>
<v:select-list name="{@name}">
	<xsl:copy-of select="vm:attrs/@*"/>
	<xsl:apply-templates select="vm:events"/>
</v:select-list>
</td>
</xsl:if>
<xsl:if test="vm:caption/@align='top'">
<td>
<table border="0"><tr><td>
	<xsl:if test="string-length(@rowspan) >0">
	<xsl:copy-of select="@rowspan"/>
	</xsl:if>
	<xsl:if test="string-length(@valign) >0">
	<xsl:copy-of select="@valign"/>
	</xsl:if>
<span class="{vm:caption/@class}">
<xsl:value-of select="vm:caption/@value"/></span>
</td></tr><tr>
<td>
	<xsl:if test="string-length(@rowspan) >0">
	<xsl:copy-of select="@rowspan"/>
	</xsl:if>
	<xsl:if test="string-length(@colspan) >0">
	<xsl:copy-of select="@colspan"/>
	</xsl:if>
	<xsl:if test="string-length(@valign) >0">
	<xsl:copy-of select="@valign"/>
	</xsl:if>
<v:select-list name="{@name}">
	<xsl:copy-of select="vm:attrs/@*"/>
	<xsl:apply-templates select="vm:events"/>
</v:select-list>
</td>
</tr>
</table>
</td>
</xsl:if>
<xsl:if test="string-length(vm:caption/@align) =0">
<td>
	<xsl:if test="string-length(@rowspan) >0">
	<xsl:copy-of select="@rowspan"/>
	</xsl:if>
	<xsl:if test="string-length(@colspan) >0">
	<xsl:copy-of select="@colspan"/>
	</xsl:if>
	<xsl:if test="string-length(@valign) >0">
	<xsl:copy-of select="@valign"/>
	</xsl:if>
<v:select-list name="{@name}">
	<xsl:copy-of select="vm:attrs/@*"/>
	<xsl:apply-templates select="vm:events"/>
</v:select-list>
</td>

</xsl:if>
</xsl:template>

<xsl:template match="vm:control[@type='textarea']">
<xsl:choose>
	<xsl:when test="vm:caption/@pos='left'">
	<td style="border-width:0">
		<span class="{vm:caption/@class}"><xsl:value-of select="vm:caption/@value"/></span></td>
		<td>
		<xsl:copy-of select="@colspan"/>
		<xsl:copy-of select="@rowspan"/>
			<v:textarea name="{@name}">
			<xsl:copy-of select="vm:attrs/@*"/>
			<xsl:apply-templates select="vm:events"/>
			</v:textarea>
		</td>
	</xsl:when>
	<xsl:when test="vm:caption/@pos='top'">
		<td style="border-width:0">
		<xsl:copy-of select="@colspan"/>
		<xsl:copy-of select="@rowspan"/>
		<xsl:copy-of select="@align"/>
			<table border="0" width="100%">
			<tr><td><span class="{vm:caption/@class}"><xsl:value-of select="vm:caption/@value"/></span>	</td></tr>
			<tr><td>
			<v:textarea name="{@name}">
			<xsl:copy-of select="vm:attrs/@*"/>
			<xsl:apply-templates select="vm:events"/>
			</v:textarea>
			</td></tr>
			</table>
		</td>
	</xsl:when>
</xsl:choose>
</xsl:template>

<xsl:template match="vm:container">
<td>
<xsl:copy-of select="@colspan"/>
<xsl:copy-of select="@rowspan"/>
<xsl:copy-of select="@align"/>
<xsl:copy-of select="@valign"/>
<table>
<xsl:copy-of select="@class"/>
<xsl:copy-of select="@cellspacing"/>
<xsl:copy-of select="@cellpadding"/>
 <xsl:if test="@title">
	<caption><span><xsl:attribute name="class"><xsl:value-of select="@titleclass"/></xsl:attribute><xsl:value-of select="@title"/></span></caption>
	</xsl:if>

<xsl:apply-templates/>
</table>
</td>
</xsl:template>

<xsl:template match="vm:control[@type='button']">
   <xsl:choose>
		<xsl:when test="@action='reset'">
		<input type="reset" name="{@name}" value="{@value}"/>
		</xsl:when>
		<xsl:otherwise>
			<v:button>
				<xsl:copy-of select="@*"/>
			</v:button>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>

<xsl:template match="vm:bgroup">
<td>
<xsl:copy-of select="@*"/>
<xsl:apply-templates select="node()|processing-instruction()" />
</td>
</xsl:template>



</xsl:stylesheet>
