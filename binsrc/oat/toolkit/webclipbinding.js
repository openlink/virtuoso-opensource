/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2018 OpenLink Software
 *
 *  See LICENSE file for details.
 */
/*
	OAT.WebClipBindings.bind(div, type, toXMLcallback, fromXMLcallback, activeCallback, inactiveCallback)
*/

OAT.WebClipBindings = {
	bind:function(div, typeCallback, toXMLcallback, fromXMLcallback, activeCallback, inactiveCallback) {
		var copyCallback = function() {
			var content = new LiveClipboardContent();
			content.data.formats[0] = new DataFormat();
			content.data.formats[0].type = typeCallback();
			content.data.formats[0].contentType = "application/xhtml+xml";
			content.data.formats[0].items = new Array(1);
			content.data.formats[0].items[0] = new DataItem();
			content.data.formats[0].items[0].data = toXMLcallback();
			return content;
		} /* copyCallback */

		var pasteCallback = function(clipData) {
			var type = typeCallback();
			for (var i=0; i<clipData.data.formats.length;i++) {
				if ((clipData.data.formats[i].type == type) &&
					(clipData.data.formats[i].items.length > 0) &&
					(clipData.data.formats[i].items[0].data)) {

					var xml = clipData.data.formats[i].items[0].data;
					fromXMLcallback(xml);
					return;
				} /* if suitable format found */
			} /* for all formats in clipboard */
		} /* pasteCallback */

        var webclip = new WebClip($(div),copyCallback,pasteCallback,activeCallback,inactiveCallback);
	} /* OAT.WebClipBindings.bind() */
}
