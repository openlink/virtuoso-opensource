/*
 *  bif_phrasematch.c
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

#include "libutil.h"
#include "sqlfn.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "bif_text.h"
#include "text.h"
#include "xml.h"
#include "bif_xper.h"
#include "srvmultibyte.h"
#include "html_mode.h"
#include "security.h"
#include "xmlparser.h"
#include "xmlparser_impl.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "langfunc.h"
#ifdef __cplusplus
}
#endif
#include "arith.h"

/*! Phrase class as stored in DB.DBA.SYS_ANN_PHRASE_CLASS */
typedef struct ap_class_s {
  ptrlong	apc_id;			/*!< Class ID as in APC_ID */
  caddr_t	apc_name;		/*!< Reference name of a class as in APC_NAME */
  ptrlong	apc_owner_uid;		/*!< Owner UID, as in APC_OWNER_UID, -1 if NULL */
  ptrlong	apc_reader_gid;		/*!< Reader GID, as in APC_READER_GID, -1 if NULL */
  caddr_t	apc_callback;		/*!< Default class-specific annotation callback */
  caddr_t	apc_app_env;		/*!< Any app-specific data for callback */
  rwlock_t *	apc_rwlock;
} ap_class_t;

/*! Description of in-memory bitarrays. */
typedef struct ap_bitarrays_s {
  uint32 *	apb_arrayX;	/*!< First bitarray */
  uint32 *	apb_arrayY;	/*!< Second bitarray */
  size_t	apb_bufsize;	/*!< Size of every bitarray in memory, in bytes */
  int		apb_scale;	/*!< Bitarray scale (how many bits in the index of a bit in the array) */
  int		apb_diffbits;	/*!< Number of bits of the checksum that are used only in one of bitarrays */
  int		apb_unusedbits; /*!< Number of bits of the checksum that are not used in any of bitarrays */
  int		apb_shift;	/*!< Right shift to get full index in arrayX and high bits of index in arrayY from a checksum */
  uint32	apb_maskYhi;	/*!< Mask to get high bits of index in arrayY from a checksum */
  uint32	apb_maskYlo;	/*!< Mask to get low bits of index in arrayY from a checksum (its shift is equal to apb_unusedbits) */
  int		apb_arrays_ok;	/*!< Nonzero if arrayX and arrayY are filled by actual data, zero if only initialized by zeroes. */
} ap_bitarrays_t;

#define AP_CHKSUM_TO_X(apb,chk) ((chk) >> (apb).apb_shift)
#define AP_CHKSUM_TO_Y(apb,chk) ((((chk) >> (apb).apb_shift) & (apb).apb_maskYhi) | (((chk) >> apb.apb_unusedbits) & (apb).apb_maskYlo))
#define AP_CHKSUM_TO_MIN_CHKSUM_OF_SAME_X(apb,chk) (((chk) >> (apb).apb_shift) << (apb).apb_shift)
#define AP_CHKSUM_TO_MAX_CHKSUM_OF_SAME_X(apb,chk) (~(((~(chk)) >> (apb).apb_shift) << (apb).apb_shift))

#define APS_PHRASE_VALID 0
#define APS_PHRASE_EMPTY -1
#define APS_PHRASE_LONG -2

#define AP_PHRASE_CHKSUM_MASK 0x7FFFffff

/*! Phrase set (almost) as stored in DB.DBA.SYS_ANN_PHRASE_SET */
typedef struct ap_set_s {
  ptrlong	aps_id;		/*!< Set ID as in APS_ID */
  caddr_t	aps_name;	/*!< Reference name as in APS_NAME */
  ptrlong	aps_owner_uid;	/*!< Owner UID, as in APS_OWNER_UID, -1 if NULL */
  ptrlong	aps_reader_gid;	/*!< Reader GID, as in APS_READER_GID, -1 if NULL */
  ap_class_t *  aps_class;	/*!< Class of the phrase set whose apc_id is equal to APS_APC_ID */
  lang_handler_t * aps_lh;	/*!< Language handler whose name is equal to APS_LANG_NAME */
  caddr_t	aps_app_env;	/*!< Any app-specific data for callback */
  ptrlong	aps_size;	/*!< Current number of phrases in the set */
  ap_bitarrays_t aps_bitarrays;	/*!< In-memory bitarrays */
  rwlock_t *	aps_rwlock;
#ifdef AP_CHKSUM_DEBUG
  ptrlong	aps_probes;	/*!< Number of probes */
  ptrlong	aps_bit_hits;	/*!< Number of bitmask hits */
  ptrlong	aps_real_hits;	/*!< Number of table hits */
#endif
} ap_set_t;

/*! Phrase (almost) as stored in DB.DBA.SYS_ANN_PHRASE */
typedef struct ap_phrase_s {
  uint32	app_chksum;	/*!< The hash checksum of the phrase as in AP_CHKSUM */
  ap_set_t *	app_set;	/*!< Pointer to the phrase set mentioned in AP_APS_ID */
  caddr_t	app_text;	/*!< Text of the phrase in UTF-8, as in AP_TEXT */
  /* nothing for AP_PARSED_TEXT for a while */
  caddr_t	app_link_data;	/*!< Deserialized content of AP_LINK_DATA / AP_LINK_DATA_LONG */
} ap_phrase_t;

/* Internal structures of the annotation phrase processor */

#define APA_PLAIN_WORD	0
#define APA_OPENING_TAG 1
#define APA_CLOSING_TAG 2
#define APA_OTHER	3

/*! Location in the text */
typedef struct ap_arrow_s {
  int		apa_is_markup;		/*!< One of APA_xxx values */
  int		apa_start;		/*!< Byte offset of the first byte of word in the source doc */
  int		apa_end;		/*!< Byte offset of the first byte after the word in the source doc */
  unsigned	apa_htmltm_bits;	/*!< Bits from HTMLTM_xxx set of all enclosing tags */
  int		apa_innermost_tag;	/*!< The index of the arrow of the innermost tag that is opened but not yet closed where the arrow begins */
  dk_set_t	apa_all_hits;		/*!< All hits that are in effect at this word (actual phrases only not checksum hits) */
} ap_arrow_t;

/*! A hit in the text (bitmask-only or fully confirmed) */
typedef struct ap_hit_s {
  int		aph_first_idx;		/*!< The index of the first word of the location where the hit is found */
  int		aph_last_idx;		/*!< The index of the last word of the location where the hit is found */
  unsigned	aph_htmltm_bits;	/*!< Bits from HTMLTM_xxx set of all enclosing tags */
  union {
    struct {
      uint32		aph_chksum;	/*!< The checksum found */
      ap_set_t *	aph_set;	/*!< The phrase set where a phrase checksum is found */
      } aph_candidate;
    struct {
      ap_phrase_t *	aph_phrase;	/*!< The phrase found */
      int		aph_serial;	/*!< The serial number of a hit in a text */
      int		aph_prev;	/*!< The serial of the previous hit of same phrase in the text, if any */
      } aph_confirmed;
    } aph_;
} ap_hit_t;

#define APPI_MAX_PHRASE_WORDS	6
#define APPI_MAX_PHRASE_NONNOISE 4

/* There are too many globals already. */

typedef struct ap_globals_s {
  int apg_init_passed;
  dk_mutex_t *apg_mutex;	/*!< Mutex used to wrap an access to members of this structure */
  dk_hash_t *apg_classes;	/*!< All registered classes */
  dk_hash_t *apg_sets;		/*!< All registered phrase sets */
  id_hash_t *apg_sets_byname;	/*!< Same, but names as keys */
  int	apg_max_aps_id;
  int	apg_max_apc_id;
} ap_globals_t;

extern ap_globals_t ap_globals;

/*! An instance of annotation phrase processor */
typedef struct ap_proc_inst_s {
/* Input parameters for document processing */
  query_instance_t *	appi_qi;	/*!< Query where the processor is called from */
  ap_set_t **	appi_sets;		/*!< An array of phrase sets to scan */
  int		appi_set_count;		/*!< Number of sets in use */
  lang_handler_t *appi_lh;		/*!< The language in use. Any of phrase sets in use are silently ignored if they does not match to this one */
  encodedlang_handler_t *appi_elh_UTF8;	/*!< handler of appi_lh in UTF-8 encoding */
  caddr_t	appi_source_UTF8;	/*!< The source in UTF-8 encoding */
/* Temporary data, mostly memory-pooled, used in callbacks of phrase classes */
  mem_pool_t *	appi_mp;
  int		appi_place_count;	/*!< Accumulated length of appi_places, i.e. actual length of appi_places_revlist */
  ap_arrow_t **	appi_places;		/*!< All places found (both words and markup) */
  int		appi_word_count;	/*!< Accumulated(?) length of appi_words */
  ap_arrow_t **	appi_words;		/*!< All words found */
  ap_phrase_t **	appi_phrases;	/*!< All phrase found, in the order of occurrence of their beginnings in the text, then in the order of their ends, then in order of set IDs */
/* Temporary data, memory-pooled, used when the source is parsed */
  wchar_t *	appi_source_wide;	/*!< The same source in wide encoding if this is required for word splitting and normalization */
  dk_set_t	appi_places_revlist;	/*!< Temporary revlist of all found places */
  int		appi_place_idx_last [APPI_MAX_PHRASE_NONNOISE];	/*!< Up to APPI_MAX_PHRASE_NONNOISE last nonnoise words, as indexes in appi_places, circular buffer */
  int		appi_place_last_ffree_idx;			/*!< Circular index of the first unused or outdated item in appi_place_idx_last */
  uint32	appi_chksums [APPI_MAX_PHRASE_NONNOISE];	/*!< Known checksums of phrases that end at current word. Index is (phrase_len - 1) */
  dk_set_t	appi_candidate_hits_revlist;			/*!< Temporary revlist of all found checksum hits */
  int		appi_candidate_hit_count;			/*!< Accumulated length of appi_candidate_hits_revlist */
  dk_set_t	appi_confirmed_hits_list;			/*!< Temporary list of all found real hits */
  int		appi_confirmed_hit_count;			/*!< Accumulated length of appi_confirmed_hits_list */
  dk_set_t	appi_phrases_revlist;				/*!< Temporary revlist of all found phrases */
  vt_batch_t *  appi_vtb;
} ap_proc_inst_t;

#define AP_FREE_LOCK		0x1	/*!< Unlock the structure (and maybe class) */
#define AP_FREE_HASHTABLES	0x2	/*!< Remove from hashtables. Wrap the call of apX_free by ap_globals.apg_mutex if the bit is set. */
#define AP_FREE_MEMBERS		0x4	/*!< Free fields but not the structure (for structures on stack) */
#define AP_FREE_STRUCT		0x8	/*!< Free the structure but not fields */

extern void apc_free (ap_class_t *apc, int mode);
extern void aps_free (ap_set_t *aps, int mode);

extern ap_class_t *apc_register (query_instance_t *qst, ptrlong id, int allow_overwrite);
extern ap_set_t *aps_register (query_instance_t *qst, ptrlong id, int allow_overwrite);
extern void ap_global_init (query_instance_t *qst);
extern ap_class_t *apc_get (ptrlong id, int lock_mode /* 0 = none, 1 = rdlock, 2 = wrlock */);
extern ap_set_t *aps_get (ptrlong id, int lock_mode /* 0 = none, 1 = rdlock, 2 = wrlock */);
extern ap_set_t *aps_get_byname (caddr_t name, int lock_mode /* 0 = none, 1 = rdlock, 2 = wrlock */);


/* Implementation. Memory cache loading and unloading */

#define APB_BLANK(apb) do { \
    memset (apb.apb_arrayX, 0, apb.apb_bufsize); \
    memset (apb.apb_arrayY, 0, apb.apb_bufsize); \
    apb.apb_arrays_ok = 0; \
  } while (0)

#define APB_ALLOC(apb) do { \
    apb.apb_arrayX = (uint32 *) dk_alloc (apb.apb_bufsize); \
    apb.apb_arrayY = (uint32 *) dk_alloc (apb.apb_bufsize); \
    APB_BLANK(apb); \
  } while (0)

#define APB_FREE(apb) do { \
    if (NULL != apb.apb_arrayX) \
      { \
	dk_free (apb.apb_arrayX, apb.apb_bufsize); \
	dk_free (apb.apb_arrayY, apb.apb_bufsize); \
	apb.apb_arrayX = NULL; \
	apb.apb_arrayY = NULL; \
      } \
  } while (0)

/*No more need: memory is cheaper :)
#define APB_ARRAYY_MULT1 223092871 */

ap_globals_t ap_globals;

/* Frees an apc, to some degree. Wrap it by ap_globals.apg_mutex if AP_FREE_HASHTABLES is used! */
void apc_free (ap_class_t *apc, int mode)
{
  if (mode & AP_FREE_LOCK)
    rwlock_unlock (apc->apc_rwlock);
  if (mode & AP_FREE_HASHTABLES)
    remhash ((void *)((ptrlong)(apc->apc_id)), ap_globals.apg_classes);
  if (mode & AP_FREE_MEMBERS)
    {
      dk_free_box (apc->apc_name);
      dk_free_box (apc->apc_callback);
      dk_free_tree (apc->apc_app_env);
      if (NULL != apc->apc_rwlock)
        rwlock_free (apc->apc_rwlock);
    }
  if (mode & AP_FREE_STRUCT)
    dk_free (apc, sizeof (ap_class_t));
}

/* Frees an aps, to some degree. Wrap it by ap_globals.apg_mutex if AP_FREE_HASHTABLES is used! */
void aps_free (ap_set_t *aps, int mode)
{
  if (mode & AP_FREE_LOCK)
    rwlock_unlock (aps->aps_rwlock);
  if (mode & AP_FREE_HASHTABLES)
    {
      remhash ((void *)((ptrlong)(aps->aps_id)), ap_globals.apg_sets);
      id_hash_remove (ap_globals.apg_sets_byname, (caddr_t)(&(aps->aps_name)));
    }
  if (mode & AP_FREE_MEMBERS)
    {
      dk_free_box (aps->aps_name);
      dk_free_tree (aps->aps_app_env);
      APB_FREE (aps->aps_bitarrays);
    }
  if (mode & AP_FREE_STRUCT)
    dk_free (aps, sizeof (ap_set_t));
}

static query_t *apc_select_by_id__qr = NULL;
static const char *apc_select_by_id__text =
  "select APC_NAME, APC_OWNER_UID, APC_READER_GID, APC_CALLBACK, APC_APP_ENV from DB.DBA.SYS_ANN_PHRASE_CLASS where APC_ID = ?";

ptrlong unbox_uid (caddr_t box)
{
  if (DV_LONG_INT == DV_TYPE_OF (box))
    return unbox (box);
#ifdef DEBUG
  if (DV_DB_NULL != DV_TYPE_OF (box))
    GPF_T;
#endif
  return -1;
}

/* Returns an wrlock-ed ap_class_t */
ap_class_t *apc_register (query_instance_t *qst, ptrlong id, int allow_overwrite)
{
  ap_class_t *apc, apc_tmp;
  caddr_t err = NULL;
  local_cursor_t *lc;
/* First of all, we try to read the table, before entering any mutexes */
  err = qr_quick_exec (apc_select_by_id__qr, qst->qi_client, "", &lc, 1, ":0", (ptrlong) id, QRP_INT);
  if ((caddr_t) SQL_SUCCESS != err)
    sqlr_resignal (err);
  if (!lc_next (lc))
    sqlr_new_error ("42000", "APC02", "Annotation phrase class #%ld not found in DB.DBA.SYS_ANN_PHRASE_CLASS", (long)id);
  if (id > ap_globals.apg_max_apc_id)
    ap_globals.apg_max_apc_id = id;
  apc_tmp.apc_id = id;
  apc_tmp.apc_name = box_copy (lc_nth_col (lc, 0));
  apc_tmp.apc_owner_uid = unbox_uid (lc_nth_col (lc, 1));
  apc_tmp.apc_reader_gid = unbox_uid (lc_nth_col (lc, 2));
  apc_tmp.apc_callback = box_copy (lc_nth_col (lc, 3));
  apc_tmp.apc_app_env = box_copy_tree (lc_nth_col (lc, 4));
  apc_tmp.apc_rwlock = NULL;
  lc_free (lc);
/* Now apc_tmp is OK */
  mutex_enter (ap_globals.apg_mutex);
  apc = (ap_class_t *) gethash ((void*)((ptrlong)id), ap_globals.apg_classes);
  if (NULL == apc)
    {
      apc = (ap_class_t *) dk_alloc (sizeof (ap_class_t));
      memcpy (apc, &apc_tmp, sizeof (ap_class_t));
      sethash ((void*)((ptrlong)id), ap_globals.apg_classes, apc);
      apc->apc_rwlock = rwlock_allocate ();
      rwlock_wrlock (apc->apc_rwlock); /* Safe to lock inside ap_globals.apg_mutex because nobody else can know the address */
      mutex_leave (ap_globals.apg_mutex);
      return apc;
    }
  if (allow_overwrite)
    {
      mutex_leave (ap_globals.apg_mutex);
      rwlock_wrlock (apc->apc_rwlock);
      apc_tmp.apc_rwlock = apc->apc_rwlock;
      apc->apc_rwlock = NULL;
      apc_free (apc, AP_FREE_MEMBERS);
      memcpy (apc, &apc_tmp, sizeof (ap_class_t));
      return apc;
    }
  else
    {
      mutex_leave (ap_globals.apg_mutex);
      apc_free (&apc_tmp, AP_FREE_MEMBERS);
      sqlr_new_error ("42000", "APC01", "Annotation phrase class #%ld is already loaded into memory", (long)id);
    }
  return apc;
}

void apc_unregister (query_instance_t *qst, ptrlong id)
{
  ap_class_t *apc;
  caddr_t err = NULL;
  local_cursor_t *lc;
/* First of all, we try to read the table, before entering any mutexes */
  err = qr_quick_exec (apc_select_by_id__qr, qst->qi_client, "", &lc, 1, ":0", (ptrlong) id, QRP_INT);
  if ((caddr_t) SQL_SUCCESS != err)
    sqlr_resignal (err);
  if (!lc_next (lc))
    sqlr_new_error ("42000", "APC03", "Annotation phrase class #%ld not found in DB.DBA.SYS_ANN_PHRASE_CLASS", (long)id);
  if (id > ap_globals.apg_max_apc_id)
    ap_globals.apg_max_apc_id = id;
  lc_free (lc);
/* Now apc_tmp is OK */
  mutex_enter (ap_globals.apg_mutex);
  apc = (ap_class_t *) gethash ((void*)((ptrlong)id), ap_globals.apg_classes);
  if (NULL == apc)
    return;
  mutex_leave (ap_globals.apg_mutex);
  rwlock_wrlock (apc->apc_rwlock);
  dk_free_tree (apc->apc_app_env);
  apc->apc_app_env = NULL;
  rwlock_unlock (apc->apc_rwlock);
  apc_free (apc, AP_FREE_LOCK /* | AP_FREE_MEMBERS | AP_FREE_STRUCT */); /* For a while, memory leak is better than GPF on access to freed mem from aps */
}

ptrlong aps_calc_scale (ptrlong size)
{
  ptrlong scale;
  scale = 1;
  while (0 != size) { scale++; size = size >> 1; }
  scale += 3;
  if (scale < 8)
    scale = 8;
  if (scale > 28)
    scale = 28;
  return scale;
}

void apb_prepare (ap_bitarrays_t *apb, ptrlong scale)
{
  apb->apb_scale = scale;
  apb->apb_bufsize = (1 << (scale - 3));
  apb->apb_diffbits = ((scale >= 16) ? (31 - scale) : scale);
  apb->apb_unusedbits = ((scale >= 16) ? 0 : (31 - 2 * scale));
  apb->apb_shift = apb->apb_diffbits + apb->apb_unusedbits;
  apb->apb_maskYlo = ((unsigned)0x7FFFFFFF) >> (31 - apb->apb_diffbits);
  apb->apb_maskYhi = ((unsigned)0x7FFFFFFF) ^ apb->apb_maskYlo;
  apb->apb_arrayX = NULL;
  apb->apb_arrayY = NULL;
  apb->apb_arrays_ok = 0;
}

static query_t *aps_select_by_id__qr = NULL;
static const char *aps_select_by_id__text =
  "select APS_NAME, APS_OWNER_UID, APS_READER_GID, APS_APC_ID, APS_LANG_NAME, APS_APP_ENV, APS_SIZE from DB.DBA.SYS_ANN_PHRASE_SET where APS_ID = ?";

/* Returns an wrlock-ed ap_set_t */
ap_set_t *aps_register (query_instance_t *qst, ptrlong id, int allow_overwrite)
{
  ap_set_t *aps, aps_tmp;
  ptrlong apc_id;
  caddr_t err = NULL;
  local_cursor_t *lc;
  ptrlong scale;
/* First of all, we try to read the table, before entering any mutexes */
  err = qr_quick_exec (aps_select_by_id__qr, qst->qi_client, "", &lc, 1, ":0", (ptrlong) id, QRP_INT);
  if ((caddr_t) SQL_SUCCESS != err)
    sqlr_resignal (err);
  if (!lc_next (lc))
    sqlr_new_error ("42000", "APS02", "Annotation phrase set #%ld not found in DB.DBA.SYS_ANN_PHRASE_SET", (long)id);
  if (id > ap_globals.apg_max_aps_id)
    ap_globals.apg_max_aps_id = id;
  memset (&aps_tmp, 0, sizeof (ap_set_t));
  aps_tmp.aps_id = id;
  aps_tmp.aps_name = box_copy (lc_nth_col (lc, 0));
  aps_tmp.aps_owner_uid = unbox_uid (lc_nth_col (lc, 1));
  aps_tmp.aps_reader_gid = unbox_uid (lc_nth_col (lc, 2));
  aps_tmp.aps_class = NULL; apc_id = unbox (lc_nth_col (lc, 3)); /* to be completed inside mutex */
  aps_tmp.aps_lh = lh_get_handler (lc_nth_col (lc, 4));
  aps_tmp.aps_app_env = box_copy_tree (lc_nth_col (lc, 5));
  aps_tmp.aps_size = unbox (lc_nth_col (lc, 6));
  aps_tmp.aps_rwlock = NULL;
/* Now we can calculate bitmap's data */
  scale = aps_calc_scale (aps_tmp.aps_size);
  apb_prepare (&aps_tmp.aps_bitarrays, scale);
  lc_free (lc);
  if (NULL == aps_tmp.aps_lh)
    sqlr_new_error ("42000", "APS06", "Annotation phrase set #%ld refers to an unknown language", (long)id);
  if (NULL == elh_get_handler (&eh__UTF8, aps_tmp.aps_lh))
    sqlr_new_error ("42000", "APS07", "Annotation phrase set #%ld refers to an language '%.300s' that has no accelerated UTF-8 support", (long)id, aps_tmp.aps_lh->lh_ISO639_id);
/* Now aps_tmp is OK */
  mutex_enter (ap_globals.apg_mutex);
  aps_tmp.aps_class = (ap_class_t *) gethash ((void *)((ptrlong)apc_id), ap_globals.apg_classes);
  if (NULL == aps_tmp.aps_class)
    {
      mutex_leave (ap_globals.apg_mutex);
      aps_free (&aps_tmp, AP_FREE_MEMBERS);
      sqlr_new_error ("42000", "APS03", "Annotation phrase set #%ld refers to a phrase class #%ld that is not registered", (long)id, (long)apc_id);
    }
  aps = (ap_set_t *) gethash ((void*)((ptrlong)id), ap_globals.apg_sets);
  if (NULL == aps)
    {
      aps = (ap_set_t *) dk_alloc (sizeof (ap_set_t));
      APB_ALLOC(aps_tmp.aps_bitarrays);
      memcpy (aps, &aps_tmp, sizeof (ap_set_t));
      sethash ((void*)((ptrlong)id), ap_globals.apg_sets, aps);
      id_hash_set (ap_globals.apg_sets_byname, (caddr_t)(&(aps->aps_name)), (caddr_t)(&aps));
      aps->aps_rwlock = rwlock_allocate ();
      rwlock_wrlock (aps->aps_rwlock); /* Safe to lock inside inside ap_globals.apg_mutex because nobody else can know the address */
      mutex_leave (ap_globals.apg_mutex);
      return aps;
    }
  if (!allow_overwrite)
    {
      mutex_leave (ap_globals.apg_mutex);
      aps_free (&aps_tmp, AP_FREE_MEMBERS);
      sqlr_new_error ("42000", "APS01", "Annotation phrase set #%ld is already loaded into memory", (long)id);
    }
  if (aps->aps_lh != aps_tmp.aps_lh)
    {
      mutex_leave (ap_globals.apg_mutex);
      aps_free (&aps_tmp, AP_FREE_MEMBERS);
      sqlr_new_error ("42000", "APS08", "Can not change the language of an annotation phrase set #%ld from '%.300s' to '%.300s'",
        (long)id, aps->aps_lh->lh_RFC1766_id, aps_tmp.aps_lh->lh_RFC1766_id );
    }
  else
    {
/* The pair of id_hash_remove() and id_hash_set() is here to prevent the use of deleted string aps->aps_name as a key */
      id_hash_remove (ap_globals.apg_sets_byname, (caddr_t)(&(aps->aps_name)));
      id_hash_set (ap_globals.apg_sets_byname, (caddr_t)(&(aps_tmp.aps_name)), (caddr_t)(&aps));
      mutex_leave (ap_globals.apg_mutex);
      rwlock_wrlock (aps->aps_rwlock);
      aps_tmp.aps_rwlock = aps->aps_rwlock;
      if (aps_tmp.aps_bitarrays.apb_bufsize == aps->aps_bitarrays.apb_bufsize)
        {
	  aps_tmp.aps_bitarrays.apb_arrayX = aps->aps_bitarrays.apb_arrayX; aps->aps_bitarrays.apb_arrayX = NULL;
	  aps_tmp.aps_bitarrays.apb_arrayY = aps->aps_bitarrays.apb_arrayY; aps->aps_bitarrays.apb_arrayY = NULL;
          aps_tmp.aps_bitarrays.apb_arrays_ok = aps->aps_bitarrays.apb_arrays_ok;
        }
      else
        {
          APB_FREE(aps->aps_bitarrays);
          APB_ALLOC(aps_tmp.aps_bitarrays);
        }
      aps->aps_rwlock = NULL;
      aps_free (aps, AP_FREE_MEMBERS);
      memcpy (aps, &aps_tmp, sizeof (ap_set_t));
      return aps;
    }
  return aps;
}

void aps_unregister (query_instance_t *qst, ptrlong id)
{
  ap_set_t *aps;
  caddr_t err = NULL;
  local_cursor_t *lc;
/* First of all, we try to read the table, before entering any mutexes */
  err = qr_quick_exec (aps_select_by_id__qr, qst->qi_client, "", &lc, 1, ":0", (ptrlong) id, QRP_INT);
  if ((caddr_t) SQL_SUCCESS != err)
    sqlr_resignal (err);
  if (!lc_next (lc))
    sqlr_new_error ("42000", "APS09", "Annotation phrase set #%ld not found in DB.DBA.SYS_ANN_PHRASE_CLASS", (long)id);
  if (id > ap_globals.apg_max_aps_id)
    ap_globals.apg_max_aps_id = id;
  lc_free (lc);
/* Now aps_tmp is OK */
  mutex_enter (ap_globals.apg_mutex);
  aps = (ap_set_t *) gethash ((void*)((ptrlong)id), ap_globals.apg_sets);
  if (NULL == aps)
    return;
  mutex_leave (ap_globals.apg_mutex);
  rwlock_wrlock (aps->aps_rwlock);
  dk_free_tree (aps->aps_app_env);
  aps->aps_app_env = NULL;
  aps_free (aps, AP_FREE_HASHTABLES | AP_FREE_LOCK | AP_FREE_MEMBERS | AP_FREE_STRUCT);
}


static query_t *ap_select_chksum_and_aps_id__qr = NULL;
static const char *ap_select_chksum_and_aps_id__text =
  "select AP_CHKSUM from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = ?";

/*! This creates all bitarrays in all phrase sets in a single pass through SYS_ANN_PHRASE. */
void aps_load_phrases (query_instance_t *qst, ap_set_t *aps)
{
  caddr_t err = NULL;
  local_cursor_t *lc;
  ap_bitarrays_t *apb = &(aps->aps_bitarrays);
  if (apb->apb_arrays_ok) /* Already filled, blank before refill */
    APB_BLANK(apb[0]);
  apb_prepare (apb, aps_calc_scale (aps->aps_size));
  APB_ALLOC(apb[0]);
  err = qr_quick_exec (ap_select_chksum_and_aps_id__qr, qst->qi_client, "", &lc, 1,
      ":0", (ptrlong) (aps->aps_id), QRP_INT );
  if ((caddr_t) SQL_SUCCESS != err)
    sqlr_resignal (err);
  while (lc_next (lc))
    {
      unsigned int32 chksum, idxX, idxY;
      /*unsigned int32 chk2, idxY2;*/
      chksum = ((uptrlong)(unbox (lc_nth_col (lc, 0)))) & AP_PHRASE_CHKSUM_MASK;
      /* chk2 = (chksum * APB_ARRAYY_MULT1) & AP_PHRASE_CHKSUM_MASK; */
      idxX = AP_CHKSUM_TO_X (aps->aps_bitarrays, chksum);
      idxY = AP_CHKSUM_TO_Y (aps->aps_bitarrays, chksum);
      /* idxY2 = AP_CHKSUM_TO_Y (aps->aps_bitarrays, chk2); */
      apb->apb_arrayX[idxX >> 5] |= (1 << (idxX & 0x1F));
      apb->apb_arrayY[idxY >> 5] |= (1 << (idxY & 0x1F));
      /*apb->apb_arrayY[idxY2 >> 5] |= (1 << (idxY2 & 0x1F));*/
    }
  apb->apb_arrays_ok = 1;
}


/* Implementation. Obtaining objects in use */

ap_class_t *apc_get (ptrlong id, int lock_mode /* 0 = none, 1 = rdlock, 2 = wrlock */)
{
  ap_class_t *res;
  if (!lock_mode)
    mutex_enter (ap_globals.apg_mutex);
  res = (ap_class_t *)gethash ((void *)id, ap_globals.apg_classes);
  if (!lock_mode)
    mutex_leave (ap_globals.apg_mutex);
  if (NULL == res)
    return NULL;
  switch (lock_mode)
    {
    case 0: break;
    case 1: rwlock_rdlock (res->apc_rwlock); break;
    case 2: rwlock_wrlock (res->apc_rwlock); break;
    default: GPF_T;
    }
  return res;
}

ap_set_t *aps_get (ptrlong id, int lock_mode /* 0 = none, 1 = rdlock, 2 = wrlock */)
{
  ap_set_t *res;
  if (!lock_mode)
    mutex_enter (ap_globals.apg_mutex);
  res = (ap_set_t *)gethash ((void *)id, ap_globals.apg_sets);
  if (!lock_mode)
    mutex_leave (ap_globals.apg_mutex);
  if (NULL == res)
    return NULL;
  switch (lock_mode)
    {
    case 0: break;
    case 1: rwlock_rdlock (res->aps_rwlock); break;
    case 2: rwlock_wrlock (res->aps_rwlock); break;
    default: GPF_T;
    }
  return res;
}

ap_set_t *aps_get_byname (caddr_t name, int lock_mode /* 0 = none, 1 = rdlock, 2 = wrlock */)
{
  ap_set_t **res_ptr, *res;
  if (!lock_mode)
    mutex_enter (ap_globals.apg_mutex);
  res_ptr = (ap_set_t **)id_hash_get (ap_globals.apg_sets_byname, (caddr_t)(&name));
  if (!lock_mode)
    mutex_leave (ap_globals.apg_mutex);
  if (NULL == res_ptr)
    return NULL;
  res = res_ptr[0];
  switch (lock_mode)
    {
    case 0: break;
    case 1: rwlock_rdlock (res->aps_rwlock); break;
    case 2: rwlock_wrlock (res->aps_rwlock); break;
    default: GPF_T;
    }
  return res;
}


ap_set_t **aps_tryrdlock_array (caddr_t *set_ids, int load_phrases, query_instance_t *qst /* can be NULL if no need to load phrases */)
{
  ap_set_t **sets;
  int set_ctr, set_count;
  set_count = BOX_ELEMENTS (set_ids);
  sets = (ap_set_t **) dk_alloc (set_count * sizeof (ap_set_t *));
  mutex_enter (ap_globals.apg_mutex);
  for (set_ctr = 0; set_ctr < set_count; set_ctr++)
    {
      ap_set_t *set = (ap_set_t *)gethash ((void *)unbox_ptrlong (set_ids[set_ctr]), ap_globals.apg_sets);
      if (NULL == set)
	goto oblom;
      if (!rwlock_tryrdlock (set->aps_rwlock))
        goto oblom;
      sets[set_ctr] = set;
    }
  if (load_phrases)
    {
      for (set_ctr = 0; set_ctr < set_count; set_ctr++)
        {
          ap_set_t *set = sets[set_ctr];
          if (!set->aps_bitarrays.apb_arrays_ok)
            aps_load_phrases (qst, set);
#ifdef AP_CHKSUM_DEBUG
	  set->aps_probes = set->aps_bit_hits = set->aps_real_hits = 0;
#endif
        }
    }
  mutex_leave (ap_globals.apg_mutex);
  return sets;

oblom:
  mutex_leave (ap_globals.apg_mutex);
  while (set_ctr-- > 0)
    rwlock_unlock (sets[set_ctr]->aps_rwlock);
  dk_free (sets, set_count * sizeof (ap_set_t *));
  sqlr_new_error ("OBLOM", "APD02", "Unable to get all phrase sets");
  return NULL;
}


void aps_unlock_array (ap_set_t **sets, int set_count, int free_array)
{
  int set_ctr;
  for (set_ctr = 0; set_ctr < set_count; set_ctr++)
    {
      ap_set_t *set = sets[set_ctr];
#ifdef AP_CHKSUM_DEBUG
      double density;
#endif
      rwlock_unlock (set->aps_rwlock);
#ifdef AP_CHKSUM_DEBUG
      dbg_printf (("Phrase set %s (%ld): %ld probes, %ld bit misses, %ld bit hits, %ld tbl misses %ld tbl hits\n",
          set->aps_name, set->aps_id,
          set->aps_probes, set->aps_probes - set->aps_bit_hits, set->aps_bit_hits,
          set->aps_bit_hits - set->aps_real_hits,  set->aps_real_hits ));
      density = (double)(set->aps_size) / (double)(set->aps_bitarrays.apb_bufsize * 8);
      dbg_printf (("%ld phrases in %d bits (%d scale) might give %d bit hits on %ld probes\n",
          set->aps_size, set->aps_bitarrays.apb_bufsize * 16, set->aps_bitarrays.apb_scale,
	  (int)((double)(set->aps_probes) * density * density), set->aps_probes ));
#endif
    }
  if (free_array)
    dk_free (sets, set_count * sizeof (ap_set_t *));
}


/* Implementation. Adding and removal of phrases into phrase sets. */

void ap_phrase_chksum_callback (const utf8char *buf, size_t bufsize, void *appdata)
{
  uint32 *chksum_acc = (uint32 *)appdata;
  uint32 word_hash;
  BYTE_BUFFER_HASH(word_hash,buf,bufsize);
  chksum_acc[0] += word_hash * (2 * chksum_acc[1] + 1);
  chksum_acc[1] += 1;
}

uint32 ap_phrase_chksum (caddr_t ptext, encodedlang_handler_t *elh__UTF8, int *errcode_ret)
{
  uint32 chksum_acc[2];
  chksum_acc[0] = chksum_acc[1] = 0;
  elh__UTF8->elh_iterate_patched_words (
    ptext, box_length (ptext) - 1,
    elh__UTF8->elh_unicoded_language->lh_is_vtb_word,
    elh__UTF8->elh_unicoded_language->lh_toupper_word,
    ap_phrase_chksum_callback, (void *)chksum_acc);
  if (0 == chksum_acc[1])
    {
      errcode_ret[0] = APS_PHRASE_EMPTY;
      return 0;
    }
  if (APPI_MAX_PHRASE_NONNOISE < chksum_acc[1])
    {
      errcode_ret[0] = APS_PHRASE_LONG;
      return 0;
    }
  errcode_ret[0] = APS_PHRASE_VALID;
  return chksum_acc[0] & AP_PHRASE_CHKSUM_MASK;
}


#define AP_DELETE_IT ((void *)((ptrlong)0xDEADC0DE))

static int
ap_phrase_cmp (const void *cp1, const void *cp2)
{
  const ap_phrase_t *p1 = (const ap_phrase_t *) cp1;
  const ap_phrase_t *p2 = (const ap_phrase_t *) cp2;
  int res;
  if (p1->app_set->aps_id != p2->app_set->aps_id)
    return ((p1->app_set->aps_id > p2->app_set->aps_id) ? 1 : -1);
  if (p1->app_chksum != p2->app_chksum)
    return ((p1->app_chksum > p2->app_chksum) ? 1 : -1);
  res = strcmp ((NULL != p1->app_text) ? p1->app_text : "", (NULL != p2->app_text) ? p2->app_text : "");
  if (0 != res)
    return res;
  if (AP_DELETE_IT == p1->app_link_data)
    return ((AP_DELETE_IT == p2->app_link_data) ? 0 : -1);
  if (AP_DELETE_IT == p2->app_link_data)
    return 1;
  return 0;
}

#define BOX_SERIALIZATION_IS_TOO_LONG 0x7fffffff
#define BOX_SERIALIZATION_IMPOSSIBLE -1
extern void *writetable[256];

int box_serialization_length_est (caddr_t box, int threshold)
{
  dtp_t box_dtp;
  int len;
  box_dtp = DV_TYPE_OF (box);
  switch (box_dtp)
    {
    case DV_ARRAY_OF_POINTER: case DV_LIST_OF_POINTER: case DV_ARRAY_OF_XQVAL: case DV_XTREE_HEAD: case DV_XTREE_NODE:
    {
      int total = 5;
      int ctr;
      DO_BOX_FAST (caddr_t, itm, ctr, box)
        {
          int itm_len = box_serialization_length_est (itm, threshold - total);
          if ((BOX_SERIALIZATION_IS_TOO_LONG == itm_len) || (BOX_SERIALIZATION_IMPOSSIBLE == itm_len))
            return itm_len;
          total += itm_len;
          if (total > threshold)
            return BOX_SERIALIZATION_IS_TOO_LONG;
        }
      END_DO_BOX_FAST;
      return total;
    }
    case DV_LONG_INT: case DV_STRING: case DV_UNAME: case DV_SINGLE_FLOAT: case DV_DOUBLE_FLOAT: case DV_DB_NULL:
    case DV_SHORT_CONT_STRING: case DV_LONG_CONT_STRING:
      len = (IS_BOX_POINTER (box) ? (5 + box_length (box)) : 5);
      if (len > threshold)
        return BOX_SERIALIZATION_IS_TOO_LONG;
      return len;
    default:
      if (NULL == writetable[box_dtp])
        return BOX_SERIALIZATION_IMPOSSIBLE;
    }
  return BOX_SERIALIZATION_IS_TOO_LONG;
}

static query_t *ap_insert_short__qr = NULL;
static const char *ap_insert_short__text = /* note that there's no AP_PARSED_TEXT for a while */
  "insert replacing DB.DBA.SYS_ANN_PHRASE (AP_APS_ID, AP_CHKSUM, AP_TEXT, AP_LINK_DATA, AP_LINK_DATA_LONG) values (?, ?, ?, ?, NULL)";

static query_t *ap_insert_ext__qr = NULL;
static const char *ap_insert_ext__text = /* note that there's no AP_PARSED_TEXT for a while */
  "insert replacing DB.DBA.SYS_ANN_PHRASE (AP_APS_ID, AP_CHKSUM, AP_TEXT, AP_LINK_DATA, AP_LINK_DATA_LONG) values (?, ?, ?, NULL,  serialize (?))";

static query_t *ap_delete1__qr = NULL;
static const char *ap_delete1__text =
  "delete from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = ? and AP_CHKSUM = ? and AP_TEXT = ?";

static query_t *ap_find_bitX_sample__qr = NULL;
static const char *ap_find_bitX_sample__text =
  "select top 1 1 from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = ? and AP_CHKSUM >= ? and AP_CHKSUM <= ?";

void aps_add_phrases (query_instance_t *qst, ap_set_t *aps, caddr_t **descrs)
{
  size_t ctr, ap_count = BOX_ELEMENTS (descrs);
  ap_phrase_t *new_phrases;
  /*ap_set_t *aps;*/
  lang_handler_t *aps_lh;
  encodedlang_handler_t * aps_elh__UTF8;
  caddr_t err;
/*
  aps = gethash ((void *)((ptrlong)aps_id));
  if (NULL == aps)
    sqlr_new_error ("42000", "APS05", "No one annotation phrase set in memory has id=%ld", (long) aps_id);
  */
  aps_lh = aps->aps_lh;
  aps_elh__UTF8 = elh_get_handler (&eh__UTF8, aps_lh);
  new_phrases = (ap_phrase_t *) dk_alloc (ap_count * sizeof (ap_phrase_t));
  for (ctr = ap_count; ctr--; /* no step */)
    {
      ap_phrase_t *ap = new_phrases + ctr;
      int errcode;
      ap->app_set = aps;
      if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (descrs[ctr])) ||
        (BOX_ELEMENTS (descrs[ctr]) < 1) || (BOX_ELEMENTS (descrs[ctr]) > 2) ||
        (DV_STRING != DV_TYPE_OF (descrs[ctr][0])) )
        {
          ap->app_text = NULL;
          ap->app_link_data = NULL;
          ap->app_chksum = 0;
          continue;
        }
      ap->app_text = descrs[ctr][0];
      ap->app_link_data = (BOX_ELEMENTS (descrs[ctr]) > 1) ? descrs[ctr][1] : AP_DELETE_IT;
      ap->app_chksum = ap_phrase_chksum (ap->app_text, aps_elh__UTF8, &errcode);
      if (APS_PHRASE_VALID != errcode)
        ap->app_text = NULL;
    }
  qsort (new_phrases, ap_count, sizeof (ap_phrase_t), ap_phrase_cmp);
/* Now actual insertion of phrases: */
  for (ctr = 0; ctr < ap_count; ctr++) /* This is incremental to process in ascending order of checksums */
    {
      ap_phrase_t *ap = new_phrases + ctr;
      uptrlong chksum, minchksum, maxchksum, idxX, idxY;
      if (NULL == ap->app_text)
        continue;
      if ((ctr > 0) && (ap[-1].app_chksum == ap->app_chksum) &&
        (NULL != ap[-1].app_text) && !strcmp (ap[-1].app_text, ap->app_text))
        continue; /* because one phrase has more than one action specified */
      chksum = ap->app_chksum;
      idxX = AP_CHKSUM_TO_X (aps->aps_bitarrays, chksum);
      idxY = AP_CHKSUM_TO_Y (aps->aps_bitarrays, chksum);
      err = NULL;
      if (AP_DELETE_IT == ap->app_link_data)
        {
	  local_cursor_t *lc = NULL;
          err = qr_quick_exec (ap_delete1__qr, qst->qi_client, "", NULL, 3,
			":0", (ptrlong) ap->app_set->aps_id, QRP_INT,
			":1", (ptrlong) ap->app_chksum, QRP_INT,
			":2", ap->app_text, QRP_STR );
	  if ((caddr_t) SQL_SUCCESS != err)
	    goto errexit;
          minchksum = AP_CHKSUM_TO_MIN_CHKSUM_OF_SAME_X(aps->aps_bitarrays, chksum);
          maxchksum = AP_CHKSUM_TO_MAX_CHKSUM_OF_SAME_X(aps->aps_bitarrays, chksum);
          err = qr_quick_exec (ap_find_bitX_sample__qr, qst->qi_client, "", &lc, 3,
			":0", (ptrlong) ap->app_set->aps_id, QRP_INT,
			":1", (ptrlong) minchksum, QRP_INT,
			":2", (ptrlong) maxchksum, QRP_INT
			 );
	  if ((caddr_t) SQL_SUCCESS != err)
	    goto errexit;
          if (!lc_next (lc))
	    aps->aps_bitarrays.apb_arrayX[idxX >> 5] &= ~(1 << (idxX & 0x1F));
	  lc_free (lc);
        }
      else
        {
          int est_len = box_serialization_length_est (ap->app_link_data, 2000);
          query_t *ins_qr;
          /*uptrlong chk2, idxY2;*/
          /* chk2 = (chksum * APB_ARRAYY_MULT1) & AP_PHRASE_CHKSUM_MASK;
          idxY2 = AP_CHKSUM_TO_Y (aps->aps_bitarrays, chk2); */
	  aps->aps_bitarrays.apb_arrayX[idxX >> 5] |= (1 << (idxX & 0x1F));
	  aps->aps_bitarrays.apb_arrayY[idxY >> 5] |= (1 << (idxY & 0x1F));
	  /*aps->aps_bitarrays.apb_arrayY[idxY2 >> 5] |= (1 << (idxY2 & 0x1F));*/
          ins_qr = (
            ((BOX_SERIALIZATION_IS_TOO_LONG == est_len) ||
              (BOX_SERIALIZATION_IMPOSSIBLE == est_len) ) ?
            ap_insert_ext__qr : ap_insert_short__qr );
          err = qr_quick_exec (ins_qr, qst->qi_client, "", NULL, 4,
			":0", (ptrlong) ap->app_set->aps_id, QRP_INT,
			":1", (ptrlong) ap->app_chksum, QRP_INT,
			":2", (ptrlong) ap->app_text, QRP_STR,
			":3", box_copy_tree (ap->app_link_data), QRP_RAW );
	  if ((caddr_t) SQL_SUCCESS != err)
	    goto errexit;
        }
    }
  dk_free (new_phrases, ap_count * sizeof (ap_phrase_t));
  return;

errexit:
  dk_free (new_phrases, ap_count * sizeof (ap_phrase_t));
  sqlr_resignal (err);
}


/* Implementation. Common routines for text parsing */

#define appi_alloc(SZ)  mp_alloc (appi->appi_mp, (SZ))
#define appi_alloc_type(TYPE)  ((TYPE *) mp_alloc (appi->appi_mp, sizeof (TYPE)))
#define appi_alloc_box(SZ,DTP)  mp_alloc_box (appi->appi_mp, (SZ), (DTP))

ap_proc_inst_t *appi_create (query_instance_t *qi, caddr_t source_UTF8, ap_set_t **sets, int set_count, lang_handler_t *lh)
{
  int set_ctr;
  NEW_VARZ (ap_proc_inst_t, appi);
  appi->appi_qi = qi;
  appi->appi_mp = mem_pool_alloc ();
  appi->appi_source_UTF8 = source_UTF8;
  appi->appi_lh = lh;
  appi->appi_elh_UTF8 = elh_get_handler (&eh__UTF8, lh);
  appi->appi_vtb = NULL;
  appi->appi_sets = (ap_set_t **) appi_alloc(set_count * sizeof (ap_set_t *));
  for (set_ctr = 0; set_ctr < set_count; set_ctr++)
    {
      if ((NULL != sets[set_ctr]) && (lh == sets[set_ctr]->aps_lh))
        appi->appi_sets[(appi->appi_set_count)++] = sets[set_ctr];
    }
  return appi;
}

void appi_free (ap_proc_inst_t *appi)
{
  mp_free (appi->appi_mp);
  dk_free (appi, sizeof (ap_proc_inst_t));
}

/*! This adds one more arrow to the interpreter's state. */
ap_arrow_t *appi_add_arrow (int type, unsigned apa_start, unsigned apa_end, unsigned htmltm_bits, int innermost_tag, ap_proc_inst_t *appi)
{
  ap_arrow_t *arr;
  arr = appi_alloc_type (ap_arrow_t);
  arr->apa_is_markup = type;
  arr->apa_htmltm_bits = htmltm_bits;
  arr->apa_start = apa_start;
  arr->apa_end = apa_end;
  arr->apa_all_hits = NULL;
  arr->apa_innermost_tag = innermost_tag;
  mp_set_push (appi->appi_mp, &(appi->appi_places_revlist), arr);
  appi->appi_place_count += 1;
  return arr;
}

/*! This adds one more word arrow to the interpreter's state, it also updates phrase checksums and detects checksum hits.
Attention: apa_innermost_tag is not set. */
void appi_add_word_arrow (const utf8char *buf, size_t bufsize, unsigned apa_start, unsigned apa_end, unsigned htmltm_bits, int innermost_tag, ap_proc_inst_t *appi)
{
  ap_arrow_t *arr;
  unichar check_buf[WORD_MAX_CHARS];
  unichar patch_buf[WORD_MAX_CHARS];
  utf8char chksum_buf[BUFSIZEOF__UTF8_WORD], *chksum_end;
  const utf8char *check_src_begin = buf;
  int check_buf_length, word_idx, aps_ctr, max_phrase_len;
  size_t patch_buf_length;
  uint32 word_hash;
  check_buf_length = eh_decode_buffer__UTF8 (check_buf, WORD_MAX_CHARS, (__constcharptr *)(&check_src_begin), (const char *)(buf+bufsize));
  if ((check_buf_length <= 0) || (check_src_begin != buf+bufsize))
    { /* This is not a word of reasonable size or an encoding error. That is strange but...*/
#ifdef DEBUG
      GPF_T;
#endif
      return;
    }
  arr = appi_add_arrow (APA_PLAIN_WORD, apa_start, apa_end, htmltm_bits, innermost_tag, appi);
  appi->appi_lh->lh_toupper_word (check_buf, check_buf_length, patch_buf, &patch_buf_length);
  chksum_end = (utf8char *)eh_encode_buffer__UTF8 (patch_buf, patch_buf + patch_buf_length, (char *)chksum_buf, (char *)(chksum_buf + BUFSIZEOF__UTF8_WORD));
  BYTE_BUFFER_HASH(word_hash, chksum_buf, chksum_end - chksum_buf);

  appi->appi_word_count += 1;
  appi->appi_place_idx_last [appi->appi_place_last_ffree_idx] = appi->appi_place_count-1;
  appi->appi_place_last_ffree_idx += 1;
  appi->appi_place_last_ffree_idx %= APPI_MAX_PHRASE_NONNOISE;
  max_phrase_len = APPI_MAX_PHRASE_NONNOISE;
  if (max_phrase_len >= appi->appi_word_count)
    max_phrase_len = appi->appi_word_count;
  for (word_idx = max_phrase_len - 2; word_idx >= 0; word_idx--)
    appi->appi_chksums [word_idx+1] = appi->appi_chksums [word_idx] + word_hash * (2 * word_idx + 3); /* i.e. ... + word_hash * (2 * (word_idx+1) + 1) */
  appi->appi_chksums [0] = word_hash;
  for (word_idx = 0; word_idx < max_phrase_len; word_idx++)
    {
      uint32 chksum = (appi->appi_chksums [word_idx]) & AP_PHRASE_CHKSUM_MASK;
      /*uptrlong chk2;*/
      dbg_printf (("Probing 0x%08lx\n", (unsigned long)(chksum)));
      for (aps_ctr = appi->appi_set_count; aps_ctr--; /* no step*/)
        {
          ap_set_t *aps = appi->appi_sets [aps_ctr];
          ap_hit_t *aph;
          uint32 idxX, idxY;
          /*uint32 idxY2;*/
#ifdef AP_CHKSUM_DEBUG
	  aps->aps_probes += 1;
#endif
          idxX = AP_CHKSUM_TO_X(aps->aps_bitarrays, chksum);
          if (! (aps->aps_bitarrays.apb_arrayX[idxX >> 5] & (1 << (idxX & 0x1F))))
            {
              dbg_printf (("   failed in X that is 0x%08lx, ofs %ld\n", (unsigned long)(aps->aps_bitarrays.apb_arrayX[idxX >> 5]), (long)(idxX >> 5)));
              continue;
            }
          dbg_printf (("      PASSED in X that is 0x%08lx, ofs %ld\n", (unsigned long)(aps->aps_bitarrays.apb_arrayX[idxX >> 5]), (long)(idxX >> 5)));
          idxY = AP_CHKSUM_TO_Y(aps->aps_bitarrays, chksum);
          if (! (aps->aps_bitarrays.apb_arrayY[idxY >> 5] & (1 << (idxY & 0x1F))))
            {
              dbg_printf (("      failed in Y that is 0x%08lx, ofs %ld\n", (unsigned long)(aps->aps_bitarrays.apb_arrayY[idxY >> 5]), (long)(idxY >> 5)));
              continue;
            }
          dbg_printf (("         PASSED in Y that is 0x%08lx, ofs %ld\n", (unsigned long)(aps->aps_bitarrays.apb_arrayY[idxY >> 5]), (long)(idxY >> 5)));
          /*chk2 = (chksum * APB_ARRAYY_MULT1) & AP_PHRASE_CHKSUM_MASK;
          idxY2 = AP_CHKSUM_TO_Y (aps->aps_bitarrays, chk2);
          if (! (aps->aps_bitarrays.apb_arrayY[idxY2 >> 5] & (1 << (idxY2 & 0x1F))))
            continue;*/
          aph = appi_alloc_type (ap_hit_t);
          aph->aph_htmltm_bits = htmltm_bits;
	  aph->aph_first_idx = appi->appi_place_idx_last [(appi->appi_place_last_ffree_idx + APPI_MAX_PHRASE_NONNOISE - (word_idx+1)) % APPI_MAX_PHRASE_NONNOISE];
	  aph->aph_last_idx = appi->appi_place_idx_last [(appi->appi_place_last_ffree_idx + APPI_MAX_PHRASE_NONNOISE - 1) % APPI_MAX_PHRASE_NONNOISE];
	  aph->aph_.aph_candidate.aph_chksum = chksum;
          aph->aph_.aph_candidate.aph_set = aps;
	  mp_set_push (appi->appi_mp, &(appi->appi_candidate_hits_revlist), aph);
	  appi->appi_candidate_hit_count += 1;
#ifdef AP_CHKSUM_DEBUG
          do {
              /*
              ap_arrow_t *start_word = appi->appi_places[aph->aph_first_idx];
              ap_arrow_t *end_word = appi->appi_places[aph->aph_last_idx];
              */
              ap_arrow_t *start_word = dk_set_nth (appi->appi_places_revlist, appi->appi_place_count - aph->aph_first_idx);
              ap_arrow_t *end_word = dk_set_nth (appi->appi_places_revlist, appi->appi_place_count - aph->aph_last_idx);
              caddr_t fragm = box_dv_short_nchars (appi->appi_source_UTF8 + start_word->apa_start, end_word->apa_end - start_word->apa_start);
              dbg_printf (("         Candidate fragment is [%s]", fragm));
              dk_free_tree (fragm);
            } while (0);
	  aps->aps_bit_hits += 1;
#endif
       }
    }
}

static int
ap_hit_cmp (const void *pp1, const void *pp2)
{
  const ap_hit_t *p1 = ((const ap_hit_t **)pp1)[0];
  const ap_hit_t *p2 = ((const ap_hit_t **)pp2)[0];
  if (p1->aph_.aph_candidate.aph_set->aps_id != p2->aph_.aph_candidate.aph_set->aps_id)
    return ((p1->aph_.aph_candidate.aph_set->aps_id > p2->aph_.aph_candidate.aph_set->aps_id) ? 1 : -1);
  if (p1->aph_.aph_candidate.aph_chksum != p2->aph_.aph_candidate.aph_chksum)
    return ((p1->aph_.aph_candidate.aph_chksum > p2->aph_.aph_candidate.aph_chksum) ? 1 : -1);
  if (p1->aph_first_idx != p2->aph_first_idx)
    return ((p1->aph_first_idx > p2->aph_first_idx) ? 1 : -1);
  return 0;
}


static query_t *app_find_by_hit__qr = NULL;
static const char *app_find_by_hit__text =
  "select AP_TEXT, case (isnull (AP_LINK_DATA_LONG)) when 0 then deserialize (AP_LINK_DATA_LONG) else AP_LINK_DATA end \
from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = ? and AP_CHKSUM = ?";

/*! This converts revlists into arrays, sort hits by checksums and extracts phrase data. */
void appi_prepare_to_class_callbacks (ap_proc_inst_t *appi)
{
  int place_ctr, place_count, word_ctr, word_count, candidate_hit_ctr, candidate_hit_count, phrase_ctr, phrase_count;
  dk_set_t tail;
  ap_hit_t **candidate_hits;
  /* All places and words */
  place_ctr = place_count = appi->appi_place_count;
  word_ctr = word_count = appi->appi_word_count;
  appi->appi_places = (ap_arrow_t **) appi_alloc (place_count * sizeof (ap_arrow_t *));
  appi->appi_words = (ap_arrow_t **) appi_alloc (word_count * sizeof (ap_arrow_t *));
  for (tail = appi->appi_places_revlist; NULL != tail; tail = tail->next)
    {
      ap_arrow_t *curr = (ap_arrow_t *)(tail->data);
      appi->appi_places [--place_ctr] = curr;
      if (APA_PLAIN_WORD == curr->apa_is_markup)
        appi->appi_words [--word_ctr] = curr;
    }
  if ((0 != place_ctr) || (0 != word_ctr))
    GPF_T;
  /* All hits */
  candidate_hit_ctr = candidate_hit_count = appi->appi_candidate_hit_count;
  candidate_hits = (ap_hit_t **) appi_alloc (candidate_hit_count * sizeof (ap_hit_t *));
  for (tail = appi->appi_candidate_hits_revlist; NULL != tail; tail = tail->next)
   {
     ap_hit_t *curr = (ap_hit_t *)(tail->data);
     candidate_hits [--candidate_hit_ctr] = curr;
   }
  if (0 != candidate_hit_ctr)
    GPF_T;
  qsort (candidate_hits, candidate_hit_count, sizeof (ap_hit_t *), ap_hit_cmp);
  candidate_hit_ctr = 0;
  phrase_count = 0;
  while (candidate_hit_ctr < candidate_hit_count)
    {
      ap_hit_t *curr_hit = candidate_hits [candidate_hit_ctr];
      uint32 chksum = curr_hit->aph_.aph_candidate.aph_chksum;
      ap_set_t *aps = curr_hit->aph_.aph_candidate.aph_set;
      ptrlong aps_id = aps->aps_id;
      caddr_t err = NULL;
      local_cursor_t *lc = NULL;
      int aux_hit_ctr, next_diff_hit_ctr;
      for (next_diff_hit_ctr = candidate_hit_ctr + 1; next_diff_hit_ctr < candidate_hit_count; next_diff_hit_ctr++)
        {
	  ap_hit_t *next_hit = candidate_hits [next_diff_hit_ctr];
	  if (chksum != next_hit->aph_.aph_candidate.aph_chksum)
            break;
          if (aps_id != next_hit->aph_.aph_candidate.aph_set->aps_id)
            break;
        }
      err = qr_quick_exec (app_find_by_hit__qr, appi->appi_qi->qi_client, "", &lc, 2,
		":0", (ptrlong) aps_id, QRP_INT,
		":1", (ptrlong) chksum, QRP_INT
		 );
      if ((caddr_t) SQL_SUCCESS == err)
	{
	  while (lc_next (lc))
	    {
	      ap_phrase_t *app = appi_alloc_type (ap_phrase_t);
	      int prev_serial = -1;
	      app->app_chksum = chksum;
	      app->app_set = aps;
	      app->app_text = mp_box_copy (appi->appi_mp, lc_nth_col (lc, 0));
	      app->app_link_data = mp_full_box_copy_tree (appi->appi_mp, lc_nth_col (lc, 1));
	      mp_set_push (appi->appi_mp, &(appi->appi_phrases_revlist), app);
	      phrase_count ++;
#ifdef AP_CHKSUM_DEBUG
	      aps->aps_real_hits += 1;
#endif
              for (aux_hit_ctr = candidate_hit_ctr; aux_hit_ctr < next_diff_hit_ctr; aux_hit_ctr++)
                {
		  int first_idx;
		  int last_idx;
                  int word_idx;
		  ap_hit_t *confirmed;
	          curr_hit = candidate_hits [aux_hit_ctr];
		  first_idx = curr_hit->aph_first_idx;
		  last_idx = curr_hit->aph_last_idx;
                  confirmed = appi_alloc_type (ap_hit_t);
                  confirmed->aph_first_idx = curr_hit->aph_first_idx;
                  confirmed->aph_last_idx = curr_hit->aph_last_idx;
                  confirmed->aph_htmltm_bits = curr_hit->aph_htmltm_bits;
		  confirmed->aph_.aph_confirmed.aph_phrase = app;
		  confirmed->aph_.aph_confirmed.aph_serial = appi->appi_confirmed_hit_count;
		  confirmed->aph_.aph_confirmed.aph_prev = prev_serial;
		  prev_serial = appi->appi_confirmed_hit_count;
                  mp_set_push (appi->appi_mp, &(appi->appi_confirmed_hits_list), confirmed);
                  appi->appi_confirmed_hit_count += 1;
		  for (word_idx = first_idx; word_idx <= last_idx; word_idx++)
		    {
		      ap_arrow_t *apa = appi->appi_places [word_idx];
		      if (APA_PLAIN_WORD == apa->apa_is_markup)
			mp_set_push (appi->appi_mp, &(apa->apa_all_hits), confirmed);
		    }
		}
	    }
	}
      if (lc)
	{
	  lc_free (lc);
	  lc = NULL;
	}
      candidate_hit_ctr = next_diff_hit_ctr;
    }
  appi->appi_phrases = (ap_phrase_t **) appi_alloc (phrase_count * sizeof (ap_phrase_t *));
  phrase_ctr = phrase_count;
  for (tail = appi->appi_phrases_revlist; NULL != tail; tail = tail->next)
   {
     ap_phrase_t *curr = (ap_phrase_t *)(tail->data);
     appi->appi_phrases [--phrase_ctr] = curr;
   }
  if (0 != phrase_ctr)
    GPF_T;
}

caddr_t appi_prepare_match_list (ap_proc_inst_t *appi, int collapse_flags)
{
  int aps_ctr, aps_count, app_ctr, app_count, m_apc_boxelems;
  int apa_ctr, apa_count, apa_fctr, apa_fcount, apa_farray_is_tmp, apa_w_ctr, apa_w_count;
  int aph_ctr;
  caddr_t *m_apc, *m_aps, *m_app, *m_apa, *m_apa_w, *m_aph;
  dk_hash_t *apc_hash, *aps_hash, *app_hash;
  ap_arrow_t **apa_farray;
  dk_set_t aph_tail;
  aps_count = appi->appi_set_count;
  apc_hash = hash_table_allocate (aps_count);
  aps_hash = hash_table_allocate (aps_count);
  m_apc_boxelems = 0;
  for (aps_ctr = 0; aps_ctr < aps_count; aps_ctr++)
    {
      ap_class_t *apc = appi->appi_sets[aps_ctr]->aps_class;
      if (NULL == gethash (apc, apc_hash))
        {
          m_apc_boxelems++;
          sethash (apc, apc_hash, (void *)((ptrlong)(m_apc_boxelems++)));
        }
    }
  m_apc = dk_alloc_box_zero (m_apc_boxelems * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  m_aps = dk_alloc_box_zero (aps_count * 2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (aps_ctr = 0; aps_ctr < aps_count; aps_ctr++)
    {
      ap_set_t *aps = appi->appi_sets[aps_ctr];
      ap_class_t *apc = aps->aps_class;
      ptrlong apc_idx = (ptrlong) gethash (apc, apc_hash);
#ifdef DEBUG
      if (! apc_idx)
	GPF_T;
#endif
      if (NULL == m_apc[apc_idx])
        {
          m_apc [apc_idx-1] = box_num (apc->apc_id);
          m_apc [apc_idx] = list (3,
	      box_dv_short_string (apc->apc_name),
	      box_dv_short_string (apc->apc_callback),
	      box_copy_tree (apc->apc_app_env) );
        }
      m_aps [aps_ctr * 2] = box_num (aps->aps_id);
      m_aps [aps_ctr * 2 + 1] = list (4,
	  box_dv_short_string (aps->aps_name),
	  box_num (aps->aps_class->apc_id),
	  box_num (apc_idx),
	  box_copy_tree (aps->aps_app_env) );
      sethash (aps, aps_hash, (void *)((ptrlong)(aps_ctr * 2 + 1)));
    }
  app_count = BOX_ELEMENTS (appi->appi_phrases);
  app_hash = hash_table_allocate (app_count);
  m_app = dk_alloc_box_zero (app_count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (app_ctr = 0; app_ctr < app_count; app_ctr++)
    {
      ap_phrase_t *app = appi->appi_phrases[app_ctr];
      m_app [app_ctr] = list (4,
	box_num (app->app_set->aps_id),
	box_num ((ptrlong)gethash (app->app_set, aps_hash)),
        box_dv_short_string (app->app_text),
        box_copy_tree (app->app_link_data) );
      sethash (app, app_hash, (void *)((ptrlong)(app_ctr)));
    }
  apa_count = appi->appi_place_count;
  apa_fcount = apa_w_count = 0;
  if (collapse_flags)
    {
      apa_farray_is_tmp = 1;
      apa_farray = dk_alloc (apa_count * sizeof (ap_arrow_t *));
      for (apa_ctr = 0; apa_ctr < apa_count; apa_ctr++)
	{
	  ap_arrow_t *apa = appi->appi_places [apa_ctr];
	  switch (apa->apa_is_markup)
	    {
	    case APA_PLAIN_WORD:
	      if ((NULL == apa->apa_all_hits) && (collapse_flags & 0x02))
		continue;
	      break;
	    case APA_OPENING_TAG:
	      break;
	    case APA_CLOSING_TAG: case APA_OTHER:
	      if (collapse_flags & 0x1)
		continue;
	      break;
	    default:
	      GPF_T;
	    }
          apa_farray [apa_fcount++] = apa;
        }
    }
  else
    {
      apa_farray_is_tmp = 0;
      apa_farray = appi->appi_places;
      apa_fcount = apa_count;
    }
  for (apa_fctr = 0; apa_fctr < apa_fcount; apa_fctr++)
    {
      ap_arrow_t *apa = apa_farray [apa_fctr];
      if (APA_PLAIN_WORD == apa->apa_is_markup)
	apa_w_count++;
    }
  apa_w_ctr = 0;
  m_apa = dk_alloc_box_zero (apa_fcount * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  m_apa_w = dk_alloc_box_zero (apa_w_count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (apa_fctr = 0; apa_fctr < apa_fcount; apa_fctr++)
    {
      ap_arrow_t *apa = apa_farray [apa_fctr];
      caddr_t apa_itm;
      caddr_t *hits = NULL;
      if ((APA_PLAIN_WORD == apa->apa_is_markup) && (NULL != apa->apa_all_hits))
	{
	  int hit_count = 0;
	  dk_set_t tail;
	  hits = dk_alloc_box (dk_set_length (apa->apa_all_hits) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  for (tail = apa->apa_all_hits; NULL != tail; tail = tail->next)
	    {
	      ap_hit_t *aph = (ap_hit_t *)(tail->data);
	      hits [hit_count++] = box_num ((ptrlong) (gethash (aph->aph_.aph_confirmed.aph_phrase, app_hash)));
	    }
	}
      if (NULL != hits)
        {
	  apa_itm = list (6,
	      box_num (apa->apa_is_markup),
	      box_num (apa->apa_start),
	      box_num (apa->apa_end),
	      box_num (apa->apa_htmltm_bits),
	      box_num (apa->apa_innermost_tag),
	      hits );
	}
      else
        {
	  apa_itm = list (5,
	      box_num (apa->apa_is_markup),
	      box_num (apa->apa_start),
	      box_num (apa->apa_end),
	      box_num (apa->apa_htmltm_bits),
	      box_num (apa->apa_innermost_tag) );
        }
      m_apa [apa_fctr] = apa_itm;
      if (APA_PLAIN_WORD == apa->apa_is_markup)
	m_apa_w [apa_w_ctr ++] = box_num (apa_fctr);
    }
  m_aph = dk_alloc_box_zero (appi->appi_confirmed_hit_count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  aph_ctr = appi->appi_confirmed_hit_count;
  aph_tail = appi->appi_confirmed_hits_list;
  while (aph_ctr--)
    {
      caddr_t aph_itm;
      ap_hit_t *aph = aph_tail->data;
      aph_tail = aph_tail->next;
      aph_itm = list (4,
	  box_num (aph->aph_first_idx),
	  box_num (aph->aph_last_idx),
	  box_num ((ptrlong) gethash (aph->aph_.aph_confirmed.aph_phrase, app_hash)),
          box_num (aph->aph_.aph_confirmed.aph_prev) );
      m_aph [aph->aph_.aph_confirmed.aph_serial] = aph_itm;
    }
  hash_table_free (apc_hash);
  hash_table_free (aps_hash);
  hash_table_free (app_hash);
  if (apa_farray_is_tmp)
    dk_free (apa_farray, apa_count * sizeof (ap_arrow_t *));
  return list (6, m_apc, m_aps, m_app, m_apa, m_apa_w, m_aph);
}

/* Implementation. Plain text parsing (e.g., conversion from plain text to Wiki) */

void appi_word_cbk_ptext (const utf8char *buf, size_t bufsize, void *userdata)
{
  ap_proc_inst_t *appi = (ap_proc_inst_t *)userdata;
  unsigned apa_start = buf - (const utf8char *)appi->appi_source_UTF8;
  unsigned apa_end = apa_start + bufsize;
  appi_add_word_arrow (buf, bufsize, apa_start, apa_end, 0, 0, (ap_proc_inst_t *)userdata);
  if (NULL != appi->appi_vtb)
    {
      vt_batch_t * vtb = appi->appi_vtb;
      lh_iterate_patched_words (
	  vtb->vtb_default_eh,
	  appi->appi_lh,
	  (const char *)buf, bufsize,
	  appi->appi_lh->lh_is_vtb_word,
	  appi->appi_lh->lh_normalize_word,
	  (lh_word_callback_t *) vtb_hash_string_ins_callback, (void *)vtb);
    }
}


void appi_markup_ptext (ap_proc_inst_t *appi)
{
  appi->appi_elh_UTF8->elh_iterate_words (
    appi->appi_source_UTF8, box_length (appi->appi_source_UTF8) - 1,
    appi->appi_lh->lh_is_vtb_word, appi_word_cbk_ptext, appi);
}

/* Implementation. HTML parsing */

#define APPI_MAX_TAGS XML_PARSER_MAX_DEPTH

typedef struct appi_html_ctx_s {
  ap_proc_inst_t *	ah_appi;
  vxml_parser_t *	ah_parser;
  int			ah_depth;	/*!< Current number of unclosed tags */
  int			ah_prev_end;
  const utf8char *	ah_chars_begin;
  ap_arrow_t *		ah_tags [APPI_MAX_TAGS];
  int			ah_arrow_idx [APPI_MAX_TAGS];
  dk_set_t		ah_recent_places;
  dk_set_t		ah_free_list;
} appi_html_ctx_t;

void appi_element (void *userdata, const char * name, vxml_parser_attrdata_t *attrdata)
{
  appi_html_ctx_t * ah = (appi_html_ctx_t*) userdata;
  ap_proc_inst_t *appi = ah->ah_appi;
  html_tag_descr_t *htd = (html_tag_descr_t *)id_hash_get (html_tag_hash, (caddr_t)(&name));
  ap_arrow_t *curr_apa;
  int start = ah->ah_prev_end;
  int end = ah->ah_prev_end = VXmlGetCurrentByteNumber (ah->ah_parser);
  unsigned htmltm_bits = ah->ah_tags[ah->ah_depth - 1]->apa_htmltm_bits;
  if (NULL != htd)
    htmltm_bits |= htd->htmltd_mask_o;
  curr_apa = appi_add_arrow (
      APA_OPENING_TAG, start, end, htmltm_bits, ah->ah_arrow_idx [ah->ah_depth - 1], appi);
  ah->ah_tags [ah->ah_depth] = curr_apa;
  ah->ah_arrow_idx [ah->ah_depth] = appi->appi_place_count;
  ah->ah_depth += 1;
}

void appi_element_end (void *userdata, const char * name)
{
  appi_html_ctx_t * ah = (appi_html_ctx_t*) userdata;
  ap_proc_inst_t *appi = ah->ah_appi;
  ap_arrow_t *curr_apa;
  int start = ah->ah_prev_end;
  int end = ah->ah_prev_end = VXmlGetCurrentByteNumber (ah->ah_parser);
  unsigned htmltm_bits = ah->ah_tags[ah->ah_depth - 2]->apa_htmltm_bits;
  curr_apa = appi_add_arrow (
      APA_CLOSING_TAG, start, end, htmltm_bits, ah->ah_arrow_idx [ah->ah_depth - 1], appi);
  ah->ah_depth -= 1;
}

void appi_id (void *userdata, const char * name)
{
}

void appi_word_cbk_html (const utf8char *buf, size_t bufsize, void *userdata)
{
  appi_html_ctx_t * ah = (appi_html_ctx_t*) userdata;
  ap_proc_inst_t *appi = ah->ah_appi;
  unsigned apa_start = buf - ah->ah_chars_begin;
  unsigned apa_end = apa_start + bufsize;
  appi_add_word_arrow (buf, bufsize,
    apa_start, apa_end,
    ah->ah_tags[ah->ah_depth - 1]->apa_htmltm_bits, ah->ah_arrow_idx[ah->ah_depth - 1],
    ah->ah_appi );
  if (NULL != appi->appi_vtb)
    {
      vt_batch_t * vtb = appi->appi_vtb;
      lh_iterate_patched_words (
	  vtb->vtb_default_eh,
	  appi->appi_lh,
	  (const char *)buf, bufsize,
	  appi->appi_lh->lh_is_vtb_word,
	  appi->appi_lh->lh_normalize_word,
	  (lh_word_callback_t *) vtb_hash_string_ins_callback, (void *)vtb);
    }
}

void appi_character (void *userdata, const char * s, size_t len)
{
  appi_html_ctx_t * ah = (appi_html_ctx_t*) userdata;
  ap_proc_inst_t *appi = ah->ah_appi;
  dk_set_t old_places = appi->appi_places_revlist;
  dk_set_t place_iter;
  const char *orig_s, *orig_s_end, *orig_s_curr, *s_curr, *s_stop;
  orig_s = appi->appi_source_UTF8 + ah->ah_prev_end;
  ah->ah_prev_end = VXmlGetCurrentByteNumber (ah->ah_parser);
  orig_s_end = appi->appi_source_UTF8 + ah->ah_prev_end;
  if (orig_s_end == orig_s) /* Recovery after errors such as an invalid entity ref */
    {
      if (';' != orig_s_end[-1])
        ah->ah_prev_end--; /* This is to revert the effect of 1-char prefetch. */
      return; /* The name of an entity or a garbage is not a meaningful word anyway. */
    }
  if (('<' == s[0]) && (orig_s > appi->appi_source_UTF8) && ('<' == orig_s[-1]))  /* Recovery after weird '<' */
    {
      orig_s--;
    }
  ah->ah_chars_begin = (const utf8char *)s;
  appi->appi_elh_UTF8->elh_iterate_words (
    s, len,
    appi->appi_lh->lh_is_vtb_word, appi_word_cbk_html, ah);
/* At this point we have items in appi_hits_revlist that have apa_start and apa_end relative to
the translated buffer \c s. Now these offsets should be translated into offsets in the original text */
#ifdef DEBUG
  if (NULL != ah->ah_recent_places)
    GPF_T;
#endif
  for (place_iter = appi->appi_places_revlist; place_iter != old_places; place_iter = place_iter->next)
    {
      if (NULL == ah->ah_free_list)
        mp_set_push (appi->appi_mp, &(ah->ah_recent_places), place_iter->data);
      else
        {
	  dk_set_t swap = ah->ah_free_list;
          ah->ah_free_list = swap->next;
	  swap->data = place_iter->data;
          swap->next = ah->ah_recent_places;
          ah->ah_recent_places = swap;
        }
    }
  orig_s_curr = orig_s;
  s_curr = s;
  for (place_iter = ah->ah_recent_places; NULL != place_iter; place_iter = place_iter->next)
    {
      ap_arrow_t *apa = (ap_arrow_t *)(place_iter->data);
      int is_apa_start = 1;
      int *res_ptr = &(apa->apa_start);
next_run:
      s_stop = s + res_ptr[0];
      while (s_curr < s_stop)
        {
#ifdef DEBUG
	  if (('&' != orig_s_curr[0]) && (s_curr[0] != orig_s_curr[0]))
	    GPF_T;
	  if ((0x80 == (s_curr[0] & 0xC0)) || (0x80 == (orig_s_curr[0] & 0xC0)))
	    GPF_T;
#endif
          s_curr++; while (0x80 == (s_curr[0] & 0xC0)) s_curr++;
          if ('&' == orig_s_curr[0])
            {
	      const char *orig_s_amp = orig_s_curr;
	      orig_s_curr++;
	      if (orig_s_curr >= orig_s_end)
                goto not_an_entity;
              if ('#' == orig_s_curr[0])
		{
		  orig_s_curr++;
		  if (orig_s_curr >= orig_s_end)
		    goto not_an_entity;
		  if ('x' == orig_s_curr[0])
		    {
		      while ((orig_s_curr < orig_s_end) && isxdigit ((unsigned char)(orig_s_curr[0])))
			orig_s_curr++;
		    }
		  else
		    {
		      while ((orig_s_curr < orig_s_end) && isdigit ((unsigned char)(orig_s_curr[0])))
			orig_s_curr++;
		    }
		}
	      else
		{
		  while ((orig_s_curr < orig_s_end) && isalnum ((unsigned char)(orig_s_curr[0])))
		    orig_s_curr++;
		}
	      if (orig_s_curr >= orig_s_end)
		goto not_an_entity;
	      if (';' != orig_s_curr[0])
		goto not_an_entity;
	      orig_s_curr++;
	      goto skip_complete;

not_an_entity:
	      orig_s_curr = orig_s_amp + 1;
              goto skip_complete;
skip_complete:;
	    }
	  else
            {
              orig_s_curr++; while (0x80 == (orig_s_curr[0] & 0xC0)) orig_s_curr++;
            }
        }
      res_ptr[0] = orig_s_curr - appi->appi_source_UTF8;
      if (is_apa_start)
        {
	  res_ptr = &(apa->apa_end);
	  is_apa_start = 0;
	  goto next_run;
        }
    }
  ah->ah_free_list = ah->ah_recent_places;
  ah->ah_recent_places = NULL;
}

void appi_other (void *userdata)
{
  appi_html_ctx_t * ah = (appi_html_ctx_t*) userdata;
  ap_proc_inst_t *appi = ah->ah_appi;
  ap_arrow_t *curr_apa;
  int start = ah->ah_prev_end;
  int end = ah->ah_prev_end = VXmlGetCurrentByteNumber (ah->ah_parser);
  unsigned htmltm_bits = ah->ah_tags[ah->ah_depth - 1]->apa_htmltm_bits;
  curr_apa = appi_add_arrow (
      APA_OTHER, start, end, htmltm_bits, ah->ah_arrow_idx [ah->ah_depth - 1], appi);
}

void appi_pi (void *userdata, const char * target, const char * data)
{
  appi_other (userdata);
}

void appi_comment (void *userdata, const char * text)
{
  appi_other (userdata);
}

void appi_entity (void *userdata, const char *refname, size_t reflen, int isparam, const xml_def_4_entity_t *edef)
{
  appi_other (userdata);
}

void appi_markup_html (ap_proc_inst_t *appi, int is_html, caddr_t *err_ret)
{
  query_instance_t * qi = appi->appi_qi;
  caddr_t text = appi->appi_source_UTF8;
  s_size_t text_len = box_length (text) - 1;
  vxml_parser_config_t config;
  vxml_parser_t * parser;
  ap_arrow_t *fake_root;
  appi_html_ctx_t acontext;
  int rc;
  if (DV_STRING != DV_TYPE_OF (text))
    GPF_T;
  memset (&acontext, 0, sizeof (acontext));
  memset (&config, 0, sizeof(config));
  config.input_is_wide = 0;
  config.input_is_ge = GE_XML;
  config.input_is_html = is_html;
  config.input_is_xslt = 0;
  config.user_encoding_handler = intl_find_user_charset;
  config.initial_src_enc_name = "!UTF-8";
  config.uri_resolver = (VXmlUriResolver)(xml_uri_resolve_like_get);
  config.uri_reader = (VXmlUriReader)(xml_uri_get);
  config.uri_appdata = qi; /* Both xml_uri_resolve_like_get and xml_uri_get uses qi as first argument */
  config.error_reporter = (VXmlErrorReporter)(DBG_NAME(sqlr_error));
  config.uri = /*((NULL == uri) ?*/ uname___empty /*: uri)*/;
  config.dtd_config = mp_box_string (appi->appi_mp, "Validation=DISABLE ErrorContext=DISABLE BuildStandalone=DISABLE Include=DISABLE");
  config.root_lang_handler = appi->appi_lh;
  parser = VXmlParserCreate (&config);
  parser->fill_ns_2dict = 0;
  acontext.ah_appi = appi;
  acontext.ah_parser = parser;
  fake_root = appi_alloc_type (ap_arrow_t);
  memset (fake_root, 0, sizeof (ap_arrow_t));
  fake_root->apa_is_markup = APA_OTHER;
  fake_root->apa_start = fake_root->apa_end = -1;
  fake_root->apa_innermost_tag = -1;
  acontext.ah_tags[0] = fake_root;
  acontext.ah_depth = 1;
  VXmlSetUserData (parser, &acontext);
  VXmlSetElementHandler (parser, (VXmlStartElementHandler) appi_element, appi_element_end);
  VXmlSetIdHandler (parser, (VXmlIdHandler)appi_id);
  VXmlSetCharacterDataHandler (parser, (VXmlCharacterDataHandler) appi_character);
  VXmlSetEntityRefHandler (parser, (VXmlEntityRefHandler) appi_entity);
  VXmlSetProcessingInstructionHandler (parser, (VXmlProcessingInstructionHandler) appi_pi);
  VXmlSetCommentHandler (parser, (VXmlCommentHandler) appi_comment);
  QR_RESET_CTX
    {
/*      if (0 == setjmp (context.xp_error_ctx))*/
        rc = VXmlParse (parser, text, text_len);
/*      else
	rc = 0;*/
    }
  QR_RESET_CODE
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      POP_QR_RESET;
      /*xp_free (&context);*/
      VXmlParserDestroy (parser);
      if (err_ret)
	*err_ret = err;
      else
	dk_free_tree (err);
      return;
    }
  END_QR_RESET;
  if (!rc)
    {
      caddr_t rc_msg = VXmlFullErrorMessage (parser);
      /*xp_free (&context);*/
      VXmlParserDestroy (parser);
      if (err_ret)
	*err_ret = srv_make_new_error ("22007", "XM003", "%.1500s", rc_msg);
      dk_free_box (rc_msg);
      return;
    }
  /*XP_STRSES_FLUSH (&context);*/
  VXmlParserDestroy (parser);
  /*xp_free (&context);*/
}


/* Implementation. Unit initialization */

static query_t *apc_select_max_id__qr = NULL;
static const char *apc_select_max_id__text =
  "select max (APC_ID) from DB.DBA.SYS_ANN_PHRASE_CLASS";

static query_t *aps_select_max_id__qr = NULL;
static const char *aps_select_max_id__text =
  "select max (APS_ID) from DB.DBA.SYS_ANN_PHRASE_SET";


void
sql_compile_many (int count, int compile_static, ...)
{
  int idx;
  va_list ap;
  va_start (ap, compile_static);
  for (idx = 0; idx < count; idx++)
    {
      caddr_t err = NULL;
      const char *txt = va_arg (ap, const char *);
      query_t **qry_ptr = va_arg (ap, query_t **);
      if ((NULL == txt) || (NULL == qry_ptr))
        GPF_T;
      if (compile_static)
        qry_ptr[0] = sql_compile_static (txt, bootstrap_cli, &err, 0);
      else
        qry_ptr[0] = sql_compile (txt, bootstrap_cli, &err, 0);
      if (NULL != err)
        sqlr_resignal (err);
    }
  if (NULL != va_arg (ap, const char *))
    GPF_T;
}


void ap_global_init (query_instance_t *qst)
{
  caddr_t err, maxval;
  local_cursor_t *lc;
  sql_compile_many (10, 1,
    apc_select_by_id__text		, &apc_select_by_id__qr			,
    apc_select_max_id__text		, &apc_select_max_id__qr		,
    aps_select_by_id__text		, &aps_select_by_id__qr			,
    aps_select_max_id__text		, &aps_select_max_id__qr		,
    ap_select_chksum_and_aps_id__text	, &ap_select_chksum_and_aps_id__qr	,
    ap_insert_short__text		, &ap_insert_short__qr			,
    ap_insert_ext__text			, &ap_insert_ext__qr			,
    ap_delete1__text			, &ap_delete1__qr			,
    ap_find_bitX_sample__text		, &ap_find_bitX_sample__qr		,
    app_find_by_hit__text		, &app_find_by_hit__qr		,
    NULL );

  if (ap_globals.apg_init_passed)
    GPF_T;

  err = qr_quick_exec (apc_select_max_id__qr, qst->qi_client, "", &lc, 0);
  if ((caddr_t) SQL_SUCCESS != err)
    sqlr_resignal (err);
  if (!lc_next (lc))
    GPF_T;
  maxval = lc_nth_col (lc, 0);
  ap_globals.apg_max_apc_id = ((DV_LONG_INT == DV_TYPE_OF (maxval)) ? unbox (maxval) : 0);
  lc_free (lc);
  err = qr_quick_exec (aps_select_max_id__qr, qst->qi_client, "", &lc, 0);
  if ((caddr_t) SQL_SUCCESS != err)
    sqlr_resignal (err);
  if (!lc_next (lc))
    GPF_T;
  maxval = lc_nth_col (lc, 0);
  ap_globals.apg_max_aps_id = ((DV_LONG_INT == DV_TYPE_OF (maxval)) ? unbox (maxval) : 0);
  lc_free (lc);

  ap_globals.apg_mutex = mutex_allocate ();
  ap_globals.apg_classes = hash_table_allocate (ap_globals.apg_max_apc_id * 2);
  ap_globals.apg_sets = hash_table_allocate (ap_globals.apg_max_aps_id * 2);
  ap_globals.apg_sets_byname = id_str_hash_create (hash_nextprime (ap_globals.apg_max_aps_id * 2));
  ap_globals.apg_init_passed = 1;
}



/* Implementation. BIFs */

caddr_t
bif_ap_global_init (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sec_check_dba ((query_instance_t *)qst, "ap_global_init");
  if (!ap_globals.apg_init_passed)
    ap_global_init ((query_instance_t *)qst);
  return NULL;
}


caddr_t
bif_ap_class_status (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int argc = BOX_ELEMENTS (args);
  ptrlong apc_id = bif_long_arg (qst, args, 0, "ap_class_status");
  ptrlong new_status = ((argc > 1) ? bif_long_arg (qst, args, 1, "ap_class_status") : -1);
  ptrlong allow_overwrite = ((argc > 2) ? bif_long_arg (qst, args, 2, "ap_class_status") : -1);
  ap_class_t *apc;
  sec_check_dba ((query_instance_t *)qst, "ap_class_status");
  if (!ap_globals.apg_init_passed)
    sqlr_new_error ("42000", "APG01", "Text annotation API is not initialized");
  switch (new_status)
    {
    case 0: apc_unregister ((query_instance_t *)qst, apc_id); return box_num (0);
    case 1:
      apc = apc_register ((query_instance_t *)qst, apc_id, allow_overwrite);
      rwlock_unlock (apc->apc_rwlock);
      return box_num (1);
    default:
      apc = apc_get (apc_id, 0);
      return box_num ((NULL != apc) ? 1 : 0);
    }
}


caddr_t
bif_ap_set_status (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int argc = BOX_ELEMENTS (args);
  ptrlong aps_id = bif_long_arg (qst, args, 0, "ap_set_status");
  ptrlong new_status = ((argc > 1) ? bif_long_arg (qst, args, 1, "ap_set_status") : -1);
  ptrlong allow_overwrite = ((argc > 2) ? bif_long_arg (qst, args, 2, "ap_set_status") : -1);
  ap_set_t *aps;
  sec_check_dba ((query_instance_t *)qst, "ap_set_status");
  if (!ap_globals.apg_init_passed)
    sqlr_new_error ("42000", "APG02", "Text annotation API is not initialized");
  switch (new_status)
    {
    case 0: aps_unregister ((query_instance_t *)qst, aps_id); return box_num (0);
    case 1:
      aps = aps_register ((query_instance_t *)qst, aps_id, allow_overwrite);
      rwlock_unlock (aps->aps_rwlock);
      return box_num (1);
    case 2:
      aps = aps_get (aps_id, 2);
      if (NULL == aps)
        aps = aps_register ((query_instance_t *)qst, aps_id, allow_overwrite);
      if (!aps->aps_bitarrays.apb_arrays_ok || aps->aps_bitarrays.apb_scale < aps_calc_scale (aps->aps_size))
        aps_load_phrases ((query_instance_t *)qst, aps);
      rwlock_unlock (aps->aps_rwlock);
      return box_num (2);
    default:
      aps = aps_get (aps_id, 0);
      if (NULL == aps)
        return box_num (0);
      return box_num (aps->aps_bitarrays.apb_arrays_ok ? 2 : 1);
    }
}


caddr_t
bif_ap_phrase_chksum (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t phrase_UTF8 = bif_string_arg (qst, args, 0, "ap_phrase_chksum");
  caddr_t lang_name = bif_string_arg (qst, args, 1, "ap_phrase_chksum");
  lang_handler_t *lh;
  encodedlang_handler_t *elh;
  uint32 chksum;
  int err;
  lh = lh_get_handler (lang_name);
  if (NULL == lh)
    sqlr_new_error ("42000", "APG07", "Unknown language name '%.300s'", lang_name);
  elh = elh_get_handler (&eh__UTF8, lh);
  if (NULL == elh)
    sqlr_new_error ("42000", "APG08", "Language '%.300s' has no accelerated UTF-8 support and can not be used for text annotation routines", lang_name);
  chksum = ap_phrase_chksum (phrase_UTF8, elh, &err);
  switch (err)
    {
    case APS_PHRASE_EMPTY:
      sqlr_new_error ("42000", "APG09", "The phrase does not contain non-noise words");
    case APS_PHRASE_LONG:
      sqlr_new_error ("42000", "APG10", "The phrase contains too many words");
    case APS_PHRASE_VALID:
      return box_num (chksum);
#ifdef DEBUG
    default: GPF_T;
#endif
    }
  return NULL; /* Never reached */
}


caddr_t
bif_ap_add_phrases (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong aps_id = bif_long_arg (qst, args, 0, "ap_add_phrases");
  caddr_t descrs = bif_arg (qst, args, 1, "ap_add_phrases");
  ap_set_t *aps;
  sec_check_dba ((query_instance_t *)qst, "ap_add_phrases");
  if (!ap_globals.apg_init_passed)
    sqlr_new_error ("42000", "APG03", "Text annotation API is not initialized");
  aps = aps_get (aps_id, 2);
  if (NULL == aps)
    sqlr_new_error ("42000", "APS04", "Can not add phrases to an unregistered annotation phrase set #%ld", (long)aps_id);
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (descrs))
    sqlr_new_error ("42000", "APS05", "Argument 2 of ap_add_phrases() should be a vector of descriptions of phrases");
  if (!aps->aps_bitarrays.apb_arrays_ok || aps->aps_bitarrays.apb_scale < aps_calc_scale (aps->aps_size))
    aps_load_phrases ((query_instance_t *)qst, aps);
  aps_add_phrases ((query_instance_t *)qst, aps, (caddr_t **)(descrs));
  rwlock_unlock (aps->aps_rwlock);
  return NULL;
}

caddr_t
bif_ap_debug_langhandler (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t source_UTF8 = bif_string_arg (qst, args, 0, "ap_debug_langhandler");
  caddr_t lang_name = bif_string_arg (qst, args, 1, "ap_debug_langhandler");
  caddr_t *set_ids = (caddr_t *)bif_array_arg (qst, args, 2, "ap_debug_langhandler");
  dk_session_t *out_ses = (dk_session_t *) bif_strses_arg (qst, args, 3, "ap_debug_langhandler");
  ap_set_t **sets;
  lang_handler_t *lh;
  ap_proc_inst_t *appi;
  int set_count, ctr, prev_pos;
  sec_check_dba ((query_instance_t *)qst, "ap_debug_langhandler");
  if (!ap_globals.apg_init_passed)
    sqlr_new_error ("42000", "APG06", "Text annotation API is not initialized");
  lh = lh_get_handler (lang_name);
  if (NULL == lh)
    sqlr_new_error ("OBLOM", "APD01", "Unknown language name '%.300s'", lang_name);
  set_count = BOX_ELEMENTS (set_ids);
  sets = aps_tryrdlock_array (set_ids, 1, (query_instance_t *)qst);
  appi = appi_create ((query_instance_t *)qst, source_UTF8, sets, set_count, lh);
  appi_markup_ptext (appi);
  appi_prepare_to_class_callbacks (appi);
  prev_pos = 0;
  for (ctr = 0; ctr < appi->appi_word_count; ctr++)
    {
      ap_arrow_t *curr_word = appi->appi_words[ctr];
      session_buffered_write (out_ses, appi->appi_source_UTF8 + prev_pos, curr_word->apa_start - prev_pos);
      if (NULL == curr_word->apa_all_hits)
        {
          session_buffered_write (out_ses, "(", 1);
        }
      else
        {
          dk_set_t hittail;
          session_buffered_write (out_ses, "[[", 2);
          for (hittail = curr_word->apa_all_hits; NULL != hittail; hittail = hittail->next)
	    {
	      ap_phrase_t *app = ((ap_hit_t *)(hittail->data))->aph_.aph_confirmed.aph_phrase;
              caddr_t linkdata = app->app_link_data;
              if (hittail != curr_word->apa_all_hits)
		session_buffered_write (out_ses, " ; ", 3);
	      if (DV_STRING == DV_TYPE_OF (linkdata))
	        session_buffered_write (out_ses, linkdata, box_length (linkdata) - 1);
              else
	        session_buffered_write (out_ses, "...", 3);
	    }
          session_buffered_write (out_ses, "][", 1);
        }
      session_buffered_write (out_ses, appi->appi_source_UTF8 + curr_word->apa_start, curr_word->apa_end - curr_word->apa_start);
      if (NULL == curr_word->apa_all_hits)
        {
          session_buffered_write (out_ses, ")", 1);
        }
      else
        {
          session_buffered_write (out_ses, "]]", 2);
        }
      prev_pos = curr_word->apa_end;
    }
  if (0 < appi->appi_word_count)
    session_buffered_write (out_ses, appi->appi_source_UTF8 + prev_pos, box_length (appi->appi_source_UTF8) - (1 + prev_pos));
  appi_free (appi);
  aps_unlock_array (sets, set_count, 1);
  return NULL;
}


caddr_t
bif_ap_build_match_list (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *set_ids = (caddr_t *)bif_array_arg (qst, args, 0, "ap_build_match_list");
  caddr_t source_UTF8 = bif_string_arg (qst, args, 1, "ap_build_match_list");
  caddr_t lang_name = bif_string_arg (qst, args, 2, "ap_build_match_list");
  ptrlong is_html = bif_long_arg (qst, args, 3, "ap_build_match_list");
  ptrlong collapse_flags = bif_long_arg (qst, args, 4, "ap_build_match_list");
  caddr_t match_list;
  ap_set_t **sets;
  lang_handler_t *lh;
  ap_proc_inst_t *appi;
  int set_count;
  sec_check_dba ((query_instance_t *)qst, "ap_build_match_list");
  if (!ap_globals.apg_init_passed)
    sqlr_new_error ("42000", "APG05", "Text annotation API is not initialized");
  lh = lh_get_handler (lang_name);
  if (NULL == lh)
    sqlr_new_error ("OBLOM", "APD01", "Unknown language name '%.300s'", lang_name);
  if (is_html < 0 || is_html > DEAD_HTML)
    sqlr_new_error ("22023", "APG11", "The flag for HTML mode must be between 0 and 2, use 0 to indicate plain text 1 or 2 for HTML mode");

  set_count = BOX_ELEMENTS (set_ids);
  sets = aps_tryrdlock_array (set_ids, 1, (query_instance_t *)qst);
  appi = appi_create ((query_instance_t *)qst, source_UTF8, sets, set_count, lh);
  if (BOX_ELEMENTS (args) > 5)
    {
      vt_batch_t * vtb = bif_vtb_arg (qst, args, 5, "ap_build_match_list");
      appi->appi_vtb = vtb;
    }
  if (is_html)
    {
      caddr_t err = NULL;
      appi_markup_html (appi, is_html, &err);
      if (NULL != err)
        {
	  appi_free (appi);
	  aps_unlock_array (sets, set_count, 1);
	  sqlr_resignal (err);
        }
    }
  else
    appi_markup_ptext (appi);
  appi_prepare_to_class_callbacks (appi);
  match_list = appi_prepare_match_list (appi, collapse_flags);
  appi_free (appi);
  aps_unlock_array (sets, set_count, 1);
  dk_check_tree (match_list);
  return match_list;
}

void
bif_ap_init (void)
{
  bif_define ("ap_global_init", bif_ap_global_init);
  bif_define ("ap_class_status", bif_ap_class_status);
  bif_define ("ap_set_status", bif_ap_set_status);
  bif_define ("ap_phrase_chksum", bif_ap_phrase_chksum);
  bif_define ("ap_add_phrases", bif_ap_add_phrases);
  bif_define ("ap_debug_langhandler", bif_ap_debug_langhandler);
  bif_define ("ap_build_match_list", bif_ap_build_match_list);
}
