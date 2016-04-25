/*
 *  $Id$
 *
 *  Implementation of the JDBC Blob class
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

import java.sql.Blob;
import java.sql.SQLException;
import java.io.*;

public class OPLHeapBlob implements Blob, Serializable {

  static final long serialVersionUID = -6793193829176495886L;

  private byte[] blobData = null;
  private long  blobLength = 0;
  private final static int buf_size = 0x8000;
  private Object lck;

  public OPLHeapBlob() {
    lck = this;
    blobData = new byte[1];
  }

  public OPLHeapBlob(byte[] b) {
    this(b, 0, b.length);
  }

  public OPLHeapBlob(byte[] b, int off, int len) {
    lck = this;
    blobData = new byte[len];
    System.arraycopy(b, off, blobData, 0, len);
    blobLength = len;
  }

  public OPLHeapBlob(InputStream is) throws SQLException {
    lck = this;
    try {
      ByteArrayOutputStream out = new ByteArrayOutputStream(buf_size);
      BufferedInputStream in = new BufferedInputStream(is, buf_size);
      byte[] tmp = new byte[buf_size];
      int sz = in.read(tmp, 0, buf_size);

      while( sz != -1 ) {
  	out.write(tmp, 0, sz);
	sz = in.read(tmp, 0, buf_size);
      }
      blobData = out.toByteArray();
      blobLength = blobData.length;
    } catch( IOException e ) {
      throw OPLMessage_u.makeException(e);
    }
  }

  /**
   * Returns the number of bytes in the <code>BLOB</code> value
   * designated by this <code>Blob</code> object.
   * @return length of the <code>BLOB</code> in bytes
   * @exception SQLException if there is an error accessing the
   * length of the <code>BLOB</code>
   * @since 1.2
   */
  public long length() throws SQLException {
    ensureOpen();
    synchronized (lck) {
      return blobLength;
    }
  }

  /**
   * Retrieves all or part of the <code>BLOB</code>
   * value that this <code>Blob</code> object represents, as an array of
   * bytes.  This <code>byte</code> array contains up to <code>length</code>
   * consecutive bytes starting at position <code>pos</code>.
   *
   * @param pos the ordinal position of the first byte in the
   *        <code>BLOB</code> value to be extracted; the first byte is at
   *        position 1
   * @param length the number of consecutive bytes to be copied
   * @return a byte array containing up to <code>length</code>
   *         consecutive bytes from the <code>BLOB</code> value designated
   *         by this <code>Blob</code> object, starting with the
   *         byte at position <code>pos</code>
   * @exception SQLException if there is an error accessing the
   *            <code>BLOB</code> value
   * @see #setBytes
   * @since 1.2
   */
  public byte[] getBytes(long pos, int len) throws SQLException {
    ensureOpen();
    synchronized (lck) {
      pos--;
      if( pos >= blobLength )
        throw OPLMessage_u.makeException(OPLMessage_u.erru_Invalid_start_position);

      if( len > blobLength - pos )
        len = (int)(blobLength - pos);

      byte[] tmp = new byte[len];
      System.arraycopy(blobData, (int)pos, tmp, 0, len);
      return tmp;
    }
  }

  /**
   * Retrieves the <code>BLOB</code> value designated by this
   * <code>Blob</code> instance as a stream.
   *
   * @return a stream containing the <code>BLOB</code> data
   * @exception SQLException if there is an error accessing the
   *            <code>BLOB</code> value
   * @see #setBinaryStream
   * @since 1.2
   */
  public InputStream getBinaryStream() throws SQLException {
    ensureOpen();
    return new BlobInputStream(lck);
  }

  /**
   * Retrieves the byte position at which the specified byte array
   * <code>pattern</code> begins within the <code>BLOB</code>
   * value that this <code>Blob</code> object represents.  The
   * search for <code>pattern</code> begins at position
   * <code>start</code>.
   *
   * @param pattern the byte array for which to search
   * @param start the position at which to begin searching; the
   *        first position is 1
   * @return the position at which the pattern appears, else -1
   * @exception SQLException if there is an error accessing the
   * <code>BLOB</code>
   * @since 1.2
   */
  public long position(byte[] pattern, long start) throws SQLException {
    ensureOpen();
    synchronized (lck) {
      if( start < 1 )
        throw OPLMessage_u.makeException(OPLMessage_u.erru_Invalid_start_position);

      start--;
      boolean match;

      if (start > blobLength)
        return -1;

      for(int i=(int)start; i<blobLength; i++) {
        if( pattern.length > (blobLength-i) )
            break;

        if( blobData[i] == pattern[0] ) {
  	    match = true;

	    for(int j=1; j<pattern.length; j++) {
	      if( blobData[i+j] != pattern[j] ) {
	 	 match = false;
		 break;
              }
            }
	    if( match )
	       return i+1;
        }
      }
    }
    return -1;
  }

  /**
   * Retrieves the byte position in the <code>BLOB</code> value
   * designated by this <code>Blob</code> object at which
   * <code>pattern</code> begins.  The search begins at position
   * <code>start</code>.
   *
   * @param pattern the <code>Blob</code> object designating
   * the <code>BLOB</code> value for which to search
   * @param start the position in the <code>BLOB</code> value
   *        at which to begin searching; the first position is 1
   * @return the position at which the pattern begins, else -1
   * @exception SQLException if there is an error accessing the
   *            <code>BLOB</code> value
   * @since 1.2
   */
  public long position(Blob pattern, long start) throws SQLException {
    ensureOpen();
    if( start < 1 )
        throw OPLMessage_u.makeException(OPLMessage_u.erru_Invalid_start_position);

    return position(pattern.getBytes(0, (int)pattern.length()), start);
  }

    // -------------------------- JDBC 3.0 -----------------------------------
#if JDK_VER >= 14

    /**
     * Writes the given array of bytes to the <code>BLOB</code> value that
     * this <code>Blob</code> object represents, starting at position
     * <code>pos</code>, and returns the number of bytes written.
     *
     * @param pos the position in the <code>BLOB</code> object at which
     *        to start writing
     * @param bytes the array of bytes to be written to the <code>BLOB</code>
     *        value that this <code>Blob</code> object represents
     * @return the number of bytes written
     * @exception SQLException if there is an error accessing the
     *            <code>BLOB</code> value
     * @see #getBytes
     * @since 1.4
     */
  public int setBytes(long pos, byte[] bytes) throws SQLException {
    ensureOpen();
    return setBytes(pos, bytes, 0, bytes.length);
  }

    /**
     * Writes all or part of the given <code>byte</code> array to the
     * <code>BLOB</code> value that this <code>Blob</code> object represents
     * and returns the number of bytes written.
     * Writing starts at position <code>pos</code> in the <code>BLOB</code>
     * value; <code>len</code> bytes from the given byte array are written.
     *
     * @param pos the position in the <code>BLOB</code> object at which
     *        to start writing
     * @param bytes the array of bytes to be written to this <code>BLOB</code>
     *        object
     * @param offset the offset into the array <code>bytes</code> at which
     *        to start reading the bytes to be set
     * @param len the number of bytes to be written to the <code>BLOB</code>
     *        value from the array of bytes <code>bytes</code>
     * @return the number of bytes written
     * @exception SQLException if there is an error accessing the
     *            <code>BLOB</code> value
     * @see #getBytes
     * @since 1.4
     */
  public int setBytes(long pos, byte[] bytes, int offset, int len) throws SQLException {
    ensureOpen();
    synchronized (lck) {
      OutputStream os = new BlobOutputStream(lck, pos);
      try {
       os.write(bytes, offset, len);
      } catch (IOException e) {
        OPLMessage_u.makeException(e);
      }
    }
    return len;
  }

    /**
     * Retrieves a stream that can be used to write to the <code>BLOB</code>
     * value that this <code>Blob</code> object represents.  The stream begins
     * at position <code>pos</code>.
     *
     * @param pos the position in the <code>BLOB</code> value at which
     *        to start writing
     * @return a <code>java.io.OutputStream</code> object to which data can
     *         be written
     * @exception SQLException if there is an error accessing the
     *            <code>BLOB</code> value
     * @see #getBinaryStream
     * @since 1.4
     */
  public java.io.OutputStream setBinaryStream(long pos) throws SQLException {
    ensureOpen();
    return new BlobOutputStream(lck, pos);
  }

    /**
     * Truncates the <code>BLOB</code> value that this <code>Blob</code>
     * object represents to be <code>len</code> bytes in length.
     *
     * @param len the length, in bytes, to which the <code>BLOB</code> value
     *        that this <code>Blob</code> object represents should be truncated
     * @exception SQLException if there is an error accessing the
     *            <code>BLOB</code> value
     * @since 1.4
     */
  public void truncate(long len) throws SQLException {
    ensureOpen();
    synchronized (lck) {
      int newLen = (int)len;
      if( newLen < 0 || newLen > blobLength)
        throw OPLMessage_u.makeException(OPLMessage_u.erru_Invalid_length);
      if (newLen < blobData.length) {
        byte newbuf[] = new byte[newLen];
        System.arraycopy(blobData, 0, newbuf, 0, newLen);
        blobData = newbuf;
      }
      blobLength = len;
    }
  }

#if JDK_VER >= 16
    /**
     * This method frees the <code>Blob</code> object and releases the resources that
     * it holds. The object is invalid once the <code>free</code>
     * method is called.
     *<p>
     * After <code>free</code> has been called, any attempt to invoke a
     * method other than <code>free</code> will result in a <code>SQLException</code>
     * being thrown.  If <code>free</code> is called multiple times, the subsequent
     * calls to <code>free</code> are treated as a no-op.
     *<p>
     *
     * @throws SQLException if an error occurs releasing
     * the Blob's resources
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public void free() throws SQLException
  {
    synchronized (lck) {
        blobData = null;
    }
  }


    /**
     * Returns an <code>InputStream</code> object that contains a partial <code>Blob</code> value,
     * starting  with the byte specified by pos, which is length bytes in length.
     *
     * @param pos the offset to the first byte of the partial value to be retrieved.
     *  The first byte in the <code>Blob</code> is at position 1
     * @param length the length in bytes of the partial value to be retrieved
     * @return <code>InputStream</code> through which the partial <code>Blob</code> value can be read.
     * @throws SQLException if pos is less than 1 or if pos is greater than the number of bytes
     * in the <code>Blob</code> or if pos + length is greater than the number of bytes
     * in the <code>Blob</code>
     *
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public InputStream getBinaryStream(long pos, long length) throws SQLException
  {
    ensureOpen();
    return new BlobInputStream(lck, pos, length);
  }


#endif
#endif
  private void ensureOpen() throws SQLException
  {
    if (blobData == null)
       throw OPLMessage_u.makeException(OPLMessage_u.erru_Blob_is_freed);
  }


  // === Inner class ===========================================
  protected class BlobInputStream extends InputStream {

    private boolean isClosed = false;
    private int pos = 0;
    private long length;
    private Object lock;

    protected BlobInputStream(Object lck) {
      this.lock = lck;
      length = blobLength;
    }

    protected BlobInputStream(Object lck, long pos, long length) {
      this.lock = lck;
      this.pos = (int)pos;
      this.length = length;
    }

    public int read() throws IOException {
      ensureOpen();
      synchronized (lock) {
        return (pos < length) ? (blobData[pos++] & 0xff) : -1;
      }
    }

    public int read(byte b[], int off, int len) throws IOException {
      ensureOpen();
      synchronized (lock) {
	if (b == null)
	   throw new NullPointerException();

        if ((off < 0) || (off > b.length) || (len < 0) ||
		   ((off + len) > b.length) || ((off + len) < 0))
	   throw new IndexOutOfBoundsException();

	if (pos >= length)
	    return -1;

	if (pos + len > length)
	    len = (int)(length - pos);

        if (len <= 0)
           return 0;

	System.arraycopy(blobData, pos, b, off, len);
	pos += len;
	return len;
      }
    }

    public long skip(long n) throws IOException {
      ensureOpen();
      synchronized (lock) {
	if (pos + n > length)
	    n = length - pos;

	if (n < 0)
	    return 0;

	pos += n;
	return n;
      }
    }

    public void close() {
      synchronized (lock) {
	isClosed = true;
      }
    }

    private void ensureOpen() throws IOException {
        if (isClosed || blobData == null)
          throw new IOException(OPLMessage_u.getMessage(OPLMessage_u.erru_Stream_is_closed ));
    }
  }
/*DROP_FOR_JDBC2*/
  // === Inner class ===========================================
  protected class BlobOutputStream extends OutputStream {

    protected int count;
    private boolean isClosed = false;
    private Object lock;

    protected BlobOutputStream(Object lck, long pos) {
      this.lock = lck;
      count = (int)pos;
    }

    public void write(int b) throws IOException {
      ensureOpen();
      synchronized (lock) {
        int newcount = count + 1;
        if (newcount > blobData.length) {
 	  byte newbuf[] = new byte[Math.max(blobData.length + buf_size, newcount)];
	  System.arraycopy(blobData, 0, newbuf, 0, count);
	  blobData = newbuf;
        }
        blobData[count] = (byte)b;
        count = newcount;
        blobLength+=1;
      }
    }

    public void write(byte b[], int off, int len) throws IOException {
      ensureOpen();
      synchronized (lock) {
	if ((off < 0) || (off > b.length) || (len < 0) ||
            ((off + len) > b.length) || ((off + len) < 0)) {
	    throw new IndexOutOfBoundsException();
	} else if (len == 0) {
	    return;
	}
        int newcount = count + len;
        if (newcount > blobData.length) {
            byte newbuf[] = new byte[Math.max(blobData.length + buf_size, newcount)];
            System.arraycopy(blobData, 0, newbuf, 0, count);
            blobData = newbuf;
        }
        System.arraycopy(b, off, blobData, count, len);
        count = newcount;
        blobLength += len;
      }
    }

    public void close() {
      synchronized (lock) {
	isClosed = true;
      }
    }

    private void ensureOpen() throws IOException {
        if (isClosed || blobData == null)
          throw new IOException(OPLMessage_u.getMessage(OPLMessage_u.erru_Stream_is_closed ));
    }
  }
/*_DROP_FOR_JDBC2*/

}
