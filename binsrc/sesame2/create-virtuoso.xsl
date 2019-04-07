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
		<script type="text/javascript">
			<![CDATA[
			function populateParameters() {
				var href = document.location.href;
				var elements = href.substring(href.indexOf('?') + 1).split(decodeURIComponent('%26'));
				for (var i=0;elements.length-i;i++) {
					var pair = elements[i].split('=');
					var value = decodeURIComponent(pair[1]).replace(/\+/g, ' ');
					if (pair[0] == 'id') {
						document.getElementById('id').value = value;
					}
					if (pair[0] == 'title') {
						document.getElementById('title').value = value;
					}
				}
			}
			window.onload = function() {
				populateParameters();
			}
			]]>
		</script>
		<form action="create" method="post">
			<table class="dataentry">
				<tbody>
					<tr>
						<th>
							<xsl:value-of
								select="$repository-type.label" />
						</th>
						<td>
							<select id="type" name="type">
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
							<input type="text" id="id"
								name="Repository ID" size="16" 
								value="myvirtuoso" />
						</td>
						<td></td>
					</tr>
					<tr>
						<th>
							<xsl:value-of
								select="$repository-title.label" />
						</th>
						<td>
							<input type="text" id="title"
								name="Repository title" size="48"
								value="Virtuoso RDF store" />
						</td>
						<td></td>
					</tr>
					<tr>
						<th>
							Virtuoso connection host list
						</th>
						<td>
							<input type="text" id="hostList"
								name="Host list" size="48"
								value="localhost:1111" />
						</td>
						<td></td>
					</tr>
					<tr>
						<th>
							Username
						</th>
						<td>
							<input type="text" id="username"
								name="Username" size="24"
								value="dba" />
						</td>
						<td></td>
					</tr>
					<tr>
						<th>
							Password
						</th>
						<td>
							<input type="password" id="password"
								name="Password" size="24"
								value="dba" />
						</td>
						<td></td>
					</tr>
					<tr>
						<th>
							Default graph name
						</th>
						<td>
							<input type="text" id="defGraph"
								name="Default graph name" size="48"
								value="sesame:nil" />
						</td>
						<td></td>
					</tr>
					<tr>
						<td>
						        Enable using batch optimization
						</td>
						<td>
							<input type="radio" id="useLazyAdd"
								name="Enable using batch optimization" size="48" value="true" />
							<xsl:value-of select="$true.label" />
							<input type="radio" id="useLazyAdd"
								name="Enable using batch optimization" size="48" value="false" checked="true" />
							<xsl:value-of select="$false.label" />
						</td>
						<td></td>
					</tr>
					<tr>
						<th>
						        Batch buffer size
						</th>
						<td>
							<input type="text" id="batchSize"
								name="Batch buffer size" size="4" value="5000" />
						</td>
						<td></td>
					</tr>
					<tr>
						<td>
						        Use RoundRobin for connection
						</td>
						<td>
							<input type="radio" id="roundRobin"
								name="Use RoundRobin for connection" size="48" value="true" />
							<xsl:value-of select="$true.label" />
							<input type="radio" id="roundRobin"
								name="Use RoundRobin for connection" size="48" value="false" checked="true" />
							<xsl:value-of select="$false.label" />
						</td>
						<td></td>
					</tr>
					<tr>
						<th>
						        Buffer fetch size
						</th>
						<td>
							<input type="text" id="fetchSize"
								name="Buffer fetch size" size="4" value="100" />
						</td>
						<td></td>
					</tr>
					<tr>
						<th>
						        Inference RuleSet name
						</th>
						<td>
							<input type="text" id="ruleSet"
								name="Inference RuleSet name" size="48" value="null" />
						</td>
						<td></td>
					</tr>
					<tr>
						<td>
						        Insert BNode as Virtuoso IRI
						</td>
						<td>
							<input type="radio" id="insertBNodeAsVirtuosoIRI"
								name="Insert BNode as Virtuoso IRI" size="48" value="true" />
							<xsl:value-of select="$true.label" />
							<input type="radio" id="insertBNodeAsVirtuosoIRI"
								name="Insert BNode as Virtuoso IRI" size="48" value="false" checked="true" />
							<xsl:value-of select="$false.label" />
						</td>
						<td></td>
					</tr>
					<tr>
						<td>
						        Use defGraph with SPARQL queries, if query default graphs weren't set
						</td>
						<td>
							<input type="radio" id="useDefGraphForQueries"
								name="Use defGraph for Queries" size="48" value="true" />
							<xsl:value-of select="$true.label" />
							<input type="radio" id="useDefGraphForQueries"
								name="Use defGraph for Queries" size="48" value="false" checked="true" />
							<xsl:value-of select="$false.label" />
						</td>
						<td></td>
					</tr>



					<tr>
						<td></td>
						<td>
							<input type="button" value="{$cancel.label}"
								style="float:right" href="repositories"
								onclick="document.location.href=this.getAttribute('href')" />
							<input type="submit"
								value="{$create.label}" />
						</td>
					</tr>
				</tbody>
			</table>
		</form>
	</xsl:template>

</xsl:stylesheet>
