---
layout: post
title: "Efficient Memory Management for Large Language Model Serving with PagedAttention"
categories:
---

[Efficient Memory Management for Large Language Model Serving with PagedAttention](https://dl.acm.org/doi/10.1145/3600006.3613165)

## What is the research?

Large language models (like OpenAI's [ChatGPT](https://openai.com/blog/chatgpt), Google's [Bard](https://bard.google.com), Meta's [Llama](https://ai.meta.com/llama/), and Mistral's [Mixtral](https://mistral.ai/news/mixtral-of-experts/)) take in a user prompt and respond with generated text (note: for the purposes of this paper, the authors don't include multi-modal response). Based on public reports, supporting this functionality is [expensive](https://www.businessinsider.com/how-much-chatgpt-costs-openai-to-run-estimate-report-2023-4), and given the relatively new nature of LLMs deployed at scale, there are opportunities for improving performance.

To that end, this paper focuses on increasing the queries per second (a.k.a throughput) large language models (LLMs) can serve through two innovations, _PagedAttention_, and _vLLM_, discussed in detail later in this paper review. Improving throughput can significantly decrease the cost of large language model serving by responding to more requests with the same number of GPU resources. The evaluations from the paper show that, "vLLM improves the LLM serving throughput by 2-4× compared to the state-of-the-art systems...without affecting the model accuracy at all."

Based on the observation that large language model serving is memory bound, the authors identify several areas of improvement for GPU memory allocation, then design a system that addresses these shortcomings. One of the foremost problems they address is static allocation of memory. Existing LLM serving systems (or at least publically released ones) set aside fixed, contiguous memory to store the data needed to generate a response. If the response to the user is shorter than this fixed size, the resources are inaccessible to use for serving other requests until the original request is complete. Requiring contiguous memory blocks adds additional resource waste by "stranding" memory between the contiguously allocated areas of memory, causing it become unusable for serving other requests.

{% maincolumn 'assets/pagedattention/figure1.png' '' %}

Borrowing ideas a page from virtual memory, the authors propose a solution, _PagedAttention_, that can _dynamically_ grow the memory used in LLM serving (in addition to incorporating other optimizations). The paper also describes how _PagedAttention_ is implemented in a new GPU serving library via the open source [vLLM project](https://github.com/vllm-project/vllm).

## How does the system work?

Large language models take in a prompt from a user, then generate a text response.  The paper focuses specifically on improving the performance of serving for transformers, a technology used by predominantly all implementations of large language models to generate the next word in a sequence - for more background, I recommend [The Illustrated Transformer](http://jalammar.github.io/illustrated-transformer/) and [Understand how transformers work by demystifying all the math behind them](https://osanseviero.github.io/hackerllama/blog/posts/random_transformer/).

Generating these sequences requires information on the users prompt, and about previous tokens in the response - this knowledge takes the form of vectors stored in memory in  a data structure the authors call the Key Value Cache (aka _KV cache_). Because the limiting step in the execution of an LLM depends on reading and writing data to/from memory, an LLM process is "memory bound" - as a result, improving memory utilization (specifically, of the _KV Cache_) can increase performance of the system.

The authors identify three main types of waste in the _KV Cache_:

> _reserved slots_ for future tokens, _internal fragmentation_ due to over-provisioning for potential maximum sequence lengths, and _external fragmentation_ from the memory allocator.

{% maincolumn 'assets/pagedattention/figure2.png' '' %}
{% maincolumn 'assets/pagedattention/figure3.png' '' %}

### PagedAttention

One of the paper's key insights is that allowing a model to _dynamically_ scale up its usage of non-contiguous memory can drastically improve memory utilization. The authors propose _PagedAttention_, which introduces the idea of _logical_ and _physical_ memory blocks for storing data in the _KV Cache_. This distinction is [similar to virtual memory](https://stackoverflow.com/a/15851473) which provides the abstraction of contiguous RAM to a program, even though the data is physically stored in separate areas of RAM.

{% maincolumn 'assets/pagedattention/figure5.png' '' %}

Blocks contain entries for more than one token, and blocks are allocated on demand based on how the LLM responds to a user query - for example, the prompt "Four score and seven years ago our fathers brought forth" contains ten tokens, causing the allocation of three blocks each with the space for four entries (the last block allocated because of the prompt is partially filled). Gradually allocating blocks primarily addresses _internal fragmentation_ and _reserved_ memory.

{% maincolumn 'assets/pagedattention/figure6.png' '' %}

As the large language model generates tokens, it references data on previous tokens using a _block table_ storing the mapping between logical blocks for a query and physical GPU DRAM. Critically, this approach allows for the GPU to serve multiple requests at the same time while using non-contiguous memory, addressing concerns like _external fragmentation_.

{% maincolumn 'assets/pagedattention/figure7.png' '' %}

The paper also describes how PagedAttention approach is able to reduce memory usage in three other large language model serving request patterns - _parallel sampling_, _beam search_, and _shared prefix_ prompting.

_Parallel sampling_ involves generating multiple results for a single prompt - this can occur by having the LLM choose a different token, leading to a different branch of response. The implementation follows a ["copy-on-write"](https://stackoverflow.com/questions/628938/what-is-copy-on-write) pattern that reuse the same data in GPU memory until the branch in output occurs (at which point, the block with the difference is copied to a new location in memory, and execution completes independently for the different branches).

{% maincolumn 'assets/pagedattention/figure8.png' '' %}

The paper also describes PagedAttention in the context of _beam search_, an algorithm for generating possible next states and choosing a "top-K" subset to continue with - the paper cites [Sequence to Sequence Learning
with Neural Networks](https://proceedings.neurips.cc/paper/2014/file/a14ac55a4f27472c5d894ec1c3c743d2-Paper.pdf) when referencing beam search, but I think [this explanation](https://d2l.ai/chapter_recurrent-modern/beam-search.html#id1) gets the gist across better. A _beam search_ implemented with _PagedAttention_ can reuse blocks across multiple search paths, meaning that the process has less memory overhead.

{% maincolumn 'assets/pagedattention/figure9.png' '' %}

Lastly, the paper discusses PagedAttention's impact on prompts with a _shared prefix_ - in many situations, a user of an LLM will provide a separate "system" prompt that applies, no matter the details of the task (this is also discussed in [OpenAI's documentation on prompt engineering](https://platform.openai.com/docs/guides/prompt-engineering)). One example system prompt is, "you are a helpful agent that only speaks JSON". PagedAttention allows the blocks allocated for this part of the prompt to be reused across multiple tasks, reducing memory usage.

{% maincolumn 'assets/pagedattention/figure10.png' '' %}

### vLLM

To deploy PagedAttention in a distributed environment, the paper proposes the vLLM system, containing a _scheduler_ (which chooses which work to run where), the _KV Cache Manager_, _Workers_ (computers containing GPU hardware), and _Block Allocators_. I elide the details of this section given that vLLM is an [open source project](https://github.com/vllm-project/vllm/tree/d0215a58e78572d91dadafe9d832a2db89b09a13/vllm/core), and the details of the infrastructure are likely to change.

{% maincolumn 'assets/pagedattention/figure4.png' '' %}

That said, there were a few interesting design choices that stuck out to me:
- vLLM adopts patterns from [Megatron-LM](https://arxiv.org/pdf/1909.08053.pdf), which details how to run transformers at scale across many GPUs while minimizing communication.
- vLLM implements the [OpenAI API interface](https://docs.vllm.ai/en/latest/getting_started/quickstart.html#openai-compatible-server), simplifying developer adoption.
- vLLM supports higher-level abstractions (via `fork`, `append`, and `free` commands) used to implement approaches like _beam search_, _parallel sampling_, and _shared prefix_ - luckily [the code is open source](https://github.com/vllm-project/vllm/blob/937e7b7d7c460c00805ac358a4873ec0653ab2f5/vllm/sequence.py#L212) which allows for a deeper dive!

## How is the research evaluated?

The paper compares performance of models served with vLLM against other serving systems (e.g. a custom implementation of [Orca](https://www.usenix.org/conference/osdi22/presentation/yu), an LLM-serving system described in research from OSDI 2022) emulating workloads sourced based on open source datasets ([ShareGPT](https://sharegpt.com/) and [Stanford Alpaca](https://github.com/tatsu-lab/stanford_alpaca)).

{% maincolumn 'assets/pagedattention/figure11.png' '' %}

The paper compares three different types of tasks - basic sampling (e.g. normal LLM usage), search-based techniques like _parallel sampling_ and _beam search_, and chatbot-like uses of LLMs (which have longer prompts, along with back and forth between the user and the LLM).

For _basic sampling_, _parallel sampling_, _beam search_, and chatbot-like workloads, vLLM is able to achieve significantly higher request rates.

{% maincolumn 'assets/pagedattention/figure12.png' '' %}
{% maincolumn 'assets/pagedattention/figure14.png' '' %}
{% maincolumn 'assets/pagedattention/figure17.png' '' %}

Additionally, vLLM and PagedAttention are able to save significant amounts of memory on tasks where it is possible to re-use blocks (e.g. parallel sampling and beam search) - these graphs show average amount of memory saving as a percent, but it would be interesting to know in absolute terms.

{% maincolumn 'assets/pagedattention/figure15.png' '' %}

## Conclusion

PagedAttention and vLLM are at the cutting edge of systems research and its application to AI - something that is becoming more of a topic in research and in practice (e.g. [Charles Frye's post](https://charlesfrye.github.io/programming/2023/11/10/llms-systems.html)) now that LLMs are beginning to operate at scale. I'm looking forward to following along on the progress of the vLLM open source project, and from digging into the project, I discovered it is compatible with [SkyPilot](https://skypilot.readthedocs.io/en/latest/) (an open source project for deploying infrastructure cross-cloud, discussed in research from [NSDI 2023](https://www.usenix.org/conference/nsdi23/presentation/yang-zongheng)). As I tinker on [LLM-based side-projects](https://twitter.com/micahlerner/status/1741989855041843504), I'm looking forward to experimenting with and learning from these promising new tools.