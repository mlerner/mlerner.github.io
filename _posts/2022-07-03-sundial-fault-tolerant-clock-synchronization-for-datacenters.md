---
layout: post
title: "Sundial: Fault-tolerant Clock Synchronization for Datacenters"
categories:
---

[Sundial: Fault-tolerant Clock Synchronization for Datacenters](https://www.usenix.org/conference/osdi20/presentation/li-yuliang)

## What is the research?

The Sundial paper describes a system for clock synchronization, an approach to building a view of time across many machines in a data center environment. Time is critical to distributed systems, as many applications rely on an accurate time to make decisions - for example, some distributed databases use time to determine when it is safe to commit transactions{% sidenote 'spannercommit' "In particular, this idea is used by [Spanner](https://research.google/pubs/pub39966/). There is a great overview of Spanner from the [MIT distributed system's course](https://www.youtube.com/watch?v=ZulDvY429B8&feature=youtu.be), and useful summaries by Timilehin Adeniran [here](https://timilearning.com/posts/mit-6.824/lecture-13-spanner/) and [Murat Demirbas](http://muratbuffalo.blogspot.com/2013/07/spanner-googles-globally-distributed_4.html)."%}. Furthermore, fast and accurate time enables new applications in data center environments, like basing congestion control algorithms on one way delay{% sidenote 'swift' "The paper cites [Swift: Delay is Simple and Effective for Congestion Control in
the Datacenter](https://dl.acm.org/doi/pdf/10.1145/3387514.3406591), which I hope to read in a future paper review."%}.

Unfortunately, building a view of time across many machines is a difficult problem. Clock synchronization, the approach described by the Sundial paper, involves reconciling many individual data points from disparate computers{% sidenote 'time' "Accurate time at even a single computer / location is also [a difficult problem](https://www.inverse.com/science/redefining-a-second-atomic-clock)!"%}. Implementing systems not only need to build distributed-system-like logic for communication, but also have to handle the failure modes of clocks themselves (including measurement drift due to factors like temperature changes).

Other systems have tackled clock synchronization (in particular TrueTime), and the Sundial paper aims to build on them. In particular, one design choice that the paper reuses is not providing a single global measurement of time. Instead, the machines in the system maintain a time and an associated error bound, which grows and shrinks according to several factors (like how recently the node has synchronized its time with others). In other ways, Sundial differs from prior research - specifically, the system described by the paper prioritizes detection and recovery from failures. As a result, it provides more accurate and resilient time measurements, improving application performance and enabling applications that require time{% sidenote 'distributedtracing' "While I mentioned that accurate time is useful for congestion control, applications like distributed tracing also benefit - being able to line up events across a system relies on a shared understanding of how they relate to one another. "%}.

## Background

Fast and accurate time measurements are an important problem to solve for datacenter environments, for which there are several existing solutions{% sidenote 'existing' "Existing solutions include [HUYGENS](https://www.usenix.org/system/files/conference/nsdi18/nsdi18-geng.pdf), [Datacenter Time Protocol](https://dl.acm.org/doi/10.1145/2934872.2934885) (DTP), and [Precision Time Protocol](https://standards.ieee.org/ieee/1588/4355/) (PTP)." %}.

{% maincolumn 'assets/sundial/table1.png' '' %}

Each implementation makes tradeoffs around:

- _Type of clocks used_: do you use few expensive clocks or many commodity clocks?
- _Overhead of clock synchronization_: which networking layer does clock synchronization happen on? Hardware support allows lower overhead networking communication, but can require custom devices (which increases the difficulty of implementation).
- _Frequency of clock synchronization_: how often do nodes in the system synchronize their clocks? Clock synchronization consumes networking resources, but the frequency of synchronization determines how much clocks drift from one another.
- _Which nodes communicate with one another_: should nodes communicate in a tree or a mesh? Asynchronously or synchronously? This decision also balances networking overhead with clock error.

Deciding the _type of clocks used_ comes down to choosing between cost and clock accuracy. On one end of the spectrum, a system can have expensive and accurate clocks in a network, then connect computers to those sources of truth{% sidenote 'truetime' "[This post from Kevin Sookocheff](https://www.allaboutcircuits.com/news/precise-time-keeping-crystal-oscillator-atomic-clock-quantum-clock/) is a handy overview for TrueTime." %}. Another approach is to have many commodity datacenter clocks that synchronize with each other to get a global view of time{% sidenote 'graham' "[Graham: Synchronizing Clocks by Leveraging Local Clock Properties](https://www.usenix.org/system/files/nsdi22-paper-najafi_1.pdf) is a paper along these lines that I hope to cover in a future paper review."%} - clocks in these types of systems often use crystal oscillators{% sidenote 'crystal' "[This reference](https://www.allaboutcircuits.com/news/precise-time-keeping-crystal-oscillator-atomic-clock-quantum-clock/) talks about the difference between crystal oscillators and more expensive/accurate clocks."%} which can drift for a variety of reasons, including "factors such as temperature changes, voltage changes, or aging".

To limit error in time measurements, the clocks periodically sync with one another by transmitting messages on the network.

{% maincolumn 'assets/sundial/figure1.png' '' %}

This communication contributes to the _overhead of clock synchronization_. Sending messages on different levels of the network{% sidenote 'network' "From the [OSI model](https://www.cloudflare.com/learning/ddos/glossary/open-systems-interconnection-model-osi/)."%} incurs different overheads, and can also require specialized hardware. For example, one predecessor to Sundial ([Datacenter Time Protocol](https://dl.acm.org/doi/10.1145/2934872.2934885)), relies on hardware support (which could be a blocker to adoption). At the same time, Datacenter Time Protocol is able to send messages with zero overhead by making use of special hardware. In contrast, other clock synchronization implementations send messages at higher levels of the network stack, limiting reliance on custom hardware, but incurring higher overheads.

Another set of tradeoffs is deciding the _frequency of clock synchronization_ - more frequent messaging places a bound on how much clocks can drift from one another, increasing accuracy at the cost of networking overhead. This decision also contributes to how fast a node is able to detect failure upstream - assuming that a node fails over to using a different upstream machine after not receiving _n_ messages, longer intervals between each synchronization message will contribute to a longer time for the node to react.

{% maincolumn 'assets/sundial/figure3.png' '' %}

A clock synchronization implementation also needs to decide _which nodes comunicate with each other_, and whether there is a single "primary" time that must propagate through the system. Communication can happen through several different structures, including mesh or tree{% sidenote 'spanning' "The paper talks about using a spanning tree - it is always fun to see content from a datastructures course pop up in research."%} topologies. Furthermore, nodes in the network can communicately synchronously or asynchrously, potentially blocking on receiving updates from upstream nodes.

{% maincolumn 'assets/sundial/figure15.png' '' %}

## What are the paper's contributions?

The paper makes three main contributions:

- The design of a system capable of quickly detecting and recovering from clock synchronization failures (leading to time measurement errors).
- Implementation of the design, including details of novel algorithms associated with failure recovery.
- Evaluation of the system relative to existing clock synchronization approaches.

## How does the system work?

Based on a study of previous systems, Sundial establishes two design requirements: a _small sync interval_ (to limit error in time measurements), and _fast failure recovery_ (to ensure minimal interruption to clock synchronization when failure occurs).

The _small sync interval_ ensures that a machine sends out synchronization messages periodically and is able to detect when it hasn't received communication from upstream nodes. To keep track of the interval, the design relies on a periodically incrementing counter in custom hardware (discussed in more detail in the _Sundial Hardware_ section). While implementing such a counter is possible in software, doing so was likely to consume significant CPU. Building a counter in hardware offloads this functionality to a component dedicated for the function.

Each node in a Sundial deployment contains a combination of this specialized hardware and software to handle several situations:  _sending synchronization messages_, _receiving synchronization messages_, and _responding to failures_.

{% maincolumn 'assets/sundial/figure6.png' '' %}

Nodes determine how to _send and receive synchronization messages_ based on a netowrk represented via a spanning tree, and a node's position in the tree (root or non-root) determines its behavior. Synchronization messages flow through the network from root nodes downwards, and when downstream nodes detect that upstream nodes are not sending these messages, the network reconfigures itself to exclude the failing machines.

{% maincolumn 'assets/sundial/figure7.png' '' %}

### Sundial Hardware

The Sundial Hardware is active in _sending synchronization messages_, _receiving synchronization messages_, and _responding to failures_.

As mentioned above, synchronization messages flow through the tree from root nodes to non-root nodes. Root nodes send messages periodically, using a continuously incrementing interal counter. After the counter reaches a threshold, the root sends synchronization messages downstream.

When a node{% sidenote 'root' "Root nodes don't receive from other nodes."%} receives a synchronization message, it processes the incoming message (updating its clock and error), resets the timeout used to detect failure in upstream nodes, then sends synchronization messages to its own downstream nodes.

If a node doesn't receive a synchronization message before several _sync intervals_{% sidenote 'syncinterval' "Each sync interval is defined by a configurable time period associated with ticks of the hardware counter." %} pass{% sidenote 'sync' 'From the paper, "The timeout is set to span multiple sync-intervals, such that occasional message drop or corruption doesn’t trigger it."'%} (as measured by the hardware counter), the hardware will trigger an interrupt to prompt failure recovery by the software component of Sundial (handling this situation is discussed in more detail in the next section).

### Sundial Software

The Sundial software has two primary responsibilities: _handling failure recovery when it is detected by hardware_, and _pre-calculating a backup plan_.

Sundial hardware triggers an interrupt to signal failure when an upstream node stops sending synchronization messages. To recover from failure, a machine follows a backup plan that is computed and distributed to nodes by a central component of Sundial, called the _Centralized Controller_. The backup plan includes information on which node(s) to treat as the upstream and/or downstream nodes.

To ensure that failure recovery succeeds, the _Centralized Controller_ constructs the backup plan{% sidenote 'backupplan' "The paper also describes the details of several subalgorithms involved in calculating the plan, and I highly encourage those interested to reference those very interesting details (which take advantage of several graph/tree algorithms)."%} following several invariants:

- _No-loop condition_: nodes in a subtree must connect to nodes outside of the subtree, otherwise there is no guarantee that the backup plan will connect the subtree to the root node. If the subtree is not connected to the root node, then synchronization messages will not flow.

{% maincolumn 'assets/sundial/figure8.png' '' %}

- _No-ancestor condition_: a node can't use its ancestor as a backup because the downstream node won't be connected to the tree if the ancestor fails.
- _Reachability condition_: the backup plan contains a backup root in case the root fails, and the backup root must have a path to all nodes (otherwise synchronization messages won't fully propagate).
- _Disjoint-failure-domain condition_: a node's backup can't be impacted by the same failures as the given node, unless the given node *also* goes down (this stops a node from being isolated).
- _Root failure detection_: when the root fails, a backup root should be able to be elected (so that recovery is possible).

{% maincolumn 'assets/sundial/figure9.png' '' %}

The paper points at several potential issues with a precomputed backup plan - one of which is the idea of concurrent failures that the backup plan hasn't anticipated. In this situation, error grows large but the controller can still recover due to the _Disjoint-failure-domain condition_.

{% maincolumn 'assets/sundial/figure11.png' '' %}

## How is the research evaluated?

The Sundial paper contains an evaluation on several metrics. First, the paper compares Sundial to other existing implementations of clock synchronization in both non-failure conditions and failure conditions.

In non-failure conditions, Sundial has the lowest error because it is able to maintain a small sync interval and synchronize clocks in the network quickly.

{% maincolumn 'assets/sundial/figure18.png' '' %}

In failure conditions, Sundial has fast failure recovery, resulting in the lowest error increases in abnormal conditions (as visible from the lower overall error and small sawtooth pattern in the graph below).

{% maincolumn 'assets/sundial/figure19.png' '' %}

The paper also evaluates the implementation's impact on applications. As mentioned at the beginning of the paper, more accurate clock synchronization confers several advantages. The paper evaluates this claim by including commit-wait{% sidenote 'spannertxn' "Timilehin Adeniran's [article on Spanner](https://timilearning.com/posts/mit-6.824/lecture-13-spanner/#commit-wait) covers the idea of commit wait."%} latency for Spanner - when the database decides to commit a transaction, it waits until a time after the error bound. Thus, reducing the error bound allows Spanner to commit earlier, an affect visible in the latency of a load test that relies on the database.

{% maincolumn 'assets/sundial/table2.png' '' %}

## Conclusion

The Sundial paper is one of several papers I've been reading about time and clock synchronization. In particular, one of the components of the research I enjoyed was its deep dive on the constraints and algorithm internals associated with building a backup plan - it is always intriguing to see how simple data structures represent the core of solutions to complex problems. I also enjoyed the paper's description of where Sundial is in the design space of the problems it is trying to address. This type of in-depth discussion is often left to the reader, and it is refreshing to see it spelled out explicitly.