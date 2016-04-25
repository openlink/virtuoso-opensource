/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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
 */

package openlink.util;

import java.util.*;

/**
 * The Vector class is an implementation to store objects.
 *
 * @see java.util.Vector
 */
public class Vector
{
   // The array where to store objects
   protected Object elementData[];

   // The number of valid objects in the array
   protected int elementCount;

   // The increment of the array when ther's no space left
   protected int capacityIncrement;

   /**
    * Constructs an empty vector with the specified initial capacity and
    * capacity increment.
    *
    * @param   initialCapacity     the initial capacity of the vector.
    * @param   capacityIncrement   the amount by which the capacity is
    */
   public Vector(int initialCapacity, int capacityIncrement)
   {
      this.elementData = new Object[initialCapacity];
      this.capacityIncrement = capacityIncrement;
   }

   /**
    * Constructs an empty vector with the specified initial capacity.
    *
    * @param   initialCapacity   the initial capacity of the vector.
    */
   public Vector(int initialCapacity)
   {
      this (initialCapacity,0);
   }

   /**
    * Constructs an empty vector.
    */
   public Vector()
   {
      this (10);
   }

   /**
    * Constructs a vector from an array of objects.
    *
    * @param   array   the array to copy into the vector.
    */
   public Vector(Object[] array)
   {
      elementData = array;
      elementCount = array.length;
   }

   /**
    * Copies the components of this vector into the specified array.
    * The array must be big enough to hold all the objects in this  vector.
    *
    * @param   anArray   the array into which the components get copied.
    */
   public void copyInto(Object anArray[])
   {
      System.arraycopy(elementData,0,anArray,0,elementCount);
   }

   /**
    * Trims the capacity of this vector to be the vector's current
    * size. An application can use this operation to minimize the
    * storage of a vector.
    */
   public void trimToSize()
   {
      int oldCapacity = elementData.length;
      if(elementCount < oldCapacity)
      {
         Object oldData[] = elementData;
         elementData = new Object[elementCount];
         System.arraycopy(oldData,0,elementData,0,elementCount);
      }
   }

   /**
    * Increases the capacity of this vector, if necessary, to ensure
    * that it can hold at least the number of components specified by
    * the minimum capacity argument.
    *
    * @param   minCapacity   the desired minimum capacity.
    */
   public void ensureCapacity(int minCapacity)
   {
      if(minCapacity > elementData.length)
         ensureCapacityHelper(minCapacity);
   }

   /**
    * This implements the unsynchronized semantics of ensureCapacity.
    * Synchronized methods in this class can internally call this
    * method for ensuring capacity without incurring the cost of an
    * extra synchronization.
    *
    * @see java.util.Vector#ensureCapacity(int)
    */
   private void ensureCapacityHelper(int minCapacity)
   {
      int oldCapacity = elementData.length;
      Object oldData[] = elementData;
      int newCapacity = (capacityIncrement > 0) ? (oldCapacity + capacityIncrement) : (oldCapacity * 2);
      if(newCapacity < minCapacity)
         newCapacity = minCapacity;
      elementData = new Object[newCapacity];
      System.arraycopy(oldData,0,elementData,0,elementCount);
   }

   /**
    * Sets the size of this vector. If the new size is greater than the
    * current size, new <code>null</code> items are added to the end of
    * the vector. If the new size is less than the current size, all
    * components at index <code>newSize</code> and greater are discarded.
    *
    * @param   newSize   the new size of this vector.
    * @since   JDK1.0
    */
   public void setSize(int newSize)
   {
      if((newSize > elementCount) && (newSize > elementData.length))
         ensureCapacityHelper(newSize);
      else
         for(int i = newSize;i < elementCount;i++)
            elementData[i] = null;
      elementCount = newSize;
   }

   /**
    * Returns the current capacity of this vector.
    *
    * @return  the current capacity of this vector.
    */
   public int capacity()
   {
      return elementData.length;
   }

   /**
    * Returns the number of components in this vector.
    *
    * @return  the number of components in this vector.
    */
   public final int size()
   {
      return elementCount;
   }

   /**
    * Tests if this vector has no components.
    *
    * @return  <code>true</code> if this vector has no components;
    *          <code>false</code> otherwise.
    */
   public boolean isEmpty()
   {
      return elementCount == 0;
   }

   /**
    * Returns an enumeration of the components of this vector.
    *
    * @return  an enumeration of the components of this vector.
    * @see     java.util.Enumeration
    */
   public Enumeration elements()
   {
      return new VectorEnumerator(this);
   }

   /**
    * Tests if the specified object is a component in this vector.
    *
    * @param   elem   an object.
    * @return  <code>true</code> if the specified object is a component in
    *          this vector; <code>false</code> otherwise.
    */
   public boolean contains(Object elem)
   {
      return indexOf(elem,0) >= 0;
   }

   /**
    * Searches for the first occurrence of the given argument, testing
    * for equality using the <code>equals</code> method.
    *
    * @param   elem   an object.
    * @return  the index of the first occurrence of the argument in this
    *          vector; returns <code>-1</code> if the object is not found.
    * @see     java.lang.Object#equals(java.lang.Object)
    */
   public int indexOf(Object elem)
   {
      return indexOf(elem,0);
   }

   /**
    * Searches for the first occurrence of the given argument, beginning
    * the search at <code>index</code>, and testing for equality using
    * the <code>equals</code> method.
    *
    * @param   elem    an object.
    * @param   index   the index to start searching from.
    * @return  the index of the first occurrence of the object argument in
    *          this vector at position <code>index</code> or later in the
    *          vector; returns <code>-1</code> if the object is not found.
    * @see     java.lang.Object#equals(java.lang.Object)
    */
   public int indexOf(Object elem, int index)
   {
      for(int i = index;i < elementCount;i++)
         if(elem.equals(elementData[i]))
            return i;
      return -1;
   }

   /**
    * Returns the index of the last occurrence of the specified object in
    * this vector.
    *
    * @param   elem   the desired component.
    * @return  the index of the last occurrence of the specified object in
    *          this vector; returns <code>-1</code> if the object is not found.
    */
   public int lastIndexOf(Object elem)
   {
      return lastIndexOf(elem,elementCount - 1);
   }

   /**
    * Searches backwards for the specified object, starting from the
    * specified index, and returns an index to it.
    *
    * @param   elem    the desired component.
    * @param   index   the index to start searching from.
    * @return  the index of the last occurrence of the specified object in this
    *          vector at position less than <code>index</code> in the vector;
    *          <code>-1</code> if the object is not found.
    */
   public int lastIndexOf(Object elem, int index)
   {
      for(int i = index;i >= 0;i--)
         if(elem.equals(elementData[i]))
            return i;
      return -1;
   }

   /**
    * Returns the component at the specified index.
    *
    * @param      index   an index into this vector.
    * @return     the component at the specified index.
    * @exception  ArrayIndexOutOfBoundsException  if an invalid index was
    *               given.
    */
   public Object elementAt(int index)
   {
      return elementData[index];
   }

   /**
    * Returns the first component of this vector.
    *
    * @return     the first component of this vector.
    * @exception  NoSuchElementException  if this vector has no components.
    */
   public Object firstElement()
   {
      return elementData[0];
   }

   /**
    * Returns the last component of the vector.
    *
    * @return  the last component of the vector, i.e., the component at index
    *          <code>size()&nbsp;-&nbsp;1</code>.
    * @exception  NoSuchElementException  if this vector is empty.
    */
   public Object lastElement()
   {
      return elementData[elementCount - 1];
   }

   /**
    * Sets the component at the specified <code>index</code> of this
    * vector to be the specified object. The previous component at that
    * position is discarded.
    * <p>
    * The index must be a value greater than or equal to <code>0</code>
    * and less than the current size of the vector.
    *
    * @param      obj     what the component is to be set to.
    * @param      index   the specified index.
    * @exception  ArrayIndexOutOfBoundsException  if the index was invalid.
    * @see        java.util.Vector#size()
    */
   public void setElementAt(Object obj, int index)
   {
      elementData[index] = obj;
      if(index >= elementCount)
         elementCount = index + 1;
   }

   /**
    * Deletes the component at the specified index. Each component in
    * this vector with an index greater or equal to the specified
    * <code>index</code> is shifted downward to have an index one
    * smaller than the value it had previously.
    * <p>
    * The index must be a value greater than or equal to <code>0</code>
    * and less than the current size of the vector.
    *
    * @param      index   the index of the object to remove.
    * @exception  ArrayIndexOutOfBoundsException  if the index was invalid.
    * @see        java.util.Vector#size()
    */
   public void removeElementAt(int index)
   {
      int j = elementCount - index - 1;
      if(j > 0)
         System.arraycopy(elementData,index + 1,elementData,index,j);
      if(elementCount > 0)
         elementCount--;
      elementData[elementCount] = null;
   /* to let gc do its work */
   }

   /**
    * Inserts the specified object as a component in this vector at the
    * specified <code>index</code>. Each component in this vector with
    * an index greater or equal to the specified <code>index</code> is
    * shifted upward to have an index one greater than the value it had
    * previously.
    * <p>
    * The index must be a value greater than or equal to <code>0</code>
    * and less than or equal to the current size of the vector.
    *
    * @param      obj     the component to insert.
    * @param      index   where to insert the new component.
    * @exception  ArrayIndexOutOfBoundsException  if the index was invalid.
    * @see        java.util.Vector#size()
    */
   public void insertElementAt(Object obj, int index)
   {
      int newcount = elementCount + 1;
      if(newcount > elementData.length)
         ensureCapacityHelper(newcount);
      System.arraycopy(elementData,index,elementData,index + 1,elementCount - index);
      elementData[index] = obj;
      elementCount++;
   }

   /**
    * Adds the specified component to the end of this vector,
    * increasing its size by one. The capacity of this vector is
    * increased if its size becomes greater than its capacity.
    *
    * @param   obj   the component to be added.
    */
   public void addElement(Object obj)
   {
      int newcount = elementCount + 1;
      if(newcount > elementData.length)
         ensureCapacityHelper(newcount);
      elementData[elementCount++] = obj;
   }

   /**
    * Removes the first occurrence of the argument from this vector. If
    * the object is found in this vector, each component in the vector
    * with an index greater or equal to the object's index is shifted
    * downward to have an index one smaller than the value it had previously.
    *
    * @param   obj   the component to be removed.
    * @return  <code>true</code> if the argument was a component of this
    *          vector; <code>false</code> otherwise.
    */
   public boolean removeElement(Object obj)
   {
      int i = indexOf(obj);
      if(i >= 0)
      {
         removeElementAt(i);
         return true;
      }
      return false;
   }

   /**
    * Removes all components from this vector and sets its size to zero.
    */
   public void removeAllElements()
   {
      for(int i = 0;i < elementCount;i++)
         elementData[i] = null;
      elementCount = 0;
   }

   /**
    * Returns a string representation of this vector.
    *
    * @return  a string representation of this vector.
    */
   public String toString()
   {
      int max = size() - 1;
      StringBuffer buf = new StringBuffer();
      Enumeration e = elements();
      buf.append("[");
      for(int i = 0;i <= max;i++)
      {
         Object obj = e.nextElement();
         String s = (obj==null) ? "<null>" : obj.toString();
         buf.append(s);
         if(i < max)
            buf.append(", ");
      }
      buf.append("]");
      return buf.toString();
   }

   public Object clone()
   {
      Object[] _new = new Object[elementCount];
      System.arraycopy(elementData,0,_new,0,elementCount);
      return new Vector(_new);
   }

}

final class VectorEnumerator implements Enumeration
{
   openlink.util.Vector vector;

   int count;

   VectorEnumerator(openlink.util.Vector v)
   {
      vector = v;
      count = 0;
   }

   public boolean hasMoreElements()
   {
      return count < vector.elementCount;
   }

   public Object nextElement()
   {
      return vector.elementData[count++];
   }

}

