---
layout: post
title: "TelaMalloc: Efficient On-Chip Memory Allocation for Production Machine Learning Accelerators"
categories:
---

## What is the research?

In order to run machine learning models, you need to give them memory. While you could implement a naive approach, doing so optimally is difficult (TODO NP-hard optimization problem).

Systems normally accomplish memory allocation by relying on a model that makes use of the resources that are available to it. ML Systems are also different because they have a unique structure of memory-usage - memory allocation is also well studied (see Dynamic Storage Allocation: A Survey and Critical Review TODO https://www.cs.hmc.edu/~oneill/gc-library/Wilson-Alloc-Survey-1995.pdf). ML is more like 2D-binpacking because "live ranges" are known in advance.

To perform memory allocation, there are existing solutions that rely on heuristics (TODO reference XLA, TFLite) or solvers. Solvers could produce a closer to optimal output but often take longer to run. The Telamalloc paper aims to provide a balance of heuristic and solver implementation in order to perform this function in a way that doesn't negatively impact users. It tackles challenges like the fact that there are different hardware constraints for different devices, impacting the time that it takes the model to run.

## What are the paper's contributions?

The paper makes three main contributions:

- Combining a heuristic-based approach to memory allocation with a solver aware of domain-specific knowledge.
- An evaluation of the approach combined approach
- A forward-looking proposal for improving on initial results by taking production data and feeding it back into the system.

## How does the system work?

The system takes the problem and turns it into a 2D-optimization problem, where memory blocks are assigned to different ranges of address space over time, based on the flow of the program.

TODO figure 1

The authors aim the approach at tensor memory allocation both on mobile devices and in Tensor Processing Units, a custom piece of hardware that is used for machine learning at scale (TODO cite research about TPUs). It is worth noting how well studied using memory is, and the paper reviews compilers how many compilers:

> 1) take a graph representation of the model and perform various graph transformations, 2) divide the graph into smaller units of work (operators), and 3) map these operators to different units of hardware.

The authors call the third component the _mapping problem_, and note it is fundamentally different than the problem they're focused on, which they call the _memory allocation problem_:

> the _mapping problem_ is concerned with determining which level of a memory hierarchy to map each buffer to, the _memory allocation_ problem selects buffer locations within addressable scratchpad memories that are shared between multiple buffers with overlapping live ranges.

Notably, running this code impacts users. If the compilation of a model takes a long time, the user will notice. If the problem is solved quickly, but suboptimally the model won't successfully run (because the memory it isn't using isn't available as predicted)

TODO figure 3

### Problem Formulation

The authors represent provide a set of buffers with start, end, and size to the allocator, along with a limit to the memory it is able to use.

The allocator then, "produces a mapping 𝐵 to Address, where: 1) Address is an integer representing the start/lowest address of the buffer, 2) no two buffers overlap, and 3) the highest address of the buffer never exceeds 𝑀."

### Memory Allocation Heuristics

The paper describes three main heuristics for assigning buffers to addresses: _best-fit_, _greedy_, the _approach Telamalloc implements_ (which is a combination of both).

A _best-fit_ allocator assigns buffers to address space in start time order (TODO this is what tf does). The paper notes, "This approach works well if memory is abundant but fails if the memory budget is tight". It likely fails if the memory budget is type because TODO.

The _greedy_ approach (TODO it references something, paper 38) takes, "the end time into account to pick locations one buffer at time, while ensuring that it does not overlap with any previously allocated buffers." Again, this approach doesn't do well when memory is tight because TODO.

Lastly, there is the heuristic that Telamalloc implements, which takes into account the contention of a point of time (represented by the number of buffers that need to be assigned). Buffers with the highest contention are placed first at the lowest possible address (stored by keeping a "skyline" for each time period){% sidenote 'skyline' "This is reminiscent of the [Skyline Problem](https://leetcode.com/problems/the-skyline-problem/)!" %}. If there are multiple buffers, the heuristic makes a decision based on other factors like the length of time a buffer exists.

### Solver-based Approaches

Heuristics have a few downsides, including that their performance depends on the specific workload and problem difficulty - "once a heuristic has made a wrong decision that prevents it from solving the problem, it has no way to recover." To address the shortcomings of heuristic failure, Telamalloc integrates a solver-based approach that has knowledge of the problem (TODO reference solver approach canonical source).

For example, the constraints of the problem can be formulated as essentially all of the buffers taking up space at a given time can not exceed memory and buffers can not overlap.

TODO Figure 5

### Telamalloc Overview

As mentioned earlier, Telamalloc doesn't solely rely on heuristics, nor solvers - heuristics get stuck on certain cases, and solvers can take too long. Normally solvers (the paper links to a specific CP-SAT solver TODO link) return the whole solution given an input and a set of constraints - instead, the program that guides the solver integrates interactively, reading the state of the solver for a particular buffer and making choices, then responding to feedback.

TODO figure 6

At each step, the Search Heuristic chooses from the remaining unplaced blocks{% sidenote 'heur' 'It chooses blocks based on the following heuristics in order, "(1) The block with the longest lifetime (end-start time). (2) The block with the largest size. (3) The block with the largest area (i.e., size × lifetime)."'%}, and "backtracks" to undo choices if a state it ends up in is invalid. It breaks down backtracking into "minor" and "major" backtracking based on how much needs to be undone - the former corresponds to a single placement, whereas the latter corresponds to undoing a whole line of choices because the final state is invalid.

TODO figure 7

The authors describe a number of optimizations to implement _smart backtracking_. Several of these assignments are focused on avoiding a return to the conditions that caused the initial backtrack. For example, on failure to satisfy constraints, the solver reports which placements occurred, so the search algorithm can unwind them. Another example optimization is explicitly prioritizing buffers that led to a major backtrack over other candidates - "this avoids cases where the solver got stuck by ignoring blocks that were important but not among the largest or longest-lived blocks".

Lastly, Telamalloc groups together buffers that contend with one another into _phases_, then runs the algorithm over each _phase_. This approach reduces the complexity of the problem, and allows choosing from a smaller set of candidate buffers when making choices.

## How is the research evaluated?

The paper considers two main aspects of Telamalloc: _microbenchmarks_ evaluating the algorithm in isolation, and measurements from compiling models and making memory allocations on a Pixel 6.

The microbenchmarks consider the time to compute memory placements in the best and worst cases. In normal conditions, Telamalloc completes incredibly quickly ("≈10-100us for common problem sizes"). The worst case is represented by a large number of blocks (one thousand) with full overlap - in this situation, Telamalloc takes around 100000 ms, and each step takes significantly longer due to the strain placed on the solver (which needs to consider how a candidates interacts with many different potential placements).

TODO table 1

When comparing Telamalloc's compilation of common models on the Pixel 6 running against a solver (which is capable of achieving near-optimal results given enough time), the memory allocations Telamalloc produces are nearly identical. Telamalloc is also able to achieve a, "median speedup of ≈ 4.7× across the benchmark".

TODO TAble 2

TODO figure 12

## Conclusion

Telamalloc is an interesting paper because it discusses a novel application of algorithms that are fairly common. The paper also discusses using ML to make the performance of "smart" backtracking better, and this seems like an area where there would be awesome data and further work. Java has the JIT compiler, which takes data about a program's performance and execution, then uses that to make the program better over time. This seems like a really neat thing to dig into: https://developers.redhat.com/articles/2021/06/23/how-jit-compiler-boosts-java-performance-openjdk#. Javascript V8 compiler is another example. Cache-aware algorithms are another example.
