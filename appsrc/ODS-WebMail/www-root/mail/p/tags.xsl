<xsl:stylesheet xmlns:xsl = "http://www.w3.org/1999/XSL/Transform" version = "1.0" >
<xsl:output method = "text" />

	<xsl:template match = "/">
		<xsl:apply-templates select="tag_list"/>
	</xsl:template>

	<!-- ====================================================================================== -->
	<xsl:template match = "tag_list"><![CDATA[<xsl:stylesheet xmlns:xsl = "http://www.w3.org/1999/XSL/Transform" version = "1.0" >]]>
		<xsl:apply-templates select="allow_tags"/>
		<xsl:apply-templates select="ban_tags"/>
<![CDATA[</xsl:stylesheet>]]>
	</xsl:template>

	<!-- ====================================================================================== -->
	<xsl:template match = "allow_tags">
		<xsl:apply-templates select="*" mode="tags"/>
	</xsl:template>

	<!-- ====================================================================================== -->
	<xsl:template match = "ban_tags">
		<xsl:apply-templates select="*" mode="btags"/>
	</xsl:template>

	<!-- ====================================================================================== -->
	<xsl:template match = "*" mode="tags">
	<![CDATA[<!-- ]]><xsl:value-of select = "{name()}" /><![CDATA[ ========================================================================== -->]]>
	<![CDATA[<xsl:template match = "]]><xsl:value-of select = "{name()}" /><![CDATA[">]]>
			<xsl:element name = "{name()}" >
				<xsl:apply-templates select="*" mode="atts"/>
				<![CDATA[<xsl:apply-templates/>]]>
			</xsl:element>
		<![CDATA[</xsl:template>]]>
	 </xsl:template>

	<!-- ====================================================================================== -->
	<xsl:template match = "*" mode="atts">
			<![CDATA[<xsl:if test="@]]><xsl:value-of select = "{name()}" /><![CDATA[ != ''">]]>
				<![CDATA[<xsl:attribute name="]]><xsl:value-of select = "{name()}" /><![CDATA[">]]>
						<xsl:choose>
						  <xsl:when test="@value != ''">
									<xsl:value-of select = "@value" />
						  </xsl:when>
						  <xsl:otherwise>
						    	<xsl:value-of select = "@avalue" /><![CDATA[<xsl:value-of select = "@]]><xsl:value-of select = "{name()}" /><![CDATA[" />]]>
						  </xsl:otherwise>
						</xsl:choose>
				<![CDATA[</xsl:attribute>]]>
			<![CDATA[</xsl:if>]]>
	 </xsl:template>

	<!-- ====================================================================================== -->
	<xsl:template match = "*" mode="btags">
	<![CDATA[<!-- ]]><xsl:value-of select = "{name()}" /><![CDATA[ ========================================================================== -->]]>
	<![CDATA[<xsl:template match = "]]><xsl:value-of select = "{name()}" /><![CDATA["/>]]>
	 </xsl:template>


</xsl:stylesheet> 