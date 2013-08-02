/*
 *  $Id$
 *
 *  Implementation of the JDBC Clob class
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

import java.sql.Clob;
import java.io.*;
import java.sql.SQLException;

public class OPLHeapClob implements Clob, Serializable {

  static final long serialVersionUID = 6296947263965593908L;

  private char[] blobData = null;
  private long  blobLength = 0;
  private final static int buf_size = 0x8000;
  private Object lck;

  public OPLHeapClob() {
    lck = this;
    blobData = new char[1];
  }

  public OPLHeapClob(String b) {
    lck = this;
    blobData = b.toCharArray();
    blobLength = blobData.length;
  }

  public OPLHeapClob(char[] b) {
    lck = this;
    blobData = new char[b.length];
    System.arraycopy(b, 0, blobData, 0, b.length);
    blobLength = b.length;
  }

  public OPLHeapClob(Reader is) throws SQLException {
    lck = this;
    try {
      CharArrayWriter out = new CharArrayWriter(buf_size);
      BufferedReader in = new BufferedReader(is, buf_size);
      char[] tmp = new char[buf_size];
      int sz = in.read(tmp, 0, buf_size);

      while( sz != -1 ) {
  	out.write(tmp, 0, sz);
	sz = in.read(tmp, 0, buf_size);
      }
      blobData = out.toCharArray();
      blobLength = blobData.length;
    } catch( IOException e ) {
      throw OPLMessage_u.makeException(e);
    }
  }

  /**
   * Retrieves the number of characters
   * in the <code>CLOB</code> value
   * designated by this <code>Clob</code> object.
   *
   * @return length of the <code>CLOB</code> in characters
   * @exception SQLException if there is an error accessing the
   *            length of the <code>CLOB</code> value
   * @since 1.2
   */
  public long length() throws SQLException {
    ensureOpen();
    synchronized(lck) {
      return blobLength;
    }
  }

  /**
   * Retrieves a copy of the specified substring
   * in the <code>CLOB</code> value
   * designated by this <code>Clob</code> object.
   * The substring begins at position
   * <code>pos</code> and has up to <code>length</code> consecutive
   * characters.
   *
   * @param pos the first character of the substring to be extracted.
   *            The first character is at position 1.
   * @param length the number of consecutive characters to be copied
   * @return a <code>String</code> that is the specified substring in
   *         the <code>CLOB</code> value designated by this <code>Clob</code> object
   * @exception SQLException if there is an error accessing the
   *            <code>CLOB</code> value
   * @since 1.2
   */
  public String getSubString(long pos, int len) throws SQLException {
    ensureOpen();
    synchronized(lck) {
      pos--;
      if ( pos >= blobLength )
        throw OPLMessage_u.makeException(OPLMessage_u.erru_Invalid_start_position);

      if ( len > blobLength - pos )
        len = (int)(blobLength - pos);

      return new String(blobData, (int)pos, len);
    }
  }

  /**
   * Retrieves the <code>CLOB</code> value designated by this <code>Clob</code>
   * object as a <code>java.io.Reader</code> object (or as a stream of
   * characters).
   *
   * @return a <code>java.io.Reader</code> object containing the
   *         <code>CLOB</code> data
   * @exception SQLException if there is an error accessing the
   *            <code>CLOB</code> value
   * @see #setCharacterStream
   * @since 1.2
   */
  public Reader getCharacterStream() throws SQLException {
    ensureOpen();
    return new OPLHeapClob.BlobInputReader(lck);
  }

  /**
   * Retrieves the <code>CLOB</code> value designated by this <code>Clob</code>
   * object as an ascii stream.
   *
   * @return a <code>java.io.InputStream</code> object containing the
   *         <code>CLOB</code> data
   * @exception SQLException if there is an error accessing the
   *            <code>CLOB</code> value
   * @see #setAsciiStream
   * @since 1.2
   */
  public InputStream getAsciiStream() throws SQLException {
    ensureOpen();
    return new BlobInputStream(getCharacterStream());
  }

  /**
   * Retrieves the character position at which the specified substring
   * <code>searchstr</code> appears in the SQL <code>CLOB</code> value
   * represented by this <code>Clob</code> object.  The search
   * begins at position <code>start</code>.
   *
   * @param searchstr the substring for which to search
   * @param start the position at which to begin searching; the first position
   *              is 1
   * @return the position at which the substring appears or -1 if it is not
   *         present; the first position is 1
   * @exception SQLException if there is an error accessing the
   *            <code>CLOB</code> value
   * @since 1.2
   */
  public long position(String searchstr, long start) throws SQLException {
    ensureOpen();
    synchronized(lck) {
      if ( start < 1 )
        throw OPLMessage_u.makeException(OPLMessage_u.erru_Invalid_start_position);

      start--;
      boolean match;

      if (start > blobLength)
        return -1;

      for(int i=(int)start; i<blobLength; i++) {
        if( searchstr.length() > (blobLength-i) )
            break;

        if( blobData[i] == searchstr.charAt(0) ) {
  	    match = true;

	    for(int j=1; j<searchstr.length(); j++) {
	      if( blobData[i+j] != searchstr.charAt(j) ) {
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
   * Retrieves the character position at which the specified
   * <code>Clob</code> object <code>searchstr</code> appears in this
   * <code>Clob</code> object.  The search begins at position
   * <code>start</code>.
   *
   * @param searchstr the <code>Clob</code> object for which to search
   * @param start the position at which to begin searching; the first
   *              position is 1
   * @return the position at which the <code>Clob</code> object appears
   *              or -1 if it is not present; the first position is 1
   * @exception SQLException if there is an error accessing the
   *            <code>CLOB</code> value
   * @since 1.2
   */
  public long position(Clob searchstr, long start) throws SQLException {
    ensureOpen();
    if( start < 1 )
        throw OPLMessage_u.makeException(OPLMessage_u.erru_Invalid_start_position);

    return position(searchstr.getSubString(0, (int)searchstr.length()), start);
  }

    //---------------------------- jdbc 3.0 -----------------------------------

#if JDK_VER >= 14

    /**
     * Writes the given Java <code>String</code> to the <code>CLOB</code>
     * value that this <code>Clob</code> object designates at the position
     * <code>pos</code>.
     *
     * @param pos the position at which to start writing to the <code>CLOB</code>
     *         value that this <code>Clob</code> object represents
     * @param str the string to be written to the <code>CLOB</code>
     *        value that this <code>Clob</code> designates
     * @return the number of characters written
     * @exception SQLException if there is an error accessing the
     *            <code>CLOB</code> value
     *
     * @since 1.4
     */
  public int setString(long pos, String str) throws SQLException {
    ensureOpen();
    return setString(pos, str, 0, str.length());
  }

    /**
     * Writes <code>len</code> characters of <code>str</code>, starting
     * at character <code>offset</code>, to the <code>CLOB</code> value
     * that this <code>Clob</code> represents.
     *
     * @param pos the position at which to start writing to this
     *        <code>CLOB</code> object
     * @param str the string to be written to the <code>CLOB</code>
     *        value that this <code>Clob</code> object represents
     * @param offset the offset into <code>str</code> to start reading
     *        the characters to be written
     * @param len the number of characters to be written
     * @return the number of characters written
     * @exception SQLException if there is an error accessing the
     *            <code>CLOB</code> value
     *
     * @since 1.4
     */
  public int setString(long pos, String str, int offset, int len) throws SQLException {
    ensureOpen();
    synchronized (lck) {
      Writer os = new BlobOutputWriter(lck, pos);
      try {
        os.write(str, offset, len);
      } catch (IOException e) {
        OPLMessage_u.makeException(e);
      }
    }
    return len;
  }

    /**
     * Retrieves a stream to be used to write Ascii characters to the
     * <code>CLOB</code> value that this <code>Clob</code> object represents,
     * starting at position <code>pos</code>.
     *
     * @param pos the position at which to start writing to this
     *        <code>CLOB</code> object
     * @return the stream to which ASCII encoded characters can be written
     * @exception SQLException if there is an error accessing the
     *            <code>CLOB</code> value
     * @see #getAsciiStream
     *
     * @since 1.4
     */
  public java.io.OutputStream setAsciiStream(long pos) throws SQLException {
    ensureOpen();
    return new BlobOutputStream(new BlobOutputWriter(lck, pos));
  }

    /**
     * Retrieves a stream to be used to write a stream of Unicode characters
     * to the <code>CLOB</code> value that this <code>Clob</code> object
     * represents, at position <code>pos</code>.
     *
     * @param  pos the position at which to start writing to the
     *        <code>CLOB</code> value
     *
     * @return a stream to which Unicode encoded characters can be written
     * @exception SQLException if there is an error accessing the
     *            <code>CLOB</code> value
     * @see #getCharacterStream
     *
     * @since 1.4
     */
  public java.io.Writer setCharacterStream(long pos) throws SQLException {
    ensureOpen();
    return new BlobOutputWriter(lck, pos);
  }

    /**
     * Truncates the <code>CLOB</code> value that this <code>Clob</code>
     * designates to have a length of <code>len</code>
     * characters.
     * @param len the length, in bytes, to which the <code>CLOB</code> value
     *        should be truncated
     * @exception SQLException if there is an error accessing the
     *            <code>CLOB</code> value
     *
     * @since 1.4
     */
  public void truncate(long len) throws SQLException {
    ensureOpen();
    synchronized(lck) {
      int newLen = (int)len;
      if (newLen < 0 || newLen > blobData.length)
         throw OPLMessage_u.makeException(OPLMessage_u.erru_Invalid_length);
      if (newLen < blobData.length) {
        char[] newbuf = new char[newLen];
        System.arraycopy(blobData, 0, newbuf, 0, newLen);
        blobData = newbuf;
      }
      blobLength = len;
    }
  }

#if JDK_VER >= 16
    /**
     * This method frees the <code>Clob</code> object and releases the resources the resources
     * that it holds.  The object is invalid once the <code>free</code> method
     * is called.
     * <p>
     * After <code>free</code> has been called, any attempt to invoke a
     * method other than <code>free</code> will result in a <code>SQLException</code>
     * being thrown.  If <code>free</code> is called multiple times, the subsequent
     * calls to <code>free</code> are treated as a no-op.
     * <p>
     * @throws SQLException if an error occurs releasing
     * the Clob's resources
     *
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
     * Returns a <code>Reader</code> object that contains a partial <code>Clob</code> value, starting
     * with the character specified by pos, which is length characters in length.
     *
     * @param pos the offset to the first character of the partial value to
     * be retrieved.  The first character in the Clob is at position 1.
     * @param length the length in characters of the partial value to be retrieved.
     * @return <code>Reader</code> through which the partial <code>Clob</code> value can be read.
     * @throws SQLException if pos is less than 1 or if pos is greater than the number of
     * characters in the <code>Clob</code> or if pos + length is greater than the number of
     * characters in the <code>Clob</code>
     *
     * @exception SQLFeatureNotSupportedException if the JDBC driver does not support
     * this method
     * @since 1.6
     */
  public Reader getCharacterStream(long pos, long length) throws SQLException
  {
    ensureOpen();
    return new OPLHeapClob.BlobInputReader(lck, pos, length);
  }


#endif
#endif

  private void ensureOpen() throws SQLException
  {
    if (blobData == null)
       throw OPLMessage_u.makeException(OPLMessage_u.erru_Blob_is_freed);
  }


  // === Inner class ===========================================
  protected class BlobInputReader extends Reader {

    private boolean isClosed = false;
    private int pos = 0;
    private long length = 0;

    protected BlobInputReader(Object lck) {
      super(lck);
      length = blobData.length;
    }

    protected BlobInputReader(Object lck, long pos, long length) {
      super(lck);
      this.pos = (int)pos;
      this.length = length;
    }

    public int read() throws IOException {
      synchronized (lock) {
        ensureOpen();
        return (pos < length) ? blobData[pos++] : -1;
      }
    }

    public int read(char b[], int off, int len) throws IOException {
      synchronized (lock) {
	ensureOpen();
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

    public synchronized long skip(long n) throws IOException {
	synchronized (lock) {
	    ensureOpen();
	    if (pos + n > length)
		n = length - pos;

	    if (n < 0)
		return 0;

	    pos += n;
	    return n;
	}
    }

    public boolean ready() throws IOException {
      synchronized (lock) {
        ensureOpen();
        return true;
      }
    }

    public void close() {
	isClosed = true;
    }

    private void ensureOpen() throws IOException {
        if (isClosed || blobData == null)
          throw new IOException(OPLMessage_u.getMessage(OPLMessage_u.erru_Stream_is_closed));
    }
  }

  // === Inner class ===========================================
  protected class BlobInputStream extends InputStream {
    private static final int defBufSize = 32;
    private byte[] buf;
    private char[] cbuf;
    private int pos = 0;
    private int count = 0;
    private Reader in;

    BlobInputStream(Reader in) {
      buf = new byte[defBufSize];
      cbuf = new char[defBufSize / 4];
      this.in = in;
    }

    private void ensureOpen() throws IOException {
      if (in == null || blobData == null)
         throw new IOException(OPLMessage_u.getMessage(OPLMessage_u.erru_Stream_is_closed));
    }

    private void fill() throws IOException {
      count = pos = 0;
      int cnt;

      if ((cnt = in.read(cbuf)) == -1)
         return;//EOF

      byte[] tmp = (new String(cbuf)).getBytes();
      System.arraycopy(tmp, 0, buf, 0, tmp.length);
      count = tmp.length;
    }

    public synchronized int read() throws IOException {
      ensureOpen();
      if (pos >= count) {
          fill();
          if (pos >= count)
	      return -1;
      }
      return buf[pos++] & 0xff;
    }

    private int read1(byte[] b, int off, int len) throws IOException {
      int avail = count - pos;
      if (avail <= 0) {
          fill();
          avail = count - pos;
          if (avail <= 0) return -1;
      }
      int cnt = (avail < len) ? avail : len;
      System.arraycopy(buf, pos, b, off, cnt);
      pos += cnt;
      return cnt;
    }

    public synchronized int read(byte b[], int off, int len)
	  throws IOException
    {
      ensureOpen();
      if ((off | len | (off + len) | (b.length - (off + len))) < 0)
        throw new IndexOutOfBoundsException();
      else if (len == 0)
        return 0;

      int n = read1(b, off, len);
      if (n <= 0) return n;
      while (n < len) {
          int n1 = read1(b, off + n, len - n);
          if (n1 <= 0) break;
          n += n1;
      }
      return n;
    }

    public synchronized int available() throws IOException {
      ensureOpen();
      return (count - pos);
    }

    public synchronized void close() throws IOException
    {
      buf = null;
      cbuf = null;
      in.close();
      in = null;
    }

  }

#if JDK_VER >= 14
  // === Inner class ===========================================
  protected class BlobOutputWriter extends Writer {

    protected int count;
    private boolean isClosed = false;

    protected BlobOutputWriter(Object lck, long pos) {
      super(lck);
      count = (int)pos;
    }

    public void write(int c) throws IOException {
      ensureOpen();
      synchronized (lock) {
	int newcount = count + 1;
	if (newcount > blobData.length) {
	   char newbuf[] = new char[Math.max(blobData.length + buf_size, newcount)];
	   System.arraycopy(blobData, 0, newbuf, 0, count);
	   blobData = newbuf;
        }
	blobData[count] = (char)c;
	count = newcount;
      }
    }

    public void write(char c[], int off, int len) throws IOException {
      ensureOpen();
      if ((off < 0) || (off > c.length) || (len < 0) ||
         ((off + len) > c.length) || ((off + len) < 0)) {
	 throw new IndexOutOfBoundsException();
      } else if (len == 0) {
	 return;
      }
      synchronized (lock) {
	int newcount = count + len;
	if (newcount > blobData.length) {
          char newbuf[] = new char[Math.max(blobData.length + buf_size, newcount)];
	  System.arraycopy(blobData, 0, newbuf, 0, count);
	  blobData = newbuf;
        }
	System.arraycopy(c, off, blobData, count, len);
	count = newcount;
      }
    }

    public void write(String str, int off, int len) throws IOException {
      ensureOpen();
      synchronized (lock) {
	int newcount = count + len;
	if (newcount > blobData.length) {
	  char newbuf[] = new char[Math.max(blobData.length + buf_size, newcount)];
  	  System.arraycopy(blobData, 0, newbuf, 0, count);
	  blobData = newbuf;
        }
	str.getChars(off, off + len, blobData, count);
	count = newcount;
      }
    }

    public void flush() { }

    public synchronized void close() {
      synchronized (lock) {
	isClosed = true;
      }
    }

    private void ensureOpen() throws IOException {
        if (isClosed || blobData == null)
          throw new IOException(OPLMessage_u.getMessage(OPLMessage_u.erru_Stream_is_closed ));
    }
  }


  // === Inner class ===========================================
  protected class BlobOutputStream extends OutputStream {

    private Writer out;
    private boolean isClosed = false;

    protected BlobOutputStream(Writer out) {
      this.out = out;
    }

    public synchronized void write(int b) throws IOException {
      ensureOpen();
      byte[] tmp = {(byte)b};
      out.write(new String(tmp));
    }

    public void write(byte b[], int off, int len) throws IOException {
      ensureOpen();
      if (len == 0)
	 return;
      out.write(new String(b, off, len));
    }

    public void close() throws IOException{
      isClosed = true;
      out.close();
    }

    private void ensureOpen() throws IOException {
      if (isClosed || blobData == null)
         throw new IOException(OPLMessage_u.getMessage(OPLMessage_u.erru_Stream_is_closed));
    }

  }
#endif

}
