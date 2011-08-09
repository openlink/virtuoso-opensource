<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet [
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#">
<!ENTITY xsi "http://www.w3.org/2001/XMLSchema-instance">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY dcterms "http://purl.org/dc/terms/">
<!ENTITY dcmitype "http://purl.org/dc/dcmitype/">
<!ENTITY bibo "http://purl.org/ontology/bibo/">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY sioc "http://rdfs.org/sioc/ns#">
<!ENTITY owl "http://www.w3.org/2002/07/owl#">
<!ENTITY content "http://purl.org/rss/1.0/modules/content/">
<!ENTITY cp "http://schemas.openxmlformats.org/package/2006/metadata/core-properties">
<!ENTITY ep "http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
<!ENTITY vt "http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
<!ENTITY a "http://schemas.openxmlformats.org/drawingml/2006/main">
<!ENTITY p "http://schemas.openxmlformats.org/presentationml/2006/main">
<!ENTITY r "http://schemas.openxmlformats.org/package/2006/relationships">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:xsd="&xsd;"
    xmlns:xsi="&xsi;"
    xmlns:dc="&dc;"
    xmlns:dcterms="&dcterms;"
    xmlns:dcmitype="&dcmitype;"
    xmlns:bibo="&bibo;"
    xmlns:foaf="&foaf;"
    xmlns:sioc="&sioc;"
    xmlns:content="&content;"
    xmlns:cp="&cp;"
    xmlns:ep="&ep;"
    xmlns:vt="&vt;"
    xmlns:a="&a;"
    xmlns:owl="&owl;"	
    xmlns:p="&p;"
    xmlns:r="&r;"
    >

  <xsl:output method="xml" indent="yes" cdata-section-elements="content:encoded" />

  <xsl:param name="baseUri" />
  <xsl:param name="urihost" />
  <xsl:param name="fileExt" />
  <xsl:param name="slideDir" />
  <xsl:param name="mode" />
  <xsl:param name="slideNum" />
  <xsl:param name="imageDavPath" />
  <xsl:param name="sourceDoc" />
  <xsl:param name="slideUri" />

    <xsl:variable name="resourceURL" select="vi:proxyIRI($baseUri)"/>
    <xsl:variable name="docIRI" select="vi:docIRI($baseUri)"/>
    <xsl:variable name="docproxyIRI" select="vi:docproxyIRI($baseUri)"/>


  <xsl:variable name="documentResourceURL">
    <xsl:value-of select="$resourceURL"/>
  </xsl:variable>

  <xsl:variable name="sourceDoc">
    <xsl:value-of select="$sourceDoc"/>
  </xsl:variable>

  <xsl:variable name="entityURL">
    <xsl:value-of select="substring-before($baseUri, $fileExt)"/>
  </xsl:variable>

  <xsl:variable name="slideUri">
    <xsl:value-of select="$slideUri"/>
  </xsl:variable>

  <xsl:template match="/">
    <xsl:choose>
      <xsl:when test="contains($mode, 'get_slide_content')">
        <xsl:apply-templates mode="get_slide_content" />
      </xsl:when>
      <xsl:when test="contains($mode, 'get_slide_list')">
        <xsl:apply-templates mode="get_slide_list" />
      </xsl:when>
      <xsl:when test="contains($mode, 'get_image_descs')">
        <xsl:apply-templates mode="get_image_descs" />
      </xsl:when>
      <xsl:when test="contains($mode, 'get_image_file_list')">
        <xsl:apply-templates mode="get_image_file_list" />
      </xsl:when>
      <xsl:when test="contains($mode, 'raw_slide_content')">
        <xsl:apply-templates mode="raw_slide_content" />
      </xsl:when>
      <xsl:when test="contains($mode, 'html_encode_slide_content')">
        <xsl:apply-templates mode="html_encode_slide_content" />
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Template for parsing <file name>.pptx/docProps/core.xml -->
  <xsl:template match="cp:coreProperties">
    <rdf:RDF>
      <!-- Describe a container document which points to the presentation resource -->
      <!-- Container document URI = URI of .pptx file *minus* the file suffix
      <rdf:Description rdf:about="{$entityURL}">
	<rdf:type>bibo:Slideshow</rdf:type>
      -->
	<!-- Alternatively
	<rdf:type>bibo:Document</rdf:type>
	<rdf:type>foaf:Document</rdf:type>
	<rdf:type>sioc:Container</rdf:type>
	<dc:type>Presentation</dc:type>
	-->
      <!--
	<foaf:primaryTopic><xsl:value-of select="$documentResourceURL"/></foaf:primaryTopic>
	<dcterms:hasFormat rdf:resource="{$documentResourceURL}"/>
      </rdf:Description>
      -->

      	<rdf:Description rdf:about="{$docproxyIRI}">
      		<rdf:type rdf:resource="&bibo;Document"/>
      		<dc:title><xsl:value-of select="$baseUri"/></dc:title>
      		<sioc:container_of rdf:resource="{$resourceURL}"/>
      		<dcterms:subject rdf:resource="{$resourceURL}"/>
      		<foaf:primaryTopic rdf:resource="{$resourceURL}"/>
      		<owl:sameAs rdf:resource="{$docIRI}"/>
      	</rdf:Description>
      	

      <!-- The PPTX representation of the presentation i.e. .pptx file URI *including* file suffix -->
      <rdf:Description rdf:about="{$documentResourceURL}">
	<rdf:type>bibo:Slideshow</rdf:type>
	<dcterms:format>application/vnd.openxmlformats-officedocument.presentationml.presentation</dcterms:format>
	<dc:source rdf:resource="{$sourceDoc}"/>
        <rdfs:label><xsl:value-of select="dc:title"/></rdfs:label>
        <xsl:copy-of select="dc:title"/>
        <xsl:copy-of select="dc:subject"/>
        <xsl:copy-of select="dc:description"/>
        <xsl:copy-of select="dc:creator"/>
        <dcterms:created><xsl:value-of select="dcterms:created"/></dcterms:created>
        <dcterms:modified><xsl:value-of select="dcterms:modified"/></dcterms:modified>
	<!-- Container doc link
	<dcterms:isFormatOf rdf:resource="{$entityURL}"/>
	-->
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>

  <!-- Template for parsing <file name>.pptx/docProps/app.xml -->
  <xsl:template match="ep:Properties">
    <rdf:RDF>
      <rdf:Description rdf:about="{$documentResourceURL}">
        <xsl:copy-of select="ep:Slides"/>
        <xsl:apply-templates select="ep:TitlesOfParts" />
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>

  <!-- Get the title of each slide -->
  <xsl:template match="ep:TitlesOfParts/vt:vector">
    <xsl:for-each select="vt:lpstr">
      <xsl:choose>
	<!-- Skip slides which describe the presentation layout/theme/template -->
        <xsl:when test="position() &lt;= (number(../@size) - number(/ep:Properties/ep:Slides))">
        </xsl:when>

        <xsl:otherwise>
	  <dcterms:hasPart>
	    <bibo:Slide>
	      <xsl:attribute name="rdf:about">
	        <xsl:value-of select="concat($documentResourceURL, '#slide', string(position() + number(/ep:Properties/ep:Slides) - number(../@size)))"/>
	      </xsl:attribute>
	      <dcterms:isPartOf rdf:resource="{$documentResourceURL}"/>
              <dc:title><xsl:value-of select="."/></dc:title>
              <rdfs:label><xsl:value-of select="."/></rdfs:label>
	    </bibo:Slide>
	  </dcterms:hasPart>
        </xsl:otherwise>

      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <!-- Template for parsing <file name>.pptx/ppt/slides/slide[:digit:]+ -->
  <!-- Extract slide text -->
  <xsl:template match="p:sld" mode="raw_slide_content">
    <slide_text>
    <xsl:for-each select=".//a:t">
      <xsl:if test="not(contains(., 'All rights reserved' ))"> <!-- Skip copyright notices -->
      <xsl:value-of select="normalize-space()"/><xsl:text> </xsl:text>
      </xsl:if>
    </xsl:for-each>
    </slide_text>
  </xsl:template>
  <!-- Extract slide text into content encoded bullet list -->
  <xsl:template match="p:sld" mode="html_encode_slide_content">
    <rdf:RDF>
      <rdf:Description rdf:about="{$slideUri}">
        <content:encoded>
          &lt;ul&gt;
          <xsl:for-each select=".//p:sp">
            <xsl:choose>
	      <xsl:when test=".//p:ph[@type='title']|.//p:ph[@type='ctrTitle']">
	      </xsl:when>
	        <!-- Skip if a child p:ph element of type "ctrTitle" or "title" is present,
	             since this will be the same as the slide's dc:title value -->
	      <xsl:otherwise>
                <xsl:for-each select=".//a:p">
	          <xsl:if test="not(contains(., 'All rights reserved' ))"> <!-- Skip copyright notices -->
	            <xsl:if test=".//a:t"> <!-- Guard against empty list items -->
                      &lt;li&gt;
                      <xsl:for-each select=".//a:t">
                        <xsl:value-of select="normalize-space()"/><xsl:text> </xsl:text>
                      </xsl:for-each>
                      &lt;/li&gt;
		    </xsl:if>
	          </xsl:if>
                </xsl:for-each>
	      </xsl:otherwise>
	    </xsl:choose>
          </xsl:for-each>
          &lt;/ul&gt;
        </content:encoded>
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>

  <!-- Template for parsing <file name>.pptx/ppt/_rels/presentation.xml.rels -->
  <!-- Get a colon-separated list of slides contained in slides folder, slides/slide1.xml:slides/slide2.xml:... -->
  <xsl:template match="r:Relationships" mode="get_slide_list">
    <xsl:for-each select="r:Relationship[@Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide']/@Target">
      <xsl:value-of select="concat(':', .)"/>
    </xsl:for-each>
  </xsl:template>

  <!-- Templates for parsing <file name>.pptx/ppt/slides/_rels/slide[:digit:]+.xml.rels -->
  <!-- Get descriptions of any images embedded in the slide -->
  <xsl:template match="r:Relationships" mode="get_image_descs">
    <xsl:for-each select="r:Relationship[@Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/image']/@Target">
      <bibo:Slide>
        <xsl:attribute name="rdf:about">
          <xsl:value-of select="concat($documentResourceURL, '#slide', $slideNum)"/>
        </xsl:attribute>
        <foaf:depiction>
	  <xsl:attribute name="rdf:resource">
	    <xsl:value-of select="concat('http://', $urihost, $imageDavPath, substring-after(., 'media/'))"/>
	  </xsl:attribute>
	</foaf:depiction>
      </bibo:Slide>
    </xsl:for-each>
  </xsl:template>
  <!-- Get a colon-separated list of any images embedded in the slide -->
  <xsl:template match="r:Relationships" mode="get_image_file_list">
    <xsl:for-each select="r:Relationship[@Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/image']/@Target">
      <xsl:value-of select="concat(':', .)"/>
    </xsl:for-each>
  </xsl:template>

  <!-- Get the text content of each slide (which could be used as the basis for a free-text search) -->
  <!-- Used for testing with Xalan. Not used with Virtuoso Sponger
  <xsl:template match="r:Relationships" mode="get_slide_content">
    <rdf:RDF>
      <rdf:Description rdf:about="{$documentResourceURL}">
        <rdf:value>
          <xsl:for-each select="r:Relationship[@Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide']/@Target">
            <xsl:apply-templates select="document(concat($slideDir, '/', .))"/>
          </xsl:for-each>
        </rdf:value>
      </rdf:Description>
    </rdf:RDF>
  </xsl:template>
  -->

  <xsl:template match="text()|@*"/>

</xsl:stylesheet>
