/*!
* @file SHA256.c
* @brief SHA256 Algorithm Implementation (C)
* @author LDFranck
* @date January 2023
* @warning Message padding works only for byte-size data (8bits chunks).
* @note Code based on and tested with: https://sha256algorithm.com/
*
* @details 
*  The code is divided into lowercase and uppercase functions.
*  The lowercase ones are message or constants related ("software"), whereas the
*  uppercase functions make up the compression part of the algorithm ("hardware").
*/

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

typedef uint64_t word64;
typedef uint32_t word32;
typedef uint8_t byte8;

//! Conversion: 32bits <-> 4*8bits
typedef union _wrap32{
   word32 w32;
   byte8  b8[4];
} wrap32;

//! Message Block (16 * word32 = 512bits)
typedef struct _msgBlock512{
   wrap32 m[16];
} msgBlock512;

//! Shift Right Logical
word32 SRL(word32 x, word32 n){
   return x >> n;
}

//! Rotate Right Logical
word32 ROR(word32 x, word32 n){
   return (x >> n) | (x << 32-n);
}

//! Logical XOR (3 inputs)
word32 XOR3(word32 x, word32 y, word32 z){
   return x ^ y ^ z;
}

//! Logical XOR (2 inputs)
word32 XOR2(word32 x, word32 y){
   return x ^ y;
}

//! Logical AND
word32 AND(word32 x, word32 y){
   return x & y;
}

//! Logical NOT
word32 NOT(word32 x){
   return ~x;
}

//! Addition modulo 2^32 (32bits)
word32 ADD(word32 v, word32 w, word32 x, word32 y, word32 z){
   return v + w + x + y + z;
}

//! Lowercase sigma 0
word32 LSIGMA0(word32 x){
   return XOR3(ROR(x, 7), ROR(x, 18), SRL(x, 3));
}

//! Lowercase sigma 1
word32 LSIGMA1(word32 x){
   return XOR3(ROR(x, 17), ROR(x, 19), SRL(x, 10));
}

//! Uppercase Sigma 0
word32 USIGMA0(word32 x){
   return XOR3(ROR(x, 2), ROR(x, 13), ROR(x, 22));
}

//! Uppercase Sigma 1
word32 USIGMA1(word32 x){
   return XOR3(ROR(x, 6), ROR(x, 11), ROR(x, 25));
}

//! Bitwise IF x == 1 THEN y ELSE z
word32 CHOICE(word32 x, word32 y, word32 z){
   return XOR2(AND(x, y), AND(NOT(x), z));
}

//! Bitwise majority function (returns the most frequent bit)
word32 MAJORITY(word32 x, word32 y, word32 z){
   return XOR3(AND(x, y), AND(x, z), AND(y, z));
}

//! Cube Root Constants Generation
word32 getConstantCube(word32 x){
   double dec, var = cbrt(x);
   var = modf(var, &dec);

   return (word32)(var * pow(2, 32));
}

//! Square Root Constants Generation
word32 getConstantSquare(word32 x){
   double dec, var = sqrt(x);
   var = modf(var, &dec);

   return (word32)(var * pow(2, 32));
}

//! Compression Function Constants
void compConstants(word32 k[]){
   word32 primes[64] = {  2,   3,   5,   7,  11,  13,  17,  19,  23,  29,  31,
                         37,  41,  43,  47,  53,  59,  61,  67,  71,  73,  79,
                         83,  89,  97, 101, 103, 107, 109, 113, 127, 131, 137,
                        139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193,
                        197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257,
                        263, 269, 271, 277, 281, 283, 293, 307, 311};

   for (unsigned char i = 0; i < 64; i++) k[i] = getConstantCube(primes[i]);
   
   return;
}

//! Number of 512bits Message Blocks
word64 numMsgBlocks(word64 msgLen){
   word64 numMB = 0;
   
   while(msgLen / 64){
      numMB++;
      msgLen -= 64;
   }

   if(msgLen / 56) numMB += 2;
   else numMB += 1;

   return numMB;   
}

//! Messsage Expansion & Compression Function (core SHA256)
void SHA256(msgBlock512 block, word32 hash[]){
   
   word64 i;
   word32 hash0[8], w[64], k[64], Temp1, Temp2;

   // Original hash storage
   for(i = 0; i < 8; i++) hash0[i] = hash[i];

   // Message expansion
   for(i = 0; i < 16; i++) w[i] = block.m[i].w32;
   for(; i < 64; i++) w[i] = ADD(w[i-16], LSIGMA0(w[i-15]), w[i-7], LSIGMA1(w[i-2]), 0);

   // Get constants
   compConstants(k);

   // Compression function (state update)
   for(i = 0; i < 64; i++){
      Temp1 = ADD(hash[7], USIGMA1(hash[4]), CHOICE(hash[4], hash[5], hash[6]), k[i], w[i]);
      Temp2 = ADD(USIGMA0(hash[0]), MAJORITY(hash[0], hash[1], hash[2]), 0, 0, 0);

      hash[7] = hash[6];
      hash[6] = hash[5];
      hash[5] = hash[4];
      hash[4] = ADD(hash[3], Temp1, 0, 0, 0);
      hash[3] = hash[2];
      hash[2] = hash[1];
      hash[1] = hash[0];
      hash[0] = ADD(Temp1, Temp2, 0, 0, 0);
   }

   // FinalHash = original hash + current state
   for(i = 0; i < 8; i++) hash[i] = ADD(hash0[i], hash[i], 0, 0, 0);

   return;
}

//! MainFunction: message padding + original hash + SHA256 + output
int main() {

   word64 i, j, k, l;

   // Non-padded input message (maximum size = 2^64 - 1 bits)
   char msg[] = "abc";
   
   // Msg PADDING for byte-size input:
   // msgBlock size = 512 bits, last 64bits to store msgSize
   word64 len = strlen(msg);
   word64 numMB = numMsgBlocks(len);
   msgBlock512 msgBlock[numMB];

   // Initializing msgBlocks
   for(i = 0; i < numMB; i++) for(j = 0; j < 16; j++) msgBlock[i].m[j].w32 = 0;
   
   // Filling msgBlocks
   i = j = k = l = 0;
   while(l < len){
      msgBlock[i].m[j].b8[3-k++] = msg[l++];
      if(k == 4) {k = 0; j++;}
      if(j == 16) {j = 0; i++;}
   }

   // Append separator ('1')
   msgBlock[i].m[j].b8[3-k] = 128;

   // Append message bit length (last 64bits)
   union w64tow32{
      word64 w64;
      word32 w32[2];
   } msgSize;

   msgSize.w64 = len*8;
   msgBlock[numMB-1].m[14].w32 = msgSize.w32[1];
   msgBlock[numMB-1].m[15].w32 = msgSize.w32[0];
 
   // Initial hash
   word32 hash[8], primes[8] = {2, 3, 5, 7, 11, 13, 17, 19};
   for(i = 0; i < 8; i++) hash[i] = getConstantSquare(primes[i]);
   
   // Msg expansion & compression for all blocks
   for(i = 0; i < numMB; i++) SHA256(msgBlock[i], hash);

   // Output
   for(i = 0; i < 8; i++) printf("%08x", hash[i]);
}
