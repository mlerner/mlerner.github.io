---
layout: post
title: "Log-structured Protocols in Delos"
categories:
---

_The papers over the next few weeks will be from [SOSP](https://sosp2021.mpi-sws.org/). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions about papers to read! These paper reviews can [be delivered weekly to your inbox](https://newsletter.micahlerner.com/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml)._  

[Log-structured Protocols in Delos](TODO)

This week's paper review, "Log-structured Protocols in Delos", discusses a novel approach to building applications on top of shared/replicated logs. Many systems use log replication to maintain multiple copies of a dataset (like MySQL replication) or to increase fault tolerance (like Zookeeper). Consumers of the logic execute logic on the log entries to produce a specific state of the world. Each node that has consumed the log up to the same point, will have the same "state of the world" (assuming that the log consumption code is deterministic!), leading to the name _state machine replication_{% sidenote 'smr' "TODO describe / link to previous SMR research"%}.

The Delos papers aim to simplify the development and deployment of applications built on a shared logic by abstracting away common functionality - a previous paper on Delos, TODO link to Virtual consensus in Delos, discusses abstracting a shared log to simplify its deployment and operations (including upgrading the consensus algorithm used to sync the log under the hood). The most recent Delos paper published at SOSP aims to build abstractions that applications based on a shared log can use, as the authors observed that many systems that use a shared log to replicate state implement common functionality.  

To take advantage of this fact, the paper proposes (and implements) the idea of _log-structured protocols_, implementing common functionality (like batching writes to the log) in reusable lower-level building blocks and application-specific logic at higher-levels. The paper discusses several advantages to log-structured protocols on top of a shared log, including code-reuse, upgradability, and flexibility.

I really enjoyed this paper for a few reasons - the paper's authors have been researching shared logs for some time{% sidenote 'tango' "Mahesh published a paper on using them to build datastructures, Tango TODO."%} for some time and as such have a large body of expertise! Additionally, the newest Delos papers are quite interesting because they share the production-focused experiences of working with developer teams to shape requirements - I like this rubber-meets-the-road approach!

## What are the paper's contributions?'

## Log Structured Protocol Design

## Two Databases and Nine Engines

## Evaluation

## Conclusion