--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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
VHOST_REMOVE (vhost=>'localhost:4334',lhost=>'localhost:4334',lpath=>'/');

VHOST_DEFINE (vhost=>'localhost:4334',lhost=>'localhost:4334',lpath=>'/',ppath=>'/ssl/', def_page=>'index.html', is_brws=>1, sec=>'SSL', auth_opts=>vector ('https_cert','PATH_TO_THE_CERTIFICATE','https_key','PATH_TO_THE_PRIVATE_KEY', 'https_cv', 'PATH_TO_THE_CA_LIST', 'https_cv_depth', 2));

