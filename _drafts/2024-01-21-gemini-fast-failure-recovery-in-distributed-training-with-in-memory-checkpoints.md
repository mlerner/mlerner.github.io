---
layout: post
title: "Gemini: Fast Failure Recovery in Distributed Training with In-Memory Checkpoints"
categories:
---


## What is the research and why does it matter?

Training AI models requires a large amount of compute, in particular GPUs. The raw resources and the power to run it are not cheap. TODO reference how much Meta is spending on it this year.

Training models isn't cheap for few reasons - in particular, their reliability impacts the training cost. For example, if a machine involved in training fails, the work that it did is lost. Motivated by data that existing solutions don't handle this case well, the authors propose a framework for limiting the amount of wasted resources - "According to the report from OPT-175B training [85], about 178,000 GPU hours were wasted due to various training failures." This maps to TODO dollars

This paper to solves this problem by providing a failure recovery system that builds on existing approaches, most of which rely on far remote storage which is costly to read/write to. Instead, Gemini essentially builds a multi-level cache comprising GPU memory, local and remote CPU memory, and persistent storage as a last resort. It is able to successfully achieve TODO result without significantly impacting training.

## How does the system work?

The paper layouts three factors in "wasted time":

- Checkpoint time:
- Checkpoint frequency:
- Retrieval time:

The key challenge with existing systems is that they often rely on retrieval from external storage which is costly from a latency perspective.

To drive down wasted time, the authors propose a system that aims to "maximize the probability of failure recovery from checkpoints stored in CPU memory". This system basically involves a multiple-level cache (similar to the memory architecture paper TODO).

There are two parts of the Gemini system: the _checkpoint creation module_ and the _failure recovery module_.


The _checkpoint creation module_ creates checkpoints and figures out where to store them.

The _failure recovery module_ contains four components:

- Gemini worker agents: TODO
- Root agent: TODO
- Distributed KV Store: TODO
- Cloud Operator: TODO

### Technical Challenges

The system aims to address two challenges: minimizing the impact of machine failure and limiting the impact of Gemini's approach on the network (which could negatively affect the model training).

To minimize the impact of machine failures, the paper investigates different configurations of where to place the checkpoints - it calls them _group_, _ring, and _mixed_.

TODO figure 3

To minimze training interference, the authors implemenet _traffic interleaving_, which attempts to send the checkpoints over the network in a way that doesn't interfere with other network traffic associated with training - TODO describe the other traffic on the network.

TODO figure 4

Unfortunately, a naive implementation to this doesn't succeed on its own as the checkpoints are too large for memory. Instead, the paper splits up a checkpoint into partitions and incrementally sends them over the network. TODO describe the algorithm for checkpoint partitions.

The authors also describe an approach to _online profiling_ where the dynamics of network traffic are learned over time and then eventually feed into the decision making for sending traffic over the network.

### Resuming from failure

The authors describe two different failure types: software failures and hardware failure. TODO describe the difference.

Critically, GEMINI treats them differently because of the impact they have on the in-memory data used to restore from checkpoint. "In practice, the majority of failures during large model training are software failures or hardware failures with one machine replaced; it is rare to have two or more machine failures at the same time [3, 14]." TODO describe what GEMINI does for hardware.

## How is the research evaluated?

The research evaluates GEMINI's impact on training efficiency, effectiveness in traffic interleaving, and lastly makes projections around the systems scalability and impact to training large language models.

For training efficiency, the paper measures whether GEMINI changes training time, wasted time, and checkpoint time. The research finds that GEMINI doesn't increase iteration time while significantly reducing wasted time. Additionally, TODO discuss impact on checkpoint time.

The paper also measures the effectiveness of traffic interleaving (including varying the approaches among the four e.g. naive batching). Varying the approaches for traffic interleaving has almost no impact.

Lastly, the research contains projections about GEMINI if it were applied to training a large language model - while the results of this projection seem promising, it seems like there is more work to be done here.

## Conclusion

GEMINI is an interesting system that could potentially dramatically reduce wasted time in training AI models. As models get bigger and bigger, this will become even more of a concern than it already is. One of my main takeaways is that somewhat pedestrian topics in systems are being applied to AI models and how they're trained, often with dramatic speedups. This is exciting because it means there is a lot of low hanging fruit, and also this is a totally new type of system that we are trying to develop at scale (TODO ref paged attention). I'm looking forward to further developments in this space, and hope to see a followup paper from the authors soon (or alternatively a reference to using GEMINI-like techniques in other model trainings).
