<?xml version="1.0" encoding="UTF-8"?>
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
 -  
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:param name="fragment"/>
	<xsl:param name="database"/>
	<xsl:template match="table">
		<xsl:variable name="table_name" select="@name"/>
		<xsl:variable name="table_parent" select="@parent"/>
		<xsl:choose>
			<xsl:when test="$database/table[@name = $table_name]">
				<xsl:choose>
					<xsl:when test="@drop = 'true'">
						<table name="{@name}" mode="drop"/>
					</xsl:when>
					<xsl:otherwise>
						<table name="{@name}" mode="diff">
							<xsl:choose>
								<xsl:when test="$database//table[@name = $table_name]/@parent != $table_parent">
									<xsl:choose>
										<xsl:when test="$database//table[@name = $table_name]/@parent != 'xsi:nil'  and $table_parent != 'xsi:nil'">
											<parent opeation="modify" value="{$table_parent}"/>
										</xsl:when>
										<xsl:when test="$database//table[@name = $table_name]/@parent != 'xsi:nil'  and $table_parent = 'xsi:nil'">
											<parent opeation="drop"/>
										</xsl:when>
										<xsl:when test="$database//table[@name = $table_name]/@parent = 'xsi:nil'  and $table_parent != 'xsi:nil'">
											<parent opeation="add" value="{$table_parent}"/>
										</xsl:when>
									</xsl:choose>
								</xsl:when>
							</xsl:choose>
							<xsl:for-each select="column">
								<xsl:variable name="column_name" select="@name"/>
								<xsl:variable name="column_type" select="@type"/>
								<xsl:variable name="column_prec" select="@prec"/>
								<xsl:variable name="column_scale" select="@scale"/>
								<xsl:variable name="column_type_text" select="@type-text"/>
								<xsl:variable name="column_not_nullable" select="@nullable"/>
								<xsl:variable name="column_collation" select="@collation"/>
								<xsl:variable name="column_identity" select="@identity"/>
								<xsl:variable name="column_identified_by" select="@identified_by"/>
								<xsl:choose>
									<xsl:when test="$database//table[@name = $table_name]/column[@name = $column_name]">
										<xsl:choose>
											<xsl:when test="not($database//table[@name = $table_name]/column[@name = $column_name]/@type = $column_type) or  
							                            (($column_prec != '') and not ($database//table[@name = $table_name]/column[@name = $column_name]/@prec = $column_prec)) or
							                            (($column_scale != '') and  not ($database//table[@name = $table_name]/column[@name = $column_name]/@scale = $column_scale)) or
							                             not ($database//table[@name = $table_name]/column[@name = $column_name]/@nullable = $column_not_nullable) or
							                             not ($database//table[@name = $table_name]/column[@name = $column_name]/@collation = $column_collation) or
							                             not ($database//table[@name = $table_name]/column[@name = $column_name]/@identity = $column_identity) or
							                             not ($database//table[@name = $table_name]/column[@name = $column_name]/@identified_by = $column_identified_by)">
												<column op="modify" name="{@name}" type="{$column_type}" type-text="{$column_type_text}" prec="{$column_prec}"  scale="{$column_scale}" nullable="{$column_not_nullable}" collation="{$column_collation}" identity="{$column_identity}" identified_by="{$column_identified_by}"/>
											</xsl:when>
										</xsl:choose>
									</xsl:when>
									<xsl:otherwise>
										<column op="add" name="{@name}" type="{$column_type}" prec="{$column_prec}"  scale="{$column_scale}" type-text="{$column_type_text}" nullable="{$column_not_nullable}" collation="{$column_collation}" identity="{$column_identity}" identified_by="{$column_identified_by}"/>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:for-each>
							<xsl:apply-templates select="$database//table[@name = $table_name]" mode="reverse_columns_check"/>
							<!-- PK check-->
							<xsl:choose>
								<xsl:when test="pk">
									<xsl:choose>
										<xsl:when test="$database//table[@name = $table_name]/pk">
											<xsl:choose>
												<xsl:when test="not(count($database//table[@name = $table_name]/pk/field) != count(pk/field))">
													<pk is_unique="{pk/@is_unique}" is_clustered="{pk/@is_clustered}" is_oid="{@pk/is_oid}">
														<xsl:for-each select="pk/field">
															<xsl:copy-of select="."/>
															<xsl:if test="not($database//table[@name = $table_name]/pk/field[@ord = current()/@ord and @col = current()/@col])">
																<xsl:attribute name="op">modify</xsl:attribute>
															</xsl:if>
														</xsl:for-each>
													</pk>
												</xsl:when>
												<xsl:otherwise>
													<pk op="modify" is_unique="{pk/@is_unique}" is_clustered="{pk/@is_clustered}" is_oid="{@pk/is_oid}">
														<xsl:copy-of select="pk/field"/>
													</pk>
												</xsl:otherwise>
											</xsl:choose>
										</xsl:when>
										<xsl:otherwise>
											<pk op="add" is_unique="{pk/@is_unique}" is_clustered="{pk/@is_clustered}" is_oid="{@pk/is_oid}">
												<xsl:copy-of select="pk/field"/>
											</pk>
										</xsl:otherwise>
									</xsl:choose>
								</xsl:when>
								<xsl:otherwise>
									<pk op="drop"/>
								</xsl:otherwise>
							</xsl:choose>
							<!-- end of pk processing-->
							<xsl:for-each select="fk">
								<xsl:variable name="ref_table" select="@ref_table"/>
								<xsl:choose>
									<xsl:when test="$database//table[@name = $table_name]/fk[@ref_table = $ref_table]">
										<xsl:choose>
											<xsl:when test="not(count($database//table[@name = $table_name]/fk[@ref_table = $ref_table]/reference) != count(reference))">
												<fk ref_table="{$ref_table}" delete_rule="{@delete_rule}" update_rule="{@update_rule}">
													<xsl:for-each select="reference">
														<xsl:copy-of select="."/>
														<xsl:if test="not($database//table[@name = $table_name]/fk[@ref_table = $ref_table]/reference[@col = current()/@col and @ref_col = current()/@ref_col])">
															<xsl:attribute name="op">modify</xsl:attribute>
														</xsl:if>
													</xsl:for-each>
												</fk>
											</xsl:when>
											<xsl:otherwise>
												<fk op="modify" ref_table="{$ref_table}" delete_rule="{@delete_rule}" update_rule="{@update_rule}">
													<xsl:copy-of select="reference"/>
												</fk>
											</xsl:otherwise>
										</xsl:choose>
									</xsl:when>
									<xsl:otherwise>
										<fk op="add" ref_table="{$ref_table}" delete_rule="{@delete_rule}" update_rule="{@update_rule}">
											<xsl:for-each select="reference">
												<reference col="{@col}" ref_col="{@ref_col}"/>
											</xsl:for-each>
										</fk>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:for-each>
							<xsl:apply-templates select="$database//table[@name = $table_name]" mode="reverse_fk_check"/>
							<!-- Check constraints -->
							<xsl:for-each select="constraint">
								<xsl:variable name="constraint_name" select="@name"/>
								<xsl:variable name="constraint_value" select="code/text()"/>
								<xsl:choose>
									<xsl:when test="$database//table[@name = $table_name]/constraint[@name = $constraint_name]">
										<xsl:choose>
											<xsl:when test="not($database//table[@name = $table_name]/constraint[@name = $constraint_name]/code/text() = $constraint_value)">
												<constraint op="modify" name="{$constraint_name}">
												 <code><xsl:value-of select="code/text()"/></code>
												</constraint>
											</xsl:when>
										</xsl:choose>
									</xsl:when>
									<xsl:otherwise>
												<constraint op="add" name="{$constraint_name}">
												 <code><xsl:value-of select="code/text()"/></code>
												</constraint>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:for-each>
							<xsl:apply-templates select="$database//table[@name = $table_name]" mode="reverse_constraints_check"/>
						</table>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:when>
			<xsl:otherwise>
				<table name="{@name}" parent="{@parent}">
					<xsl:copy-of select="column"/>
					<xsl:copy-of select="constraint"/>
					<xsl:copy-of select="pk"/>
					<xsl:copy-of select="fk"/>
				</table>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	
	<xsl:template match="column" mode="reverse_columns_check">
		<xsl:variable name="its_name" select="@name"/>
		<xsl:variable name="table_name" select="../@name"/>
		<xsl:choose>
		<xsl:when test="$fragment/table[@name = $table_name]">
			<xsl:choose>
				<xsl:when test="$fragment/table[@name = $table_name]/column[@name = $its_name]"/>
				<xsl:otherwise>
					<column op="drop" name="{@name}"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:when>
		<xsl:otherwise>
			<xsl:choose>
				<xsl:when test="$fragment/column[@name = $its_name]"/>
				<xsl:otherwise>
					<column op="drop" name="{@name}"/>
				</xsl:otherwise>
			</xsl:choose>
	 </xsl:otherwise>
	 </xsl:choose>
	</xsl:template>
	
	<xsl:template match="fk" mode="reverse_fk_check">
		<xsl:variable name="its_ref_table" select="@ref_table"/>
		<xsl:variable name="its_table" select="../@name"/>
		<xsl:choose>
		<xsl:when test="$fragment/table[@name = $table_name]">
			<xsl:choose>
				<xsl:when test="$fragment/tables/table[@name = $its_table]/fk[@ref_table = $its_ref_table]"/>			
				<xsl:otherwise>
					<fk op="drop" ref_table="@ref_table">
						<xsl:copy-of select="reference"/>
					</fk>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:when>
		<xsl:otherwise>
			<xsl:choose>
				<xsl:when test="$fragment/table[@name = $its_table]/fk[@ref_table = $its_ref_table]"/>			
			  <xsl:otherwise>
					<fk op="drop" ref_table="@ref_table">
						<xsl:copy-of select="reference"/>
					</fk>
			  </xsl:otherwise>
			</xsl:choose>
	 </xsl:otherwise>
	 </xsl:choose>
	</xsl:template>
	
	<xsl:template match="constraint" mode="reverse_constraints_check">
		<xsl:variable name="its_name" select="@name"/>
		<xsl:variable name="table_name" select="../@name"/>
		<xsl:choose>
		<xsl:when test="$fragment/table[@name = $table_name]">		
			<xsl:choose>
				<xsl:when test="$fragment/table[@name = $table_name]/constraint[@name = $its_name]"/>
				<xsl:otherwise>
					<constraint op="drop" name="{@name}"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:when>
		<xsl:otherwise>			
			<xsl:choose>
				<xsl:when test="$fragment/constraint[@name = $its_name]"/>
				<xsl:otherwise>
					<column op="drop" name="{@name}"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:otherwise>
	</xsl:choose>	
	</xsl:template>
	
</xsl:stylesheet>
<!--
						</xsl:when>
						<xsl:otherwise>
							<pk is_unique="{$pk_is_unique}" is_clustered="{$pk_is_clustered}" is_oid="{$pk_is_oid}">
								<xsl:choose>
									<xsl:when test="$database//table[@name = $table_name]/pk">
										<xsl:attribute name="op">modify</xsl:attribute>
										<xsl:apply-templates select="$database//table[@name = $table_name]/pk" mode="reverse_pk_check"/>
									</xsl:when>
									<xsl:otherwise>
										<xsl:attribute name="op">drop</xsl:attribute>
									</xsl:otherwise>
								</xsl:choose>
								<xsl:for-each select="pk/field">
									<xsl:variable name="pk_col" select="@col"/>
									<xsl:variable name="pk_ord" select="@ord"/>
									<xsl:choose>
										<xsl:when test="$database//table[@name = $table_name]/pk/field[@col = $pk_col]/@col">
											<xsl:choose>
												<xsl:when test="not($database//table[@name = $table_name]/pk/field[@col = $pk_col]/@ord  = $pk_ord )">
													<field op="modify" col="{$pk_col}" ord="{$pk_ord}"/>
												</xsl:when>
											</xsl:choose>
										</xsl:when>
										<xsl:otherwise>
											<field op="add" col="{$pk_col}" ord="{$pk_ord}"/>
										</xsl:otherwise>
									</xsl:choose>
								</xsl:for-each>
							</pk>
						</xsl:otherwise>
					</xsl:choose>


							<xsl:when test="$database//table[@name = $table_name]/column[@name = $column_name]">
						
								<xsl:choose>
									<xsl:when test="not($database//table[@name = $table_name]/column[@name = $column_name]/@type = $column_type) or  
							                             not ($database//table[@name = $table_name]/column[@name = $column_name]/@nullable = $column_not_nullable) or
							                             not ($database//table[@name = $table_name]/column[@name = $column_name]/@collation = $column_collation) or
							                             not ($database//table[@name = $table_name]/column[@name = $column_name]/@identity = $column_identity) or
							                             not ($database//table[@name = $table_name]/column[@name = $column_name]/@identified_by = $column_identified_by)">
										<column op="modify" name="{@name}" type="{$column_type}" nullable="{$column_not_nullable}" collation="{$column_collation}" identity="{$column_identity}" identified_by="{$column_identified_by}"/>
									</xsl:when>
								</xsl:choose>
							</xsl:when>

 -->
