---
layout: post
title: "Breakfast of Champions: Towards Zero-Copy Serialization with NIC Scatter-Gather"
date: '2021-07-08 00:00:00Z'
categories:
---

_This week's paper is from HotOS 2021. Many of the HotOS papers (like this one) propose future directions for Operating Systems research, in addition to including prototypes (in contrast with other papers that focus on a single system's implementation). The full proceedings of the conference are [here](https://sigops.org/s/conferences/hotos/2021/) - as always, if there are any papers that stick out to you, feel free to reach out on [Twitter](https://twitter.com/micahlerner)_.

[Breakfast of Champions: Towards Zero-Copy Serialization with NIC Scatter-Gather](https://www.sigops.org/s/conferences/hotos/2021/papers/hotos21-s10-raghavan.pdf) Deepti Raghavan, Philip Levis, Matei Zaharia, Irene Zhang.

This paper (written by authors from Stanford and Microsoft Research) focuses on how to speed up data serialization associated with Remote Procedure Call (RPC){% sidenote 'rpc' "Martin Kleppman, the author of the amazing ['Designing Data-Intensive Applications'](https://dataintensive.net/) has a useful lecture on RPC [here](https://www.youtube.com/watch?v=S2osKiqQG9s)." %} systems in the datacenter. Normally, RPC systems are not focused on as a performance bottleneck, but the authors argue that that as we [enter the "microsecond era"](https://cacm.acm.org/magazines/2017/4/215032-attack-of-the-killer-microseconds/fulltext){%sidenote 'microsecond' "The microsecond era refers to a time when 'low-latency I/IO devices, ranging from faster datacenter networking to emerging non-volatile memories and accelerators' are used more widely in industry."%}, the performance of previously overlooked systems will standout.

RPC systems (like gRPC and Apache Thrift) are very popular, but incur overhead in the process of reading data from or writing data to the network. This overhead comes from "coalescing or flattening in-memory data structures" - taking application objects that may contain pointers to separate areas of memory and moving the associated data into a contiguous area of memory (so that the combined object can be sent over the network).

To limit (and possibly eliminate) this overhead, the authors suggest leveraging functions of commodity Network Interface Cards (NICs) with built in support for high performance computing primitives{% sidenote 'mellanox' 'The paper includes benchmarks from using a Mellanox NIC - see [here](https://www.nextplatform.com/2015/11/12/mellanox-turns-infiniband-switches-into-mpi-accelerators/) for a discussion of how Mellanox can accelerate MPI operations.' %}. The primitive focused on in the paper is scatter-gather{% sidenote 'scattergather' '[Specializing the network for scatter-gather workloads](https://people.inf.ethz.ch/asingla/papers/socc20-scattergather.pdf) describes a number of use cases for scatter-gather, for example: "Web services such as search engines often involve a user-facing server receiving a user request, and in turn, contact hundreds to thousands of back-end servers, e.g.,for queries across a distributed search index".' %}, which bears a strong resemblance to the function that the authors are trying to optimize:

> Scatter-gather was designed for high-performance computing, where applications frequently move large, statically-sized chunks of memory between servers.

Even though some NICs support scatter-gather, an extra step (called _kernel bypass_) must be taken to ensure that there are no memory copies made in the serialization/deserialization process. Kernel-bypass is used to build high-speed networking stacks, for example [at Cloudflare](https://blog.cloudflare.com/kernel-bypass/). The technique can make IO devices (like a NIC) available to user-space, ensuring that no unncessary memory movement in or out of the kernel occurs{% sidenote "kernelbypass" "[This video](https://www.youtube.com/watch?v=MpjlWt7fvrw) contains an in-depth explanation of kernel-bypass for high-speed networking. One of the authors of the paper (Irene Zhang), also has an interesting paper on a system that provides abstractions for kernel-bypass: [I’m Not Dead Yet! The Role of the Operating System in a Kernel-Bypass Era](https://irenezhang.net/papers/demikernel-hotos19.pdf)." %}. 

## What are the paper's contributions?

The paper makes three main contributions: it explores the sources of RPC serialization (and deserialization) overhead, proposes a solution to limiting that overhead, and outlines potential areas of research in the future to expand on the proposed approach.

## The Limits of Software Serialization

To explore performance issues with software serialization (_software_ serialization because no extra hardware, like an "accelerator" is used), the paper includes two experimental results.

{% maincolumn 'assets/breakfast/serialize_perf.png' '' %}

The first experiment shows the limits of different RPC serialization/deserialization implementations for a server that is deserializing and serializing a 1024 byte string message{% sidenote '1024' 'A simple string message was chosen because it is a can represent "the minimal overhead for serialization today."' %}(where the limit is the latency associated with a given throughput). Predominantly all of the implementations are grouped together on the performance graph, with three important gaps. 

First, Protobuf performs poorly relatively to the other RPC libraries (as it performs UTF-8 validation on the string message). 

The next gap is between DPDK{% sidenote 'dpdk' '[DPDK](https://doc.dpdk.org/guides/prog_guide/overview.html) stands for "Data Plane Development Kit", and is a software library that allows for NICs to be programmed from user-space, facilitating high speed networking through bypassing the kernel.'%} single core and the RPC libraries - the serialization libraries need to make copies when encoding to or decoding from a wire format (see graph below for a comparison between Protobuf and Cap'n Proto in this regard). These extra copies mean lower peak throughput.  main gap is between the serialization libraries (Protobuf/Protobytes/Cap'nproto/Flatbuffers) and DPDK (representing a kernel-bypass based system). In other words, the DPDK lines indicates what would be possible performance wise if serialization libraries could manipulate shared memory with the networking stack (which could be possible in a world where RPC libaries were integrated with a kernel-bypass library like DPDK).

{% maincolumn 'assets/breakfast/serialize.png' '' %}

The second experiment is included above - it shows how both Protobuf and Cap'n Proto incur copies when performing serialization/deserialization (and the time for each grow with the size of the message).

## Leveraging the NIC for Serialization

Before introducing the scatter-gather based implementation, the paper explores the performance of splitting up a payload into differently sized chunks. This experiment uses an echo server benchmark (where a client serializes a message and sends it to a server, which returns it to the client), with the results indicating that objects below a threshold size of 256 bytes do not benefit from a zero-copy scatter-gather approach. Dividing up a payload into smaller packets can hurt performance if the packets are too small relative to the overhead of the NIC building them (where the definition of "too small" varies with the model of NIC being used, a topic that will come up in the next section).

{% maincolumn 'assets/breakfast/scatter_gather_array.png' '' %}

To use a NIC's scatter-gather functionality to speed up serialization/deserialization, the paper implements a datastructure called a _ScatterGatherArray_ that contains a count of the number of entries, a list of pointers, and the size of each entry - "when applications call serialize, the library produces a scatter-gather array that can be passed to the networking stack instead of a single contiguous buffer". An associated header contains a bitmap of which fields in the _ScatterGatherArray_ are filled and metadata about the type of the field. When serializing an object, the "resulting wireformat is similar to [Cap’n Proto’s wireformat](https://capnproto.org/encoding.html)."

The paper additionally includes details of deserializing an object. I won't include full details on deserialization (as they are readily accessible in the paper), but there are several interesting features. For one, the paper discusses pros of a potentially different wire format where information on all fields is stored in the header (in contrast to the implementation which has a header that only includes metadata on a field if it is present) - if all fields are stored, the header would likely be larger, but deserialization could be constant time, rather than requiring a scan of all fields in the header. 

Most importantly, the prototype using NIC scatter-gather, kernel-bypass, the _ScatterGatherArray_, and the wireformat almost reach DPDK single-core performance benchmark from the first experiment outlined in "The Limits of Software Serialization_ above:

> The prototype implementation achieves about 9.15 Gbps (highest throughput measured under 15μs of tail latency). The prototype’s performance improves on all the serialization libraries and the 1-copy (”No Serialization”) baseline, but falls about 1.2 Gbps short of the optimal DPDK throughput.

## Open Research Challenges

There are four main research challenges associated with combining NIC scatter-gather with serialization libraries:

- _NIC support for scatter gather_: the costs of sending payloads using NIC scatter-gather aren't worth it if the payloads are below a threshold size. Can NICs be designed with this in mind?
- _Using scatter-gather efficiently_: Different application payloads may or may not work well with different NICs, as different NICs have different performance profiles with small or oddly sized payloads
- _Accessing Application Memory for Zero-Copy I/O_: Memory that is shared between the NIC and user-space must be pinned, meaning that large amounts of memory could be reserved for an application, but may never be used (or used rarely). Managing what memory is pinned, when it is pinned, and how it is allocated are all active areas of developement (with papers linked to by the authors), as a user of the approach wouldn't want to incur enormous overhead.
- _Providing Zero-Copy I/O with Memory Safety_: If the NIC and CPU are both interacting with memory concurrently, they will need a way to do so safely. Other challenges include implementing a way for deserialized responses to be reclaimed once an application is done using them (otherwise the response will stay in memory, which will eventually run out).

## Conclusion

Kernel-bypass and the microsecond era are leading to an exciting time in systems as researchers figure out how to rework existing and ensure high performance. Accelerators (and abstracting away the use of them) is an area I hope to cover more in the future. While this paper is a slight deviation from the types of papers that I've previously reviewed on this blog, I hope you enjoyed it - if you have feedback feel free to ping me on [Twitter](https://twitter.com/micahlerner). Until next time!