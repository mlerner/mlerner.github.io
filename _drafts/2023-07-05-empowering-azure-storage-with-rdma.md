---
layout: post
title: "Empowering Azure Storage with RDMA"
categories:
---

[Empowering Azure Storage with RDMA](TODO)

_This is one in a series of papers I'm reading from NSDI. These paper reviews can be [delivered weekly to your inbox](https://newsletter.micahlerner.com/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions!_

Azure Storage powers applications in Microsoft's cloud that write to disk. This paper describes the work that went into using RDMA on their networks instead of TCP/IP for traffic. RDMA is way better because it moves computation from the loop, meaning that there are fewer resources involved in creating the storage service. As a result, Microsoft is able to save on cost, and pass those savings on to their customers.

Unfortunately, deploying RDMA at scale came with its own sets of challenges. For example, TCP/IP datacenter networks are well understood and operate with mostly low-latency. In contrast, RDMA has even stricter requirements of lossless. To accomodate these requirements takes some work. Alternatively, you could bolt on a separate network specifically for RDMA, but that would introduce a lot of cost and additional resources.

So, they wanted to make RDMA work on their existing network, but they had to make changes to hardware to do it. Also, the existing hardware and software it runs had nuanced problems. At the end of the day, RDMA is able to deliver substantial performance benefits and cost savings.

## What are the paper's contributions?

The paper makes three main contributions:

- A description of the RDMA deployment in use by Azure Storage
- Characeterization of the problems the system faced, along with solutions.
- Evaluation of the system running at scale.

## How does the system work?

### Architecture

The paper describes two components of Azure storage: the architecture of the network the system runs on, and Azure storage itself.

#### Network

The architecture of Microsoft Azure regions is made up of Clos topologies (TODO reference Clos!!), with three levels of routers. At the bottom are servers, which are connected to T0 "top of rack" switches. T1 switches contact many T0 switches inside of a cluster.  Higher up the stack T2 switches connect many clusters, forming a datacenter. Lastly, a region is made up of many datacenters. Importantly, the types of switches varies throughout the stack, leading to a quality called heterogenity. It isn't practical to make all the switches the same because there is failure in the background, along with vendors producing new switches all of the time.

RDMA can run over an existing data center network by wrapping the technology in UDP packets, using a technology called RDMA over Converged Ethernet (RoCE) TODO ref RoCE.

TODO show the packet for RDMA

#### Azure Storage

The Azure storage system is divided into compute and storage, following a common pattern of trying to separate these two resources (TODO ref the ECS paper). Compute contains hosts who perform IO, whereas the storage system integrates with backing medium like SSDs.

The storage layer (the focus of the paper), is made up of three layers:

- _Frontend layer_: TODO
- _Partition layer_: TODO
- _Stream layer_: TODO

Azure has many qualities in common with other blob store systems (TODO ref Ambry). There is an abstraction on top of raw bytes that the system operates on called an _extent_ - "a file is essentially an ordered list of large storage chunks called _extents_." Writes are represented as appends to a distributed log, and the system replicates them to ensure durability (no data loss).

Communication between components of the system is classified as _frontend_ ("between compute and storage servers") or _backend_ ("between storage servers, e.g., replication and disk reconstruction"). The paper notes that using RDMA for _backend_ traffic is "relatively easy because almost all the backend traffic stays within a storage cluster", meaning that it is less prone to congestion and packet loss. Frontend traffic is more likely to be cross-cluster because applications using storage aren't always co-located with the storage they're using, meaning that traffic can cross the datacenter boundary.

### Challenges

The authors detail several requirements of their solution, then describe how the current system meets those requirements:

- High performance
- Reliability and graceful degradation
- Debuggability and observability
- Legacy infrastructure needs to work with RDMA
- Heterogenous hardware (including NICs and switches)
- Different latency profiles within and among regions
- Nearly lossless networking conditions, capable of handling congestion

These challenges come up throughout the paper.

### RDMA Libraries

To actually use RDMA in Azure storage (enabling the fulfillment of the "high-performance" requirement), the team built two libraries: _sU-RDMA_, and _sK-RDMA_. Both of the libraries implement highly optimized usage of the basic RDMA features, for example using a "credit-based flow control" that allows usage of remote memory, while tracking how much memory is being transferred.

_sU-RDMA_ was designed to run in user-space code and, "is used for storage backend (storage to storage) communication". Its focus is providing an abstraction of basic RDMA commands (TODO basic RDMA commands) - for example, implementing a high-performance, general replication function for data between nodes in the system. The library also includes functionality targeted at graceful degradation, and is capable of sending RDMA messages over TCP, rather than the RoCE, if needed.

TODO figure 4

_sK-RDMA_ runs in the kernel on machines where applications are. It provides functionality like surfacing disk reads/writes - when an application issues one of these operations, the instruction is actually forwarded in the kernel to Azure storage, rather than a physically attached disk.

TODO figure 5

### RDMA Extended Statistics (Estats)

To assist in debuggability and observability into the distributed storage system, the implementers created _RDMA Estats_{% sidenote 'estats' "TODO where this name comes from"%}. The authors describe existing tools, but said they didn't fill the requirements.

Estats basically measures timing information at different points in the network (specifically, the sender, receiver, and networking hardware). It does this by keeping track of:

> a fine-grained breakdown of latency for each RDMA operation, in addition to collecting regular counters such as bytes sent/received and number of NACKs.

Each component of the system is integrated with this tool, allowing analysis of how long different steps are taking. Interestingly, the system relies on clock synchronization to make sure that things like latency (differences between two timestamps) is accurate.

### Software for Opening Networking in the Cloud (SONiC)

To handle the different types of switches from many different vendors, the team built an abstraction they called SONiC. It aims to drive a standardization of the switch software stack so that switches are more configurable and can integrate with the RDMA setup well. TODO describe SONiC consortium?

Standardization of the core components of switches allowed for two types of tests to run on a recurring basis: _software-based tests_ and _hardware-based tests_. The _software-based tests_ allow testing of things like packet-forwarding behave handled by software. Previously, this was difficult to test because devices didn't have a system they could just start using. _Hardware-based tests_ intend to test the hardware itself, useful for high performance behavior or things that are predominantly dependent on the actual hardware. These test cases are also open source! https://github.com/sonic-net/sonic-mgmt/

### Congestion Control

Congestion control often happens when networking hardware is overloaded (like switches). One situation in which this happens is when a switch has too many packets in its queue. TODO ref.

By default, an approach called _priority-based flow control (PFC)_ is used in many networks TODO link PFC. PFC starts working when a switch detects that it has too many packets in its buffer.

TODO screenshot from talk

For RDMA, relying on PFC has the opportunity to introduce substantial latency that is unacceptable on the read/write path for IO. It could also lead to potential packet loss, which doesn't work for RDMA application for TODO reasons. A major downside of PFC is that it is port-based, not flow-based, meaning that multiple flows flowing through the same port can be unintentionally impacted if there is some congestion event.

Instead, the system augments PFC with another approach called DCQCN. DCQCN works by relying on ECN (TODO link ECN), which relies on a sender, congestion point, and notification point (destination). When a switch registers that a packet is causing congestion, it marks it with an ECN signal (TODO reference ECN). Then, the destination can provide feedback to the original sender via congestion notification packets (CNP). ECN is supported on most networking hardware, so building an algorithm that uses it was possible.

Unfortunately, not all devices implement it the same way, and these differences can lead to performanace impact (for example, limiting some flows when they shouldn't be). To fund these sitatuations, they are able to use automated tests mentioned earlier.

DCQCN also has some parameters that can be tuned, and they did this. This seems like a large area of operational complexity going forward, as the parameters are dependent on the networking configuration.

## How is the research evaluated?

The research is evaluated to understand the performance benefits of deploying RDMA. Specifically, they consider _CPU usage in absence of RDMA_, _message completion times_, _average CPU usage per operation_, and _operation latency_.

First, the authors compare the CPU usage across storage servers with RDMA on, compare to a TCP-based storage implementation. The data indicates that RDMA operates at 80% of the CPU usage of a TCP-based implementation.

TODO figure 7

RDMA also leads to lower message completion times (mapping to faster processing of device IO).

TODO figure 8

When comparing a TCP-based implementation of Azure storage to the RDMA one, the RDMA implementation consumes significantly less CPU for both reads and writes.

TODO figure 9

Lastly, user-facing IO latency is significantly reduced for an RDMA implementation of storage, with the most dramatic impact to large reads and writes.

TODO figure 10

## Conclusion

This paper builds on several previous published works by the authors (TODO reference those), as well as foundational research outside of Microsoft. It talks about making tradeoffs in order to get RDMA into production (for example, not using fancy hardware) that remind me of the Clos topologies paper. To me, the most interesting part was the networking components, as they were able to leverage a system that was inspired by DCTCP (congestion control is an interesting area of research). I'd be interested to hear more about why they chose to make some decisions (like DCQCN instead of TIMELY or another RTT-based solution) - that was mentioned in the DCQCN paper, but is just presented as final here. Overall an interesting paper!