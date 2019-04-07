<xsl:stylesheet version='1.0' xmlns:xsl='http://www.w3.org/1999/XSL/Transform'>
<!--

  $Id$

  This file is part of the OpenLink Ajax Toolkit (OAT) project

  Copyright (C) 2005-2019 OpenLink Software

  This project is free software; you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by the
  Free Software Foundation; only version 2 of the License, dated June 1991

  This project is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software Foundation,
  Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

-->
<xsl:output method="html"/>

<xsl:template match="/" >
<html>
<head>

	<title>SQL Designer redirection...</title>
	<script type="text/javascript">
		function init() {
			document.location = "/DAV/JS/dbdesigner/index.html?load="+encodeURIComponent(document.location);
		}
	</script>
</head>

<body onload="init()"></body>
</html>
</xsl:template>
</xsl:stylesheet>
