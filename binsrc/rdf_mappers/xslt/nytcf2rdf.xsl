<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xsl:stylesheet [
<!ENTITY xsd "http://www.w3.org/2001/XMLSchema#">
<!ENTITY rdf "http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<!ENTITY rdfs "http://www.w3.org/2000/01/rdf-schema#">
<!ENTITY foaf "http://xmlns.com/foaf/0.1/">
<!ENTITY dc "http://purl.org/dc/elements/1.1/">
<!ENTITY nyt "http://www.nytimes.com/">
]>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:vi="http://www.openlinksw.com/virtuoso/xslt/"
    xmlns:rdf="&rdf;"
    xmlns:rdfs="&rdfs;"
    xmlns:foaf="&foaf;"
    xmlns:dc="&dc;"
    xmlns:nyt="&nyt;"
    >

    <xsl:output method="xml" indent="yes" />

    <xsl:template match="/result_set/status">
      <xsl:if test="text() = 'OK'">
        <xsl:apply-templates mode="ok" select="/result_set/results/candidate"/>
      </xsl:if>
    </xsl:template>

    <xsl:template match="candidate" mode="ok">
      <rdf:Description rdf:about="{$baseUri}">
	  <nyt:candidate_name><xsl:value-of select="candidate_name"/></nyt:candidate_name>
	  <nyt:committee_id><xsl:value-of select="committee_id"/></nyt:committee_id>
	  <nyt:party><xsl:value-of select="party"/></nyt:party>
	  <nyt:total_receipts><xsl:value-of select="total_receipts"/></nyt:total_receipts>
	  <nyt:total_disbursements><xsl:value-of select="total_disbursements"/></nyt:total_disbursements>
	  <nyt:cash_on_hand><xsl:value-of select="cash_on_hand"/></nyt:cash_on_hand>
	  <nyt:net_individual_contributions><xsl:value-of select="net_individual_contributions"/></nyt:net_individual_contributions>
	  <nyt:net_party_contributions><xsl:value-of select="net_party_contributions"/></nyt:net_party_contributions>
	  <nyt:net_pac_contributions><xsl:value-of select="net_pac_contributions"/></nyt:net_pac_contributions>
	  <nyt:net_candidate_contributions><xsl:value-of select="net_candidate_contributions"/></nyt:net_candidate_contributions>
	  <nyt:federal_funds><xsl:value-of select="federal_funds"/></nyt:federal_funds>
	  <nyt:total_contributions_less_than_200><xsl:value-of select="total_contributions_less_than_200"/></nyt:total_contributions_less_than_200>
	  <nyt:total_contributions_2300><xsl:value-of select="total_contributions_2300"/></nyt:total_contributions_2300>
	  <nyt:net_primary_contributions><xsl:value-of select="net_primary_contributions"/></nyt:net_primary_contributions>
	  <nyt:net_general_contributions><xsl:value-of select="net_general_contributions"/></nyt:net_general_contributions>
	  <nyt:total_refunds><xsl:value-of select="total_refunds"/></nyt:total_refunds>
	  <nyt:date_coverage_from rdf:datatype="&xsd;date"><xsl:value-of select="date_coverage_from"/></nyt:date_coverage_from>
	  <nyt:date_coverage_to rdf:datatype="&xsd;date"><xsl:value-of select="date_coverage_to"/></nyt:date_coverage_to>
      </rdf:Description>
    </xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
