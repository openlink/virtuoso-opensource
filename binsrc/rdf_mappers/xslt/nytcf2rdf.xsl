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
	<xsl:apply-templates mode="ok" select="/result_set/results/member"/>
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

    <xsl:template match="member" mode="ok">
      <rdf:Description rdf:about="{$baseUri}">
	  <nyt:id><xsl:value-of select="id"/></nyt:id>
	  <nyt:name><xsl:value-of select="name"/></nyt:name>
	  <nyt:first_name><xsl:value-of select="first_name"/></nyt:first_name>
	  <nyt:middle_name><xsl:value-of select="middle_name"/></nyt:middle_name>
	  <nyt:last_name><xsl:value-of select="last_name"/></nyt:last_name>
	  <nyt:date_of_birth><xsl:value-of select="date_of_birth"/></nyt:date_of_birth>
	  <nyt:gender><xsl:value-of select="gender"/></nyt:gender>
	  <nyt:url><xsl:value-of select="url"/></nyt:url>
	  <nyt:govtrack_id><xsl:value-of select="govtrack_id"/></nyt:govtrack_id>
	  <xsl:for-each select="roles/role">
		<nyt:has_role rdf:resource="{vi:proxyIRI(concat($baseUri, '#', congress))}"/>
          </xsl:for-each>
      </rdf:Description>
      <xsl:for-each select="roles/role">
          <nyt:role rdf:about="{vi:proxyIRI(concat($baseUri, '#', congress))}">
		<nyt:congress><xsl:value-of select="congress"/></nyt:congress>
		<nyt:chamber><xsl:value-of select="chamber"/></nyt:chamber>
		<nyt:title><xsl:value-of select="title"/></nyt:title>
                <nyt:state><xsl:value-of select="state"/></nyt:state>
                <nyt:party><xsl:value-of select="party"/></nyt:party>
                <nyt:start_date><xsl:value-of select="start_date"/></nyt:start_date>
                <nyt:end_date><xsl:value-of select="end_date"/></nyt:end_date>
                <nyt:missed_votes_pct><xsl:value-of select="missed_votes_pct"/></nyt:missed_votes_pct>
                <nyt:votes_with_party_pct><xsl:value-of select="votes_with_party_pct"/></nyt:votes_with_party_pct>		
          </nyt:role>
      </xsl:for-each>
      
    </xsl:template>

    <xsl:template match="text()|@*"/>

</xsl:stylesheet>
