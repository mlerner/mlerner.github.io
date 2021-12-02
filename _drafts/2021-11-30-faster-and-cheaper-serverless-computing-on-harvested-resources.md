---
layout: post
title: "Faster and Cheaper Serverless Computing on Harvested Resources"
categories:
---

_The papers over the next few weeks will be from [SOSP](https://sosp2021.mpi-sws.org/). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions about papers to read! These paper reviews can [be delivered weekly to your inbox](https://newsletter.micahlerner.com/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml)._  

This week's paper review is "Faster and Cheaper Serverless Computing on Harvested Resources" and builds on the research group's previous work{% sidenote 'slos' "Previous work TODO" %} into _Harvest Virtual Machines_ (aka _Harvest VMs_). _Harvest VMs_ are similar to relatively cheap{% sidenote 'spot' 'Spot resources are generally cheaper than "reserved" resources spot VMs can be interrupted, while reserved resources can not - in other words, users of cloud providers pay a premium for the predictability of their resources.' %} "spot" resources available from many cloud providers, with one key difference - Harvest VMs can grow and shrink dynamically (down to a set minimum and up to a maximum) according to the available resources in the host system, while spot resources can not. 

This paper in particular focuses on whether the Harvest VM paradigm can be used to efficiently and cheaply execute serverless workloads. The serverless paradigm is growing in popularity (TODO source), and TODO other notes about serverless

While Harvest VMs pose great potential for lowering the costs of datacenter even further (by using otherwise idle resources), using them poses its own challenges. For example, Harvest VMs are evicted from a machine if the Harvest VM's minimum resources are needed by higher priority applications. Furthermore, dynamic resizing of Harvest VMs means that applications scheduled to run with the original resources may be constrained after a resize.

## What are the paper's contributions?

The paper makes four contributions: characterization of Harvest VMs and serverless workloads on Microsoft Azure using production traces, the design of a system for running serverless workloads on Harvest VMs, a concrete implementation of the design, and an evaluation of the system.

## Characterization

The first part of the paper evaluates whether Harvest VMs and serverless workloads are compatible. Harvest VMs dynamically resize according to the available resources on the host machine. If resizing happens too frequently or the Harvest VM is evicted (because the minimum resources needed to maintain the VM are no longer available), that could impact the viability of using the technique for serverless workloads.

### Characterizing Harvest VMs 

First, the paper looks at two properties of the Harvest VMs: 

- _Eviction rate_: evictions of Harvest VMs happen when higher priority VMs (like reserved resources) require that the Harvest VM shrink below its minimum resources{% sidenote 'mentioned' "Harvest VMs are configured with minimum and maximum resource bounds, where the maximum specifies the most cores/memory that the VM can consume." %}. If evictions occur often enough, it wouldn't be possible for serverless functions to complete, meaning that the workload might be better suited for more expensive reserved resources where pre-emption is not possible.
- _Resource variability_: Harvest VMs grow and shrink according to the available resources on the host. If this variation happens too frequently, the Harvest VM may become resource constrained and unable to process work assigned to it in a timely manner - for example, if 32 cores worth of work is assigned, but the Harvest VM is shortly thereafter downsized to 16 cores, the machine may not be able to execute the assigned computation.

### Characterizing Serverless Workloads

Then the paper evalutes whether serverless workloads are able to efficiently execute in the presence of evictions.

## Design

## Implementation

## Evaluation

## Conclusion