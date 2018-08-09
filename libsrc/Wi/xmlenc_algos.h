/*
 *  xmlenc_algos.h
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

#ifndef XMLENC_DSIG_ALGOS_H
#define XMLENC_DSIG_ALGOS_H


/* Canonicalization method */
int xenc_canon_exc_algo (dk_session_t * ses_in, long len, dk_session_t * ses_out);

/* digest functions
   typedef int (*dsig_digest_f) (dk_session_t * ses_in, long len,
	dk_session_t * ses_out, xenc_try_block_t * t);
*/
int dsig_sha1_digest (dk_session_t * ses_in, long len, caddr_t * digest_out);
int dsig_hmac_sha1_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out);

/* signature functions
   typedef int (*dsig_algo_f) (dk_session_t * ses_in, long len, xenc_key_t * key,
	dk_session_t * ses_out);
*/
int dsig_dsa_sha1_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out);
int dsig_dsa_sha1_verify (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t digest);
int dsig_rsa_sha1_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out);
int dsig_rsa_sha1_verify (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t digest);
/*
int (*dsig_canon_2_f) (query_instance_t * qi, caddr_t *  doc_tree, caddr_t * siginfo_tree,
	id_hash_t * nss, dk_session_t * ses_out);
*/
int dsig_dh_sha1_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out);
int dsig_dh_sha1_verify (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t digest);

#ifdef SHA256_ENABLE
int dsig_rsa_sha256_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out);
int dsig_rsa_sha256_verify (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t digest);
int dsig_sha256_digest (dk_session_t * ses_in, long len, caddr_t * digest_out);
int dsig_hmac_sha256_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out);
int dsig_dh_sha256_digest (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t * sign_out);
int dsig_dh_sha256_verify (dk_session_t * ses_in, long len, xenc_key_t * key, caddr_t digest);
#endif

int xml_canonicalize (query_instance_t * qi, caddr_t * doc_tree, caddr_t * siginfo_tree,
	id_hash_t * nss, dk_session_t * ses_out);

/* transforms
   typedef int (*dsig_transform_f) (dk_session_t * ses_in, long len, dk_session_t * ses_out,
				 caddr_t transform_data)
*/

int dsig_tr_enveloped_signature (query_instance_t * qi, dk_session_t * ses_in, long len,
	dk_session_t * ses_out,	caddr_t transform_data);
int dsig_tr_canon_exc_algo  (query_instance_t * qi, dk_session_t * ses_in, long len,
	dk_session_t * ses_out,	caddr_t transform_data);
int dsig_tr_fake_uri (query_instance_t * qi, dk_session_t * ses_in, long len,
	dk_session_t * ses_out,	caddr_t transform_data);

int xenc_des3_decryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out, xenc_key_t * key, xenc_try_block_t * t);
int xenc_des3_encryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			   xenc_key_t * key, xenc_try_block_t * t);
int xenc_aes_encryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			xenc_key_t * key, xenc_try_block_t * t);
int xenc_aes_decryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			xenc_key_t * key, xenc_try_block_t * t);
int xenc_rsa_decryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out, xenc_key_t * key, xenc_try_block_t * t);
int xenc_rsa_encryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			   xenc_key_t * key, xenc_try_block_t * t);
int xenc_dsa_decryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out, xenc_key_t * key, xenc_try_block_t * t);
int xenc_dsa_encryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			   xenc_key_t * key, xenc_try_block_t * t);
int xenc_signature_wrapper (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			    xenc_key_t * key, xenc_try_block_t * t);
int xenc_signature_wrapper_1 (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			      xenc_key_t * key, xenc_try_block_t * t);
int xenc_dh_decryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out, xenc_key_t * key, xenc_try_block_t * t);
int xenc_dh_encryptor (dk_session_t * ses_in, long seslen, dk_session_t * ses_out,
			   xenc_key_t * key, xenc_try_block_t * t);
/* P_SHA-1 Algorithm */
extern P_SHA1_CTX *P_SHA1_init(const char *secret, int secret_len, const char *seed, int seed_len);
extern void P_SHA1_block(P_SHA1_CTX *ctx, char *dst);
extern void P_SHA1_free(P_SHA1_CTX *ctx);

/* utilities */
/* convert non-negative integer to octet stream buf with length len
   returns zero if success
 */
int xenc_I2OSP (long x, long octet_len, unsigned char* buf);
#endif
