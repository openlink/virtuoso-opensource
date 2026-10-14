/*
 *  vvec_simd.h -- SIMD float32 distance kernels for the native HNSW vector index.
 *
 *  Production-readiness perf phase 1 (see vvec-production-readiness/perf/03).
 *
 *  Replaces the per-element float->double distance loops in vvec.c with float32
 *  kernels that (a) accumulate in float32 (like FAISS/hnswlib) instead of widening
 *  every element to double, and (b) on little-endian hosts fuse the on-page
 *  big-endian byte-swap into a single vectorized load, so the hot traversal kernel
 *  stops paying a per-element deswizzle + widen tax.
 *
 *  Two families:
 *    vvec_*_f32     -- both operands are native, contiguous float32 (query vs query,
 *                      neighbor-vs-neighbor during build, overflow path).
 *    vvec_*_extf32  -- the left operand is a raw on-page vector (stored big-endian on
 *                      little-endian hosts; see FLOAT_TO_EXT/EXT_TO_FLOAT in widisk.h),
 *                      the right operand is native float32 (the query). Used by the hot
 *                      vvec_distance_node path with no intermediate buffer.
 *
 *  The header is deliberately free of Virtuoso dependencies so it can be tested
 *  standalone against a double-precision oracle; the server exposes the same test
 *  as __VEC_SIMD_SELFTEST, and __VEC_SIMD_INFO names the kernels in use.
 *
 *  Each kernel has a body per instruction family: scalar (always), NEON (arm64)
 *  and AVX2+FMA (x86-64).  arm64 calls NEON directly.  An x86-64 build made with
 *  -mavx2 -mfma calls AVX2 directly.  Any other x86-64 build with GCC or Clang
 *  compiles the AVX2 bodies with a target attribute and chooses them at start-up
 *  (vvec_simd_select) when the CPU and the OS support AVX2 and FMA, the scalar
 *  bodies otherwise -- a stock -O2 build used to run the scalar loops on every
 *  x86-64 machine, since compilers do not vectorize a float reduction without
 *  -ffast-math.
 */
#ifndef VVEC_SIMD_H
#define VVEC_SIMD_H

#include <math.h>
#include <string.h>

/* On-page floats are stored big-endian (portable); little-endian hosts byte-swap on
 * read. This mirrors the LOW_ORDER_FIRST branch of widisk.h. */
#if defined(__BYTE_ORDER__) && defined(__ORDER_LITTLE_ENDIAN__) && \
    (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__)
# define VVEC_SIMD_SWAP 1
#else
# define VVEC_SIMD_SWAP 0
#endif

#if defined(__ARM_NEON) || defined(__ARM_NEON__) || defined(__aarch64__)
# include <arm_neon.h>
# define VVEC_SIMD_NEON 1
#endif

/* x86 AVX2: 8-wide float32 with FMA.  With -mavx2 -mfma the bodies are the only
 * kernels (VVEC_AVX2_FN empty).  Without those flags, GCC >= 4.9 and Clang build
 * them under a target attribute, and VVEC_SIMD_X86_DISPATCH makes the choice a
 * run-time one.  Other compilers and targets use the scalar bodies. */
#if !defined(VVEC_SIMD_NEON)
# if defined(__AVX2__) && defined(__FMA__)
#  include <immintrin.h>
#  define VVEC_SIMD_AVX2 1
#  define VVEC_AVX2_FN
# elif defined(__x86_64__) && (defined(__clang__) || \
       (defined(__GNUC__) && (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 9))))
#  include <immintrin.h>
#  define VVEC_SIMD_AVX2 1
#  define VVEC_SIMD_X86_DISPATCH 1
#  define VVEC_AVX2_FN __attribute__ ((target ("avx2,fma")))
# endif
#endif

/* The family this build calls when nothing is chosen at run time. */
#if defined(VVEC_SIMD_NEON)
# define VVEC_SIMD_BUILD_FAMILY "neon"
#elif defined(VVEC_SIMD_AVX2) && !defined(VVEC_SIMD_X86_DISPATCH)
# define VVEC_SIMD_BUILD_FAMILY "avx2"
#else
# define VVEC_SIMD_BUILD_FAMILY "scalar"
#endif
/* This header has vvec_simd_select () and the family names. */
#define VVEC_SIMD_HAVE_SELECT 1

/* Read one on-page (ext) float into a native float. */
static float
vvec_ext_f32 (const unsigned char *p)
{
  float f;
#if VVEC_SIMD_SWAP
  unsigned char t[4];
  t[0] = p[3]; t[1] = p[2]; t[2] = p[1]; t[3] = p[0];
  memcpy (&f, t, 4);
#else
  memcpy (&f, p, 4);
#endif
  return f;
}

/* ======================================================================= *
 *  Scalar bodies: the portable reference, and what x86-64 without AVX2 runs.
 * ======================================================================= */

static float
vvec_l2sqr_f32_scalar (const float *a, const float *b, int n)
{
  float s = 0;
  int i;
  for (i = 0; i < n; i++)
    { float d = a[i] - b[i]; s += d * d; }
  return s;
}

static float
vvec_l1_f32_scalar (const float *a, const float *b, int n)
{
  float s = 0;
  int i;
  for (i = 0; i < n; i++)
    s += fabsf (a[i] - b[i]);
  return s;
}

static float
vvec_ip_f32_scalar (const float *a, const float *b, int n)
{
  float s = 0;
  int i;
  for (i = 0; i < n; i++)
    s += a[i] * b[i];
  return s;
}

static float
vvec_l2sqr_extf32_scalar (const unsigned char *a, const float *b, int n)
{
  float s = 0;
  int i;
  for (i = 0; i < n; i++)
    { float d = vvec_ext_f32 (a + i * 4) - b[i]; s += d * d; }
  return s;
}

static float
vvec_l1_extf32_scalar (const unsigned char *a, const float *b, int n)
{
  float s = 0;
  int i;
  for (i = 0; i < n; i++)
    s += fabsf (vvec_ext_f32 (a + i * 4) - b[i]);
  return s;
}

static float
vvec_ip_extf32_scalar (const unsigned char *a, const float *b, int n)
{
  float s = 0;
  int i;
  for (i = 0; i < n; i++)
    s += vvec_ext_f32 (a + i * 4) * b[i];
  return s;
}

/* ======================================================================= *
 *  NEON bodies (arm64).
 * ======================================================================= */
#if defined(VVEC_SIMD_NEON)
/* Load 4 native floats from an on-page (ext) vector, byte-swapping if needed. */
static float32x4_t
vvec_ld4_ext (const unsigned char *p)
{
#if VVEC_SIMD_SWAP
  return vreinterpretq_f32_u8 (vrev32q_u8 (vld1q_u8 (p)));
#else
  return vld1q_f32 ((const float *) p);
#endif
}

static float
vvec_l2sqr_f32_neon (const float *a, const float *b, int n)
{
  float32x4_t a0 = vdupq_n_f32 (0), a1 = vdupq_n_f32 (0);
  float32x4_t a2 = vdupq_n_f32 (0), a3 = vdupq_n_f32 (0);
  float32x4_t d0, d1, d2, d3, acc;
  float s;
  int i = 0;
  for (; i + 16 <= n; i += 16)
    {
      d0 = vsubq_f32 (vld1q_f32 (a + i),      vld1q_f32 (b + i));
      d1 = vsubq_f32 (vld1q_f32 (a + i + 4),  vld1q_f32 (b + i + 4));
      d2 = vsubq_f32 (vld1q_f32 (a + i + 8),  vld1q_f32 (b + i + 8));
      d3 = vsubq_f32 (vld1q_f32 (a + i + 12), vld1q_f32 (b + i + 12));
      a0 = vfmaq_f32 (a0, d0, d0);  a1 = vfmaq_f32 (a1, d1, d1);
      a2 = vfmaq_f32 (a2, d2, d2);  a3 = vfmaq_f32 (a3, d3, d3);
    }
  acc = vaddq_f32 (vaddq_f32 (a0, a1), vaddq_f32 (a2, a3));
  for (; i + 4 <= n; i += 4)
    { d0 = vsubq_f32 (vld1q_f32 (a + i), vld1q_f32 (b + i)); acc = vfmaq_f32 (acc, d0, d0); }
  s = vaddvq_f32 (acc);
  for (; i < n; i++)
    { float d = a[i] - b[i]; s += d * d; }
  return s;
}

static float
vvec_l1_f32_neon (const float *a, const float *b, int n)
{
  float32x4_t a0 = vdupq_n_f32 (0), a1 = vdupq_n_f32 (0);
  float32x4_t a2 = vdupq_n_f32 (0), a3 = vdupq_n_f32 (0), acc;
  float s;
  int i = 0;
  for (; i + 16 <= n; i += 16)
    {
      a0 = vaddq_f32 (a0, vabdq_f32 (vld1q_f32 (a + i),      vld1q_f32 (b + i)));
      a1 = vaddq_f32 (a1, vabdq_f32 (vld1q_f32 (a + i + 4),  vld1q_f32 (b + i + 4)));
      a2 = vaddq_f32 (a2, vabdq_f32 (vld1q_f32 (a + i + 8),  vld1q_f32 (b + i + 8)));
      a3 = vaddq_f32 (a3, vabdq_f32 (vld1q_f32 (a + i + 12), vld1q_f32 (b + i + 12)));
    }
  acc = vaddq_f32 (vaddq_f32 (a0, a1), vaddq_f32 (a2, a3));
  for (; i + 4 <= n; i += 4)
    acc = vaddq_f32 (acc, vabdq_f32 (vld1q_f32 (a + i), vld1q_f32 (b + i)));
  s = vaddvq_f32 (acc);
  for (; i < n; i++)
    s += fabsf (a[i] - b[i]);
  return s;
}

static float
vvec_ip_f32_neon (const float *a, const float *b, int n)
{
  float32x4_t a0 = vdupq_n_f32 (0), a1 = vdupq_n_f32 (0);
  float32x4_t a2 = vdupq_n_f32 (0), a3 = vdupq_n_f32 (0), acc;
  float s;
  int i = 0;
  for (; i + 16 <= n; i += 16)
    {
      a0 = vfmaq_f32 (a0, vld1q_f32 (a + i),      vld1q_f32 (b + i));
      a1 = vfmaq_f32 (a1, vld1q_f32 (a + i + 4),  vld1q_f32 (b + i + 4));
      a2 = vfmaq_f32 (a2, vld1q_f32 (a + i + 8),  vld1q_f32 (b + i + 8));
      a3 = vfmaq_f32 (a3, vld1q_f32 (a + i + 12), vld1q_f32 (b + i + 12));
    }
  acc = vaddq_f32 (vaddq_f32 (a0, a1), vaddq_f32 (a2, a3));
  for (; i + 4 <= n; i += 4)
    acc = vfmaq_f32 (acc, vld1q_f32 (a + i), vld1q_f32 (b + i));
  s = vaddvq_f32 (acc);
  for (; i < n; i++)
    s += a[i] * b[i];
  return s;
}

static float
vvec_l2sqr_extf32_neon (const unsigned char *a, const float *b, int n)
{
  float32x4_t a0 = vdupq_n_f32 (0), a1 = vdupq_n_f32 (0);
  float32x4_t a2 = vdupq_n_f32 (0), a3 = vdupq_n_f32 (0);
  float32x4_t d0, d1, d2, d3, acc;
  float s;
  int i = 0;
  for (; i + 16 <= n; i += 16)
    {
      d0 = vsubq_f32 (vvec_ld4_ext (a + (i) * 4),      vld1q_f32 (b + i));
      d1 = vsubq_f32 (vvec_ld4_ext (a + (i + 4) * 4),  vld1q_f32 (b + i + 4));
      d2 = vsubq_f32 (vvec_ld4_ext (a + (i + 8) * 4),  vld1q_f32 (b + i + 8));
      d3 = vsubq_f32 (vvec_ld4_ext (a + (i + 12) * 4), vld1q_f32 (b + i + 12));
      a0 = vfmaq_f32 (a0, d0, d0);  a1 = vfmaq_f32 (a1, d1, d1);
      a2 = vfmaq_f32 (a2, d2, d2);  a3 = vfmaq_f32 (a3, d3, d3);
    }
  acc = vaddq_f32 (vaddq_f32 (a0, a1), vaddq_f32 (a2, a3));
  for (; i + 4 <= n; i += 4)
    { d0 = vsubq_f32 (vvec_ld4_ext (a + i * 4), vld1q_f32 (b + i)); acc = vfmaq_f32 (acc, d0, d0); }
  s = vaddvq_f32 (acc);
  for (; i < n; i++)
    { float d = vvec_ext_f32 (a + i * 4) - b[i]; s += d * d; }
  return s;
}

static float
vvec_l1_extf32_neon (const unsigned char *a, const float *b, int n)
{
  float32x4_t a0 = vdupq_n_f32 (0), a1 = vdupq_n_f32 (0);
  float32x4_t a2 = vdupq_n_f32 (0), a3 = vdupq_n_f32 (0), acc;
  float s;
  int i = 0;
  for (; i + 16 <= n; i += 16)
    {
      a0 = vaddq_f32 (a0, vabdq_f32 (vvec_ld4_ext (a + (i) * 4),      vld1q_f32 (b + i)));
      a1 = vaddq_f32 (a1, vabdq_f32 (vvec_ld4_ext (a + (i + 4) * 4),  vld1q_f32 (b + i + 4)));
      a2 = vaddq_f32 (a2, vabdq_f32 (vvec_ld4_ext (a + (i + 8) * 4),  vld1q_f32 (b + i + 8)));
      a3 = vaddq_f32 (a3, vabdq_f32 (vvec_ld4_ext (a + (i + 12) * 4), vld1q_f32 (b + i + 12)));
    }
  acc = vaddq_f32 (vaddq_f32 (a0, a1), vaddq_f32 (a2, a3));
  for (; i + 4 <= n; i += 4)
    acc = vaddq_f32 (acc, vabdq_f32 (vvec_ld4_ext (a + i * 4), vld1q_f32 (b + i)));
  s = vaddvq_f32 (acc);
  for (; i < n; i++)
    s += fabsf (vvec_ext_f32 (a + i * 4) - b[i]);
  return s;
}

static float
vvec_ip_extf32_neon (const unsigned char *a, const float *b, int n)
{
  float32x4_t a0 = vdupq_n_f32 (0), a1 = vdupq_n_f32 (0);
  float32x4_t a2 = vdupq_n_f32 (0), a3 = vdupq_n_f32 (0), acc;
  float s;
  int i = 0;
  for (; i + 16 <= n; i += 16)
    {
      a0 = vfmaq_f32 (a0, vvec_ld4_ext (a + (i) * 4),      vld1q_f32 (b + i));
      a1 = vfmaq_f32 (a1, vvec_ld4_ext (a + (i + 4) * 4),  vld1q_f32 (b + i + 4));
      a2 = vfmaq_f32 (a2, vvec_ld4_ext (a + (i + 8) * 4),  vld1q_f32 (b + i + 8));
      a3 = vfmaq_f32 (a3, vvec_ld4_ext (a + (i + 12) * 4), vld1q_f32 (b + i + 12));
    }
  acc = vaddq_f32 (vaddq_f32 (a0, a1), vaddq_f32 (a2, a3));
  for (; i + 4 <= n; i += 4)
    acc = vfmaq_f32 (acc, vvec_ld4_ext (a + i * 4), vld1q_f32 (b + i));
  s = vaddvq_f32 (acc);
  for (; i < n; i++)
    s += vvec_ext_f32 (a + i * 4) * b[i];
  return s;
}
#endif /* VVEC_SIMD_NEON */

/* ======================================================================= *
 *  AVX2+FMA bodies (x86-64).  Every function that uses an AVX2 intrinsic
 *  carries VVEC_AVX2_FN -- helpers too, or they cannot be inlined into it.
 * ======================================================================= */
#if defined(VVEC_SIMD_AVX2)
/* Load 8 native floats from an on-page (ext) vector, byte-swapping if needed.
 * On little-endian x86 the on-page bytes are big-endian: a byte shuffle within
 * each 128-bit lane reverses each 4-byte group. */
static VVEC_AVX2_FN __m256
vvec_ld8_ext (const unsigned char *p)
{
#if VVEC_SIMD_SWAP
  __m256i v = _mm256_loadu_si256 ((const __m256i *) p);
  const __m256i mask = _mm256_setr_epi8 (
      3, 2, 1, 0,  7, 6, 5, 4,  11, 10, 9, 8,  15, 14, 13, 12,
      3, 2, 1, 0,  7, 6, 5, 4,  11, 10, 9, 8,  15, 14, 13, 12);
  return _mm256_castsi256_ps (_mm256_shuffle_epi8 (v, mask));
#else
  return _mm256_loadu_ps ((const float *) p);
#endif
}

/* The eight lanes' sum: the two halves added, then the four floats in order. */
static VVEC_AVX2_FN float
vvec_hsum8 (__m256 acc)
{
  float t[4];
  _mm_storeu_ps (t, _mm_add_ps (_mm256_extractf128_ps (acc, 1), _mm256_castps256_ps128 (acc)));
  return t[0] + t[1] + t[2] + t[3];
}

static VVEC_AVX2_FN float
vvec_l2sqr_f32_avx2 (const float *a, const float *b, int n)
{
  __m256 acc0 = _mm256_setzero_ps ();
  __m256 acc1 = _mm256_setzero_ps ();
  __m256 d0, d1, acc;
  float s;
  int i = 0;
  for (; i + 16 <= n; i += 16)
    {
      d0 = _mm256_sub_ps (_mm256_loadu_ps (a + i),      _mm256_loadu_ps (b + i));
      d1 = _mm256_sub_ps (_mm256_loadu_ps (a + i + 8),  _mm256_loadu_ps (b + i + 8));
      acc0 = _mm256_fmadd_ps (d0, d0, acc0);
      acc1 = _mm256_fmadd_ps (d1, d1, acc1);
    }
  acc = _mm256_add_ps (acc0, acc1);
  for (; i + 8 <= n; i += 8)
    { d0 = _mm256_sub_ps (_mm256_loadu_ps (a + i), _mm256_loadu_ps (b + i));
      acc = _mm256_fmadd_ps (d0, d0, acc); }
  s = vvec_hsum8 (acc);
  for (; i < n; i++)
    { float d = a[i] - b[i]; s += d * d; }
  return s;
}

static VVEC_AVX2_FN float
vvec_l1_f32_avx2 (const float *a, const float *b, int n)
{
  __m256 acc0 = _mm256_setzero_ps ();
  __m256 acc1 = _mm256_setzero_ps ();
  __m256 d0, d1, acc;
  float s;
  int i = 0;
  for (; i + 16 <= n; i += 16)
    {
      /* |d| as max (d, -d), in both halves. */
      d0 = _mm256_sub_ps (_mm256_loadu_ps (a + i),     _mm256_loadu_ps (b + i));
      d1 = _mm256_sub_ps (_mm256_loadu_ps (a + i + 8), _mm256_loadu_ps (b + i + 8));
      acc0 = _mm256_add_ps (acc0, _mm256_max_ps (d0, _mm256_sub_ps (_mm256_setzero_ps (), d0)));
      acc1 = _mm256_add_ps (acc1, _mm256_max_ps (d1, _mm256_sub_ps (_mm256_setzero_ps (), d1)));
    }
  acc = _mm256_add_ps (acc0, acc1);
  for (; i + 8 <= n; i += 8)
    { d0 = _mm256_sub_ps (_mm256_loadu_ps (a + i), _mm256_loadu_ps (b + i));
      acc = _mm256_add_ps (acc, _mm256_max_ps (d0, _mm256_sub_ps (_mm256_setzero_ps (), d0))); }
  s = vvec_hsum8 (acc);
  for (; i < n; i++)
    s += fabsf (a[i] - b[i]);
  return s;
}

static VVEC_AVX2_FN float
vvec_ip_f32_avx2 (const float *a, const float *b, int n)
{
  __m256 acc0 = _mm256_setzero_ps ();
  __m256 acc1 = _mm256_setzero_ps ();
  __m256 acc;
  float s;
  int i = 0;
  for (; i + 16 <= n; i += 16)
    {
      acc0 = _mm256_fmadd_ps (_mm256_loadu_ps (a + i),     _mm256_loadu_ps (b + i),     acc0);
      acc1 = _mm256_fmadd_ps (_mm256_loadu_ps (a + i + 8), _mm256_loadu_ps (b + i + 8), acc1);
    }
  acc = _mm256_add_ps (acc0, acc1);
  for (; i + 8 <= n; i += 8)
    acc = _mm256_fmadd_ps (_mm256_loadu_ps (a + i), _mm256_loadu_ps (b + i), acc);
  s = vvec_hsum8 (acc);
  for (; i < n; i++)
    s += a[i] * b[i];
  return s;
}

static VVEC_AVX2_FN float
vvec_l2sqr_extf32_avx2 (const unsigned char *a, const float *b, int n)
{
  __m256 acc0 = _mm256_setzero_ps ();
  __m256 acc1 = _mm256_setzero_ps ();
  __m256 d0, d1, acc;
  float s;
  int i = 0;
  for (; i + 16 <= n; i += 16)
    {
      d0 = _mm256_sub_ps (vvec_ld8_ext (a + (i) * 4),     _mm256_loadu_ps (b + i));
      d1 = _mm256_sub_ps (vvec_ld8_ext (a + (i + 8) * 4), _mm256_loadu_ps (b + i + 8));
      acc0 = _mm256_fmadd_ps (d0, d0, acc0);
      acc1 = _mm256_fmadd_ps (d1, d1, acc1);
    }
  acc = _mm256_add_ps (acc0, acc1);
  for (; i + 8 <= n; i += 8)
    { d0 = _mm256_sub_ps (vvec_ld8_ext (a + i * 4), _mm256_loadu_ps (b + i));
      acc = _mm256_fmadd_ps (d0, d0, acc); }
  s = vvec_hsum8 (acc);
  for (; i < n; i++)
    { float d = vvec_ext_f32 (a + i * 4) - b[i]; s += d * d; }
  return s;
}

static VVEC_AVX2_FN float
vvec_l1_extf32_avx2 (const unsigned char *a, const float *b, int n)
{
  __m256 acc0 = _mm256_setzero_ps ();
  __m256 acc1 = _mm256_setzero_ps ();
  __m256 acc;
  float s;
  int i = 0;
  for (; i + 16 <= n; i += 16)
    {
      __m256 da0 = _mm256_sub_ps (vvec_ld8_ext (a + (i) * 4),     _mm256_loadu_ps (b + i));
      __m256 da1 = _mm256_sub_ps (vvec_ld8_ext (a + (i + 8) * 4), _mm256_loadu_ps (b + i + 8));
      acc0 = _mm256_add_ps (acc0, _mm256_max_ps (da0, _mm256_sub_ps (_mm256_setzero_ps (), da0)));
      acc1 = _mm256_add_ps (acc1, _mm256_max_ps (da1, _mm256_sub_ps (_mm256_setzero_ps (), da1)));
    }
  acc = _mm256_add_ps (acc0, acc1);
  for (; i + 8 <= n; i += 8)
    { __m256 da = _mm256_sub_ps (vvec_ld8_ext (a + i * 4), _mm256_loadu_ps (b + i));
      acc = _mm256_add_ps (acc, _mm256_max_ps (da, _mm256_sub_ps (_mm256_setzero_ps (), da))); }
  s = vvec_hsum8 (acc);
  for (; i < n; i++)
    s += fabsf (vvec_ext_f32 (a + i * 4) - b[i]);
  return s;
}

static VVEC_AVX2_FN float
vvec_ip_extf32_avx2 (const unsigned char *a, const float *b, int n)
{
  __m256 acc0 = _mm256_setzero_ps ();
  __m256 acc1 = _mm256_setzero_ps ();
  __m256 acc;
  float s;
  int i = 0;
  for (; i + 16 <= n; i += 16)
    {
      acc0 = _mm256_fmadd_ps (vvec_ld8_ext (a + (i) * 4),     _mm256_loadu_ps (b + i),     acc0);
      acc1 = _mm256_fmadd_ps (vvec_ld8_ext (a + (i + 8) * 4), _mm256_loadu_ps (b + i + 8), acc1);
    }
  acc = _mm256_add_ps (acc0, acc1);
  for (; i + 8 <= n; i += 8)
    acc = _mm256_fmadd_ps (vvec_ld8_ext (a + i * 4), _mm256_loadu_ps (b + i), acc);
  s = vvec_hsum8 (acc);
  for (; i < n; i++)
    s += vvec_ext_f32 (a + i * 4) * b[i];
  return s;
}
#endif /* VVEC_SIMD_AVX2 */

/* ======================================================================= *
 *  The families, the one in use, and the choice.
 * ======================================================================= */

typedef struct vvec_simd_kernels_s
{
  const char *	family;
  float		(*l2sqr_f32) (const float *, const float *, int);
  float		(*l1_f32) (const float *, const float *, int);
  float		(*ip_f32) (const float *, const float *, int);
  float		(*l2sqr_extf32) (const unsigned char *, const float *, int);
  float		(*l1_extf32) (const unsigned char *, const float *, int);
  float		(*ip_extf32) (const unsigned char *, const float *, int);
} vvec_simd_kernels_t;

static const vvec_simd_kernels_t vvec_simd_scalar_k = {
  "scalar", vvec_l2sqr_f32_scalar, vvec_l1_f32_scalar, vvec_ip_f32_scalar,
  vvec_l2sqr_extf32_scalar, vvec_l1_extf32_scalar, vvec_ip_extf32_scalar };
#if defined(VVEC_SIMD_NEON)
static const vvec_simd_kernels_t vvec_simd_neon_k = {
  "neon", vvec_l2sqr_f32_neon, vvec_l1_f32_neon, vvec_ip_f32_neon,
  vvec_l2sqr_extf32_neon, vvec_l1_extf32_neon, vvec_ip_extf32_neon };
#endif
#if defined(VVEC_SIMD_AVX2)
static const vvec_simd_kernels_t vvec_simd_avx2_k = {
  "avx2", vvec_l2sqr_f32_avx2, vvec_l1_f32_avx2, vvec_ip_f32_avx2,
  vvec_l2sqr_extf32_avx2, vvec_l1_extf32_avx2, vvec_ip_extf32_avx2 };
#endif

/* The family in use: the build's own until vvec_simd_select () runs -- which
 * only an x86-64 build with the run-time choice ever changes. */
#if defined(VVEC_SIMD_NEON)
static const vvec_simd_kernels_t *vvec_simd_k = &vvec_simd_neon_k;
#elif defined(VVEC_SIMD_AVX2) && !defined(VVEC_SIMD_X86_DISPATCH)
static const vvec_simd_kernels_t *vvec_simd_k = &vvec_simd_avx2_k;
#else
static const vvec_simd_kernels_t *vvec_simd_k = &vvec_simd_scalar_k;
#endif

/* 1 when this CPU and its OS run the AVX2+FMA bodies.  __builtin_cpu_supports
 * also checks that the OS saves the AVX state (XGETBV). */
static int
vvec_simd_cpu_avx2_fma (void)
{
#if defined(VVEC_SIMD_AVX2) && (defined(__x86_64__) || defined(__i386__))
# if defined(__GNUC__) && !defined(__clang__)
  __builtin_cpu_init ();
# endif
  return __builtin_cpu_supports ("avx2") && __builtin_cpu_supports ("fma") ? 1 : 0;
#elif defined(VVEC_SIMD_AVX2)
  return 1;			/* the intrinsics come from somewhere else: a test build */
#else
  return 0;
#endif
}

/* Choose the kernels.  Called once at start-up, before any search or build;
 * until then the scalar bodies answer, which are correct, only slower. */
static void
vvec_simd_select (void)
{
#if defined(VVEC_SIMD_X86_DISPATCH)
  vvec_simd_k = vvec_simd_cpu_avx2_fma () ? &vvec_simd_avx2_k : &vvec_simd_scalar_k;
#endif
}

static const char *
vvec_simd_family (void)
{
  return vvec_simd_k->family;
}

/* The kernels of family NAME -- "auto" for the ones in use -- when this machine
 * can run them, else NULL. */
static const vvec_simd_kernels_t *
vvec_simd_kernels_by_name (const char *name)
{
  if (!strcmp (name, "auto"))
    return vvec_simd_k;
  if (!strcmp (name, "scalar"))
    return &vvec_simd_scalar_k;
#if defined(VVEC_SIMD_NEON)
  if (!strcmp (name, "neon"))
    return &vvec_simd_neon_k;
#endif
#if defined(VVEC_SIMD_AVX2)
  if (!strcmp (name, "avx2") && vvec_simd_cpu_avx2_fma ())
    return &vvec_simd_avx2_k;
#endif
  return NULL;
}

/* ======================================================================= *
 *  The kernels the index calls.  Direct calls wherever the family is fixed at
 *  build time; through vvec_simd_k where it is chosen at start-up.
 * ======================================================================= */
#if defined(VVEC_SIMD_X86_DISPATCH)
# define VVEC_SIMD_CALL(fn) (vvec_simd_k->fn)
#elif defined(VVEC_SIMD_NEON)
# define VVEC_SIMD_CALL(fn) vvec_##fn##_neon
#elif defined(VVEC_SIMD_AVX2)
# define VVEC_SIMD_CALL(fn) vvec_##fn##_avx2
#else
# define VVEC_SIMD_CALL(fn) vvec_##fn##_scalar
#endif

static float
vvec_l2sqr_f32 (const float *a, const float *b, int n)
{
  return VVEC_SIMD_CALL (l2sqr_f32) (a, b, n);
}

static float
vvec_l1_f32 (const float *a, const float *b, int n)
{
  return VVEC_SIMD_CALL (l1_f32) (a, b, n);
}

static float
vvec_ip_f32 (const float *a, const float *b, int n)
{
  return VVEC_SIMD_CALL (ip_f32) (a, b, n);
}

/* sqrt of the self inner product (L2 norm / magnitude). */
static float
vvec_norm_f32 (const float *a, int n)
{
  return (float) sqrt ((double) vvec_ip_f32 (a, a, n));
}

static float
vvec_l2sqr_extf32 (const unsigned char *a, const float *b, int n)
{
  return VVEC_SIMD_CALL (l2sqr_extf32) (a, b, n);
}

static float
vvec_l1_extf32 (const unsigned char *a, const float *b, int n)
{
  return VVEC_SIMD_CALL (l1_extf32) (a, b, n);
}

static float
vvec_ip_extf32 (const unsigned char *a, const float *b, int n)
{
  return VVEC_SIMD_CALL (ip_extf32) (a, b, n);
}

#endif /* VVEC_SIMD_H */
