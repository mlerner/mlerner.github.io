---
layout: post
title: "The Demikernel Datapath OS Architecture for Microsecond-scale Datacenter Systems"
hn: "https://news.ycombinator.com/item?id=29237007"
categories:
---

_The papers over the next few weeks will be from [SOSP](https://sosp2021.mpi-sws.org/). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions about papers to read! These paper reviews can [be delivered weekly to your inbox](https://newsletter.micahlerner.com/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml)._  

[The Demikernel Datapath OS Architecture for Microsecond-scale Datacenter Systems](https://dl.acm.org/doi/10.1145/3477132.3483569)

This week's paper is _The Demikernel Datapath OS Architecture for Microsecond-scale Datacenter Systems_.  Demikernel{% sidenote 'pwl' "Irene Zhang, the paper's first author, also gave a talk at [Papers We Love](https://www.youtube.com/watch?v=4LFL0_12cK4)!" %} is an operating systems architecture designed for an age in which IO devices and network speeds are improving faster than CPUs are{% sidenote 'killerms' 'The "Attack of the Killer Microseconds" describes this problem area, and is available on the [ACM website](https://cacm.acm.org/magazines/2017/4/215032-attack-of-the-killer-microseconds/fulltext).'%}. The code is [open source](https://github.com/demikernel/demikernel) and predominantly implemented in Rust. 

One approach to addressing the growing disconnect between IO and CPU speeds is a technique called _kernel-bypass_. Kernel-bypass allows more direct access to devices by moving functionality typically inside of an OS kernel to user space{% sidenote 'userspace' 'Helpful reference on the difference between kernel space and user space is [here](https://unix.stackexchange.com/questions/87625/what-is-difference-between-user-space-and-kernel-space).'%} or offloading features to the device itself. Executing operating system functionality inside user space provides several latency-related advantages, like reducing costly userspace to kernel space transitions{% sidenote 'overhead' "The [Cloudflare blog](https://blog.cloudflare.com/kernel-bypass/) provides more details on this topic."%} and allowing applications to limit memory copies during IO (known as "zero copy IO" - more details later in this paper review). 

While kernel bypass systems are becoming ubiquitous and can enable dramatic speedups for applications (in particular, those in cloud environments), there are challenges to adoption - engineering resources must be used to port applications to this new architecture and new device APIs or versions can incur ongoing maintenance costs.

Demikernel aims to solve the tension between the utility of kernel-bypass and the engineering challenges that limit the technique's adoption - one key to its approach is providing abstractions that applications migrating to kernel-bypass can use.

## What are the paper's contributions?

The Demikernel paper makes three contributions: a new operating system API for developing kernel-bypass applications, the design for an operating system architecture that uses the new API, and several implementations of operating systems that implement the design using the API proposed by the paper.

## Demikernel approach

There are three main goals of Demikernel:

- Make it easier for engineers to adopt kernel-bypass technology
- Allow applications that use Demikernel to run across many different devices and in cloud environments
- Enable systems to achieve the ultra-low (nanosecond) IO latency required in the "Age of the killer microseconds"

First, Demikernel aims to simplify usage of kernel-bypass technology by building reusable components that can be swapped in (or out) depending on the needs of an application. Before Demikernel, kernel-bypass applications would often re-implement traditional operating system features inside of user space, one example being the network stack. Two new abstractions in Demikernel, _PDPIX_ and _libOS_, are targeted at encapsulating these common user space features in easy to use APIs, limiting the amount of time that developers spend reimplementing existing logic.

Next, Demikernel aims to allow kernel-bypass applications to run across many different devices and environments (including cloud providers). The system focuses on IO, but Demikernel still runs alongside a host kernel performing other OS functions outside of the datapath. 

Lastly, achieving ultra-low IO latency in the "Age of the Killer Microseconds" requires more advanced techniques that pose their own complexities. One example of these advanced technique is zero-copy IO{% sidenote 'zcio' "For more on zero-copy IO, I had the chance to dig into the topic in a previous paper review of [Breakfast of Champions: Towards Zero-Copy Serialization with NIC Scatter-Gather](/2021/07/07/breakfast-of-champions-towards-zero-copy-serialization-with-nic-scatter-gather.html)!"%}, which ensures that information on the data path is not copied (as unnecessary copies incur latency). Implementing zero-copy IO is complicated by different devices implementing different abstractions around the memory used in zero-copy IO{% sidenote 'zciodiff' "For example, some kernel-bypass devices (like RDMA) require 'registration' of memory used for zero-copy IO through specific API calls - more on this topic in a later section." %}.

To achieve these design goals, Demikernel implements two concepts: a _portable datapath interface (PDPIX)_ and a set of _library operating systems (libOSes)_ built with this API. 

## Portable Datapath API (PDPIX)

The _portable datapath interface (PDPIX)_ aims to provide a similar set of functionality to POSIX system calls, but reworks the POSIX systems calls to satisfy the needs of low-latency IO.

In contrast to the POSIX API:

- PDPIX replaces the file descriptor{% sidenote 'fd' "[What are file descriptors?](https://stackoverflow.com/questions/5256599/what-are-file-descriptors-explained-in-simple-terms)"%} abstraction used in POSIX with IO queues - applications `create` queues, then `push` data to or `pop` data from the queue, finally calling `close` to destroy the queue.
- PDPIX implements semantics that allow zero-copy IO (as zero-copy is crucial for low-latency IO). In one example, API calls that push data to a given queue provide access to arrays in a shared heap. The data in the shared heap can be read by the device in the kernel-bypass system immediately, without requiring an unnecessary copy into kernel space. 
- PDPIX explicitly is designed around asynchronous IO operations{% sidenote "epoll" 'While Linux has [epoll](https://linux.die.net/man/4/epoll), the paper notes two shortcomings: "epoll: (1) wait directly returns the data from the operation so the application can begin processing immediately, and (2) assuming each application worker waits on a separate qtoken, wait wakes only one worker on each I/O completion.
"'%}. API calls, like `push` and `pop`, return a `qtoken`. Applications can call `wait`  (or `wait_all` for a set of qtokens) to block further execution until an operation has completed.

{% maincolumn 'assets/demikernel/syscalls.png' '' %}

## Library Operating System (libOS)

Demikernel implements the idea of library operating systems (each implementation is called a _libOS_) to abstract an application's use of a kernel-bypass device - there are multiple types of devices used by kernel-bypass sytems, and using a different type of device involves potentially moving different parts of the operating system stack into user space. Each _libOS_ takes advantage of the _PDPIX_ API discussed in the previous section.

The paper discusses _libOS_ implementatations for several different types of IO devices, but this paper review focuses on two: 

- _Remote Direct Memory Access (RDMA)_, which allows computers to directly access the memory of other computers (for example, in a datacenter), without interfering with the processing on the other computer. RDMA is commonly used in data center networks{% sidenote 'rdma' "See research from [Microsoft](https://dl.acm.org/doi/10.1145/2829988.2787484) and [Google](https://dl.acm.org/doi/10.1145/2829988.2787510). Also, [this article](https://blogs.nvidia.com/blog/2020/04/29/what-is-rdma/) about RDMA from Nvidia's blog."%} - 
- _Data Plane Development Kit (DPDK)_: the goal of DPDK devices is high-performance processing TCP packets in user space, rather than in kernel space (the [Microsoft Azure docs](https://docs.microsoft.com/en-us/azure/virtual-network/setup-dpdk) provide additional context).

While RDMA and DPDK are both targeted at networking applications, devices that support the two approaches don't implement the same capabilities on the device itself - for example, RDMA devices support features like congestion control and reliable delivery of messages{% sidenote 'congestion control' "See [Congestion Control for Large-Scale RDMA Deployments](https://conferences.sigcomm.org/sigcomm/2015/pdf/papers/p523.pdf)"%}, while DPDK devices may not. 

Because RDMA and DPDK devices don't natively support the same functionality on the device, kernel-bypass applications that aim to use these devices are limited to what logic they can run on the device versus in user space. To make this more concrete - if an application wanted to use DPDK instead of RDMA, it would need to implement _more_ functionality in code, placing a greater burden on the application developer. 

{% maincolumn 'assets/demikernel/libos.png' '' %}

There are three main components to the libOS implementations: _IO processing_, _memory management_, and a _coroutine scheduler_.

The _libOS_ implemenations are in Rust and uses `unsafe` code{% sidenote 'rudra' "Related to my [last paper review on Rudra](/2021/10/31/rudra-finding-memory-safety-bugs-in-rust-at-the-ecosystem-scale.html), which aims to analyze `unsafe` code for security issues!"%} to call C/C++ libraries for the various devices 

Each _libOS_ processes IOs with an "error free fast path" that makes various assumptions{% sidenote 'assumptions' 'For example "packets arrive in order, send windows are open ... which is the common case in the datacenter".'%} based on the goal of optimizing for conditions in a datacenter{% sidenote 'homa' "It is very interesting to see how diffferent papers implement systems using this assumption - see my [previous paper review on Homa](2021/08/15/a-linux-kernel-implementation-of-the-homa-transport-protocol.html), a transport protocol that aims to replace TCP/IP in the datacenter."%} (where kernel-bypass applications are normally deployed). The _libOS_ has a main thread that handles this "fast path" by polling for IOs to operate on{% sidenote 'homa2' "The paper notes that polling is CPU intensive but ensures that events are processed quickly (a similar type of tradeoff is made by [Homa](/2021/08/29/a-linux-kernel-implementation-of-the-homa-transport-protocol.html))."%}.

{% maincolumn 'assets/demikernel/dpdk.png' '' %}

To manage memory (and facilitate zero-copy IO), the _libOS_ uses a "uses a device-specific, modified Hoard for memory management." [Hoard](https://github.com/emeryberger/Hoard) is a memory allocator that is much faster than `malloc`{% sidenote 'hoard' "An interesting comparison of Hoard with other memory allocators is [here](http://ithare.com/testing-memory-allocators-ptmalloc2-tcmalloc-hoard-jemalloc-while-trying-to-simulate-real-world-loads/)."%}. The original Hoard paper is [here](https://www.cs.utexas.edu/users/mckinley/papers/asplos-2000.pdf) and discusses the reasons for Hoard's performance (although the official documentation that the project has changed significantly since the original implementation). Each memory allocator must be device-specific because devices have different strategies for managing the memory available on the device itself - as an example, RDMA devices use "memory registration" that "takes a memory buffer and prepare it to be used for local and/or remote access."{% sidenote 'rdmamr' "[Ref](https://www.rdmamojo.com/2012/09/07/ibv_reg_mr/#Why_is_a_MR_good_for_anyway)"%}, while DPDK uses a "mempool library" that allocates fixed-sized objects{% sidenote 'mempool' "[Ref](https://doc.dpdk.org/guides/prog_guide/mempool_lib.html)"%}. To ensure that user-after-free{% sidenote 'uaf' "Use-after-free (abbreviated to UAF) vulnerabilities are [quite serious](https://cwe.mitre.org/data/definitions/416.html)!"%} vulnerabilities do not occur, each libOS implements reference counting{% sidenote 'refcount' "[Here](https://stackoverflow.com/questions/45080117/what-is-reference-counter-and-how-does-it-work) is a helpful description of what reference counting is."%}.

Each _libOS_ uses "Rust’s async/await language features to implement asynchronous I/O processing within coroutines"{% sidenote 'coroutines' "The paper notes that Rust async/await and coroutines are in active development. I am far from an expert on Rust, so this [RFC](https://github.com/rust-lang/rfcs/pull/2033), [design overview](https://lang-team.rust-lang.org/design_notes/general_coroutines.html), and [episode from Crust of Rust](https://www.youtube.com/watch?v=ThjvMReOXYM) were helpful background."%}. 

Coroutines are run with a _coroutine scheduler_ that runs three coroutine types:

> (1) a fast-path I/O processing coroutine for each I/O stack that polls for I/O and performs fast-path I/O processing, (2) several background coroutines for other I/O stack work (e.g., managing TCP send windows), and (3) one application coroutine per blocked qtoken, which runs an application worker to process a single request.

The details of the scheduler implementation are fascinating and I highly recommend referencing the paper for more info, as the paper discusses how it achieves the performance needed to meet the nanosecond-level design goal of Demikernel - one interesting trick is [using](https://github.com/demikernel/catnip/blob/59195aa4db5dd145683acda86bc929fc5741afd0/src/collections/async_slab.rs#L15) [Lemire's algorithm](https://lemire.me/blog/2018/02/21/iterating-over-set-bits-quickly/).

### Library Operating System (libOS) implementations

The paper describes several library operating system implementations{% sidenote 'cat' "The names of which (Catpaw, Catnap, Catmint, Catnip, and Cattree) indicate that the authors might be cat people 🙂!" %} that implement interfaces used for testing (providing the PDPIX API, but using the POSIX API under the hood), RDMA, DPDK, or the Storage Performance Developer Kit (SPDK){% sidenote 'spdk' "[SPDK](https://www.intel.com/content/www/us/en/developer/articles/tool/introduction-to-the-storage-performance-development-kit-spdk.html) is a kernel-bypass framework for storage devices."%}. Each _libOS_ is paired with a host operating system (Windows or Linux), and uses the host operating system's kernel-bypass interfaces. The paper does an amazing job of giving the implementation details of each libOS, for more detail please see the paper!

## Evaluation

The paper evaluates Demikernel on how well it achieves the three design goals described in an earlier section of this paper review. 

To evaluate the ease of use and complexity for applications that adopt Demikernel, the paper compares lines of code for a number of different applications that use the POSIX or Demikernel APIs. The authors also note the time it takes to port existing applications to Demikernel, noting that developers commented on Demikernel being the easiest interface to use.

{% maincolumn 'assets/demikernel/loc.png' '' %}

The paper evaluates whether Demikernel achieves nanosecond scale IO processing for storage and networking applications across a number of platforms.

{% maincolumn 'assets/demikernel/echo-linux.png' '' %}
{% maincolumn 'assets/demikernel/echo-win.png' '' %}

## Conclusion

The most recent paper on Demikernel is the culmination of a large body of work from the authors focused on high-performacnce IO. I'm very excited to follow how Demikernel (or similar systems built on top of the ideas) are adopted across industry - in particular, I am looking forward to hearing more about the developer experience of porting applications to the paradigm that the paper outlines.

Thanks for reading - as always, feel free to reach out with feedback on [Twitter](https://twitter.com/micahlerner)!