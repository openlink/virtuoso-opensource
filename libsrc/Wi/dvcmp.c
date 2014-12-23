/*
 *  dvcmp.c
 *
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

int
dv_compare (db_buf_t dv1, db_buf_t dv2, collation_t * collation, offset_t offset)
{
  int inx = 0;
  dtp_t dtp1 = *dv1;
  dtp_t dtp2 = *dv2;
  int32 n1 = 0, n2 = 0;		/*not used before set */
  db_buf_t org_dv1 = dv1;
  int64 ln1 = 0, ln2 = 0;
  dtp_t dv1_flags = 0, dv2_flags = 0;
#ifdef LONG_OFF
  dtp_t last4[4];
#endif
  if (DV_BOX_FLAGS == dtp1)
    {
      dv1_flags = LONG_REF_NA (dv1 + 1);
      dv1 += 5;
      dtp1 = *dv1;
    }
  if (DV_BOX_FLAGS == dtp2)
    {
      dv2_flags = LONG_REF_NA (dv2 + 1);
      dv2 += 5;
      dtp2 = *dv2;
    }
  if (dtp1 == dtp2)
    {
      switch (dtp1)
	{
	case DV_RDF_ID:
	case DV_LONG_INT:
	  n1 = LONG_REF_NA (dv1 + 1) + offset;
	  n2 = LONG_REF_NA (dv2 + 1);
	  return ((n1 < n2 ? DVC_LESS : (n1 == n2 ? DVC_MATCH : DVC_GREATER)));

	case DV_SHORT_INT:
	  n1 = ((signed char *) dv1)[1] + offset;
	  n2 = ((signed char *) dv2)[1];
	  return ((n1 < n2 ? DVC_LESS : (n1 == n2 ? DVC_MATCH : DVC_GREATER)));

	case DV_IRI_ID:
	  {
	    unsigned int32 i1 = LONG_REF_NA (dv1 + 1) + offset;
	    unsigned int32 i2 = LONG_REF_NA (dv2 + 1);
	    return ((i1 < i2 ? DVC_LESS : (i1 == i2 ? DVC_MATCH : DVC_GREATER)));
	  }
	case DV_GEO:
	  {
	    /* geometrias have no meaningful ordering as such but here they collate like strings because most order somehow */
	    long l1, l2, hl1, hl2;
	    dv_geo_length (dv1, &l1, &hl1);
	    dv_geo_length (dv2, &l2, &hl2);
	    return str_cmp_2 (dv1 + hl1, dv2 + hl2, NULL, l1, l2, 0, offset);
	  }
	case DV_SHORT_STRING_SERIAL:
	  if ((dv1_flags & BF_IRI) != (dv2_flags & BF_IRI))
	    return ((dv1_flags & BF_IRI) ? DVC_GREATER : DVC_LESS);
	  n1 = dv1[1];
	  dv1 += 2;

	  n2 = dv2[1];
	  dv2 += 2;

	  if (!collation)
	    {
	      while (1)
		{
		  dtp_t c1;
		  if (inx == n1)
		    {
		      if (inx == n2)
			return DVC_MATCH;
		      else
			return DVC_LESS;
		    }
		  if (inx == n2)
		    return DVC_GREATER;
		  c1 = dv1[inx];
		  if (inx == n1 - 1)
		    c1 += offset;
		  if (c1 < dv2[inx])
		    return DVC_LESS;
		  if (c1 > dv2[inx])
		    return DVC_GREATER;
		  inx++;
		}
	    }
	  else
	    {
	      while (1)
		{
                  wchar_t xlat1, xlat2;
		  if (inx == n1)
		    {
		      if (inx == n2)
			return DVC_MATCH;
		      else
			return DVC_LESS;
		    }
		  if (inx == n2)
		    return DVC_GREATER;
                  xlat1 = COLLATION_XLAT_NARROW (collation, dv1[inx]);
                  xlat2 = COLLATION_XLAT_NARROW (collation, dv2[inx]);
		  if (xlat1 < xlat2)
		    return DVC_LESS;
		  if (xlat1 > xlat2)
		    return DVC_GREATER;
		  inx++;
		}
	    }
	}
    }
  {
    switch (dtp1)
      {
      case DV_RDF_ID:
	inx = dv_rdf_id_compare (dv1, dv2, offset, NULL);
	if (-1 != inx)
	  return inx;
      case DV_LONG_INT:
	ln1 = LONG_REF_NA (dv1 + 1) + offset;
	collation = NULL;
	break;
      case DV_INT64:
	ln1 = INT64_REF_NA (dv1 + 1) + offset;
	dtp1 = DV_LONG_INT;
	collation = NULL;
	break;
      case DV_RDF_ID_8:
	inx = dv_rdf_id_compare (dv1, dv2, offset, NULL);
	if (-1 != inx)
	  return inx;
	ln1 = INT64_REF_NA (dv1 + 1) + offset;
	dtp1 = DV_RDF_ID;
	collation = NULL;
	break;
      case DV_SHORT_STRING_SERIAL:
	n1 = dv1[1];
	dtp1 = DV_LONG_STRING;
	dv1 += 2;
	break;
      case DV_WIDE:
	n1 = dv1[1];
	if (dtp2 == DV_SHORT_STRING_SERIAL || dtp2 == DV_LONG_STRING)
	  {
	    collation = NULL;
	    dtp1 = DV_LONG_STRING;
	  }
	else
	  {
	    dtp1 = DV_LONG_WIDE;
	  }
	dv1 += 2;
	break;
      case DV_SHORT_INT:
	ln1 = ((signed char *) dv1)[1] + offset;
	dtp1 = DV_LONG_INT;
	collation = NULL;
	break;
      case DV_NULL:
	ln1 = 0;
	dtp1 = DV_LONG_INT;
	collation = NULL;
	break;
      case DV_DATETIME:
	dtp1 = DV_BIN;
	n1 = DT_COMPARE_LENGTH;
	collation = NULL;
	dv1++;
	break;
      case DV_LONG_STRING:
	n1 = LONG_REF_NA (dv1 + 1);
	dv1 += 5;
	break;
      case DV_LONG_WIDE:
	n1 = LONG_REF_NA (dv1 + 1);
	dv1 += 5;
	if (dtp2 == DV_SHORT_STRING_SERIAL || dtp2 == DV_LONG_STRING)
	  {
	    collation = NULL;
	    dtp1 = DV_LONG_STRING;
	  }
	break;
      case DV_BIN:
	n1 = dv1[1];
	dv1 += 2;
	collation = NULL;
	break;
      case DV_LONG_BIN:
	dtp1 = DV_BIN;
	n1 = LONG_REF_NA (dv1 + 1);
	dv1 += 5;
	collation = NULL;
	break;

      case DV_IRI_ID:
	ln1 = (iri_id_t) (unsigned int32) LONG_REF_NA (dv1 + 1) + offset;
	break;
      case DV_IRI_ID_8:
	dtp1 = DV_IRI_ID;
	ln1 = INT64_REF_NA (dv1 + 1) + offset;
	break;
      case DV_RDF:
	{
	  dtp_t copy[50];
	  if (offset)
	    {
	      int len = rbs_length (dv1);
	      if (len > sizeof (copy))
		GPF_T1 ("dv rdf serialization too long in dv compare with offset");
	      memcpy (copy, dv1, len);
	      copy[len - 1] += offset;
	      dv1 = copy;
	    }
	  return dv_rdf_compare (dv1, dv2);
	}
      default:
	collation = NULL;
      }

    switch (dtp2)
      {
      case DV_RDF_ID:
      case DV_LONG_INT:
	ln2 = LONG_REF_NA (dv2 + 1);
	collation = NULL;
	break;
      case DV_INT64:
	ln2 = INT64_REF_NA (dv2 + 1);
	dtp2 = DV_LONG_INT;
	collation = NULL;
	break;
      case DV_RDF_ID_8:
	ln2 = INT64_REF_NA (dv2 + 1);
	dtp2 = DV_RDF_ID;
	collation = NULL;
	break;
      case DV_SHORT_STRING_SERIAL:
	n2 = dv2[1];
	dtp2 = DV_LONG_STRING;
	dv2 += 2;
	break;
      case DV_WIDE:
	n2 = dv2[1];
	if (dtp1 == DV_SHORT_STRING_SERIAL || dtp1 == DV_LONG_STRING)
	  {
	    collation = NULL;
	    dtp2 = DV_LONG_STRING;
	  }
	else
	  {
	    dtp2 = DV_LONG_WIDE;
	  }
	dv2 += 2;
	break;
      case DV_SHORT_INT:
	ln2 = ((signed char *) dv2)[1];
	dtp2 = DV_LONG_INT;
	collation = NULL;
	break;
      case DV_NULL:
	ln2 = 0;
	dtp2 = DV_LONG_INT;
	collation = NULL;
	break;
      case DV_DATETIME:
	dtp2 = DV_BIN;
	n2 = DT_COMPARE_LENGTH;
	dv2++;
	collation = NULL;
	break;
      case DV_LONG_STRING:
	n2 = LONG_REF_NA (dv2 + 1);
	dv2 += 5;
	break;
      case DV_LONG_WIDE:
	n2 = LONG_REF_NA (dv2 + 1);
	dv2 += 5;
	if (dtp1 == DV_SHORT_STRING_SERIAL || dtp1 == DV_LONG_STRING)
	  {
	    collation = NULL;
	    dtp2 = DV_LONG_STRING;
	  }
	break;
      case DV_BIN:
	n2 = dv2[1];
	dv2 += 2;
	collation = NULL;
	break;
      case DV_LONG_BIN:
	dtp2 = DV_BIN;
	n2 = LONG_REF_NA (dv2 + 1);
	dv2 += 5;
	collation = NULL;
	break;

      case DV_IRI_ID:
	ln2 = (iri_id_t) (uint32) LONG_REF_NA (dv2 + 1);
	break;
      case DV_IRI_ID_8:
	dtp2 = DV_IRI_ID;
	ln2 = INT64_REF_NA (dv2 + 1);
	break;
      case DV_RDF:
	{
	  dtp_t auto_copy[64];
	  db_buf_t copy = auto_copy;
	  int alloc_len = 0, rc;
	  if (offset)
	    {
	      long len, head_len;
	      db_buf_length (org_dv1, &head_len, &len);
	      if (head_len + len > sizeof (auto_copy))
		copy = dk_alloc (alloc_len = head_len + len);
	      memcpy (copy, org_dv1, head_len + len);
	      copy[head_len + len - 1] += offset;
	      org_dv1 = copy;
	    }
	  rc = dv_rdf_compare (org_dv1, dv2);
	  if (copy != auto_copy)
	    dk_free (copy, alloc_len);
	  return rc;
	}
      default:
	collation = NULL;

      }

    if (dtp1 == dtp2)
      {
	switch (dtp1)
	  {
	  case DV_RDF_ID:
	  case DV_LONG_INT:
	    return ((ln1 < ln2 ? DVC_LESS : (ln1 == ln2 ? DVC_MATCH : DVC_GREATER)));
	  case DV_LONG_STRING:
	  case DV_BIN:
	    if ((dv1_flags & BF_IRI) != (dv2_flags & BF_IRI))
	      return ((dv1_flags & BF_IRI) ? DVC_GREATER : DVC_LESS);
#ifdef LONG_OFF
	    if (offset)
	      {
		ln1 = LONG_REF_NA (dv1 + n1 - 4);
		ln1 += offset;
		LONG_SET_NA (&last4[0], ln1);
	      }
#endif
	    if (collation)
	      while (1)
		{
                  wchar_t xlat1, xlat2;
		  if (inx == n1)
		    {
		      if (inx == n2)
			return DVC_MATCH;
		      else
			return DVC_LESS;
		    }
		  if (inx == n2)
		    return DVC_GREATER;
		  xlat1 = COLLATION_XLAT_NARROW (collation, (unsigned char) dv1[inx]);
		  xlat2 = COLLATION_XLAT_NARROW (collation, (unsigned char) dv2[inx]);
		  if (xlat1 < xlat2)
		    return DVC_LESS;
		  if (xlat1 > xlat2)
		    return DVC_GREATER;
		  inx++;
		}
	    else
	      while (1)
		{
		  dtp_t c1;
		  if (inx == n1)
		    {
		      if (inx == n2)
			return DVC_MATCH;
		      else
			return DVC_LESS;
		    }
		  if (inx == n2)
		    return DVC_GREATER;
		  c1 = dv1[inx];
#ifdef LONG_OFF
		  if (offset && inx >= n1 - 4)
		    c1 = last4[4 - (n1 - inx)];
#else
		  if (inx == n1 - 1)
		    c1 += offset;
#endif
		  if (c1 < dv2[inx])
		    return DVC_LESS;
		  if (c1 > dv2[inx])
		    return DVC_GREATER;
		  inx++;
		}

	  case DV_LONG_WIDE:
	    return compare_utf8_with_collation ((caddr_t) dv1, n1, (caddr_t) dv2, n2, collation);
	  case DV_BLOB:
	    return DVC_LESS;
	  case DV_DB_NULL:
	    return DVC_MATCH;
	  case DV_NULL:
	    return DVC_MATCH;
	  case DV_COMPOSITE:
	    return (dv_composite_cmp (dv1, dv2, collation, offset));
	  case DV_IRI_ID:
	    return (NUM_COMPARE ((iri_id_t) ln1, (iri_id_t) ln2));
	  }
      }

    if (IS_NUM_DTP (dtp1) && IS_NUM_DTP (dtp2))
      {
	NUMERIC_VAR (dn1);
	NUMERIC_VAR (dn2);
#ifdef LONG_OFF
	if (offset)
	  {
	    dtp_t tmp[40];
	    dv_num_offset (dv1, offset, tmp, sizeof (tmp));
	    dtp1 = dv_ext_to_num (&tmp[0], (caddr_t) & dn1);
	  }
	else
	  dtp1 = dv_ext_to_num (dv1, (caddr_t) & dn1);
#else
	dtp1 = dv_ext_to_num (dv1, (caddr_t) & dn1);
#endif
	dtp2 = dv_ext_to_num (dv2, (caddr_t) & dn2);
#ifndef LONG_OFF
	if (DV_LONG_INT == dtp1)
	  *(boxint *) & dn1 += offset;
#endif
	return dv_num_compare ((numeric_t) & dn1, (numeric_t) & dn2, dtp1, dtp2);
      }
    /* the types are different and it is not a number to number comparison.
     * Because the range of num dtps is not contiguous, when comparing num to non-num by dtp, consider all nums as ints.
     * could get a < b and b < c and a > c if ,c num and b not num. */
    if (IS_NUM_DTP (dtp1))
      dtp1 = DV_LONG_INT;
    if (IS_NUM_DTP (dtp2))
      dtp2 = DV_LONG_INT;

    if (dtp1 < dtp2)
      return DVC_DTP_LESS;
    else
      return DVC_DTP_GREATER;
  }
}
