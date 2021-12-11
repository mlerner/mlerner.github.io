---
layout: post
title: "Kangaroo: Caching Billions of Tiny Objects on Flash"
categories:
---

_The papers over the next few weeks will be from [SOSP](https://sosp2021.mpi-sws.org/). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions about papers to read! These paper reviews can [be delivered weekly to your inbox](https://newsletter.micahlerner.com/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml)._  

This week's paper is _Kangaroo: Caching Billions of Tiny Objects on Flash_, a system that aims to address the unique issues faced by caching systems that store many small objects (like tweets, social graphs, or data from Internet of Things devices{% sidenote 'smallobjs' "TODO provide the examples for each of these" %}).
The research won a best paper award at this year's SOSP conference, and the implementation is part of the [CacheLib](https://www.cachelib.org) open source project. 

Caching systems storing small objects at scale face a tradeoff between cost and speed. This tradeoff manifests in how caching systems store data in memory (DRAM) or on flash Solid State Drives (aka SSDs) - storing all cache data in memory is expensive, but fast, while flash storage is cheaper, but slower. While some applications can tolerate increased latency from reading or writing to flash{% sidenote 'netflix' "One example of this is from Netflix's caching system, [Moneta](https://netflixtechblog.com/application-data-caching-using-ssds-5bf25df851ef). TODO"%}, the decision to use flash (instead of DRAM) is complicated by the limited number of writes that flash devices can tolerate before they wear out{% sidenote 'lifetime' "TODO cite the lifetime of flash devices" %}. This limit means that write-heavy workloads wear out flash storage faster, consuming more devices and reducing potential cost savings (as the additional flash devices aren't free).

Kangaroo seeks to address this tradeoff by 