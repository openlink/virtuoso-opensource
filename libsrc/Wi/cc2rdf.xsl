<xsl:stylesheet
    xmlns:xsl  ="http://www.w3.org/1999/XSL/Transform" version="1.0"
    xmlns:h    ="http://www.w3.org/1999/xhtml"
    xmlns:cc   ="http://web.resource.org/cc/"
    xmlns:dc   ="http://purl.org/dc/elements/1.1/"
    xmlns:rdf  ="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:dt   ="http://www.w3.org/2001/XMLSchema#"
    >
    <xsl:output method="xml" indent="yes"/>
    <xsl:template match="h:html">
	<xsl:variable name="doc">
	    <rdf:RDF>
		<cc:License rdf:about="http://creativecommons.org/licenses/by-nd/1.0/">
		    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Attribution"/>
		</cc:License>
		<cc:License rdf:about="http://creativecommons.org/licenses/by/1.0/">
		    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Attribution"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>
		</cc:License>
		<cc:License rdf:about="http://creativecommons.org/licenses/by-nd-nc/1.0/">
		    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Attribution"/>
		    <cc:prohibits rdf:resource="http://web.resource.org/cc/CommercialUse"/>
		</cc:License>

		<cc:License rdf:about="http://creativecommons.org/licenses/by-nc/1.0/">
		    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Attribution"/>
		    <cc:prohibits rdf:resource="http://web.resource.org/cc/CommercialUse"/>
		</cc:License>

		<cc:License rdf:about="http://creativecommons.org/licenses/by-nc-sa/1.0/">
		    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Attribution"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/ShareAlike"/>
		    <cc:prohibits rdf:resource="http://web.resource.org/cc/CommercialUse"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/ShareAlike"/>
		</cc:License>

		<cc:License rdf:about="http://creativecommons.org/licenses/by-sa/1.0/">
		    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Attribution"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/ShareAlike"/>
		</cc:License>
		<cc:License rdf:about="http://creativecommons.org/licenses/nd/1.0/">
		    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>
		</cc:License>
		<cc:License rdf:about="http://creativecommons.org/licenses/nd-nc/1.0/">
		    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>
		    <cc:prohibits rdf:resource="http://web.resource.org/cc/CommercialUse"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>
		</cc:License>
		<cc:License rdf:about="http://creativecommons.org/licenses/nc/1.0/">
		    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>
		    <cc:prohibits rdf:resource="http://web.resource.org/cc/CommercialUse"/>
		</cc:License>
		<cc:License rdf:about="http://creativecommons.org/licenses/nc-sa/1.0/">
		    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/ShareAlike"/>
		    <cc:prohibits rdf:resource="http://web.resource.org/cc/CommercialUse"/>
		</cc:License>
		<cc:License rdf:about="http://creativecommons.org/licenses/sa/1.0/">
		    <cc:permits rdf:resource="http://web.resource.org/cc/Reproduction"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/Distribution"/>
		    <cc:permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/Notice"/>
		    <cc:requires rdf:resource="http://web.resource.org/cc/ShareAlike"/>
		</cc:License>

	    </rdf:RDF>
	</xsl:variable>
	<rdf:RDF>
	    <xsl:if test=".//h:a[@rel='cc-license' and starts-with(@href,'http://creativecommons.org/licenses/by-nd/1.0/') and $doc/rdf:RDF/cc:License/@rdf:about = @href]">
		<cc:Work rdf:about="">
		    <xsl:for-each select=".//h:a[@rel='cc-license' and starts-with(@href,'http://creativecommons.org/licenses/by-nd/1.0/') and $doc/rdf:RDF/cc:License/@rdf:about = @href]">
			<cc:license>
			    <xsl:copy-of select="$doc/rdf:RDF/cc:License[@rdf:about=current()/@href]"/>
			</cc:license>
		    </xsl:for-each>
		</cc:Work>
	    </xsl:if>
	</rdf:RDF>
    </xsl:template>
<xsl:template match="text()|@*">
</xsl:template>
</xsl:stylesheet>
