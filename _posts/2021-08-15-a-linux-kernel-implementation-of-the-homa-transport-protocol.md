---
layout: post
title: "Homa: A Receiver-Driven Low-Latency Transport Protocol Using Network Priorities, Part I"
categories:
---
_Over the next few weeks I will be reading papers from [Usenix ATC](https://www.usenix.org/conference/atc21) and [OSDI](https://www.usenix.org/conference/osdi21) - as always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions about papers to read! These weekly paper reviews can [be delivered weekly to your inbox](https://tinyletter.com/micahlerner/), or you can subscribe to the new [Atom feed](https://www.micahlerner.com/feed.xml)._

[Homa: A Receiver-Driven Low-Latency Transport Protocol Using Network Priorities](https://people.csail.mit.edu/alizadeh/papers/homa-sigcomm18.pdf), Montazeri et al., SIGCOMM 2018

{% discussion 'https://news.ycombinator.com/item?id=28204808' %}

This week's paper review is part one of a two-part series on the same research topic - _Homa_, a transport protocol purpose-built to replace TCP for low-latency RPC inside the modern data center{% sidenote 'kurose' "If you are interested in learning more about networking, I can't recommend the Kurose & Ross book enough. Although it isn't free, there _is_ a large amount of course content (like videos), on [their site](https://gaia.cs.umass.edu/kurose_ross/online_lectures.htm)."%}. 

Specifically, _Homa_ aims to replace TCP, which was designed in the era before modern data center environments existed. Consequently, TCP doesn't take into account the unique properties of data center networks (like high-speed, high-reliability, and low-latency). Furthermore, the nature of RPC traffic is different - RPC communication in a data center often involve enormous amounts of small messages and communication between many different machines. TCP is non-ideal for this type of communication for several reasons - for example, it is designed to ensure reliable transmission of packets (under the assumption that the networks are not reliable), and is a connection-oriented protocol that requires state (meaning that operating many connections at once has a high overhead). The difference between the design goals of TCP and the nature of the data center leads to non-optimal performance under load, which shows up as tail latency{% sidenote 'tail' "For more on tail latency, I'd recommend reading [The Tail at Scale](https://cacm.acm.org/magazines/2013/2/160173-the-tail-at-scale/fulltext) - there are also several great reviews of the paper ([The Morning Paper](https://blog.acolyer.org/2015/01/15/the-tail-at-scale/), [Sid Shanker's blog](https://squidarth.com/article/systems/2020/02/29/tail-at-scale.html), or [Vivek Haldar's video review](https://www.youtube.com/watch?v=1Qxnrf2pW10))."%}. To address this issue, researchers and industry created a number of solutions{% sidenote 'newtransport' 'The paper cites [DCTCP](https://dl.acm.org/doi/abs/10.1145/1851182.1851192), [pFabric](https://dl.acm.org/doi/abs/10.1145/2534169.2486031), [NDP](https://dl.acm.org/doi/abs/10.1145/3098822.3098825), and [pHost](https://dl.acm.org/doi/abs/10.1145/2716281.2836086).' %} purpose built for the data center, of which Homa was the newest.

I will be publishing this paper review in two parts. The first part gives an overview of the _Homa_ protocol, based on _Homa: A Receiver-Driven Low-Latency Transport Protocol Using Network Priorities_ from SIGCOMM 2018. This paper lays out the problems that the research area is trying to solve, designs a solution to those problems, and presents experimental results. The second paper, _A Linux Kernel Implementation of the Homa Transport Protocol_ was published at this year's USENIX ATC conference. It discusses the implementation (and challenges to implementing) Homa as a Linux Kernel module, with the goal of evaluating the protocol in a setting that is closer to a real production environment - this paper's conclusion also discusses the limits of the implementation and a few exciting potential directions for future research.

With that, let's dive into understanding Homa.

## The Homa protocol

### Background

As discussed above, the problem that _Homa_ is trying to solve is a disconnect between the design of TCP and the unique qualities of data center networks. This disconnect increases latency and overhead of RPC communications, meaning wasted data center resources. Thus, _Homa_ is designed with the goal of achieving the "lowest possible latency" for RPC (in particular focusing on small messages at "high network load").

To achieve this goal, _Homa_ must consider a primary source of latency in this type of network: _queuing delay_. Queuing delay occurs at routers in a network when more packets arrive than can be transmitted at once{% sidenote 'queue' "For an in depth discussion of delays, I recommend [this](https://archive.is/20130114163812/http://59.67.152.66:8000/newenglish/delay.htm) chapter from the Kurose and Ross networking book."%} (meaning that they need to wait in a queue). More queuing leads to more latency!

{% maincolumn 'assets/homa/delay.png' 'Queuing delay, sourced from [here](http://www.cs.toronto.edu/~marbach/COURSES/CSC358_F19/delay.pdf).' %}

To limit queuing, a design could aim to eliminate it entirely or could accept that queueing will happen (while aiming to minimize its negative impact). The paper mentions one system, [FastPass](http://fastpass.mit.edu/Fastpass-SIGCOMM14-Perry.pdf), that implements the first approach using a central scheduler that could theoretically optimally make packet-scheduling decisions. Unfortunately, interacting with the scheduler for every packet "triples the latency" for short messages.

If queuing is accepted as inherent to the network, the paper argues _in-network priorities_ must be used to provide finer grained control over how packets are queued{% sidenote 'pfabricq' 'The paper mentions that previous work demonstrates the positive impact of using these types of priorities.' %}. _In-network priorities_ allow a priority to be assigned to a packet, then for that packet to be assigned to a queue that contains only packets with that priority. This ensures that the highest priority packets are transmitted first and provides a degree of control over how different types of traffic is treated.

{% maincolumn 'assets/homa/priorityq.png' 'A depiction of a priority queue scheduling system sourced from [this](http://www2.ic.uff.br/~michael/kr1999/6-multimedia/6_06-scheduling_and_policing.htm) resource on packet scheduling.' %}

To determine the priority of a packet, _Homa_ uses a policy called _Shortest Remaining Processing Time first_ (SRPT), "which prioritizes packets from messages with the fewest bytes remaining to transmit". Another way of explaining SRPT is that it aims to schedule packets based on how close the RPC is to completing the transfer of its associated packets. If a packet is associated with an RPC request that has fewer packets left to transmit to a receiver, scheduling that packet first will allow the request to finish faster. The paper mentions that _SRPT_ is not only common in previous work (like [pFabric](https://dl.acm.org/doi/10.1145/2486001.2486031)), but is close to optimal in the conditions that one would see in a network under load.

Lastly, the paper discusses which parts of the system (client or receiver) should make decisions about the priority of a packet (by appling the SRPT policy) and when. The paper argues that receivers are well positioned to determine packet priorities - they know which clients are sending packets to them and could be configured to keep track of how much data each client has left to send. Even though receivers calculate packet priorities, clients also need to apply SRPT to the packets that they send out (if a client is sending multiple RPCs at once, the RPC that is closest to finishing should have its associated packets sent out first).

Receivers are also in a position to optimize packet priorities beyond applying the SRPT policy. An example of further optimization is a process called _overcommitting_, where the receiver instructs more than one sender to use the same priority at the same time to ensure full network utilization. As mentioned previously, a client might receive information about how to send out packets with optimal priorities, but might delay actually sending out the packets for some reason. One example of this is if a client is sending out multiple RPCs at once and the prioritized packets are delayed client-side while a different RPC is sent out. 

### Design and Implementation

Homa is implemented with the concerns above in mind, using receiver-driven priorities decided with the SRPT policy. To accomplish its goals, the system uses four packet types to send data, communicate priorities from receiver to sender, or signal metadata.

{% maincolumn 'assets/homa/packets.png' '' %}

When a client wants to send an RPC to a receiver, it sends an initial chunk and metadata that includes the total size of the message (which the receiver will use to track request completion). This chunk is given an _unscheduled_ priority (as seen in the system diagram below).

{% maincolumn 'assets/homa/protocol.png' '' %}

The receiver then applies the SRTP algorithm to decide the priority for the next set of packets associated with the given RPC, then communicates the priority back to the sender using a _GRANT_ packet. The _GRANT_ packet instructs the sender to send a configurable number of bytes (called _RTT Bytes_) before waiting for another grant. Once the sender receives this information, it sends packets using the _scheduled_ priority until it reaches the configured limit set via _RTT Bytes_ (the paper uses 10 KB, but mentions that this number will continue to grow as link speed increases).

Now that we understand the basics of Homa, it is interesting to contrast the protocol with TCP. Homa forgoes features of TCP (and other RPC systems) that increase overhead and latency: 

- _Explicit acknowledgements_: senders transmit many packets without requiring acknowledgement, occasionally waiting for feedback from the receiver (who provides feedback via _GRANT_ packets). This approach means fewer packets need to be transmitted as part of the protocol, meaning more bandwidth can be dedicated to transmitting packets that contain RPC data.
- _Connections_: Homa is connectionless, unlike TCP. Foregoing connections means that Homa does not need to maintain certain types of state, like TCP does. Lower state overhead means Homa is able to service many more RPCs than a TCP-based sender-receiver pair would. Relatedly, the state that Homa maintains is bounded by the RTT bytes configuration parameter - there is a limit to how much data will be transmitted by a sender before waiting for feedback (and a limit to associated data that a single RPC request will consume in the router's buffers).
- _At-most-once delivery semantics_: Other RPC protocols are designed to ensure at-most once-delivery of a complete message, but Homa targets _at-least-once_ semantics{% sidenote 'atmostonce' "While [this guide](https://www.lightbend.com/blog/how-akka-works-at-least-once-message-delivery) focuses on Akka, it is a helpful overview of the different messaging semantics." %}. This means that Homa can possibly re-execute RPC requests if there are failures in the network (and an RPC ends up being retried). While at-least-once semantics put a greater burden on the receiving system (which might have to make RPCs idempotent), relaxing the messaging semantics allows Homa receivers to adapt to failures that happen in a data center environment. As an example, Homa receivers can discard state if an RPC becomes inactive, which might happen if a client exceeds a deadline and retries.

## Conclusion

The original Homa paper discusses testing the protocol on a variety of workloads - the most recent paper on Homa (covered next week) includes a Linux-compatible implementation and aims to reproduce the evaluation of the protocol in a setting that is closer to one used in production. If you enjoyed this paper review, stay tuned for the next in the series!
