/*
 *  list2.h
 *
 *  $Id$
 *
 *  Doubly linked list
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
 *  
*/

#define L2_PUSH(first, last, elt, ep) \
{ \
  elt->ep##next = first; \
  if (first) \
    first->ep##prev = elt; \
  elt->ep##prev = NULL; \
  if (!last) last = elt; \
  first = elt; \
}


#define L2_PUSH_LAST(first, last, elt, ep) \
{ \
  elt->ep##prev = last; \
  if (last) \
    last->ep##next = elt; \
  elt->ep##next = NULL; \
  if (!first) first = elt; \
  last = elt; \
}

#define L2_DELETE(first, last, elt, ep) \
{ \
  if (elt->ep##prev) \
    elt->ep##prev->ep##next = elt->ep##next; \
  if (elt->ep##next) \
    elt->ep##next->ep##prev = elt->ep##prev; \
  if (elt == first) \
    first = elt->ep##next; \
  if (elt == last) \
    last = elt->ep##prev; \
  elt->ep##prev = elt->ep##next = NULL; \
}

#define L2_INSERT(first, last, before, it, ep) \
{ \
  if (before == first) \
    { \
      L2_PUSH (first, last, it, ep); \
    } \
  else \
    { \
      it->ep##prev = before->ep##prev; \
      it->ep##next = before; \
      before->ep##prev->ep##next = it; \
      before->ep##prev = it; \
    } \
}


#define L2_INSERT_AFTER(first, last, after, it, ep)  \
{  \
  if (!after) \
    { \
      L2_PUSH (first, last, it, ep); \
    } \
  else \
    { \
      it->ep##next = after->ep##next;  \
      it->ep##prev = after; \
      after->ep##next = it; \
      if (it->ep##next)  \
	it->ep##next->ep##prev = it; \
      else  \
	last = it; \
    } \
}

