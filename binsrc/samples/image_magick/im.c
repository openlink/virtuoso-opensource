/*
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
 *  
 *  
*/
#ifdef _USRDLL
#include "plugin.h"
#include "import_gate_virtuoso.h"
#define wi_inst (wi_instance_get()[0])
#else
#include <libutil.h>
#include "sqlnode.h"
#include "sqlbif.h"
#include "wi.h"
#include "Dk.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <wand/magick-wand.h>

#define IM_VERSION "0.6"

/*#define IM_DEBUG*/

#ifdef IM_DEBUG
#define im_dbg_printf(s) printf s
#else
#define im_dbg_printf(s)
#endif

static dk_mutex_t *im_lib_mutex = NULL;
static caddr_t im_IMVERSION = NULL;

typedef struct im_env_s {
  caddr_t * ime_qst;
  state_slot_t ** ime_args;
  int ime_argcount;
  const char *ime_bifname;	/*!< BIF name used to invoke IM */
  caddr_t ime_input_filename;	/*!< Name of file to read, owned by caller */
  caddr_t ime_input_blob;
  long ime_input_blob_len;
  const char *ime_input_ext;
  const char *ime_output_ext;
  char ime_input_blob_name[64];
  char ime_output_blob_name[64];
  caddr_t ime_output_filename;	/*!< Name of file to write, owned by caller */
  long ime_width, ime_height, ime_x, ime_y;
  MagickBooleanType ime_status;
  PixelWand *ime_background;
  DrawingWand *ime_drawing_wand;
  MagickWand *ime_magick_wand;
  MagickWand *ime_target_magick_wand;
  } im_env_t;

void
im_enter (im_env_t *env)
{
  /* mutex_enter (im_lib_mutex); */
  env->ime_magick_wand = NewMagickWand ();
}

void
im_leave (im_env_t *env)
{
  if (NULL != env->ime_target_magick_wand)
    DestroyMagickWand (env->ime_target_magick_wand);
  DestroyMagickWand (env->ime_magick_wand);
  if (NULL != env->ime_drawing_wand)
    DestroyDrawingWand (env->ime_drawing_wand);
  if (NULL != env->ime_background)
    DestroyPixelWand (env->ime_background);
  im_dbg_printf (("IM %p: about to leave %s()...", env, env->ime_bifname));
  /* mutex_leave (im_lib_mutex); */
  im_dbg_printf (("... IM %p: left\n", env));
}

extern void
im_leave_with_error (im_env_t *env, const char *code, const char *virt_code, const char *string, ...)
#ifdef __GNUC__
 __attribute__ ((format (printf, 4, 5)))
#endif
;

void
im_leave_with_error (im_env_t *env, const char *code, const char *virt_code, const char *string, ...)
  {
  static char temp[2000];
  va_list lst;
  caddr_t err;
  va_start (lst, string);
  vsnprintf (temp, sizeof (temp), string, lst);
  va_end (lst);
  temp[sizeof(temp)-1] = '\0';
  err = srv_make_new_error (code, virt_code, "Function \"%s\"(): %.2000s", env->ime_bifname, temp);
  im_dbg_printf (("IM %p: an error will be signalled: Function \"%s\"(): %.2000s\n", env, env->ime_bifname, temp));
  im_leave (env);
  sqlr_resignal (err);
  }

void
im_init (im_env_t *env, caddr_t * qst, state_slot_t ** args, const char *bifname)
  {
  memset (env, 0, sizeof (im_env_t));
  env->ime_qst = qst;
  env->ime_args = args;
  env->ime_argcount = BOX_ELEMENTS (args);
  env->ime_bifname = bifname;
  im_dbg_printf (("IM %p: init %s(), %d args...", env, bifname, env->ime_argcount));
  im_enter (env);
  im_dbg_printf (("...IM %p: entered\n", env));
}

void
im_env_set_filenames (im_env_t *env, int in_arg_no, int out_arg_no)
{
  env->ime_input_filename = bif_string_arg (env->ime_qst, env->ime_args, in_arg_no, env->ime_bifname);
  im_dbg_printf (("IM %p: %s() set input file name to %s\n", env, env->ime_bifname, env->ime_input_filename));
  if (0 <= out_arg_no)
  {
      if (out_arg_no < env->ime_argcount)
        env->ime_output_filename = bif_string_arg (env->ime_qst, env->ime_args, out_arg_no, env->ime_bifname);
      else
        env->ime_output_filename = env->ime_input_filename;
      im_dbg_printf (("IM %p: %s() set output file name to %s\n", env, env->ime_bifname, env->ime_output_filename));
  }
  }


void
im_env_set_input_blob (im_env_t *env, int in_arg_no)
  {
  env->ime_input_blob = bif_string_arg (env->ime_qst, env->ime_args, in_arg_no, env->ime_bifname);
  env->ime_input_blob_len = bif_long_arg (env->ime_qst, env->ime_args, in_arg_no+1, env->ime_bifname);
  im_dbg_printf (("IM %p: %s() set input to blob, %ld bytes declared, %ld bytes actual with dtp %u\n", env, env->ime_bifname, (long)(env->ime_input_blob_len), (long)(box_length (env->ime_input_blob)), (unsigned)(DV_TYPE_OF(env->ime_input_blob))));
}

void
im_env_set_blob_ext (im_env_t *env, int in_arg_no, int out_arg_no)
  {
  if ((0 <= in_arg_no) && (in_arg_no < env->ime_argcount))
  {
      env->ime_input_ext = bif_string_arg (env->ime_qst, env->ime_args, in_arg_no, env->ime_bifname);
      im_dbg_printf (("IM %p: %s() set input extension for blob to %s\n", env, env->ime_bifname, env->ime_input_ext));
  }
  if ((0 <= out_arg_no) && (out_arg_no < env->ime_argcount))
  {
      env->ime_output_ext = bif_string_arg (env->ime_qst, env->ime_args, out_arg_no, env->ime_bifname);
      im_dbg_printf (("IM %p: %s() set output extension for blob to %s\n", env, env->ime_bifname, env->ime_input_ext));
  }
}

void
im_read (im_env_t *env)
{
  if (NULL != env->ime_input_filename)
{
      env->ime_status = MagickReadImage (env->ime_magick_wand, env->ime_input_filename);
      if (env->ime_status == MagickFalse)
        im_leave_with_error (env, "22023", "IM001", "Cannot open file \"%.1000s\"", env->ime_input_filename);
      return;
  }
  if (env->ime_input_ext != NULL)
  {
      if (strlen (env->ime_input_ext) > 30)
        im_leave_with_error (env, "22023", "IM001", "Abnormally long extension \"%.1000s\"", env->ime_input_ext);
      strcpy(env->ime_input_blob_name, "image.");
      strcat(env->ime_input_blob_name, env->ime_input_ext);
      MagickSetFilename (env->ime_magick_wand, env->ime_input_blob_name);
  }
  env->ime_status = MagickReadImageBlob(env->ime_magick_wand, (const void *)(env->ime_input_blob), (const size_t)(env->ime_input_blob_len));
  if (env->ime_status == MagickFalse)
    im_leave_with_error (env, "22023", "IM001", "Cannot read from blob");
}

void
im_reset_read (im_env_t *env)
        {
  if (NULL != env->ime_magick_wand)
                {
      DestroyMagickWand (env->ime_magick_wand);
      env->ime_magick_wand = NewMagickWand ();
                }
  env->ime_input_filename = NULL;
  env->ime_input_blob = NULL;
  env->ime_input_blob_len = 0;
  env->ime_input_ext = NULL;
  env->ime_input_blob_name[0] = '\0';
        }

caddr_t
im_write (im_env_t *env)
  {
  if (env->ime_output_filename)
  {
      env->ime_status = MagickWriteImages (env->ime_magick_wand, env->ime_output_filename, MagickTrue);
      if (env->ime_status == MagickFalse)
        im_leave_with_error (env, "22023", "IM001", "Cannot write to file \"%.1000s\"", env->ime_output_filename);
      return NULL;
  }
  else
{
      size_t length = 0;
      caddr_t image_blob = MagickGetImagesBlob (env->ime_magick_wand, &length);
  caddr_t res;
      if (length != 0)
  {
          res = dk_alloc_box (length, DV_BIN);
          memcpy (res, image_blob, length);
          MagickRelinquishMemory (image_blob);
  }
  else
    res = NEW_DB_NULL;
  return res;
}
  }

void
im_set_background (im_env_t *env, const char *color_strg)
  {
  env->ime_background = NewPixelWand ();
  env->ime_status = PixelSetColor (env->ime_background, color_strg);
  if (env->ime_status == MagickFalse)
    im_leave_with_error (env, "22023", "IM001", "Cannot set background color to \"%.1000s\"", color_strg);
}

caddr_t bif_im_CropImageFile (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  unsigned long width = (unsigned long) bif_long_arg (qst, args, 1, "IM CropImageFile");
  unsigned long height = (unsigned long) bif_long_arg (qst, args, 2, "IM CropImageFile");
  long x = bif_long_arg (qst, args, 3, "IM CropImageFile");
  long y = bif_long_arg (qst, args, 4, "IM CropImageFile");
  im_init (&env, qst, args, "IM CropImageFile");
  im_env_set_filenames (&env, 0, 5);
  im_read (&env);
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
      MagickCropImage (env.ime_magick_wand, width, height, x, y);
  }
  im_write (&env);
  im_leave (&env);
  return (0);
}

caddr_t bif_im_CropImageFileToBlob(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  caddr_t res;
  unsigned long width = bif_long_arg (qst, args, 1, "IM CropImageFileToBlob");
  unsigned long height = bif_long_arg (qst, args, 2, "IM CropImageFileToBlob");
  long x = bif_long_arg (qst, args, 3, "IM CropImageFileToBlob");
  long y = bif_long_arg (qst, args, 4, "IM CropImageFileToBlob");
  im_init (&env, qst, args, "IM CropImageFileToBlob");
  im_env_set_filenames (&env, 0, -1);
  im_read (&env);
  MagickResetIterator(env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
      MagickCropImage (env.ime_magick_wand, width, height, x, y);
  }
  res = im_write (&env);
  im_leave (&env);
  return res;
}

caddr_t
bif_im_get_impl (caddr_t * qst, caddr_t * err, state_slot_t ** args, int is_file_in, int op, const char *bifname)
  {
  im_env_t env;
  char *strg_value = NULL;
  unsigned long ul_value = 0;
  caddr_t res = NULL;
  int is_string_res = (('A' == op) || ('F' == op) || ('I' == op));
  int is_list_res = ('2' == op);
  int is_key_needed = ('A' == op);
  caddr_t key = is_key_needed ? bif_string_arg (qst, args, (is_file_in ? 1 : 2), bifname) : NULL;
  im_init (&env, qst, args, bifname);
  if (is_file_in)
    im_env_set_filenames (&env, 0, -1);
  else
{
      im_env_set_input_blob (&env, 0);
      im_env_set_blob_ext (&env, (is_key_needed ? 3 : 2), -1);
    }
  im_read (&env);
  MagickResetIterator(env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
	{
      switch (op)
		{
        case 'A': strg_value = MagickGetImageAttribute (env.ime_magick_wand, key); break;
        case 'F': strg_value = MagickGetImageFormat (env.ime_magick_wand); break;
        case 'I': strg_value = MagickIdentifyImage (env.ime_magick_wand); break;
        case 'W': ul_value = MagickGetImageWidth (env.ime_magick_wand); break;
        case 'H': ul_value = MagickGetImageHeight (env.ime_magick_wand); break;
        case 'D': ul_value = MagickGetImageDepth (env.ime_magick_wand); break;
        case '2':
          ul_value = MagickGetImageWidth (env.ime_magick_wand);
          if (ul_value)
  {
              dk_free_tree (res);
              res = dk_alloc_box (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
              ((caddr_t *)res)[0] = box_num (ul_value);
              ((caddr_t *)res)[1] = box_num (MagickGetImageHeight (env.ime_magick_wand));
  }
          break;
  }
}
  if (is_string_res)
	{
      if (strg_value)
		{
          res = box_dv_short_string (strg_value);
          MagickRelinquishMemory (strg_value);
		}
	}
  else if (!is_list_res)
  {
      if (ul_value)
        res = box_num (ul_value);
  }
  if (NULL == res)
    res = NEW_DB_NULL;
  im_leave (&env);
  return res;
}

caddr_t
bif_im_GetImageFileAttribute(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 1, 'A', "IM GetImageFileAttribute"); }
caddr_t bif_im_GetImageFileFormat(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 1, 'F', "IM GetImageFileFormat"); }
caddr_t bif_im_GetImageFileIdentify(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 1, 'I', "IM GetImageFileIdentify"); }
caddr_t bif_im_GetImageFileWidth(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 1, 'W', "IM GetImageFileWidth"); }
caddr_t bif_im_GetImageFileDepth(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 1, 'D', "IM GetImageFileDepth"); }
caddr_t bif_im_GetImageFileHeight(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 1, 'H', "IM GetImageFileHeight"); }
caddr_t bif_im_GetImageFileWH(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 1, '2', "IM GetImageFileWH"); }
caddr_t bif_im_GetImageBlobAttribute(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 0, 'A', "IM GetImageBlobAttribute"); }
caddr_t bif_im_GetImageBlobFormat(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 0, 'F', "IM GetImageBlobFormat"); }
caddr_t bif_im_GetImageBlobIdentify(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 0, 'I', "IM GetImageBlobIdentify"); }
caddr_t bif_im_GetImageBlobWidth(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 0, 'W', "IM GetImageBlobWidth"); }
caddr_t bif_im_GetImageBlobDepth(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 0, 'D', "IM GetImageBlobDepth"); }
caddr_t bif_im_GetImageBlobHeight(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 0, 'H', "IM GetImageBlobHeight"); }
caddr_t bif_im_GetImageBlobWH(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{ return bif_im_get_impl (qst, err, args, 0, '2', "IM GetImageBlobWH"); }

caddr_t bif_im_CropImageBlob(caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  caddr_t res;
  unsigned long width = bif_long_arg (qst, args, 2, "IM CropImageBlob");
  unsigned long height = bif_long_arg (qst, args, 3, "IM CropImageBlob");
  long x = bif_long_arg (qst, args, 4, "IM CropImageBlob");
  long y = bif_long_arg (qst, args, 5, "IM CropImageBlob");
  im_init (&env, qst, args, "IM CropImageBlob");
  im_env_set_input_blob (&env, 0);
  im_env_set_blob_ext (&env, 6, -1);
  im_read (&env);
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
	{
      MagickCropImage (env.ime_magick_wand, width, height, x, y);
	}
  res = im_write (&env);
  im_leave (&env);
  return res;
  }

caddr_t bif_im_CropAndResizeImageBlob(caddr_t * qst, caddr_t * err, state_slot_t ** args)
  {
  im_env_t env;
  caddr_t res;
  unsigned long width = bif_long_arg (qst, args, 2, "IM CropAndResizeImageBlob");
  unsigned long height = bif_long_arg (qst, args, 3, "IM CropAndResizeImageBlob");
  long x = bif_long_arg (qst, args, 4, "IM CropAndResizeImageBlob");
  long y = bif_long_arg (qst, args, 5, "IM CropAndResizeImageBlob");
  long h_size = bif_long_arg (qst, args, 6, "IM ResizeImageBlob");
  long v_size = bif_long_arg (qst, args, 7, "IM ResizeImageBlob");
  double blur = bif_double_arg (qst, args, 8, "IM ResizeImageBlob");
  long filter = bif_long_arg (qst, args, 9, "IM ResizeImageBlob");
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  im_init (&env, qst, args, "IM CropAndResizeImageBlob");
  im_env_set_input_blob (&env, 0);
  im_env_set_blob_ext (&env, 10, -1);
  im_read (&env);
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
      MagickCropImage (env.ime_magick_wand, width, height, x, y);
      MagickResizeImage (env.ime_magick_wand, h_size, v_size, filter, blur);
  }
  res = im_write (&env);
  im_leave (&env);
  return res;
}

caddr_t bif_im_RotateImageFile (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  double v_size = bif_double_arg (qst, args, 1, "IM RotateImageFile");
  im_init (&env, qst, args, "IM RotateImageFile");
  im_env_set_filenames (&env, 0, 2);
  im_read (&env);
  im_set_background (&env, "#000000");
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
    MagickRotateImage (env.ime_magick_wand, env.ime_background, v_size);
  }
  im_write (&env);
  im_leave (&env);
  return (0);
}

caddr_t bif_im_RotateImageFileToBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  caddr_t res;
  double v_size = bif_double_arg (qst, args, 1, "IM RotateImageFileToBlob");
  im_init (&env, qst, args, "IM RotateImageFileToBlob");
  im_env_set_filenames (&env, 0, -1);
  im_read (&env);
  im_set_background (&env, "#000000");
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
      MagickRotateImage (env.ime_magick_wand, env.ime_background, v_size);
  }
  res = im_write (&env);
  im_leave (&env);
  return res;
}

caddr_t bif_im_RotateImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  caddr_t res;
  double v_size = bif_double_arg (qst, args, 2, "IM RotateImageBlob");
  im_init (&env, qst, args, "IM RotateImageBlob");
  im_env_set_input_blob (&env, 0);
  im_env_set_blob_ext (&env, 3, -1);
  im_read (&env);
  im_set_background (&env, "#000000");
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
    MagickRotateImage (env.ime_magick_wand, env.ime_background, v_size);
  }
  res = im_write (&env);
  im_leave (&env);
  return res;
}

caddr_t bif_im_ResampleImageFile (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  double v_size = bif_double_arg (qst, args, 1, "IM ResampleImageFile");
  double h_size = bif_double_arg (qst, args, 2, "IM ResampleImageFile");
  double blur = bif_double_arg (qst, args, 3, "IM ResampleImageFile");
  long filter = bif_long_arg (qst, args, 4, "IM ResampleImageFile");
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  im_init (&env, qst, args, "IM ResampleImageFile");
  im_env_set_filenames (&env, 0, 5);
  im_read (&env);
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
      MagickResampleImage (env.ime_magick_wand,v_size, h_size,filter,blur);
  }
  im_write (&env);
  im_leave (&env);
  return(0);
}

caddr_t bif_im_ResampleImageFileToBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  caddr_t res;
  double v_size = bif_double_arg (qst, args, 1, "IM ResampleImageFileToBlob");
  double h_size = bif_double_arg (qst, args, 2, "IM ResampleImageFileToBlob");
  double blur = bif_double_arg (qst, args, 3, "IM ResampleImageFileToBlob");
  long filter = bif_long_arg (qst, args, 4, "IM ResampleImageFileToBlob");
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  im_init (&env, qst, args, "IM ResampleImageFileToBlob");
  im_env_set_filenames (&env, 0, -1);
  im_read (&env);
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
    MagickResampleImage (env.ime_magick_wand,v_size, h_size,filter,blur);
  }
  res = im_write (&env);
  im_leave (&env);
  return res;
}

caddr_t bif_im_ResampleImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  caddr_t res;
  double v_size = bif_double_arg (qst, args, 2, "IM ResampleImageBlob");
  double h_size = bif_double_arg (qst, args, 3, "IM ResampleImageBlob");
  double blur = bif_double_arg (qst, args, 4, "IM ResampleImageBlob");
  long filter = bif_long_arg (qst, args, 5, "IM ResampleImageBlob");
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  im_init (&env, qst, args, "IM ResampleImageBlob");
  im_env_set_input_blob (&env, 0);
  im_env_set_blob_ext (&env, 6, -1);
  im_read (&env);
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
    MagickResampleImage (env.ime_magick_wand,v_size, h_size,filter,blur);
  }
  res = im_write (&env);
  im_leave (&env);
  return res;
}


caddr_t bif_im_ResizeImageFile (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  long v_size = bif_long_arg (qst, args, 1, "IM ResizeImageFile");
  long h_size = bif_long_arg (qst, args, 2, "IM ResizeImageFile");
  double blur = bif_double_arg (qst, args, 3, "IM ResizeImageFile");
  long filter = bif_long_arg (qst, args, 4, "IM ResizeImageFile");
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  im_init (&env, qst, args, "IM ResiseImageFile");
  im_env_set_filenames (&env, 0, 5);
  im_read (&env);
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
    MagickResizeImage (env.ime_magick_wand,v_size, h_size,filter,blur);
  }
  im_write (&env);
  im_leave (&env);
  return(0);
}

caddr_t bif_im_ResizeImageFileToBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  caddr_t res;
  long v_size = bif_long_arg (qst, args, 1, "IM ResizeImageFileToBlob");
  long h_size = bif_long_arg (qst, args, 2, "IM ResizeImageFileToBlob");
  double blur = bif_double_arg (qst, args, 3, "IM ResizeImageFileToBlob");
  long filter = bif_long_arg (qst, args, 4, "IM ResizeImageFileToBlob");
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  im_init (&env, qst, args, "IM ResizeImageFileToBlob");
  im_env_set_filenames (&env, 0, -1);
  im_read (&env);
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
    MagickResizeImage (env.ime_magick_wand,v_size, h_size,filter,blur);
  }
  res = im_write (&env);
  im_leave (&env);
  return res;
}

caddr_t bif_im_ResizeImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  caddr_t res;
  long v_size = bif_long_arg (qst, args, 2, "IM ResizeImageBlob");
  long h_size = bif_long_arg (qst, args, 3, "IM ResizeImageBlob");
  double blur = bif_double_arg (qst, args, 4, "IM ResizeImageBlob");
  long filter = bif_long_arg (qst, args, 5, "IM ResizeImageBlob");
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  im_init (&env, qst, args, "IM ResizeImageBlob");
  im_env_set_input_blob (&env, 0);
  im_env_set_blob_ext (&env, 6, -1);
  im_read (&env);
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
    MagickResizeImage (env.ime_magick_wand,v_size, h_size,filter,blur);
  }
  res = im_write (&env);
  im_leave (&env);
  return res;
}

caddr_t bif_im_ThumbnailImageFile (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  long v_size = bif_long_arg (qst, args, 1, "IM ThumbnailImageFile");
  long h_size = bif_long_arg (qst, args, 2, "IM ThumbnailImageFile");
  long filter = bif_long_arg (qst, args, 3, "IM ThumbnailImageFile");
  im_init (&env, qst, args, "IM ThumbnailImageFile");
  im_env_set_filenames (&env, 0, 4);
  im_read (&env);
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
    MagickResizeImage (env.ime_magick_wand,v_size, h_size,filter,1.0);
    MagickProfileImage (env.ime_magick_wand, "*", NULL, 0);
  }
  im_write (&env);
  im_leave (&env);
  return(0);
}

caddr_t bif_im_ThumbnailImageFileToBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  caddr_t res;
  long v_size = bif_long_arg (qst, args, 1, "IM ThumbnailImageFileToBlob");
  long h_size = bif_long_arg (qst, args, 2, "IM ThumbnailImageFileToBlob");
  long filter = bif_long_arg (qst, args, 3, "IM ThumbnailImageFileToBlob");
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  im_init (&env, qst, args, "IM ThumbnailImageFileToBlob");
  im_env_set_filenames (&env, 0, -1);
  im_read (&env);
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
    MagickResizeImage (env.ime_magick_wand,v_size, h_size,filter,1.0);
    MagickProfileImage (env.ime_magick_wand, "*", NULL, 0);
  }
  res = im_write (&env);
  im_leave (&env);
  return res;
}

caddr_t bif_im_ThumbnailImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  caddr_t res;
  long v_size = bif_long_arg (qst, args, 2, "IM ThumbnailImageBlob");
  long h_size = bif_long_arg (qst, args, 3, "IM ThumbnailImageBlob");
  long filter = bif_long_arg (qst, args, 4, "IM ThumbnailImageBlob");
  if (filter < 0 || filter > 15)
    filter = PointFilter;
  im_init (&env, qst, args, "IM ThumbnailImageBlob");
  im_env_set_input_blob (&env, 0);
  im_env_set_blob_ext (&env, 5, -1);
  im_read (&env);
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
		{
    MagickResizeImage (env.ime_magick_wand,v_size, h_size,filter,1.0);
    MagickProfileImage (env.ime_magick_wand, "*", NULL, 0);
		}
  res = im_write (&env);
  im_leave (&env);
  return res;
	}

caddr_t bif_im_DeepZoom4to1 (caddr_t * qst, caddr_t * err, state_slot_t ** args)
  {
  im_env_t env;
  caddr_t res;
  int fmt_is_set = 0;
  int image_ctr;
  im_init (&env, qst, args, "IM DeepZoom4to1");
  im_set_background (&env, "#000000");
  env.ime_target_magick_wand = NewMagickWand ();
  if (MagickFalse == MagickNewImage (env.ime_target_magick_wand, 256, 256, env.ime_background))
    im_leave_with_error (&env, "22023", "IM001", "Can not make new image");
  if (MagickFalse == MagickSetImageType (env.ime_target_magick_wand, TrueColorType))
    im_leave_with_error (&env, "22023", "IM001", "Can not set image type");
  if (MagickFalse == MagickSetImageDepth (env.ime_target_magick_wand, 16))
    im_leave_with_error (&env, "22023", "IM001", "Can not set image depth");
  if (MagickFalse == MagickSetImageExtent (env.ime_target_magick_wand, 256, 256))
    im_leave_with_error (&env, "22023", "IM001", "Can not set image extent");
  if (MagickFalse == MagickSetImageBackgroundColor (env.ime_target_magick_wand, env.ime_background))
    im_leave_with_error (&env, "22023", "IM001", "Can not set image background");
  image_ctr = BOX_ELEMENTS (args) / 2;
  if (image_ctr > 4)
    image_ctr = 4;
  while (0 < image_ctr--)
    {
      if (DV_DB_NULL == DV_TYPE_OF (bif_arg (qst, args, image_ctr*2, "IM DeepZoom4to1")))
        continue;
      im_env_set_input_blob (&env, image_ctr * 2);
      /*im_env_set_blob_ext (&env, 2);*/
      im_read (&env);
      MagickResetIterator (env.ime_magick_wand);
      while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
        {
          unsigned long v_size, h_size;
          if (!fmt_is_set)
            {
              if (MagickFalse == MagickSetImageFormat (env.ime_target_magick_wand, MagickGetImageFormat (env.ime_magick_wand)))
                im_leave_with_error (&env, "22023", "IM001", "Can not set image format");
              fmt_is_set = 1;
            }
          h_size = MagickGetImageWidth (env.ime_magick_wand);
          v_size = MagickGetImageHeight (env.ime_magick_wand);
          if ((256 < h_size) || (256 < v_size))
            continue;
          MagickResizeImage (env.ime_magick_wand, h_size/2, v_size/2, BoxFilter, 1.0);
          if (MagickFalse == MagickCompositeImage (env.ime_target_magick_wand, env.ime_magick_wand, OverCompositeOp, (image_ctr & 1) * 128, (image_ctr & 2) * 64))
            im_leave_with_error (&env, "22023", "IM001", "Can not composite image");
        }
      im_reset_read (&env);
    }
  MagickProfileImage (env.ime_target_magick_wand, "*", NULL, 0);
  DestroyMagickWand (env.ime_magick_wand);
  env.ime_magick_wand = env.ime_target_magick_wand;
  env.ime_target_magick_wand = NULL;
  res = im_write (&env);
  im_leave (&env);
  return res;
}

#if defined(HasTTF) || defined(HasFREETYPE)
caddr_t 
bif_im_AnnotateImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  char * szMe = "IM AnnotateImageBlob";
  caddr_t res;
  caddr_t blob = (caddr_t)bif_arg (qst, args, 0, szMe);
  long blob_size = box_length (blob) - 1;
  long x_pos = bif_long_arg (qst, args, 1, szMe);
  long y_pos = bif_long_arg (qst, args, 2, szMe);
  caddr_t text = bif_string_arg (qst, args, 3, szMe);
  int n_args = BOX_ELEMENTS(args);
  long angle = n_args > 4 ? bif_long_arg (qst, args, 4, szMe) : 0;
  long f_size = n_args > 5 ? bif_long_arg (qst, args, 5, szMe) : 12;
  char *text_color = n_args > 6 ? bif_string_arg (qst, args, 6, szMe) : "black" ;
  dtp_t dtp = DV_TYPE_OF (blob);
  im_env_t env;
  im_init (&env, qst, args, "IM AnnotateImageBlob");
  if (IS_STRING_DTP (dtp))
    blob_size = box_length (blob) - 1;
  else if (dtp == DV_BIN)
    blob_size = box_length (blob);
  else
    im_leave_with_error (&env, "22023", "IM001", "AnnotateImageBlob needs string or binary as 1-st argument");
  im_env_set_blob_ext (&env, 7, -1);

  env.ime_drawing_wand = NewDrawingWand ();
  im_read (&env);
  im_set_background (&env, text_color);
  DrawSetFillColor (env.ime_drawing_wand, env.ime_background);
  DrawSetFontSize (env.ime_drawing_wand, f_size);
  MagickResetIterator  (env.ime_magick_wand);
  while (MagickNextImage  (env.ime_magick_wand) != MagickFalse)
    {
      env.ime_status = MagickAnnotateImage  (env.ime_magick_wand, env.ime_drawing_wand, x_pos, y_pos, angle, text);
      if (env.ime_status == MagickFalse)
        im_leave_with_error (&env, "22023", "IM001", "Cannot annotate image");
    }
  res = im_write (&env);
  im_leave (&env);
  return res;
}
#endif

caddr_t 
bif_im_CreateImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  char * szMe = "IM CreateImageBlob";
  caddr_t res;
  long x_size = bif_long_arg (qst, args, 0, szMe);
  long y_size = bif_long_arg (qst, args, 1, szMe);
  caddr_t bg_color = (caddr_t)bif_string_arg (qst, args, 2, szMe);
  caddr_t fmt = (caddr_t)bif_string_arg (qst, args, 3, szMe);
  im_init (&env, qst, args, "IM CreateImageBlob");
  if (x_size <= 0 || y_size <= 0)
    im_leave_with_error (&env, "22023", "IM001", "Negative image size");
  if (x_size*y_size > 3333279) /* 10M / 3 color - 54byte */
    im_leave_with_error (&env, "22023", "IM001", "Too large image image size requested");
  im_set_background (&env, bg_color);
  env.ime_status = MagickNewImage (env.ime_magick_wand, x_size, y_size, env.ime_background);
  if (env.ime_status == MagickFalse)
    im_leave_with_error (&env, "22023", "IM001", "Cannot create image");
  env.ime_status = MagickSetImageFormat (env.ime_magick_wand, fmt);
  if (env.ime_status == MagickFalse)
    im_leave_with_error (&env, "22023", "IM001", "Cannot set image format");
  res = im_write (&env);
  im_leave (&env);
  return res;
}

caddr_t bif_im_ConvertImageBlob (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  caddr_t res;
        char out_name[64];
  caddr_t format = bif_string_arg (qst, args, 2, "IM ConvertImageBlob");
  im_init (&env, qst, args, "IM ConvertImageBlob");
  im_env_set_input_blob (&env, 0);
  im_env_set_blob_ext (&env, 3, -1);
  im_read (&env);

        if (env.ime_input_ext != NULL)
        {
                if (strlen(format) < 30)
                {
                        strcpy(out_name, "image.");                                                                                                                                                               
                        strcat(out_name, format);                                                                                                                                                              
                }
	}
  MagickResetIterator (env.ime_magick_wand);
  while (MagickNextImage (env.ime_magick_wand) != MagickFalse)
  {
    env.ime_status = MagickSetImageFormat (env.ime_magick_wand, format);
    MagickSetFilename (env.ime_magick_wand, out_name);
    if (env.ime_status == MagickFalse)
      im_leave_with_error (&env, "22023", "IM001", "bif_im_ConvertImageBlob cannot convert image");
    }
  res = im_write (&env);
  im_leave (&env);
  return res;
}


caddr_t bif_im_ConvertImageFile (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  im_env_t env;
  bif_string_arg (qst, args, 1, "IM ConvertImageFile");
  im_init (&env, qst, args, "IM ConvertImageFile");
  im_env_set_filenames (&env, 0, 1);
  im_read (&env);
  im_write (&env);
  im_leave (&env);
  return(0);
  }

caddr_t
bif_im_XY_to_Morton (caddr_t * qst, caddr_t * err, state_slot_t ** args)
  {
  int x = bif_long_range_arg (qst, args, 0, "IM XYtoMorton", 0, 0x7fffffff);
  int y = bif_long_range_arg (qst, args, 1, "IM XYtoMorton", 0, 0x7fffffff);
  int i = 0, morton = 0;
  while (x || y)
    {
      morton |= (x & 1) << (i++);
      morton |= (y & 1) << (i++);
      x >>= 1;
      y >>= 1;
  }
  return box_num (morton);
}


void im_connect (void *appdata)
{
  im_IMVERSION = box_dv_short_string (IM_VERSION);
  im_lib_mutex = mutex_allocate ();

  bif_define ("IM ResizeImageFile", bif_im_ResizeImageFile);
  bif_define ("IM ThumbnailImageFile", bif_im_ThumbnailImageFile);
  bif_define ("IM ConvertImageFile", bif_im_ConvertImageFile);
  bif_define ("IM ResampleImageFile", bif_im_ResampleImageFile);
  bif_define ("IM RotateImageFile", bif_im_RotateImageFile);
  bif_define ("IM CropImageFile", bif_im_CropImageFile);
  bif_define ("IM GetImageFileAttribute", bif_im_GetImageFileAttribute);
  bif_define ("IM GetImageFileFormat", bif_im_GetImageFileFormat);
  bif_define ("IM GetImageFileIdentify", bif_im_GetImageFileIdentify);
  bif_define ("IM GetImageBlobIdentify", bif_im_GetImageBlobIdentify);

  bif_define ("IM GetImageFileWidth", bif_im_GetImageFileWidth);
  bif_define ("IM GetImageFileHeight", bif_im_GetImageFileHeight);
  bif_define ("IM GetImageFileDepth", bif_im_GetImageFileDepth);
  bif_define ("IM GetImageFileWH", bif_im_GetImageFileWH);

  bif_define ("IM ResizeImageFileToBlob", bif_im_ResizeImageFileToBlob);
  bif_define ("IM ThumbnailImageFileToBlob", bif_im_ThumbnailImageFileToBlob);
  bif_define ("IM ResampleImageFileToBlob", bif_im_ResampleImageFileToBlob);
  bif_define ("IM RotateImageFileToBlob", bif_im_RotateImageFileToBlob);
  bif_define ("IM CropImageFileToBlob", bif_im_CropImageFileToBlob);
  bif_define ("IM GetImageBlobAttribute", bif_im_GetImageBlobAttribute);
  bif_define ("IM GetImageBlobFormat", bif_im_GetImageBlobFormat);
  bif_define ("IM GetImageBlobWidth", bif_im_GetImageBlobWidth);
  bif_define ("IM GetImageBlobHeight", bif_im_GetImageBlobHeight);
  bif_define ("IM GetImageBlobDepth", bif_im_GetImageBlobDepth);
  bif_define ("IM GetImageBlobWH", bif_im_GetImageBlobWH);

  bif_define ("IM ConvertImageBlob", bif_im_ConvertImageBlob);
  bif_define ("IM ResizeImageBlob", bif_im_ResizeImageBlob);
  bif_define ("IM ThumbnailImageBlob", bif_im_ThumbnailImageBlob);
  bif_define ("IM DeepZoom4to1", bif_im_DeepZoom4to1);
  bif_define ("IM ResampleImageBlob", bif_im_ResampleImageBlob);
  bif_define ("IM RotateImageBlob", bif_im_RotateImageBlob);
  bif_define ("IM CropImageBlob", bif_im_CropImageBlob);
  bif_define ("IM CropAndResizeImageBlob", bif_im_CropAndResizeImageBlob);
#if defined(HasTTF) || defined(HasFREETYPE)
  bif_define ("IM AnnotateImageBlob", bif_im_AnnotateImageBlob);
#endif
  bif_define ("IM CreateImageBlob", bif_im_CreateImageBlob);
  bif_define ("IM XYtoMorton", bif_im_XY_to_Morton);
  MagickWandGenesis();
}

#ifdef _USRDLL
static unit_version_t
im_version = {
  "IM",        /*!< Title of unit, filled by unit */
  IM_VERSION,      /*!< Version number, filled by unit */
  "OpenLink Software",      /*!< Plugin's developer, filled by unit */
  "Support functions for Image Magick " MagickLibVersionText, /*!< Any additional info, filled by unit */
  0,          /*!< Error message, filled by unit loader */
  0,          /*!< Name of file with unit's code, filled by unit loader */
  im_connect,      /*!< Pointer to connection function, cannot be 0 */
  0,          /*!< Pointer to disconnection function, or 0 */
  0,          /*!< Pointer to activation function, or 0 */
  0,          /*!< Pointer to deactivation function, or 0 */
  &_gate
};

unit_version_t *
CALLBACK im_check (unit_version_t *in, void *appdata)
{
  return &im_version;
}
#endif
