# bloom.nim - Bloom filter implementation in Nim
# Copyright (C) 2023 Maciej Obarski
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

##[
REF: https://en.wikipedia.org/wiki/Bloom_filter
- k - number of hash functions
- m - bit capacity
- n - expected number of elements
]##

from std/random import randomize, rand
from std/math import pow, exp, ln, round
import std/strformat
import std/hashes

type BloomFilter* = object
    k* : int
    m* : int
    data* : seq[byte]
    salt* : seq[int]


proc new_bloom_filter*(k, m: int): BloomFilter =
    ## Create a new Bloom filter with k hash functions and m bits
    result = BloomFilter(k: k, m: m, data: newSeq[byte](m div 8 + 1), salt: newSeq[int](k))
    for i in 0 ..< k:
        result.salt[i] = i


proc hash(self: BloomFilter, text:string, i:int=0): int =
    ## Hash text with i-th hash function
    when false:
        let salt = self.salt[i]
        let val = "{salt}|{text}|{salt}".fmt
        return val.hash # TODO: crc32 or other well known hash
    else:
        var h : Hash = self.salt[i].hash
        h = h !& text.hash
        result = abs(!$h)

proc mark(self: var BloomFilter, pos:int) =
    ## Mark the bit at position pos
    let idx_byte = pos div 8
    let idx_bit  = pos mod 8
    let mask = 1 shl (7 - idx_bit)
    self.data[idx_byte] = self.data[idx_byte] or mask.byte

proc check(self: BloomFilter, pos:int): bool =
    ## Check the bit at position pos
    let idx_byte = pos div 8
    let idx_bit  = pos mod 8
    let mask = 1 shl (7 - idx_bit)
    return (self.data[idx_byte] and mask.byte) != 0

proc add*(self: var BloomFilter, text:string) =
    ## Add text to the set
    for i in 0 ..< self.k:
        let h = self.hash(text, i)
        let pos = h mod self.m
        self.mark(pos)

# TODO: rename to query ??? (as in wikipedia)
proc has*(self: BloomFilter, text:string, skip=0): bool =
    ## Check if text is in the set, skip last *skip* hashes
    for i in 0 ..< self.k - skip:
        let h = self.hash(text, i)
        let pos = h mod self.m
        if not self.check(pos):
            return false # definitely not in the set
    return true # probably in the set

proc randomize_salts*(self: var BloomFilter, seed=0) =
    ## Randomize the salts
    randomize(seed)
    for i in 0 ..< self.k:
        self.salt[i] = rand(high(int))

# TODO: self.k vs salts.len
proc set_salts*(self: var BloomFilter, salts:seq[int]) =
    ## Set the salts
    for i in 0 ..< self.k:
        self.salt[i] = salts[i]

# === INFO ===

proc bloom_error*(k, m, n:int): float =
    ## Calculate the probability of false positives
    let x = 1 - exp(-k.float * (n.float+0.5) / (m.float-1))
    return pow(x, k.float)

proc bloom_optimal_k*(m,n:int): int =
    ## Calculate the optimal number of hash functions
    return round(m.float / n.float * ln(2.float)).int

# ??? optimal bits per element is -1.44 * log2(error) ???
proc bloom_optimal_m*(n:int, error:float): int =
    ## Calculate the optimal number of bits
    for i in 2..128:
        let m = n*i
        let k = bloomOptimalK(m, n)
        let e = bloomError(k, m, n)
        if e <= error:
            return m

# TODO: remove
#[
proc bloom_norm*(self: BloomFilter, text:string, i=0): float =
    ## Calculate the i-th hash value and normalize it to [0,1)
    let h = self.hash(text, i)
    return h / high(int)
]#

# === TESTS ===

proc test1() =
    var x = new_bloom_filter(3, 30)
    echo x
    x.add("hello")
    echo x
    for i in 0..x.m:
        if x.check(i):
            echo "bit {i} is set".fmt
    echo x.has("hello")
    x.randomize_salts()
    echo x
    echo bloom_error(3, 30, 1)
    echo bloom_optimal_k(30, 2)
    echo bloom_optimal_m(2, 0.01)

if is_main_module:
    test1()
