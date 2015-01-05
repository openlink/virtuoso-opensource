/*
 *  $Id$
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
 */

package virtuoso.jdbc2;

import javax.transaction.xa.*;

public class VirtuosoXid implements Xid {

    private int formatId;
    private byte[] globalId;
    private byte[] branchId;

    private static final byte[] encodeTable = {
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'
    };

    private static final byte[] decodeTable;
    static {
        decodeTable = new byte[256];
        int i;
        for(i = 0; i < 256; i++)
            decodeTable[i] = -1;
        for(i = 0; i < encodeTable.length; i++)
            decodeTable[encodeTable[i]] = (byte) i;
    }

    public VirtuosoXid(Xid xid) throws XAException {
        this(xid.getFormatId(), xid.getGlobalTransactionId(), xid.getBranchQualifier());
    }

    public VirtuosoXid(int formatId, byte[] globalId, byte[] branchId) throws XAException {
        this.formatId = formatId;
        this.globalId = copyId(globalId);
        this.branchId = copyId(branchId);
	//print();
    }

    public boolean equals(Object obj) {
        if (obj == null)
            return false;
        if (obj == this)
            return true;
        if (obj instanceof Xid) {
            Xid xid = (Xid) obj;
            if (formatId != xid.getFormatId())
                return false;
            if (!equalIds(globalId, xid.getGlobalTransactionId()))
                return false;
            if (!equalIds(branchId, xid.getBranchQualifier()))
                return false;
            return true;
        }
        return false;
    }

    public int hashCode() {
        return formatId + hashId(globalId) + hashId(branchId);
    }

    public int getFormatId() {
        return formatId;
    }

    public byte[] getGlobalTransactionId() {
        return globalId == null ? null : (byte[]) globalId.clone();
    }

    public byte[] getBranchQualifier() {
        return branchId == null ? null : (byte[]) branchId.clone();
    }

    VirtuosoExplicitString encode() {
	//print();
        byte[] bytes = new byte[280];
        encode(formatId, bytes, 0);
        encode(globalId.length, bytes, 8);
        encode(branchId.length, bytes, 16);
        encode(globalId, bytes, 24);
        encode(branchId, bytes, 24 + globalId.length * 2);
        for(int i = 24 + (globalId.length + branchId.length) * 2; i < 280; i++)
            bytes[i] = (byte) '0';
        return new VirtuosoExplicitString(bytes, VirtuosoTypes.DV_STRING);
    }

    static VirtuosoXid decode(String data) throws XAException {
        int fId = decode(data, 0);
        int gIdLength = decode(data, 8);
        if (gIdLength > 64)
            throw new XAException(XAException.XAER_RMERR);
        int bIdLength = decode(data, 16);
	if (bIdLength > 64)
            throw new XAException(XAException.XAER_RMERR);
        byte[] gId = decode(data, 24, gIdLength);
        byte[] bId = decode(data, 24 + gIdLength * 2, bIdLength);
        return new VirtuosoXid(fId, gId, bId);
    }

    private byte[] copyId(byte[] id) throws XAException {
    	if(id == null)
            return null;
    	if(id.length > 64)
            throw new XAException(XAException.XAER_NOTA);
    	return (byte[]) id.clone();
    }

    private boolean equalIds(byte[] a, byte[] b) {
        if(a == b || a == null && b.length == 0 || b == null && a.length == 0)
            return true;
        if(a.length != b.length)
            return false;
        for(int i = 0; i < a.length; i++) {
            if(a[i] != b[i])
                return false;
        }
        return true;
    }

    private int hashId(byte[] a) {
	int hash = 0;
        if(a != null) {
            for(int i = 0; i < a.length; i++)
                hash = hash * 17 + a[i];
        }
        return hash;
    }

    private static void encode(int n, byte[] bytes, int offset) {
    	byte[] data = new byte[4];
    	data[0] = (byte)(n >>> 24);
	data[1] = (byte)(n >>> 16);
	data[2] = (byte)(n >>> 8);
	data[3] = (byte)(n);
	encode(data, bytes, offset);
    }

    private static void encode(byte[] data, byte[] bytes, int offset) {
	for(int i = 0; i < data.length; i++) {
            byte b = data[i];
            bytes[offset++] = encodeTable[(b >> 4) & 0x0f];
            bytes[offset++] = encodeTable[b & 0x0f];
	}
    }

    private static int decode(String data, int offset) {
	byte[] bytes = decode(data, offset, 4);
	int n = (((int) bytes[0] & 0xFF) << 24) | (((int) bytes[1] & 0xFF) << 16) | (((int) bytes[2] & 0xFF) << 8) | ((int) bytes[3] & 0xFF);
        return n;
    }

    private static byte[] decode(String data, int offset, int length) {
        byte[] bytes = new byte[length];
        for(int i = 0; i < length; i++) {
            bytes[i] = (byte) ((decodeTable[data.charAt(offset)] << 4) | decodeTable[data.charAt(offset + 1)]);
            offset += 2;
        }
        return bytes;
    }

    public String toString()
    {
      StringBuffer s = new StringBuffer("formatId:"+formatId);
      s.append("globalId length:"+globalId.length);
      s.append(":");
      for(int i = 0; i < globalId.length; i++)
            s.append(" " + globalId[i]);
      s.append(" branchId length:"+branchId.length);
      s.append(":");
      for(int i = 0; i < branchId.length; i++)
            s.append(" " + branchId[i]);
      s.append("\n");
      s.append("encoded:"+encode().toString());
      return s.toString();
    }

    private void print() {
    	System.out.println("formatId: " + formatId);
	print("globalId", globalId);
	print("branchId", branchId);
    }

    private void print(String name, byte[] bytes) {
    	System.out.println(name + " length: " + bytes.length);
	System.out.print(name + ":");
    	for(int i = 0; i < bytes.length; i++) {
            System.out.print(" " + bytes[i]);
    	}
	System.out.println();
    }

    public static void main(String[] args) throws Exception {
        byte[] gid = new byte[64];
	byte[] bid = new byte[64];
	for (int i = 0; i < 64; i++) {
		gid[i] = (byte) (256 * Math.random());
		bid[i] = (byte) (256 * Math.random());
   	}
	VirtuosoXid xid = new VirtuosoXid (0, gid, bid);

	System.out.println ("encode str=" + xid.encode());
	VirtuosoXid xid2 = VirtuosoXid.decode ((xid.encode().toString()));

	if(xid.equals (xid2))
            System.out.println ("passed");
	else
            System.out.println ("failed");

	xid.print();
	xid2.print();
    }
}
