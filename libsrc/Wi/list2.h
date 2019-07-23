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
 *  Copyright (C) 1998-2019 OpenLink Software
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

#ifndef __LIST2_H
#define __LIST2_H

/*#ifdef MALLOC_DEBUG
#define L2_DEBUG
#endif*/

#ifdef L2_DEBUG
#define L2_ASSERT_SOLO(elt, ep) { \
  if (NULL != elt->ep##prev) \
    { \
      if (elt == elt->ep##prev->ep##next) \
        GPF_T1("L2_DEBUG: elt is next of prev of elt before insert, about to destroy other list"); \
    } \
  if (NULL != elt->ep##next) \
    { \
      if (elt == elt->ep##next->ep##prev) \
        GPF_T1("L2_DEBUG: elt is prev of next of elt before insert, about to destroy other list"); \
    } \
}

#define L2_ASSERT_PROPER_ENDS(first, last, ep) { \
  if (NULL != first) \
    { \
      if (NULL == last) GPF_T1("L2_DEBUG: last is NULL but first is not"); \
      if (NULL != first->ep##prev) GPF_T1("L2_DEBUG: _prev of first is not NULL"); \
      if (NULL != last->ep##next) GPF_T1("L2_DEBUG: _next of last is not NULL"); \
    } \
  else \
    if (NULL != last) GPF_T1("L2_DEBUG: first is NULL but last is not"); \
}

#define L2_ASSERT_CONNECTION(first, last, ep) { \
  int __prev_ofs = ((char *)(&(first->ep##prev))) - ((char *)(first)); \
  int __next_ofs = ((char *)(&(first->ep##next))) - ((char *)(first)); \
  char *__iprev = NULL; \
  char *__iter = (void *)first; \
  while (__iter != last) { \
      if (NULL == __iter) GPF_T1("L2_DEBUG: last not found to the right of first"); \
      __iter = ((char **)(__iter + __next_ofs))[0]; \
    } \
}

#define L2_ASSERT_DISCONNECTION(first, outer, ep) { \
  int __prev_ofs = ((char *)(&(first->ep##prev))) - ((char *)(first)); \
  int __next_ofs = ((char *)(&(first->ep##next))) - ((char *)(first)); \
  char *__iprev = NULL; \
  char *__iter = (void *)first; \
  while (NULL != __iter) { \
      if (outer == __iter) GPF_T1("L2_DEBUG: unexpected occurrence of outer to the right of first"); \
      __iter = ((char **)(__iter + __next_ofs))[0]; \
    } \
}

#else
#define L2_ASSERT_SOLO(elt, ep)
#define L2_ASSERT_PROPER_ENDS(first, last, ep)
#define L2_ASSERT_CONNECTION(first, last, ep)
#define L2_ASSERT_DISCONNECTION(first, outer, ep)
#endif

#define L2_PUSH(first, last, elt, ep) \
{ \
  L2_ASSERT_SOLO(elt, ep) \
  L2_ASSERT_PROPER_ENDS(first, last, ep) \
  L2_ASSERT_CONNECTION(first, last, ep) \
  L2_ASSERT_DISCONNECTION(first, elt, ep) \
  elt->ep##next = first; \
  if (first) \
    first->ep##prev = elt; \
  elt->ep##prev = NULL; \
  if (!last) last = elt; \
  first = elt; \
}


#define L2_PUSH_LAST(first, last, elt, ep) \
{ \
  L2_ASSERT_SOLO(elt, ep) \
  L2_ASSERT_PROPER_ENDS(first, last, ep) \
  L2_ASSERT_CONNECTION(first, last, ep) \
  L2_ASSERT_DISCONNECTION(first, elt, ep) \
  elt->ep##prev = last; \
  if (last) \
    last->ep##next = elt; \
  elt->ep##next = NULL; \
  if (!first) first = elt; \
  last = elt; \
}

#define L2_DELETE(first, last, elt, ep) \
{ \
  L2_ASSERT_PROPER_ENDS(first, last, ep) \
  L2_ASSERT_CONNECTION(first, elt, ep) \
  L2_ASSERT_CONNECTION(elt, last, ep) \
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
  L2_ASSERT_PROPER_ENDS(first, last, ep) \
  L2_ASSERT_CONNECTION(first, before, ep) \
  L2_ASSERT_CONNECTION(before, last, ep) \
  if (before != it->ep##next) \
    { \
      L2_ASSERT_SOLO(it, ep) \
      L2_ASSERT_DISCONNECTION(first, it, ep) \
    } \
  L2_ASSERT_DISCONNECTION(first, it, ep) \
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
  L2_ASSERT_PROPER_ENDS(first, last, ep) \
  if (!after) \
    { \
      L2_ASSERT_SOLO(it, ep) \
      L2_ASSERT_DISCONNECTION(first, it, ep) \
      L2_ASSERT_CONNECTION(first, last, ep) \
      L2_PUSH (first, last, it, ep); \
    } \
  else \
    { \
      if (after != it->ep##prev) \
        { \
          L2_ASSERT_SOLO(it, ep) \
          L2_ASSERT_DISCONNECTION(first, it, ep) \
        } \
      L2_ASSERT_CONNECTION(first, after, ep) \
      L2_ASSERT_CONNECTION(after, last, ep) \
      it->ep##next = after->ep##next;  \
      it->ep##prev = after; \
      after->ep##next = it; \
      if (it->ep##next)  \
	it->ep##next->ep##prev = it; \
      else  \
	last = it; \
    } \
}

#endif
