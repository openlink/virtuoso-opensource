--
--  $Id: txslt1.sql,v 1.20.10.1 2013/01/02 16:15:37 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
--
--
-- XSL-T test script based on MS demos
-- all commented lines caused errors
--


--DO_XSLT ('/DAV/xslsamples/authors.xml', '/DAV/xslsamples/hilite-xml.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": author-patterns/authors.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/invoice.xml', '/DAV/xslsamples/invoice.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": invoice/invoice.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/ledger.xml', '/DAV/xslsamples/ledger.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": ledger/ledger.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/bids-table.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/bids-table2.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": multiple/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/price-graph.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": multiple/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/raw-xml.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/sort-bidder-.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/sort-bidder-price-.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/sort-bidder-price.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/sort-bidder.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/summary.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": multiple/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/bids-table.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/bids-table2.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": multiple/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/price-graph.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": multiple/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/raw-xml.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/sort-bidder-.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/sort-bidder-price-.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/sort-bidder-price.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/sort-bidder.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/summary.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": multiple/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/bids-table.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/bids-table2.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": multiple/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/price-graph.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": multiple/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/raw-xml.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/sort-bidder-.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/sort-bidder-price-.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/sort-bidder-price.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/sort-bidder.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": multiple/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/summary.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": multiple/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/pole.xml', '/DAV/xslsamples/pole.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": pole/pole.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/portfolio.xml', '/DAV/xslsamples/portfolio.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": portfolio/portfolio.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/portfolio-attributes.xml', '/DAV/xslsamples/portfolio-attributes.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": portfolio-attributes/portfolio-attributes.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/portfolio-choose.xml','/DAV/xslsamples/portfolio-choose.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": portfolio-choose/portfolio-choose.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/portfolio-if.xml', '/DAV/xslsamples/portfolio-if.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": portfolio-if/portfolio-if.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/portfolio-sort1.xml','/DAV/xslsamples/portfolio-sort1.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": portfolio-sort/portfolio-sort1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/portfolio-sort1.xml','/DAV/xslsamples/portfolio-sort2.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": portfolio-sort/portfolio-sort1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/portfolio-sort2.xml','/DAV/xslsamples/portfolio-sort1.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": portfolio-sort/portfolio-sort2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/portfolio-sort2.xml','/DAV/xslsamples/portfolio-sort2.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": portfolio-sort/portfolio-sort2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


DO_XSLT ('/DAV/xslsamples/portfolio2.xml', '/DAV/xslsamples/portfolio2.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": portfolio2/portfolio2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/product-list2.xml', '/DAV/xslsamples/product-list2.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": product-list2/product-list2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



-- This crashes the server
--DO_XSLT ('/DAV/xslsamples/portfolio.xml', '/DAV/xslsamples/rename.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": rename/portfolio.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/review.xml', '/DAV/xslsamples/review.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": review-xsl/review.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/simple.xml', '/DAV/xslsamples/simple.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": simple-islands/simple.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- This crashes the server
DO_XSLT ('/DAV/xslsamples/portfolio.xml', '/DAV/xslsamples/sort.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": sort/portfolio.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/bids-table.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/bids-table2.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": transform-viewer/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/defaultss.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": transform-viewer/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/price-graph.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": transform-viewer/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/sort-bidder-.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction1.xml','/DAV/xslsamples/sort-bidder-price-.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/sort-bidder-price.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/sort-bidder.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction1.xml', '/DAV/xslsamples/summary.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": transform-viewer/auction1.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/bids-table.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/bids-table2.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": transform-viewer/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/defaultss.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": transform-viewer/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/price-graph.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": transform-viewer/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/sort-bidder-.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction2.xml','/DAV/xslsamples/sort-bidder-price-.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/sort-bidder-price.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/sort-bidder.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction2.xml', '/DAV/xslsamples/summary.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": transform-viewer/auction2.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/bids-table.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/bids-table2.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": transform-viewer/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/defaultss.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": transform-viewer/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/price-graph.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": transform-viewer/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/sort-bidder-.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction3.xml','/DAV/xslsamples/sort-bidder-price-.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/sort-bidder-price.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/sort-bidder.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": transform-viewer/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/auction3.xml', '/DAV/xslsamples/summary.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": transform-viewer/auction3.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/investments.xml', '/DAV/xslsamples/investments-to-portfolio.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": translate/investments.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/investments.xml', '/DAV/xslsamples/portfolio-to-investments.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": translate/investments.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/portfolio.xml', '/DAV/xslsamples/investments-to-portfolio.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": translate/portfolio.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/portfolio.xml', '/DAV/xslsamples/portfolio-to-investments.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": translate/portfolio.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--DO_XSLT ('/DAV/xslsamples/xsl.xml', '/DAV/xslsamples/xmlspec.xsl');
--ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
--ECHO BOTH ": xsl/xsl.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/xsl-toc.xml', '/DAV/xslsamples/xmlspec-toc.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": xsl-toc/xsl-toc.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/empty_comment.xml', '/DAV/xslsamples/empty_comment.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": empty comment in XSL-T : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/utf8.xml', '/DAV/xslsamples/utf8.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": UTF-8 in XSL-T : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/attr_entity.xml', '/DAV/xslsamples/attr_entity.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": @* in select : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/number_format.xml', '/DAV/xslsamples/number_format.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": format-number() tests : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/number_format.xml', '/DAV/xslsamples/number_format1.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": format-number() with small numbers tests : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/bug1174.xml', '/DAV/xslsamples/bug1174.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": BUG1174 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


http_get ('http://localhost:$U{HTTPPORT}/DAV/xslt/xslt.vsp', null, 'GET', concat ('Authorization: Basic ', encode_base64 ('dav:dav')));

create procedure test_http_xslt ()
{
  declare a varchar;
  declare x any;
  a := http_get ('http://localhost:$U{HTTPPORT}/DAV/xslt/xslt.vsp', null, 'GET', concat ('Authorization: Basic ', encode_base64 ('dav:dav')));
  string_to_file ('../txslt.result', a, -1);
  x := xml_tree (a);
  if (a <> '<?xml version="1.0" encoding="ISO-8859-1" ?><document><g>Test</g></document>')
    signal ('XSLT0', concat('Transformation is not successful: ', a));
}

test_http_xslt ();
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": http_xslt () function test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/portfolio.xml', '/DAV/xslsamples/portfolio-cp.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": copy-of portfolio/portfolio.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/family.xml', '/DAV/xslsamples/family.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": copy-of family : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/booksshort.xml', '/DAV/xslsamples/identityxfm.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": copy booksshort.xml : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/booksshort.xml', '/DAV/xslsamples/identityxfm1.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": copy booksshort.xml attribute test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure DB.DBA.STR_CONCAT (in a varchar, in b varchar, in c integer)
{
  return concat (a, ':', b, ':',  sprintf ('%d', c));
};

xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:concat_strings', 'DB.DBA.STR_CONCAT');
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": XPATH function extension for XSL-T must be granted to PUBLIC : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

grant execute on DB.DBA.STR_CONCAT to public;
xpf_extension ('http://www.openlinksw.com/virtuoso/xslt:concat_strings', 'DB.DBA.STR_CONCAT');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": XPATH function extension for XSL-T declared : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure xstext ()
{
  declare xsl, xm varchar;
  declare xt, xe, r any;
  xsl := '<?xml version=''1.0''?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/TR/WD-xsl" xmlns:virt="http://www.openlinksw.com/virtuoso/xslt">
  <xsl:template match="/doc/a">
    <HTML>
     <BODY>
     <xsl:if test="function-available(''virt:concat_strings'')">
      <xsl:value-of select="virt:concat_strings (@id, ., @n)"/>
     </xsl:if>
     <xsl:if test="function-available(''virt:not_exists_concat_strings'')">
      <xsl:value-of select="virt:concat_strings (@id, ., @n)"/>
     </xsl:if>
     </BODY>
    </HTML>
  </xsl:template>
</xsl:stylesheet>';
  xm := '<doc><a id="foo" n="12">bar</a></doc>';

  xt := xslt_sheet ('xslt_test_ext', xml_tree_doc (xsl));
  xe := xml_tree_doc (xm);
  r := xslt ('xslt_test_ext', xe);
  declare ses any;
  ses := string_output ();
  http_value (r, null, ses);
  ses := string_output_string(ses);
  if (trim(ses) <> '<HTML><BODY>foo:bar:12</BODY></HTML>')
    signal ('XSLTE', sprintf ('The extension function execution failed. Result retrned: %s', ses));
  return ses;
};

select xstext ();
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": XPATH function extensions for XSL-T : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DO_XSLT ('/DAV/xslsamples/bug3342.xml', '/DAV/xslsamples/bug3342.xsl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": BUG3342 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

set MACRO_SUBSTITUTION off;
create procedure BUG5464(){
  declare aXXML,aXML,aResult any;
  declare sXSL varchar;

  result_names(aResult);

  sXSL := '<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
             <xsl:output method="xml" encoding="UTF-8" omit-xml-declaration="yes"/>
	     <xsl:variable name="gSomeVariable" select="Root/SomeMissingNode"/>
             <xsl:template match="/">
               <xsl:element name="test">
	       <xsl:value-of select="format-number(number(SomeNode),$gSomeVariable)"/>
               </xsl:element>
             </xsl:template>
           </xsl:stylesheet>';

  declare str, r varchar;
  xslt_sheet (sXSL,xml_tree_doc(xml_tree(sXSL)));

  aXML := xslt(sXSL,xml_tree_doc(xml_tree('<root />')));

  result(aXML);
};
set MACRO_SUBSTITUTION on;

BUG5464();
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH ": BUG5464 : empty format string in format-number STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
