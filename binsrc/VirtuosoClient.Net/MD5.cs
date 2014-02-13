//  
//  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
//  project.
//  
//  Copyright (C) 1998-2014 OpenLink Software
//  
//  This project is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the
//  Free Software Foundation; only version 2 of the License, dated June 1991.
//  
//  This program is distributed in the hope that it will be useful, but
//  WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//  General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
//  
//  
//
// $Id$
//

using System;

#if ODBC_CLIENT
namespace OpenLink.Data.VirtuosoOdbcClient
#elif CLIENT
namespace OpenLink.Data.VirtuosoClient
#else
namespace OpenLink.Data.Virtuoso
#endif
{
	internal class MD5
	{
		/// <summary>
		/// 128-bit state
		/// </summary>
		private uint[] state = new uint[4];

		/// <summary>
		/// number of bits, modulo 2^64 (lsb first).
		/// (could be true C# long?)
		/// </summary>
		private uint[] count = new uint[2];

		/// <summary>
		/// input buffer
		/// </summary>
		private byte[] buffer = new byte[64];

		private const int S11 = 7;
		private const int S12 = 12;
		private const int S13 = 17;
		private const int S14 = 22;
		private const int S21 = 5;
		private const int S22 = 9;
		private const int S23 = 14;
		private const int S24 = 20;
		private const int S31 = 4;
		private const int S32 = 11;
		private const int S33 = 16;
		private const int S34 = 23;
		private const int S41 = 6;
		private const int S42 = 10;
		private const int S43 = 15;
		private const int S44 = 21;
		
		/// <summary>
		/// Padding for Final().
		/// </summary>
		private static byte[] padding = {
							0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
							0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
							0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
							0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
						};
		/// <summary>
		/// X Buffer for Transform().
		/// </summary>
		private uint[] x = new uint[16];

		internal MD5 ()
		{
			count[0] = count[1] = 0;

			/* Load magic initialization constants. */
			state[0] = 0x67452301;
			state[1] = 0xefcdab89;
			state[2] = 0x98badcfe;
			state[3] = 0x10325476;
		}

		internal void Update (byte[] input)
		{
			Update (input, input.Length);
		}

		/* MD5 finalization. Ends an MD5 message-digest operation, writing the
		  the message digest and zeroizing the context.
		 */
		internal byte[] Final ()
		{
			// Save number of bits
			byte[] bits = new byte[8];
			Encode (bits, count);

			// Pad out to 56 mod 64.
			int index = (int) (count[0] / 8) % 64;
			int padLen = (index < 56) ? (56 - index) : (120 - index);
			Update (padding, padLen);

			// Append length (before padding)
			Update (bits, bits.Length);

			// Store state in digest
			byte[] digest = new byte[16];
			Encode (digest, state);

			Clear ();
			return digest;
		}

		/// <summary>
		/// Zeroize sensitive information.
		/// </summary>
		private void Clear ()
		{
			count[0] = count[1] = state[0] = state[1] = state[2] = state[3] = 0;
			Array.Clear (buffer, 0, buffer.Length);
			Array.Clear (x, 0, x.Length);
		}

		/*
		 *  F, G, H and I are basic MD5 functions.
		 */

		private static uint F (uint x, uint y, uint z)
		{
			return ((x & y) | (~x & z));
		}

		private static uint G (uint x, uint y, uint z)
		{
			return ((x & z) | (y & ~z));
		}

		private static uint H (uint x, uint y, uint z)
		{
			return (x ^ y ^ z);
		}

		private static uint I (uint x, uint y, uint z)
		{
			return (y ^ (x | ~z));
		}

		/// <summary>
		/// ROTATE_LEFT rotates x left n bits.
		/// </summary>
		/// <param name="x"></param>
		/// <param name="n"></param>
		/// <returns></returns>
		private static uint RotateLeft (uint x, int n)
		{
			return ((x << n) | (x >> (32 - n)));
		}

		/*
		 * FF, GG, HH, and II transformations for rounds 1, 2, 3, and 4.
		 * Rotation is separate from addition to prevent recomputation.
		 */

		private static uint FF (uint a, uint b, uint c, uint d, uint x, int s, uint ac)
		{
			a += F (b, c, d) + x + ac;
			return RotateLeft (a, s) + b;
		}

		private static uint GG (uint a, uint b, uint c, uint d, uint x, int s, uint ac)
		{
			a += G (b, c, d) + x + ac;
			return RotateLeft (a, s) + b;
		}

		private static uint HH (uint a, uint b, uint c, uint d, uint x, int s, uint ac)
		{
			a += H (b, c, d) + x + ac;
			return RotateLeft (a, s) + b;
		}

		private static uint II (uint a, uint b, uint c, uint d, uint x, int s, uint ac)
		{
			a += I (b, c, d) + x + ac;
			return RotateLeft (a, s) + b;
		}

		/// <summary>
		/// MD5 block update operation. Continues an MD5 message-digest
		/// operation, processing another message block, and updating the
		/// context.
		/// </summary>
		/// <param name="input">input block</param>
		/// <param name="length">length of input block</param>
		private void Update (byte[] input, int inputLen)
		{
			// Compute number of bytes mod 64
			int index = (int) (count[0] / 8) % 64;

			// Update number of bits
			count[0] += (uint) (inputLen * 8);
			if (count[0] < (inputLen * 8))
				count[1]++;
			count[1] += (uint) (inputLen >> 29);

			int partLen = 64 - index;

			// Transform as many times as possible.
			int i;
			if (inputLen >= partLen)
			{
				Array.Copy (input, 0, buffer, index, partLen);
				Transform (buffer, 0);

				for (i = partLen; i + 63 < inputLen; i += 64)
					Transform (input, i);

				index = 0;
			}
			else
				i = 0;

			// Buffer remaining input
			Array.Copy (input, i, buffer, index, inputLen - i);
		}

		private void Transform (byte[] block, int offset)
		{
			uint a = state[0], b = state[1], c = state[2], d = state[3];
			Decode (x, block, offset);

			/* Round 1 */
			a = FF (a, b, c, d, x[ 0], S11, 0xd76aa478); /* 1 */
			d = FF (d, a, b, c, x[ 1], S12, 0xe8c7b756); /* 2 */
			c = FF (c, d, a, b, x[ 2], S13, 0x242070db); /* 3 */
			b = FF (b, c, d, a, x[ 3], S14, 0xc1bdceee); /* 4 */
			a = FF (a, b, c, d, x[ 4], S11, 0xf57c0faf); /* 5 */
			d = FF (d, a, b, c, x[ 5], S12, 0x4787c62a); /* 6 */
			c = FF (c, d, a, b, x[ 6], S13, 0xa8304613); /* 7 */
			b = FF (b, c, d, a, x[ 7], S14, 0xfd469501); /* 8 */
			a = FF (a, b, c, d, x[ 8], S11, 0x698098d8); /* 9 */
			d = FF (d, a, b, c, x[ 9], S12, 0x8b44f7af); /* 10 */
			c = FF (c, d, a, b, x[10], S13, 0xffff5bb1); /* 11 */
			b = FF (b, c, d, a, x[11], S14, 0x895cd7be); /* 12 */
			a = FF (a, b, c, d, x[12], S11, 0x6b901122); /* 13 */
			d = FF (d, a, b, c, x[13], S12, 0xfd987193); /* 14 */
			c = FF (c, d, a, b, x[14], S13, 0xa679438e); /* 15 */
			b = FF (b, c, d, a, x[15], S14, 0x49b40821); /* 16 */

			/* Round 2 */
			a = GG (a, b, c, d, x[ 1], S21, 0xf61e2562); /* 17 */
			d = GG (d, a, b, c, x[ 6], S22, 0xc040b340); /* 18 */
			c = GG (c, d, a, b, x[11], S23, 0x265e5a51); /* 19 */
			b = GG (b, c, d, a, x[ 0], S24, 0xe9b6c7aa); /* 20 */
			a = GG (a, b, c, d, x[ 5], S21, 0xd62f105d); /* 21 */
			d = GG (d, a, b, c, x[10], S22,  0x2441453); /* 22 */
			c = GG (c, d, a, b, x[15], S23, 0xd8a1e681); /* 23 */
			b = GG (b, c, d, a, x[ 4], S24, 0xe7d3fbc8); /* 24 */
			a = GG (a, b, c, d, x[ 9], S21, 0x21e1cde6); /* 25 */
			d = GG (d, a, b, c, x[14], S22, 0xc33707d6); /* 26 */
			c = GG (c, d, a, b, x[ 3], S23, 0xf4d50d87); /* 27 */
			b = GG (b, c, d, a, x[ 8], S24, 0x455a14ed); /* 28 */
			a = GG (a, b, c, d, x[13], S21, 0xa9e3e905); /* 29 */
			d = GG (d, a, b, c, x[ 2], S22, 0xfcefa3f8); /* 30 */
			c = GG (c, d, a, b, x[ 7], S23, 0x676f02d9); /* 31 */
			b = GG (b, c, d, a, x[12], S24, 0x8d2a4c8a); /* 32 */

			/* Round 3 */
			a = HH (a, b, c, d, x[ 5], S31, 0xfffa3942); /* 33 */
			d = HH (d, a, b, c, x[ 8], S32, 0x8771f681); /* 34 */
			c = HH (c, d, a, b, x[11], S33, 0x6d9d6122); /* 35 */
			b = HH (b, c, d, a, x[14], S34, 0xfde5380c); /* 36 */
			a = HH (a, b, c, d, x[ 1], S31, 0xa4beea44); /* 37 */
			d = HH (d, a, b, c, x[ 4], S32, 0x4bdecfa9); /* 38 */
			c = HH (c, d, a, b, x[ 7], S33, 0xf6bb4b60); /* 39 */
			b = HH (b, c, d, a, x[10], S34, 0xbebfbc70); /* 40 */
			a = HH (a, b, c, d, x[13], S31, 0x289b7ec6); /* 41 */
			d = HH (d, a, b, c, x[ 0], S32, 0xeaa127fa); /* 42 */
			c = HH (c, d, a, b, x[ 3], S33, 0xd4ef3085); /* 43 */
			b = HH (b, c, d, a, x[ 6], S34,  0x4881d05); /* 44 */
			a = HH (a, b, c, d, x[ 9], S31, 0xd9d4d039); /* 45 */
			d = HH (d, a, b, c, x[12], S32, 0xe6db99e5); /* 46 */
			c = HH (c, d, a, b, x[15], S33, 0x1fa27cf8); /* 47 */
			b = HH (b, c, d, a, x[ 2], S34, 0xc4ac5665); /* 48 */

			/* Round 4 */
			a = II (a, b, c, d, x[ 0], S41, 0xf4292244); /* 49 */
			d = II (d, a, b, c, x[ 7], S42, 0x432aff97); /* 50 */
			c = II (c, d, a, b, x[14], S43, 0xab9423a7); /* 51 */
			b = II (b, c, d, a, x[ 5], S44, 0xfc93a039); /* 52 */
			a = II (a, b, c, d, x[12], S41, 0x655b59c3); /* 53 */
			d = II (d, a, b, c, x[ 3], S42, 0x8f0ccc92); /* 54 */
			c = II (c, d, a, b, x[10], S43, 0xffeff47d); /* 55 */
			b = II (b, c, d, a, x[ 1], S44, 0x85845dd1); /* 56 */
			a = II (a, b, c, d, x[ 8], S41, 0x6fa87e4f); /* 57 */
			d = II (d, a, b, c, x[15], S42, 0xfe2ce6e0); /* 58 */
			c = II (c, d, a, b, x[ 6], S43, 0xa3014314); /* 59 */
			b = II (b, c, d, a, x[13], S44, 0x4e0811a1); /* 60 */
			a = II (a, b, c, d, x[ 4], S41, 0xf7537e82); /* 61 */
			d = II (d, a, b, c, x[11], S42, 0xbd3af235); /* 62 */
			c = II (c, d, a, b, x[ 2], S43, 0x2ad7d2bb); /* 63 */
			b = II (b, c, d, a, x[ 9], S44, 0xeb86d391); /* 64 */

			state[0] += a;
			state[1] += b;
			state[2] += c;
			state[3] += d;

			/* Zeroize sensitive information. */
			Array.Clear (x, 0, x.Length);
		}

		/// <summary>
		/// Encodes input (UInt32) into output (Byte).
		/// </summary>
		/// <param name="output"></param>
		/// <param name="input"></param>
		private static void Encode (byte[] output, uint[] input)
		{
			for (int i = 0, j = 0; i < input.Length; i++) 
			{
				output[j++] = (byte) (input[i]);
				output[j++] = (byte) (input[i] >> 8);
				output[j++] = (byte) (input[i] >> 16);
				output[j++] = (byte) (input[i] >> 24);
			}
		}

		/* Decodes input (unsigned char) into output (UINT4). Assumes len is
		  a multiple of 4.
		 */
		private static void Decode (uint[] output, byte[] input, int offset)
		{
			for (int i = 0, j = offset; i < output.Length; i++, j += 4)
			{
				output[i] = ((uint) input[j]) |
					(((uint) input[j+1]) << 8) |
					(((uint) input[j+2]) << 16) |
					(((uint) input[j+3]) << 24);
			}
		}

#if MD5_TEST
		// Length of test block, number of test blocks.
		private const int TEST_BLOCK_LEN = 1000;
		private const int TEST_BLOCK_COUNT = 1000;

		// Main driver.
		//
		// Arguments (may be any combination):
		//  -sstring - digests string
		//  -t	   - runs time trial
		//  -x	   - runs test script
		//  filename - digests file
		//  (none)   - digests standard input
		public static void Main (string[] args)
		{
			if (args.Length > 0)
			{
				for (int i = 0; i < args.Length; i++)
				{
					if (args[i].StartsWith ("-s"))
						MDString (args[i].Substring (2));
					else if (args[i] == "-t")
						MDTimeTrial ();
					else if (args[i] == "-x")
						MDTestSuite ();
					else
						MDFile (args[i]);
				}
			}
			else
			{
				MDFilter ();
			}
		}

		// Digests a string and prints the result.
		private static void MDString (string s)
		{
			System.Text.Encoding encoding = System.Text.Encoding.GetEncoding ("iso-8859-1");
			if (encoding == null)
				throw new SystemException ("Cannot get iso-8859-1 encoding.");
			byte[] bytes = encoding.GetBytes (s);

			MD5 md5 = new MD5 ();
			md5.Update (bytes);
			byte[] digest = md5.Final ();

			Console.Write ("MD5 (\"{0}\") = ", s);
			MDPrint (digest);
			Console.WriteLine ();
		}

		// Measures the time to digest TEST_BLOCK_COUNT TEST_BLOCK_LEN-byte blocks.
		private static void MDTimeTrial ()
		{
			Console.WriteLine ("MD5 time trial. Digesting {0} {1}-byte blocks ...", TEST_BLOCK_LEN, TEST_BLOCK_COUNT);

			/* Initialize block */
			byte[] block = new byte[TEST_BLOCK_LEN];
			for (int i = 0; i < TEST_BLOCK_LEN; i++)
				block[i] = (byte) (i & 0xff);

			/* Start timer */
			DateTime startTime = DateTime.Now;

			/* Digest blocks */
			MD5 md5 = new MD5 ();
			for (int i = 0; i < TEST_BLOCK_COUNT; i++)
				md5.Update (block, TEST_BLOCK_LEN);
			byte[] digest = md5.Final ();

			/* Stop timer */
			DateTime endTime = DateTime.Now;

			TimeSpan time = endTime - startTime;

			Console.WriteLine ("done");
			Console.Write ("Digest = ");
			MDPrint (digest);
			Console.WriteLine ();
			Console.WriteLine ("Time = {0} seconds\n", time.TotalSeconds);
			Console.WriteLine ("Speed = {0} bytes/second", (long) TEST_BLOCK_LEN * (long) TEST_BLOCK_COUNT / time.TotalSeconds);
		}

		// Digests a reference suite of strings and prints the results.
		private static void MDTestSuite ()
		{
			Console.WriteLine ("MD5 test suite:");

			MDString ("");
			MDString ("a");
			MDString ("abc");
			MDString ("message digest");
			MDString ("abcdefghijklmnopqrstuvwxyz");
			MDString ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");
			MDString ("12345678901234567890123456789012345678901234567890123456789012345678901234567890");
		}

		// Digests a file and prints the result.
		private static void MDFile (string filename)
		{
			/*
			FILE *file;
			MD_CTX context;
			int len;
			unsigned char buffer[1024], digest[16];

			if ((file = fopen (filename, "rb")) == NULL)
				printf ("%s can't be opened\n", filename);
			else 
			{
				MDInit (&context);
				while (len = fread (buffer, 1, 1024, file))
					MDUpdate (&context, buffer, len);
				MDFinal (digest, &context);

				fclose (file);

				printf ("MD%d (%s) = ", MD, filename);
				MDPrint (digest);
				printf ("\n");
			}
			*/
		}

		// Digests the standard input and prints the result.
		private static void MDFilter ()
		{
			/*
			MD_CTX context;
			int len;
			unsigned char buffer[16], digest[16];

			MDInit (&context);
			while (len = fread (buffer, 1, 16, stdin))
				MDUpdate (&context, buffer, len);
			MDFinal (digest, &context);

			MDPrint (digest);
			printf ("\n");
			*/
		}

		/* Prints a message digest in hexadecimal.
		 */
		private static void MDPrint (byte[] digest)
		{
			for (int i = 0; i < digest.Length; i++)
				Console.Write ("{0:x2}", digest[i]);
		}
#endif
	}
}
