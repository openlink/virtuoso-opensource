/* @(#) rnd.c 12.1.1.3@(#)
 *
 * 
 * RANDOM.C -- Implements Park & Miller's "Minimum Standard" RNG
 * 
 * (Reference:  CACM, Oct 1988, pp 1192-1201)
 * 
 * NextRand:  Computes next random integer
 * UnifInt:   Yields an long uniformly distributed between given bounds 
 * UnifReal: ields a real uniformly distributed between given bounds   
 * Exponential: Yields a real exponentially distributed with given mean
 * 
 */

#include "config.h"
#include <stdio.h>
#include <math.h>
#include "tpcw.h"
#include "rnd.h" 

char *env_config(char *tag, char *dflt);
void NthElement(long, long *);

long
tpc_random(long lower, long upper, long stream)
{
	long res;

	if (upper < 0 || lower < 0 || upper < lower)
		{
		INTERNAL_ERROR("invalid RNG range");
		}
	res = UnifInt((long)lower, (long)upper, (long)stream);
	Seed[stream].usage += 1;

	return(res);
}

void
row_start(int t)	\
{
	int i;
	for (i=0; i <= MAX_STREAM; i++) 
		Seed[i].usage = 0 ; 
	
	return;
}

void
row_stop(int t)	\
	{ 
	int i;
	
	/*
	 * note: code for master/detail has been removed 
	 */
	for (i=0; i <= MAX_STREAM; i++)
		if (Seed[i].table == t)
			{ 
			if (set_seeds && (Seed[i].usage > Seed[i].boundary))
				{
				fprintf(stderr, "\nSEED CHANGE: seed[%d].usage = %d\n", 
					i, Seed[i].usage); 
				Seed[i].boundary = Seed[i].usage;
				} 
			else 
				{
				NthElement((Seed[i].boundary - Seed[i].usage), &Seed[i].value);
				}
			} 
		return;
	}

void
dump_seeds(int tbl)
{
	int i;

	for (i=0; i <= MAX_STREAM; i++)
		if (Seed[i].table == tbl)
			printf("%d:\t%ld\n", i, Seed[i].value);
	return;
}

/******************************************************************

   NextRand:  Computes next random integer

*******************************************************************/

/*
 * long NextRand( long nSeed )
 */
long
NextRand(long nSeed)

/*
 * nSeed is the previous random number; the returned value is the 
 * next random number. The routine generates all numbers in the 
 * range 1 .. nM-1.
 */

{

    /*
     * The routine returns (nSeed * nA) mod nM, where   nA (the 
     * multiplier) is 16807, and nM (the modulus) is 
     * 2147483647 = 2^31 - 1.
     * 
     * nM is prime and nA is a primitive element of the range 1..nM-1.  
     * This * means that the map nSeed = (nSeed*nA) mod nM, starting 
     * from any nSeed in 1..nM-1, runs through all elements of 1..nM-1 
     * before repeating.  It never hits 0 or nM.
     * 
     * To compute (nSeed * nA) mod nM without overflow, use the 
     * following trick.  Write nM as nQ * nA + nR, where nQ = nM / nA 
     * and nR = nM % nA.   (For nM = 2147483647 and nA = 16807, 
     * get nQ = 127773 and nR = 2836.) Write nSeed as nU * nQ + nV, 
     * where nU = nSeed / nQ and nV = nSeed % nQ.  Then we have:
     * 
     * nM  =  nA * nQ  +  nR        nQ = nM / nA        nR < nA < nQ
     * 
     * nSeed = nU * nQ  +  nV       nU = nSeed / nQ     nV < nU
     * 
     * Since nA < nQ, we have nA*nQ < nM < nA*nQ + nA < nA*nQ + nQ, 
     * i.e., nM/nQ = nA.  This gives bounds on nU and nV as well:   
     * nM > nSeed  =>  nM/nQ * >= nSeed/nQ  =>  nA >= nU ( > nV ).
     * 
     * Using ~ to mean "congruent mod nM" this gives:
     * 
     * nA * nSeed  ~  nA * (nU*nQ + nV)
     * 
     * ~  nA*nU*nQ + nA*nV
     * 
     * ~  nU * (-nR)  +  nA*nV      (as nA*nQ ~ -nR)
     * 
     * Both products in the last sum can be computed without overflow   
     * (i.e., both have absolute value < nM) since nU*nR < nA*nQ < nM, 
     * and  nA*nV < nA*nQ < nM.  Since the two products have opposite 
     * sign, their sum lies between -(nM-1) and +(nM-1).  If 
     * non-negative, it is the answer (i.e., it's congruent to 
     * nA*nSeed and lies between 0 and nM-1). Otherwise adding nM 
     * yields a number still congruent to nA*nSeed, but now between 
     * 0 and nM-1, so that's the answer.
     */

    long            nU, nV;

    nU = nSeed / nQ;
    nV = nSeed - nQ * nU;       /* i.e., nV = nSeed % nQ */
    nSeed = nA * nV - nU * nR;
    if (nSeed < 0)
        nSeed += nM;
    return (nSeed);
}

/******************************************************************

   UnifInt:  Yields an long uniformly distributed between given bounds

*******************************************************************/

/*
 * long UnifInt( long nLow, long nHigh, long nStream )
 */
long
UnifInt(long nLow, long nHigh, long nStream)

/*
 * Returns an integer uniformly distributed between nLow and nHigh, 
 * including * the endpoints.  nStream is the random number stream.   
 * Stream 0 is used if nStream is not in the range 0..MAX_STREAM.
 */

{
    double          dRange;
    long            nTemp;

    if (nStream < 0 || nStream > MAX_STREAM)
        nStream = 0;

    if (nLow > nHigh)
    {
        nTemp = nLow;
        nLow = nHigh;
        nHigh = nTemp;
    }

    dRange = (double) (nHigh - nLow + 1);
    Seed[nStream].value = NextRand(Seed[nStream].value);
    nTemp = (long) (((double) Seed[nStream].value / dM) * (dRange));
    return (nLow + nTemp);
}



/******************************************************************

   UnifReal:  Yields a real uniformly distributed between given bounds

*******************************************************************/

/*
 * double UnifReal( double dLow, double dHigh, long nStream )
 */
double
UnifReal(double dLow, double dHigh, long nStream)

/*
 * Returns a double uniformly distributed between dLow and dHigh,   
 * excluding the endpoints.  nStream is the random number stream.   
 * Stream 0 is used if nStream is not in the range 0..MAX_STREAM.
 */

{
    double          dTemp;

    if (nStream < 0 || nStream > MAX_STREAM)
        nStream = 0;
    if (dLow == dHigh)
        return (dLow);
    if (dLow > dHigh)
    {
        dTemp = dLow;
        dLow = dHigh;
        dHigh = dTemp;
    }
    Seed[nStream].value = NextRand(Seed[nStream].value);
    dTemp = ((double) Seed[nStream].value / dM) * (dHigh - dLow);
    return (dLow + dTemp);
}



/******************************************************************%

   Exponential:  Yields a real exponentially distributed with given mean

*******************************************************************/

/*
 * double Exponential( double dMean, long nStream )
 */
double
Exponential(double dMean, long nStream)

/*
 * Returns a double uniformly distributed with mean dMean.  
 * 0.0 is returned iff dMean <= 0.0. nStream is the random number 
 * stream. Stream 0 is used if nStream is not in the range 
 * 0..MAX_STREAM.
 */

{
    double          dTemp;

    if (nStream < 0 || nStream > MAX_STREAM)
        nStream = 0;
    if (dMean <= 0.0)
        return (0.0);

    Seed[nStream].value = NextRand(Seed[nStream].value);
    dTemp = (double) Seed[nStream].value / dM;        /* unif between 0..1 */
    return (-dMean * log(1.0 - dTemp));
}


/* WARNING!  This routine assumes the existence of 64-bit                 */
/* integers.  The notation used here- "HUGE" is *not* ANSI standard. */
/* Hopefully, you have this extension as well.  If not, use whatever      */
/* nonstandard trick you need to in order to get 64 bit integers.         */
/* The book says that this will work if MAXINT for the type you choose    */
/* is at least 2**46  - 1, so 64 bits is more than you *really* need      */

static DSS_HUGE Multiplier = 16807;      /* or whatever nonstandard */
static DSS_HUGE Modulus =  2147483647;   /* trick you use to get 64 bit int */

/* Advances value of Seed after N applications of the random number generator
   with multiplier Mult and given Modulus.
   NthElement(Seed[],count);

   Theory:  We are using a generator of the form
        X_n = [Mult * X_(n-1)]  mod Modulus.    It turns out that
        X_n = [(Mult ** n) X_0] mod Modulus.
   This can be computed using a divide-and-conquer technique, see
   the code below.

   In words, this means that if you want the value of the Seed after n
   applications of the generator,  you multiply the initial value of the
   Seed by the "super multiplier" which is the basic multiplier raised
   to the nth power, and then take mod Modulus.
*/

/* Nth Element of sequence starting with StartSeed */
/* Warning, needs 64-bit integers */
#ifdef SUPPORT_64BITS
void NthElement (long N, long *StartSeed)
   {
   DSS_HUGE Z;
   DSS_HUGE Mult;
   static int ln=-1;
   int i;

   if ((verbose > 0) && ++ln % 1000 == 0)
       {
       i = ln % LN_CNT;
       fprintf(stderr, "%c\b", lnoise[i]);
       }
   Mult = Multiplier;
   Z = (DSS_HUGE) *StartSeed;
   while (N > 0 )
      {
      if (N % 2 != 0)    /* testing for oddness, this seems portable */
         Z = (Mult * Z) % Modulus;
      N = N / 2;         /* integer division, truncates */
      Mult = (Mult * Mult) % Modulus;
      }
   *StartSeed = (long)Z;

   return;
   }
#else
/* add 32 bit version of NthElement HERE */
/*
 *    MODMULT.C
 *    R. M. Shelton -- Unisys
 *    July 26, 1995
 *
 *    RND_seed:  Computes the nth seed in the total sequence
 *    RND_shift:  Shifts a random number by a given number of seeds
 *    RND_ModMult:  Multiplies two numbers mod (2^31 - 1)
 *
 */



#include <math.h>
#include <stdio.h>       /* required only for F_FatalError */

typedef signed long RND;
typedef unsigned long URND;

#define FatalError(e)  F_FatalError( (e), __FILE__, __LINE__ )
void F_FatalError( int x, char *y, int z ) {fprintf(stderr, "Bang!\n");}


/* Prototypes */
RND RND_seed( RND );
RND RND_shift( RND, RND );
static RND RND_ModMult( RND, RND );



RND 
RND_seed ( RND Order            )
{
static const RND TopMask = 0x40000000;
RND Mask;
RND Result;


if (Order <= -Modulus || Order >= Modulus)
   FatalError(1023);

if (Order < 0) Order = Modulus - 1L + Order;

Mask = TopMask;
Result = 1L;

while (Mask > Order) Mask >>= 1;

while (Mask > 0)
   {
   if (Mask & Order)
      {
      Result = RND_ModMult( Result, Result);
      Result = RND_ModMult( Result, Multiplier );
      }
   else
      {
      Result = RND_ModMult( Result, Result );
      }
   Mask >>= 1;
   }

return (Result);

}  /*  RND_seed  */



/***********************************************************************

    RND_shift:  Shifts a random number by a given number of seeds

***********************************************************************/

void 
NthElement ( long Shift, long *Seed)

{
   RND Power;
   static int ln=-1;
   int i;

   if ((verbose > 0) && ++ln % 100 == 0)
       {
       i = (ln/100) % LN_CNT;
       fprintf(stderr, "%c\b", lnoise[i]);
       }


if (*Seed <= 0 || *Seed >= Modulus)
   FatalError(1023);
if (Shift <= -Modulus || Shift >= Modulus)
   FatalError(1023);

Power = RND_seed( Shift );

*Seed = RND_ModMult( *Seed, Power );

return;
}  /*  RND_shift  */



/*********************************************************************

    RND_ModMult:  Multiplies two numbers mod (2^31 - 1)

*********************************************************************/

static RND 
RND_ModMult ( RND nA, RND nB)

{

static const double dTwoPowPlus31 = 2147483648.;
static const double dTwoPowMinus31 = 1./2147483648.;
static const double dTwoPowPlus15 = 32768.;
static const double dTwoPowMinus15 = 1./32768.;
static const RND    nLowMask = 0xFFFFL;
static const URND   ulBit31 = 1uL << 31;

double dAH, dAL, dX, dY, dZ, dW;
RND    nH, nL;
URND   ulP, ulQ, ulResult;

nL = nB & nLowMask;
nH = (nB - nL) >> 16;
dAH = (double)nA * (double)nH;
dAL = (double)nA * (double)nL;
dX = floor( dAH * dTwoPowMinus15 );
dY = dAH - dX*dTwoPowPlus15;
dZ = floor( dAL * dTwoPowMinus31 );
dW = dAL - dZ*dTwoPowPlus31;

ulQ = (URND)dW + ((URND)dY << 16);
ulP = (URND)dX + (URND)dZ;
if (ulQ & ulBit31) { ulQ -= ulBit31; ulP++; }

ulResult = ulP + ulQ;
if (ulResult & ulBit31) { ulResult -= ulBit31; ulResult++; }

return (RND)ulResult;
}
#endif /* SUPPORT_64BITS */
