# Virtuoso GeoSPARQL support

_Copyright (C) 2018 OpenLink Software

## Introduction
This release marks the addition of GeoSPARQL function support to Virtuoso Open Source Edition.

Besides a number of enhancements to the core Virtuoso engine, OpenLink added three plugins that
extend Virtuoso's functionality:

  * proj4
  * geos
  * shapefileio


## Requirements
Two of these plugins can only be build against very specific versions of third party libraries which
may not be available on every OS distribution so probably will need to be build by you prior to
building Virtuoso.
```
  Package         Version         From
  -------         -------         ---------------------------
  proj            4.9.3           https://proj4.org
  geo             3.5.1           https://www.osgeo.org/geos/
```
The new plugins are automatically added to the build process if the third party libraries and header
files are found when running the configure tool. 

The following new options have been added:
```
  $ ./configure --help
  ...
  ...
  --enable-proj4(=DIR)    enable the proj4 plugin (default)
  --disable-proj4         disable the proj4 plugin
  --enable-geos(=DIR)     enable the geos plugin (default)
  --disable-geos          disable the geos plugin
  --enable-shapefileio(=DIR)
			  enable the shapefileio plugin (default)
  --disable-shapefileio   disable the shapefileio plugin
  ...
```

OpenLink will be providing binary releases of Virtuoso Open Source edition for a number of platforms
including Linux, Mac OS X and Windows.


## New Plugins

### The proj4 plugin

The proj4 plugin adds an interface between the Virtuoso engine and the [__PROJ__ library](https://proj4.org) 
currently maintained by Frank Warmerdam et al.

This plugin adds support for transforming geospatial coordinates from one coordinate reference
system (CRS) to another, including both cartographic projections as well as geodetic
transformations.

The proj4 plugin currently requires __v4.9.3__ of the library which can be [downloaded
here](https://download.osgeo.org/proj/proj-4.9.3.tar.gz)

The PROJ library uses the following license:
```
  All source, data files and other contents of the PROJ.4 package are
  available under the following terms.  Note that the PROJ 4.3 and earlier
  was "public domain" as is common with US government work, but apparently
  this is not a well defined legal term in many countries.  I am placing
  everything under the following MIT style license because I believe it is
  effectively the same as public domain, allowing anyone to use the code as
  they wish, including making proprietary derivatives.

  Though I have put my own name as copyright holder, I don't mean to imply
  I did the work.  Essentially all work was done by Gerald Evenden.

  --------------

  Copyright (c) 2000, Frank Warmerdam

  Permission is hereby granted, free of charge, to any person obtaining a
  copy of this software and associated documentation files (the "Software"),
  to deal in the Software without restriction, including without limitation
  the rights to use, copy, modify, merge, publish, distribute, sublicense,
  and/or sell copies of the Software, and to permit persons to whom the
  Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included
  in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
  DEALINGS IN THE SOFTWARE.
```

### The geos plugin
The geos plugin adds an interface between the Virtuoso engine and the [__GEOS__
library](https://www.osgeo.org/projects/geos/) currently maintained by the Open Source Geospatial
Foundation.

According to their website:
```
  GEOS (Geometry Engine - Open Source) is a C++ port of the Topology Suite (JTS). As such, it aims
  to contain the complete functionality of JTS in C++. This includes all the GIS Simple Features for
  SQL spatial predicate functions and spatial operators, as well as specific JTS enhanced topology
  functions.
```

This plugin adds support for GeoSPARQL functions to the Virtuoso engine.

The geos plugin currently requires __v3.5.1__ of the library which can be [downloaded
here](http://download.osgeo.org/geos/geos-3.5.1.tar.bz2)

The GEOS library is licensed under the terms of the [GNU Lesser General Public License
v2.1](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html).


### The shapefileio plugin
The shapefileio plugin adds an interface between the Virtuoso engine and the [__Shapefile__ C
Library](https://shapelib.maptools.org) currently maintainer by Frank Warmerdam et al.

This plugin adds support for reading ESRI Shapefiles.

At this time a version of this library is embedded in the Virtuoso code base so no external packages are required.

The shapefile library uses the following license:
```
  LICENSE
  The source for the Shapefile C Library is (c) 1998 Frank Warmerdam, and released under the following
  conditions. The intent is that anyone can do anything with the code, but that I do not assume any
  liability, nor express any warranty for this code.  As of Shapelib 1.2.6 the core portions of the
  library are made available under two possible licenses. The licensee can choose to use the code
  under either the Library GNU Public License (LGPL) described in COPYING or under the following MIT
  style license. Any files in the Shapelib distribution without explicit copyright license terms (such
  as this documentation, the Makefile and so forth) should be considered to have the following
  licensing terms. Some auxilary portions of Shapelib, notably some of the components in the contrib
  directory come under slightly different license restrictions. Check the source files that you are
  actually using for conditions.

  DEFAULT LICENSE TERMS
  Copyright (c) 1999, Frank Warmerdam
  This software is available under the following "MIT Style" license, or at the option of the
  licensee under the LGPL (see COPYING). This option is discussed in more detail in shapelib.html.

  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
  associated documentation files (the "Software"), to deal in the Software without restriction,
  including without limitation the rights to use, copy, modify, merge, publish, distribute,
  sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all copies or substantial
  portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
  NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
  OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

  SHAPELIB MODIFICATIONS 
  I am pleased to receive bug fixes, and improvements for Shapelib. Unless the submissions indicate
  otherwise I will assume that changes submitted to me remain under the the above "dual license"
  terms. If changes are made to the library with the intention that those changes should be protected
  by the LGPL then I should be informed upon submission. Note that I will not generally incorporate
  changes into the core of Shapelib that are protected under the LGPL as this would effectively limit
  the whole file and distribution to LGPL terms.

  Opting for LGPL 
  For licensee's opting to use Shapelib under LGPL as opposed to the MIT Style license above, and
  wishing to redistribute the software based on Shapelib, I would ask that all "dual license" modules
  be updated to indicate that only the LGPL (and not the MIT Style license) applies. This action
  represents opting for the LGPL, and thereafter LGPL terms apply to any redistribution and
  modification of the affected modules.
```



## Changes to virtuoso.ini
After building and installing the new plugins, you may need to add them to the __Plugins__ section of
any existing virtuoso.ini file. You need to make sure that each _Load_ line uses a unique number
although numbering does not have to be sequential.
```
  [Plugins]
  ...
  ...
  Load20 = plain, proj4
  Load21 = plain, geos
  Load22 = plain, shapefileio
```

The proj4 plugin requires access to a number of data files from the proj project which are normally
installed in /usr/share/proj. For this you need to change your virtuoso.ini file and add this
directory to the existing __DirsAllowed__ setting like this:
```
  [Parameters]
  ..
  ..
  DirsAllowed                     = ., /opt/virtuoso-opensource/vad, /usr/share/proj
  .. 
  ..
```

After making these modifications to the virtuoso.ini file, you need to restart the virtuoso engine
so these additional functions become available. If the plugins are successfully build and installed
you should see the following lines in your virtuoso.log file:
```
  12:08:51 { Loading plugin 8: Type `plain', file `proj4' in `/opt/virtuoso-opensource/hosting'
  12:08:51   plain version 3230 from OpenLink Software
  12:08:51   Cartographic Projections support based on Frank Warmerdam's proj4 library
  12:08:51   SUCCESS plugin 8: loaded from /opt/virtuoso-opensource/hosting/proj4.so }
  12:08:51 { Loading plugin 9: Type `plain', file `geos' in `/opt/virtuoso-opensource/hosting'
  12:08:51   plain version 3230 from OpenLink Software
  12:08:51   GEOS plugin based on Geometry Engine Open Source library from Open Source Geospatial Foundation
  12:08:51   SUCCESS plugin 9: loaded from /opt/virtuoso-opensource/hosting/geos.so }
  12:08:51 { Loading plugin 10: Type `plain', file `shapefileio' in `/opt/virtuoso-opensource/hosting'
  12:08:51   ShapefileIO version 0.1virt71 from OpenLink Software
  12:08:51   Shapefile support based on Frank Warmerdam's Shapelib
  12:08:51   SUCCESS plugin 10: loaded from /opt/virtuoso-opensource/hosting/shapefileio.so }
```

If you see the following lines near the bottom of you virtuoso.log file then you need to install the
proj-data package if your operating distribution has this available.
```
  12:23:17 PL LOG: Initial setup of DB.DBA.SYS_PROJ4_SRIDS data from files in "/usr/share/proj"
  12:23:17 PL LOG: Error during initial setup of DB.DBA.SYS_PROJ4_SRIDS data: 39000: FA005: 
  Can't open file '/usr/share/proj/epsg', error 2
```

If the proj plugin is initialized successfully you will see the following lines near the bottom of your virtuoso.ini file:
```
  12:10:08 PL LOG: Initial setup of DB.DBA.SYS_PROJ4_SRIDS data from files in "/usr/share/proj"
  12:10:08 PL LOG: DB.DBA.SYS_PROJ4_SRIDS now contains 8650 spatial reference systems
```
