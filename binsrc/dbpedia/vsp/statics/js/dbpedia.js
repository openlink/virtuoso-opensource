/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

function disabled__init() {
	init_long_literals();
}

var long_literal_counter = 0;
var long_literal_spans = {};
var long_literal_texts = {};
function init_long_literals() {
    var spans = document.getElementsByTagName('span');
    for (i = 0; i < spans.length; i++) {
        if (spans[i].className != 'literal') continue;
        var span = spans[i];
        var textNode = span.firstChild;
        var text = textNode.innerText;
        if (!text || text.length < 300) continue;
        var match = text.match(/([^\0]{150}[^\0]*? )([^\0]*)/);
        if (!match) continue;
        span.insertBefore(document.createTextNode(match[1] + ' ... '), span.firstChild);
        span.removeChild(textNode);
        var link = document.createElement('a');
        link.href = 'javascript:expand(' + long_literal_counter + ');';
        link.appendChild(document.createTextNode('\u00BBmore\u00BB'));
        link.className = 'expander';
        span.insertBefore(link, span.firstChild.nextSibling);
        long_literal_spans[long_literal_counter] = span;
        long_literal_texts[long_literal_counter] = textNode;
        long_literal_counter = long_literal_counter + 1;
    }
}

function expand(i) {
    var span = long_literal_spans[i];
    span.removeChild(span.firstChild);
    span.removeChild(span.firstChild);
    span.insertBefore(long_literal_texts[i], span.firstChild);
}
