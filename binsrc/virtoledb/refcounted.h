/*  refcounted.h
 *
 *  $Id$
 *
 *  Reference counted objects.
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2015 OpenLink Software
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

#ifndef REFCOUNTED_H
#define REFCOUNTED_H


class RefCountedImpl
{
public:

  RefCountedImpl(const char *identity);
  virtual ~RefCountedImpl();

  void AddRef();
  void Release();

  /**
   * This function is called when the reference count
   * goes from 0 to 1.
   */
  virtual void Referenced();

  /**
   * This function is called when the reference count
   * goes from 1 to 0.
   */
  virtual void Unreferenced();

private:

  long ref_count;
  const char *object_identity;
};


// ``Impl'' must be a subclass of the ``RefCountedImpl'' class.
template <class Impl>
class RefCounted
{
public:

  RefCounted()
  {
    impl = NULL;
  }

  ~RefCounted()
  {
    Release();
  }

  bool
  IsInitialized()
  {
    return impl != NULL;
  }

  /**
   * An utility method for implementing copy constructors.
   */
  void
  CopyCtor(const RefCounted<Impl>& other)
  {
    impl = other.impl;
    if (impl != NULL)
      impl->AddRef();
  }

  /**
   * An utility method for implementing copy operators.
   */
  void
  CopyOp(const RefCounted<Impl>& other)
  {
    if (impl != NULL)
      impl->Release();
    impl = other.impl;
    if (impl != NULL)
      impl->AddRef();
  }

  void
  Release()
  {
    if (impl != NULL)
      {
	((RefCountedImpl*) impl)->Release();
	impl = NULL;
      }
  }

protected:

  Impl *impl;
};


#endif
