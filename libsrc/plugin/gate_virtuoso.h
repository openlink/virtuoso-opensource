/*
 *  gate_virtuoso.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

/* List of all header files of Virtuoso, where exe-exported functions
   are declared. */

#include "../Dk.h"
#include "../Dk/Dkalloc.h"
#include "../Dk/Dkbox.h"
#include "../Dk/Dkhash.h"
#include "../Dk/Dksession.h"
#include "../Dk/Dkernel.h"
#include "../Dk/Dkhashext.h"
#include "../Dk/Dkpool.h"
#include "../Dk/Dksets.h"
#include "../Dk/Dktrace.h"
#include "../Thread/Dkthread.h"
#include "../Wi/wi.h"
#include "../Wi/sqlnode.h"
#include "../Wi/sqlfn.h"
#include "../Wi/eqlcomp.h"
#include "../Wi/lisprdr.h"
#include "../Wi/sqlpar.h"
#include "../Wi/sqlcmps.h"
#include "../Wi/sqlintrp.h"
#include "../Wi/sqlbif.h"
#include "../Wi/widd.h"
#include "../Wi/arith.h"
#include "../Wi/security.h"
#include "../Wi/sqlpfn.h"
#include "../Wi/date.h"
#include "../Wi/datesupp.h"
#include "../Wi/multibyte.h"
#include "../Wi/srvmultibyte.h"
#include "../Wi/srvstat.h"
#include "../Wi/bif_xper.h"
#include <math.h>
#include "../libutil.h"
#if !defined (__APPLE__)
#include <wchar.h>
#endif
#include "../Wi/http.h"
#include "../Wi/xmltree.h"
#include "../Wi/sqlofn.h"
#include "../Wi/statuslog.h"
#include "../Wi/bif_text.h"
#include "../Xml.new/xmlparser.h"
#include "../Wi/xmltree.h"
#include "../Wi/sql3.h"
#include "../Wi/repl.h"
#include "../Wi/replsr.h"
#include "../langfunc/langfunc.h"
#include "../Wi/wifn.h"
#include "../Wi/sqlfn.h"
#include "../Wi/ltrx.h"
#include "../Wi/2pc.h"
#include "../Wi/geo.h"
#include "../Wi/rdf_core.h"


#include "gate_virtuoso_stubs.h"
