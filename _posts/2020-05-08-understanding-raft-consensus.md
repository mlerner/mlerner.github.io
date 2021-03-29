---
layout: post
title: "Understanding Raft Consensus  - Part 1"
tags: ["Distributed Systems"]
---

Recently I was digging deeper into [Raft](https://raft.github.io/), an important algorithm in the field of distributed systems. Raft is a __consensus algorithm__, meaning that it is designed to facilitate a set of computers agreeing on a state of the world (more on exactly how the state of the world is represented later), even when communications between the computers in the set are interrupted (say for example, by someone accidentally unplugging a network cable that connects some of the nodes to the majority). 

The problem of reliably storing a state of the world across many computers, keeping the state in sync, and scaling this functionality is required in a number of modern systems - for example, Kubernetes stores all cluster data in [etcd](https://kubernetes.io/docs/concepts/overview/components/#etcd), a key-value store library that uses Raft under the hood. 

Given how important (and nuanced) the algorithm is, I wanted to attempt to boil it down to its simplest possible components first, then followup with a deeper dive. 

It's worth noting that there are a wealth of resources about Raft. Some of my favorites are:
- A [video explanation of Raft](https://www.youtube-nocookie.com/embed/YbZ3zDzDnrw) created by the authors of the paper.
- A [visualization](http://thesecretlivesofdata.com/raft/) of how Raft works
- An excellent walkthrough of a Raft implementation (with documentation) by Eli Bendersky, [available here](https://eli.thegreenplace.net/2020/implementing-raft-part-0-introduction/).
- [Lab 2 from MIT's 6.824 course](https://pdos.csail.mit.edu/6.824/labs/lab-raft.html), which comes with a full test suite and guidance on how to implement the algorithm in manageable chunks.

## What's novel about Raft?
As mentioned above, Raft is an algorithm designed to help computers synchronize state through a process called __consensus__, although it was not the first system designed to do so. 

A main difference between Raft and previous consensus algorithms was the desire to optimize the design with simplicity in mind - a trait that the authors thought was missing from existing research. 

In particular, Raft aimed to improve on [Paxos](https://www.microsoft.com/en-us/research/uploads/prod/2016/12/paxos-simple-Copy.pdf), a groundbreaking but (the authors of Raft argue) somewhat complicated set of ideas for achieving distributed consensus.
 
To attempt to quantify the complexity of Paxos, the Raft authors conducted a survey at NSDI, one of the top conferences for distributed systems academics:
> In an informal survey of attendees at NSDI 2012, we found few people who were comfortable with Paxos, even among seasoned researchers. We struggled with Paxos ourselves; we were not able to understand the complete protocol until after reading several simplified explanations and designing our own alternative protocol, a process that took almost a year.

Other engineers also documented difficultes productionizing Paxos. Google implemented a system based off of Paxos called [Chubby](https://static.googleusercontent.com/media/research.google.com/en//archive/chubby-osdi06.pdf) and [documented the "algorithmic and engineering challenges ... encountered in moving Paxos from theory to practice](http://www.read.seas.harvard.edu/~kohler/class/08w-dsi/chandra07paxos.pdf). In their paper they note that, "Despite the existing literature on the subject [Paxos], building a production system turned out to be a non-trivial task for a variety of reasons". 

From the above commentary, it might seem that Paxos is a terribly complicated and near-impossible set of ideas to implement, although this isn't entirely true. Some have argued that Raft trades off understability for a performance hit, although it is unclear whether this is true given the latest [etcd benchmarks](https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/performance.md). For further reading on Paxos vs Raft, [this paper](https://arxiv.org/pdf/2004.05074.pdf) is an interesting read.

## At a high level, how does Raft work?

Now that we have some context about the _why?_ of Raft, there are a few high level points that are important to understand about Raft:
- **The purpose of the Raft algorithm** is to replicate a state of the world across a cluster of computers. Rather than sending single messages that contain the complete state of the world, Raft consensus involves a log of incremental changes, represented internally as an array of commands. A key value store can be used as a more concrete example of representing the state of world with in this way - the current state of the world in a KV store contains the keys and values for those keys, but each `put`, or `delete` is a single change that leads to that state. These individual changes can be stored in an append-only log format (the 2nd part of this series goes into more detail on how the log component of Raft works in the **Raft logs and replication** section).
- Raft peers communicate using **well-defined messages**. There are several defined in the original paper, but the two essential ones are:
	- **RequestVote**: a message used by Raft to elect a peer that coordinates updating the state of the world. More info in the **Leaders and leader election** section of Part 2.
	-  **AppendEntries**: a message used by Raft to allow peers to communicate about changes to the state of the world. More details of how the state is replicated in the **Raft logs and replication** section.
- **Members of a Raft cluster are called peers and can be in one of three states**:
	- __Leader:__ the node that coordinates other nodes in the cluster to update their state. All changes to the state of the world flow through the `Leader`.
	- __Candidate__: the node is vying to become a leader
	- __Follower__: the node is receiving instructions about how to update its state from a leader
- A __Leader__ manages updates to the state of the world by taking two types of actions: **committing** and **applying**. The leader **commits** to an index in its log (called a __commitIndex__) once a majority of the nodes in the network have acknowledged that they've also stored the entry successfully. When a node moves its __commitIndex__ forward in the log (the __commitIndex__ can only move forward, never backward!), it **applies** (processes) entries in the log up to where it is committed. The ideas of committing and applying ensure that a Leader doesn't update its state of the world until it is guaranteed that the log that led to that state is impossible to change - more info on the "impossible to change" idea in the next article's **Safety** section.
	
With that context, we can start breaking Raft down into more concrete sections that try to answer questions about the protocol:
- **Leaders and leader election** covers how updates to a Raft
cluster's state are coordinated: Which computer is coordinating
changes to the state of the world, how does this computer
coordinate with other computers in the Raft cluster, and for how
long does the computer coordinate? 
- **Raft logs and replication** covers the mechanism of state being
replicated: How does the state of the world get propagated to other
computers in the cluster? How do other computers get new information about the state of the world if they were disconnected, but are now back online (someone unplugged the computer's ethernet cable)?
- **Safety** covers how Raft guards against edge cases that could corrupt the state of the world: How do we make sure that a computer with an old state of the world does not accidentally overwrite another computer's updated state of the world? 

Given that this article is already fairly lengthy, I saved the three topics outlined above for the second part of the series, [available here](/2020/05/09/understanding-raft-consensus-part-2.html).
