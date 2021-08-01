---
layout: post
title: "PaSh: Light-touch Data-Parallel Shell Processing"
categories:
---

_This week’s paper review is the third in a series on “The Future of the Shell"{% sidenote 'series' "Here are links to [Part 1](/2021/07/14/unix-shell-programming-the-next-50-years.html) and [Part 2](/2021/07/24/from-laptop-to-lambda-outsourcing-everyday-jobs-to-thousands-of-transient-functional-containers.html)" %}. These weekly paper reviews can [be delivered weekly to your inbox](https://tinyletter.com/micahlerner/), and based on feedback last week I added an [Atom feed](https://www.micahlerner.com/feed.xml) to the site. As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions about papers to read!_

[PaSh: Light-touch Data-Parallel Shell Processing](https://doi.org/10.1145/3447786.3456228)

This week's paper discusses _PaSH_, a system designed to automatically parallelize shell scripts. It accomplishes this goal by transforming a script into a graph of computation, then reworking the graph to enhance parallelism. To ensure that this transformation process is correct, PaSH analyzes a command as annotated with a unique configuration language - this configuration explicitly defines a command's inputs, outputs, and parallelizability. The final step in applying PaSH transforms the intermediate graph of computation back into a shell script, although the rewritten version of the shell script will (hopefully) be able to take advantage of greater parallelism.

On its own, PaSH can provide dramatic speedups to shell scripts (applying the system to common Unix one-liners accelerates them by up to 60x!), and it would certainly be interesting to see it coupled with other recent innovations in the shell (as discussed in other paper reviews in this series).

## What are the paper's contributions?

The paper makes three main contributions: 

- A study of shell commands and their parallelizability. The outcome of this study are categorizations of shell commands based on their behavior when attempting to parallelize them, and an annotation language used to describe this behavior. 
- A dataflow model{% sidenote 'dataflow' "There are many interesting papers that implement a dataflow model, although a foundational one is [Dryad: Distributed Data-Parallel Programs from Sequential Building Blocks](https://www.microsoft.com/en-us/research/wp-content/uploads/2007/03/eurosys07.pdf)"%} useful for representing a shell script. A given script's model is informed by the commands in it and the behavior of those commands - each command's behavior is described with a custom annotation language. The intermediate dataflow model is reworked to enhance parallelism, and is finally transformed back into a shell script (which then executes a more parallel version of the original computation).
- A runtime capable of executing the output shell script, including potentially custom steps that the PaSH system introduces into the script to facilitate parallelization.

## Shell commands and their parallelizability

PaSH seeks to parallelize shell commands, so the author's first focus on enumerating the behaviors of shell commands through this lens. The result is four categories of commands:

- _Stateless_ commands, as the name suggests, don't maintain state and are analagous to a "map" function. An example of stateless commands are `grep`, `tr`, or `basename`.
- _Parallelizable pure_ commands produce the "same outputs for same inputs — but maintain internal state across their entire pass". An example is `sort` (which should produce the same sorted output for the same input, but needs to keep track of all elements) or `wc` (which should produce the same count for a given input, but needs to maintain a counter).
- _Non-parallelizable pure_ commands are purely functional (as above, same outputs for same inputs), but "cannot be parallelized within a single data stream". An example command is `sha1sum`, which hashes input data - if the stream of data passed to the command is evaluated in a different order, a different output will be generated. This is contrast to a _parallelizable pure_ command like `sort` - no matter which order you pass in unsorted data, the same output will be produced.
- _Side-effectful_ commands alter the state of the system, "for example, updating environment variables, interacting with the filesystem, and accessing the network."

This categorization system is applied to commands in POSIX and GNU Coreutils. 

{% maincolumn 'assets/pash/parclasses.png' '' %}

While the vast majority of commands (in the _non-parallizable pure_ and _side-effectful_ categories) can not be parallelized without significant complication, a significant portion of commands can be relatively-easily parallelized (_stateless_ or _parallelizable pure_ categories).


## Shell command annotation

To describe the _parallelizability class_ of a given command and argument, the paper's authors built an _extensibility framework_. This framework contains two components: an _annotation language_ and _custom aggregators_ which collect the output of commands executing in parallel and stream provide to the next command in the script.

The _annotation language_ is used to produce _annotations_ that indicate inputs, outputs, and parallelization class on a per-command basis{% sidenote 'opensource' "The entirety of PaSH, including annotations, are [open source on GitHub](https://github.com/binpash/pash) - the docs include a [useful reference for annotating commands](https://github.com/binpash/pash/blob/main/annotations/README.md#how-to-annotate-a-command)."%}. An example for the `chmond` command is below:

```{ "command": "chmod", "cases": [ { "predicate": "default", "class": "side-effectful" } ] }```

One can also define behavior for specific command and argument combinations. For example, providing (or omitting) a specific argument might change the parallelizability class or inputs/outputs for a command - an example of this is `cut` with the `-z` operand (`cut` reads from stdin if the `-z` operand is not provided)P

```{ "predicate": {"operator": "exists", "operands": [ "-z" ]}, "class": "n-pure", "inputs": [ "args[:]" ], "outputs": [ "stdout" ] }```

_Custom aggregators_ coalesce the results of parallelized operations into a result stream - an example aggregator takes in two streams of `wc` results and produces an element in an output stream. The [PaSH open source project](https://github.com/binpash/pash/tree/main/runtime/agg/py) includes a more complete set of examples that can aggregate the results of other parallelized commands, like `uniq`.

{% maincolumn 'assets/pash/agg.png' '' %}

The implementation of PaSH relies on the annotation language and custom aggregators described above in order to transform a shell script into an intermediate state where the script's commands are represented with a _dataflow model_ - this transformation is covered in the next section.

## Transforming a script

There are multiple steps involved in transforming a script to a more-parallel form. First, PaSH parses it, transforming it into an intermediate state called a _dataflow graph_ (DFG) model. The annotation language facilitates this transformation by providing hints to the system about each step's inputs, outputs, and behavior when parallelized. The intermediate dataflow model can be reconfigured to produce a more parallel of the script's associated commands. Lastly, the resulting graph is transformed back into a shell script.

PaSH implements this transformation process end-to-end using three components: a _frontend_, the _dataflow model_, and the _backend_.

The _frontend_ first parses the provided script into an Abstract Syntax Tree (AST). From there, it "performs a depth-first search" on the AST of the shell script, building _dataflow regions_ as it goes along - a _dataflow region_ corresponds to a section of the script that can be parallelized without hitting a "barrier" that enforces sequential execution. Examples of barriers are `&&`, `||`, and `;`. It's worth noting that PaSH also is very conservative when it comes to building _dataflow regions_ that it might try to parallelize later - if an annotation for a command is not defined or it is possible that the parallelizability class of an expression could be altered (for example, if the command relies on an environment variable), then PaSH will not parallelize it. The resulting _dataflow model_ is essentially a graph where the nodes are commands and edges indicate command inputs or outputs.

{% maincolumn 'assets/pash/agg.png' '' %}

Once the dataflow graphs (DFG) for a script are produced, they can be reworked to take advantage of user-configured parallelism. The paper lays out the formal basis for this transformation - as an example, stateless and parallelizable pure commands can be reconfigured to enhance parallelism while still producing the same result (the paper presents the idea that for pure commands, the result of reordering nodes is the same). 

{% maincolumn 'assets/pash/stateless.png' '' %}

The paper also mentions other useful transformations of the graph - one in particular, adding a relay node between two nodes, is useful for enhancing performance (as described in the next section). At the transformation stage, a user provided parameter, _width_, configures the number of nodes executing data-parallel steps at the time.

After all transformations are performed on the graph, the _Backend_ transforms the graph back into an executable shell script.

## Runtime

The output script generated by the application of PaSH can be difficult to execute for several reasons outlined by the paper, although this paper review doesn't include a complete description of the runtime challenges{% sidenote 'runtime' "The paper does a better job of noting them than I could and I highly recommend digging in!"%}.

One particularly important detail of the runtime is an approach to overcoming the shell's "unusual laziness" - the paper notes that the "shell’s evaluation strategy is unusually lazy, in that most commands and shell constructs consume their inputs only when they are ready to process more." To ensure high resource utilization, PaSH inserts "relay nodes", which "consume input eagerly while attempting to push data to the output stream, forcing upstream nodes to produce output when possible while also preserving task-based parallelism". For a number of reasons, other approaches to solving the "eagerness" problem (like not addressing it or using files) result in less performant or even possibly incorrect implementations.

This eagerness relay node comes into play in the evaluation section of the paper.

## Evaluation

The evaluation section of the PaSH paper includes a number of applications, but I choose to focus on three applications that stick out to me: Common Unix One-liners, NOAA weather analysis, and Wikipedia web indexing.

Applying PaSH to the set of common UNIX one-liners exercises a variety of different scripts that use _stateless_, _parallizable pure_, and _non-parallelizable pure_ in different configurations and numbers, speeding up scripts by up to 60x. This set of tests also demonstrates that implementation details like eager evaluating (outlined in the _Runtime_ section above) make a difference{% sidenote 'benchmark' 'This result is shown by benchmarking against versions of PaSH without the implementation or with a different, blocking implementation.' %}.

The next example I chose applies PaSH to a classic example of a data pipeline that analyzes NOAA Weather data. PaSH is applied to the entire pipeline and achieves significant speedups - this example is particularly useful at demonstrating that the system can help to parallelize non-compute bound pipelines (the NOAA example downloads a signficant amount of data over the network). In particular, downloading large amounts of data over the network seems to closely relate to ideas discussed in the [first paper in this series](/2021/07/14/unix-shell-programming-the-next-50-years.html), which mentions the benefits of incremental computation - parallelizing network requests automatically while ensuring that none are repeated unnecessarily (if the script was rerun or slightly changed) would be amazing!

The last example I choose to include in this evaluation section is of Wikipedia web indexing - PaSH is able to achieve a 12X speedup when extracting text from a large body of Wikipedia's HTML. This example uses scripts written in Python and Javascript, showcasing PaSH's ability to speedup a pipeline utilizing commands from many different langauges and why the shell is still such a useful tool.

## Conclusion

PaSH presents an intriguing system for automatically transforming shell scripts into more-parallel versions of themselves. I was particularly interested in how PaSH accomplishes its goals by leveraging annotations of shell commands and arguments - it would be interesting to see an open source community sprout up around maintaining or generating these annotations{% sidenote 'homebrew' "I felt some similarity to Mac's [Homebrew](https://brew.sh/), where users define recipes for downloading different open source projects." %}. PaSH's use of a dataflow-based architecture also demonstrates how powerful the paradigm is. Last but not least, I'm looking forward to seeing how a system like PaSH could fit in with other related innovations in the shell (like next week's paper on POSH)! 

As always, if you have feedback feel free to reach on [Twitter](https://twitter.com/micahlerner). Until next time!