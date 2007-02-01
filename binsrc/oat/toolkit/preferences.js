/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2006 Ondrej Zara and OpenLink Software
 *
 *  See LICENSE file for details.
 */
OAT.Preferences = {
	showAjax:1, /* show Ajax window even if not explicitly requested by application? */
	useCursors:1, /* scrollable cursors */
	windowTypeOverride:0, /* do not guess window type */
	xsltPath:"/DAV/JS/xslt",
	version:"29.1.2006",
	httpError:1, /* show http errors */
	allowDefaultResize:1,
	allowDefaultDrag:1
}
OAT.Loader.featureLoaded("preferences");
