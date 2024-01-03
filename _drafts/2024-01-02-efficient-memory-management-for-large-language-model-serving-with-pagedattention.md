---
layout: post
title: "Efficient Memory Management for Large Language Model Serving with PagedAttention"
categories:
---

[Efficient Memory Management for Large Language Model Serving with PagedAttention](TODO)

## What is the research?

LLM serving is complicated and requires a lot of resources. It turns out that text generation is memory bound. Memory allocation isn't very good because it makes the assumption that all of the data must be contiguous in memory. As a result, there is a lot of wasted memory, meaning that the GPU resources are actually underutilized.

The paper proposes a new technique for managing memory for LLMs, and a new serving system that uses it, called vLLM. vLLM is open source and awesome. The evaluations from the paper show that ""Our evaluations on various models and workloads show that vLLM improves the LLM serving throughput by 2-4× compared to the state-of-the-art systems [31, 60], without affecting the model accuracy at all."

## How does the system work?

A core challenge with LLM serving is storing the history of what the LLM has done and generating text going forward. A key structure in the system is the KV cache. The KV cache does TODO.

Most implementations make assumptions that end up consuming a lot of resources unncessarily. TODO describe the reasons that they are wasteful.

TODO figure 2
TODO figure 3

### PagedAttention

To solve this problem, the paper proposes PagedAttention.

### vLLM

TODO describe how vLLM uses PagedAttention

## How is the research evaluated?

The paper compares performance of models served with vLLM against other models served with a system called Orca (TODO research Orca and describe it). The paper compares three different types of tasks - basic sampling (e.g. normal LLM usage), search-based techniques like parallel sampling and beam search, and chatbot like uses of LLMs (which have longer prompts).

## Conclusion

PagedAttention and vLLM are at the cutting edge of systems research and its application to AI. I've been using it in one of my projects that I posted about recently (infinite mystery). vLLM also uses SkyPilot, which is another project that I would love to write about.