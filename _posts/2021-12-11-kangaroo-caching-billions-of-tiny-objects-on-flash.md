---
layout: post
title: "Kangaroo: Caching Billions of Tiny Objects on Flash"
categories:
---

_The papers over the next few weeks will be from [SOSP](https://sosp2021.mpi-sws.org/). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions about papers to read! These paper reviews can [be delivered weekly to your inbox](https://newsletter.micahlerner.com/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml)._  

[Kangaroo: Caching Billions of Tiny Objects on Flash](https://dl.acm.org/doi/pdf/10.1145/3477132.3483568)

This week's paper is _Kangaroo: Caching Billions of Tiny Objects on Flash_, which won a best paper award at SOSP - the implementation also builds on the [CacheLib](https://www.cachelib.org) open source project. Kangaroo describes a two-level caching system that uses both flash and memory to cheaply and efficiently cache data at scale. Previous academic and industry research{% sidenote 'flash' "See the [Flashield paper](https://www.usenix.org/system/files/nsdi19-eisenman.pdf)."%} demonstrates significant cost savings (around a factor of 10!) from hybrid memory/flash caches, but doesn't solve the unique issues faced by small object caches that store information like tweets, social graphs, or data from Internet of Things devices{% sidenote 'smallobjs' "One example of tiny objects caching is covered by my previous paper review on [TAO: Facebook’s Distributed Data Store for the Social Graph](/2021/10/13/tao-facebooks-distributed-data-store-for-the-social-graph.html)" %}). Another unique property of Kangaroo is that it explicitly aims for different goals than those of persistent key-value stores (like Memcache, Redis, or RocksDB) - the system does not aim to be a persistent "source of truth" database, meaning that it has different constraints on how much data it stores and what is evicted from cache.

A key tradeoff faced by hybrid flash and memory caches is between cost and speed. This tradeoff manifests in whether caching systems store data in memory (DRAM) or on flash Solid State Drives. Storing cached data (and potentially the metadata about the cached data) in memory is expensive and fast. In contrast, flash storage is cheaper, but slower. 

While some applications can tolerate increased latency from reading or writing to flash{% sidenote 'netflix' "One example of this is from Netflix's caching system, [Moneta](https://netflixtechblog.com/application-data-caching-using-ssds-5bf25df851ef)."%}, the decision to use flash (instead of DRAM) is complicated by the limited number of writes that flash devices can tolerate before they wear out{% sidenote 'lifetime' "[Flashield: a Hybrid Key-value Cache that Controls Flash Write Amplification](https://www.usenix.org/system/files/nsdi19-eisenman.pdf) also provides more context on the dollar and cents of a hybrid flash/memory cache." %}. This limit means that write-heavy workloads wear out flash storage faster, consuming more devices and reducing potential cost savings (as the additional flash devices aren't free). To drive home the point about how important addressing this use case is, previous research{% sidenote 'leveldb' "Previous research has noted limits to write heavy workloads targeted at key-value stores like [LevelDB and RocksDB](https://www.cs.utexas.edu/~vijay/papers/sosp17-pebblesdb.pdf). Additionally, [A large scale analysis of hundreds of in-memory cache clusters at Twitter](https://www.usenix.org/system/files/osdi20-yang.pdf) notes that 30% of Twitters caches are write-heavy yet existing research has predominantly focused on read-heavy workloads." %} to characterize cache clusters at Twitter noted that around 30% are write heavy!

Kangaroo seeks to address the aforementioned tradeoff by synthesizing previously distinct design ideas for cache systems, along with several techniques for increasing cache hit rate. When tested in a production-like environment relative to an existing caching system at Facebook, Kangaroo reduces flash writes by ~40%.

## What are the paper's contributions?

The paper makes three main contributions: characterization of the unique issues faced by small-object caches, a design and implementation of a cache that addresses these issues, and an evaluation of the system (one component of which involves production traces from Twitter and Facebook).

## Challenges

Kangaroo aims to make optimal use of limited memory, while at the same time limiting writes to flash - the paper notes prior "flash-cache designs either use too much DRAM or write flash too much." 

Importantly, the paper differentiates how it is addressing a different, but related, problem from other key value systems like Redis, Memcache, or RocksDB. In particular, Kangaroo makes different assumptions - "key-value stores generally assume that deletion is rare and that stored values must be kept until told otherwise. In contrast, caches delete items frequently and at their own discretion (i.e., every time an item is evicted)". In other words, the design for Kangaroo is not intended to be a database-like key-value store that stores data persistently.

### Differences from key-value systems

The paper cites two problems that traditional key-value systems don't handle well when the cache has frequent churn: _write amplification_ and _lower effective capacity_.

_Write amplification_ is the phenomenon "where the actual amount of information physically written to the storage media is a multiple of the logical amount intended to be written"{% sidenote 'wa' "Helpful article on the topic [here](https://en.wikipedia.org/wiki/Write_amplification)."%}. 

The paper notes two types of write amplification: 

- _Device-level write amplification (DLWA)_ is caused by differences between what applications instruct the storage device to write and what the device actually writes{% sidenote 'dlwa' 'The [Flashield paper](https://www.usenix.org/system/files/nsdi19-eisenman.pdf) writes that "Device-level write amplification (DLWA) is write amplification that is caused by the internal reorganization of the SSD. The main source of DLWA comes from the size of the unit of flash reuse. Flash is read and written in small ( ̃8 KB) pages. However, pages cannot be rewritten without first being erased. Erasure happens at a granularity of groups of several pages called blocks ( ̃256 KB). The mismatch between the page size (or object sizes) and the erase unit size induces write amplification when the device is at high utilization."' %}. 
- _Application-level write amplification (ALWA)_ happens when an application intends to update a small amount of data in flash, but writes a larger amount of data to do so. This effect happens because flash drives are organized into blocks that must be updated as a whole. As an example, if a block of flash storage contains five items, and the application only wants to update one of them, the application must perform a read of all five items in the block, replace the old copy of an item with the updated version, then write back the updated set of all five items.

The other problem that key-value stores encounter under write-heavy workloads is _lower effective capacity_. Specifically, this impacts key-value stores that store data in flash. RocksDB is one example - it keeps track of key-value data using a log{% sidenote 'lsmtrees' "The log contains files called LSM Trees, and there are great articles about how they work [here](https://yetanotherdevblog.com/lsm/) and [here](https://www.igvita.com/2012/02/06/sstable-and-log-structured-storage-leveldb/)." %} that is periodically cleaned up through a process called compaction. If RocksDB receives many writes, a fixed size disk will use more of its space to track changes to keys, instead of using space to track a larger set of keys{% sidenote 'nflxstorage' "The _lower effective capacity_ problem impacted Netflix's implementation of a key-value datastore called [EVCache](https://netflixtechblog.com/application-data-caching-using-ssds-5bf25df851ef), which stores data on flash using RocksDB. RocksDB stores data in files that represent a log of the changes made to the system. Eventually older sections of the log are removed from storage, using a process called compaction. Many writes to the system create more computational work for the compaction cleanup process. In Netflix's case, they had to change their compaction process." %}.

### Existing designs

There are two cache designs that the system aims to build on: _log structured caches_ and _set-associative caches_. 

_Log structured caches_ store cached entries in a log{% sidenote 'ring' "Many also use a [circular buffer](https://towardsdatascience.com/circular-queue-or-ring-buffer-92c7b0193326)."%}. Production usage of the approach includes CDNs and Facebook's image caching service{% sidenote 'ripq' "See [RIPQ: Advanced Photo Caching on Flash for Facebook](https://www.usenix.org/conference/fast15/technical-sessions/presentation/tang)"%}. To allow fast lookups into the cache (and prevent sequential scans of the cached data), many implementations create in memory indexes tracking the location of entries. These memory indexes poses a challenge{% sidenote 'cachelib' "See the _Size Variability_ section of the [CacheLib](https://www.usenix.org/system/files/osdi20-berg.pdf) paper." %} when storing many small items, as:

> The per-object overhead differs across existing systems between 8B and 100B. For a system with a median object size of 100B ... this means that 80GB - 1TB of DRAM is needed to index objects on a 1TB flash drive.

_Set associative caches_, in contrast to _log structured caches_, do not have analagous{% sidenote 'tech' 'It is technically possible for set-associative caches to have them, but in memory indexes are not required as, "an objects possible locations are implied by its key."'%} in-memory indexes. Instead, the key associated with an object is used during lookup to find a set of items on flash storage. Unfortunately, _set associative caches_ don't perform well for writes, as changing the set associated with a key involves reading the whole set, updating the set, then writing the whole set back to flash (incurring _application level write amplification_, as mentioned earlier).

### Design

The Kangaroo system has three main components: 

- A small _DRAM Cache_, which stores a subset of recently written keys.
- _KLog_ which has 1) a buffer of cached data on flash and 2) an in-memory index into the buffer for fast lookups, similar to log structured cache systems.
- _KSet_ which stores a set of objects in pages on flash, as well as a Bloom filter{% sidenote 'bloom' "[Here](https://llimllib.github.io/bloomfilter-tutorial/) is a neat interactive tutorial on Bloom filters."%} used to track how set membership, similar to set-associative caches.

{% maincolumn 'assets/kangaroo/sys.png' '' %}

## System Operations

Kangaroo uses the three components to implement two high-level operations: _lookup_ and _insert_.

{% maincolumn 'assets/kangaroo/ops.png' '' %}

### Lookups

_Lookups_ get the value of a key if it is stored in the cache. This process occur in three main steps (corresponding to the three main components of the design).

First, check the _DRAM cache_. On a cache hit, return the value and on a cache miss, continue on to check the KLog.

If the key is not in the _DRAM Cache_, check the _KLog_ in-memory index for the key to see whether the key is in flash, reading the value from flash on cache hit or continuing to check KSet on cache miss.

On _KLog_ miss, hash the key used in the lookup to determine the associated _KSet_ for the key. Then, read the per-set in-memory Bloom filter for the associated _KSet_ to determine whether data for the key is likely{% sidenote 'prob' "'Likely' inserted here because Bloom filters are probabilistic." %} to exist on flash - if the item is on flash, read the associated set, scan for the item until it is found, and return the data.

### Inserts

_Inserts_ add a new value to the cache (again in three steps that correspond to the three components of the system).

First, write new items to the _DRAM cache_. If the _DRAM Cache_ is at capacity, some items will be evicted and potentially pushed to the KLog. Kangaroo doesn't add all items evicted from the _DRAM Cache_ to the _KLog_, as making this shift can incur writes to flash (part of what the system wants to prevent). The algorithm for deciding what is shifted is covered in the next section. 

If Kangaroo chooses to admit the items evicted from the _DRAM Cache_ to the _KLog_, the system updates the _KLog_ in-memory index and writes the entry to flash{% sidenote 'buffer' "The paper notes that writes to flash are actually buffered in memory - in a write-heavy system it is possible that the entries that make it to the KLog are quickly evicted." %} 

Writing an item to _KLog_ has the potential to cause evictions from the _KLog_ itself. Items evicted from the _KLog_ are potentially inserted into an associated KSet, although this action depends on an algorithm similar to the one earlier (which decides whether to admit items evicted from the _DRAM Cache_ to the _KLog_). If items evicted from the _KLog_ are chosen to be inserted into a associated _KSet_, *all* items both currently in the _KLog_ and associated with the to-be-written _KSet_ are shifted to the _KSet_ - "doing this amortizes flash writes in KSet, significantly reducing Kangaroo’s [application-level write amplification]".

## Implementation

The implementation of Kangaroo couples _a DRAM Cache_, _KLog_, and _KSet_ with three key ideas: _admission policies_, _partitioning of the KLog_, and _usage-based eviction_.

As mentioned earlier, items from the _DRAM Cache_ and _KLog_ are not guaranteed to be inserted into the next component in the system. The decision whether to propagate an item is decided by a tunable _admission policy_ that targets a certain level of writes to flash. The _admission policy_ for DRAM Cache to KLog transitions is probabilistic (some percent of objects are rejected), while the policy controlling the KLog to KSet transition is based on the number of items currently in the _KLog_ mapping to the candidate _KSet_{% sidenote 'klogtokset' "Updating a KSet requires writing many (or all) of the objects in a set, so only making a few updates may not be not worth it." %}.

Next, _partitioning the KLog_ reduces "reduces the per-object metadata from 190 b to 48 b per object, a 3.96× savings vs. the naïve design." This savings comes from changes to the pointers used in traversing the index. One example is an `offset` field that maps an object to the page of flash it is stored in:

> The flash offset must be large enough to identify which page in the flash log contains the object, which requires log2(𝐿𝑜𝑔𝑆𝑖𝑧𝑒/4 KB) bits. By splitting the log into 64 partitions, KLog reduces 𝐿𝑜𝑔𝑆𝑖𝑧𝑒 by 64× and saves 6 b in the pointer.

{% maincolumn 'assets/kangaroo/partitions.png' '' %}

Lastly, _usage-based eviction_ ensures infrequently-used items are evicted from the cache and is normally based on usage metadata - given fixed resources, these types of policies can increase cache hit ratio by ensuring that frequently accessed items stay in cache longer. To implement the idea while using minimal memory, Kangaroo adapts a technique from processor caches called _Re-Reference Interval Prediction (RRIP)_, (calling its adaptation _RRIParoo_):

> RRIP is essentially a multi-bit clock algorithm: RRIP associates a small number of bits with each object (3 bits in Kangaroo), which represent reuse predictions from near reuse (000) to far reuse (111). Objects are evicted only once they reach far. If there are no far objects when something must be evicted, all objects’ predictions are incremented until at least one is at far.

_RRIParoo_ tracks how long ago an item was read as well as whether it was read. For items in KLog, information about how long ago an item was read is stored using three bits in the in-memory index. 

{% maincolumn 'assets/kangaroo/rrip.png' '' %}

In contrast, usage data for items in KSet is stored in flash (as KSet doesn't have an in-memory index). Each KSet also has a bitset with one bit for every item in the KSet that tracks tracks whether an item was accessed - this set of single-bit usage data can be used to "reset" the timer for an item. 

## Evaluation

To evaluate Kangaroo, the paper compares the system's cache miss ratio rate against other cache systems and deploys it with a dark launch to production.

Kangaroo is compared to a CacheLib deployment designed for small objects, and to a log-structured cache with a DRAM index. All three systems run on the same resources, but Kangaroo achieves the lowest cache miss ratio - this, "is because Kangaroo makes effective use of both limited DRAM and flash writes, whereas prior designs are hampered by one or the other."

{% maincolumn 'assets/kangaroo/miss.png' '' %}

Kangaroo was dark launched to production inside of Facebook and compared with an existing small object cache - Kangaroo reduces flash writes and reduces cache misses. Notably, the Kangaroo configuration that allows all writes performs the best of the set, demonstrating the potential for operators to make the tradeoff between flash writes and cache miss ratio (more flash writes would be costlier, but seem to reduce the cache miss ratio).

{% maincolumn 'assets/kangaroo/prod.png' '' %}

## Conclusion

The Kangaroo paper demonstrates a unique synthesis of several threads of research, and the tradeoffs caching systems at scale make between cost and speed were interesting to read. As storage continues to improve (both in cost and performance), I'm sure we will see more research into caching systems at scale! 

As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback. Until next time.