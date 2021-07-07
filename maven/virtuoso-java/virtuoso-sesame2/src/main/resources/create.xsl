<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE rdf:RDF [
   <!ENTITY xsd  "http://www.w3.org/2001/XMLSchema#" >
 ]>
<xsl:stylesheet version="1.0"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:sparql="http://www.w3.org/2005/sparql-results#"
	xmlns="http://www.w3.org/1999/xhtml">

	<xsl:include href="../locale/messages.xsl" />

	<xsl:variable name="title">
		<xsl:value-of select="$repository-create.title" />
	</xsl:variable>

	<xsl:include href="template.xsl" />

	<xsl:template match="sparql:sparql">
		<form action="create">
			<table class="dataentry">
				<tbody>
					<tr>
						<th>
							<xsl:value-of
								select="$repository-type.label" />
						</th>
						<td>
							<select id="type" name="type">
								<option value="memory">
									In Memory Store
								</option>
								<option value="memory-rdfs">
									In Memory Store RDF Schema
								</option>
								<option value="memory-rdfs-dt">
									In Memory Store RDF Schema and
									Direct Type Hierarchy
								</option>
								<option value="native">
									Native Java Store
								</option>
								<option value="native-rdfs">
									Native Java Store RDF Schema
								</option>
								<option value="native-rdfs-dt">
									Native Java Store RDF Schema and
									Direct Type Hierarchy
								</option>
								<option value="mysql">
									MySql RDF Store
								</option>
								<option value="pgsql">
									PostgreSQL RDF Store
								</option>
								<option value="remote">
									Remote RDF Store
								</option>
								<option value="virtuoso">
									Virtuoso RDF Store
								</option>
							</select>
						</td>
						<td></td>
					</tr>
					<tr>
						<th>
							<xsl:value-of select="$repository-id.label" />
						</th>
						<td>
							<input type="text" id="id" name="id"
								size="16" />
						</td>
						<td></td>
					</tr>
					<tr>
						<th>
							<xsl:value-of
								select="$repository-title.label" />
						</th>
						<td>
							<input type="text" id="title" name="title"
								size="48" />
						</td>
						<td></td>
					</tr>
					<tr>
						<td></td>
						<td>
							<input type="button" value="{$cancel.label}"
								style="float:right" href="repositories"
								onclick="document.location.href=this.getAttribute('href')" />
							<input type="submit" name="next"
								value="{$next.label}" />
						</td>
					</tr>
				</tbody>
			</table>
		</form>
	</xsl:template>

</xsl:stylesheet>
