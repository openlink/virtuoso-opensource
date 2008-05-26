/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Ajax Toolkit (OAT) project.
 *
 *  Copyright (C) 2005-2007 OpenLink Software
 *
 *  See LICENSE file for details.
 */

google.loader.ApiKey = OAT.ApiKeys.getKey('gmapapi');
google.load("maps","2",{callback: function() { OAT.Loader.featureLoaded("gmaps") }});
