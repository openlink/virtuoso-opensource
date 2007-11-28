<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>
	<xsl:output method="html" omit-xml-declaration="yes" />

	<!-- container -->
	<xsl:template match="fresnel_container">
		<xsl:element name="div">
			<xsl:attribute name="class">
				<xsl:text>fresnel_container</xsl:text>
				<xsl:value-of select="@class" />
			</xsl:attribute>
			<xsl:attribute name="style"><xsl:value-of select="@style" /></xsl:attribute>
			<xsl:apply-templates />
		</xsl:element>
	</xsl:template>

	<!-- resource -->
	<xsl:template match="fresnel_resource">
		<xsl:element name="div">
			<xsl:attribute name="class">
				<xsl:text>fresnel_resource</xsl:text>
				<xsl:value-of select="@class" />
			</xsl:attribute>
			<xsl:attribute name="style"><xsl:value-of select="@style" /></xsl:attribute>
			<xsl:apply-templates />
		</xsl:element>
	</xsl:template>

	<!-- label -->
	<xsl:template match="fresnel_label">
		<xsl:element name="span">
			<xsl:attribute name="class">
				<xsl:text>fresnel_label</xsl:text>
				<xsl:value-of select="@class" />
			</xsl:attribute>
			<xsl:attribute name="style"><xsl:value-of select="@style" /></xsl:attribute>
			<xsl:value-of select="." />
		</xsl:element>
	</xsl:template>

	<!-- property -->
	<xsl:template match="fresnel_property">
		<xsl:element name="div">
			<xsl:attribute name="class">
				<xsl:text>fresnel_property</xsl:text>
				<xsl:value-of select="@class" />
			</xsl:attribute>
			<xsl:attribute name="style"><xsl:value-of select="@style" /></xsl:attribute>
			<xsl:apply-templates />
		</xsl:element>
	</xsl:template>

	<!-- text -->
	<xsl:template match="fresnel_text">
		<xsl:element name="span"><xsl:value-of select="." disable-output-escaping="yes"/></xsl:element>
	</xsl:template>

	<!-- value -->
	<xsl:template match="fresnel_value">
		<xsl:choose>
			<xsl:when test="@type = 'resource'">
				<xsl:element name="div">
					<xsl:attribute name="class">
						<xsl:text>fresnel_value</xsl:text>
						<xsl:value-of select="@class" />
					</xsl:attribute>
					<xsl:attribute name="style"><xsl:value-of select="@style" /></xsl:attribute>
					<xsl:apply-templates />
				</xsl:element>
			</xsl:when>
			<xsl:when test="@type = 'a'">
				<xsl:element name="a">
					<xsl:attribute name="class">
						<xsl:text>fresnel_value</xsl:text>
						<xsl:value-of select="@class" />
					</xsl:attribute>
					<xsl:attribute name="style"><xsl:value-of select="@style" /></xsl:attribute>
					<xsl:attribute name="href"><xsl:value-of select="@href" /></xsl:attribute>
					<xsl:value-of select="." />
				</xsl:element>
			</xsl:when>
			<xsl:when test="@type = 'img'">
				<xsl:element name="img">
					<xsl:attribute name="class">
						<xsl:text>fresnel_value</xsl:text>
						<xsl:value-of select="@class" />
					</xsl:attribute>
					<xsl:attribute name="style"><xsl:value-of select="@style" /></xsl:attribute>
					<xsl:attribute name="src"><xsl:value-of select="@src" /></xsl:attribute>
				</xsl:element>
			</xsl:when>
			<xsl:when test="@type = 'text'">
				<xsl:element name="span">
					<xsl:attribute name="class">
						<xsl:text>fresnel_value</xsl:text>
						<xsl:value-of select="@class" />
					</xsl:attribute>
					<xsl:attribute name="style"><xsl:value-of select="@style" /></xsl:attribute>
					<xsl:value-of select="." />
				</xsl:element>
			</xsl:when>
			<xsl:otherwise/>
		</xsl:choose>
	</xsl:template>

	<xsl:template match="/">
		<xsl:apply-templates />
	</xsl:template>
		
</xsl:stylesheet>
