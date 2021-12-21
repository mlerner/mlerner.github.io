---
layout: post
title: "Unix Shell Programming: The Next 50 Years (The Future of the Shell, Part I)"
hn: "https://news.ycombinator.com/item?id=29610956"
categories:
---

[Unix Shell Programming: The Next 50 Years](https://sigops.org/s/conferences/hotos/2021/papers/hotos21-s06-greenberg.pdf)

This week's paper won the distinguished presentation award at HotOS 2021, and discusses the potential for future innovation in the tool that many use every day - the shell!{% sidenote 'hn' "A previous submission of this paper on [Hacker News](https://news.ycombinator.com/item?id=27378444) elicited a number of strong reactions. One reaction was the assertion that there are in fact modern shells - [Elvish](https://elv.sh/) features most prominently. While I think several of the comments on the original posting are in the right direction, my takeaway from this paper was that modern shells could take advantage of exciting advances in other areas of systems research (in particular, data flow and transparent parallelization of computation)." %}

It not only proposes a way forward to address (what the authors view) as the shell's sharp edges, but also references a number of other interesting papers that I will publish paper reviews of over the next few weeks - the gist of several of the papers are mentioned further on in this article:

- [PaSh: light-touch data-parallel shell processing](https://dl.acm.org/doi/10.1145/3447786.3456228)
- [POSH: A Data-Aware Shell](https://www.usenix.org/conference/atc20/presentation/raghavan)
- [From Laptop to Lambda:  Outsourcing Everyday Jobs to Thousands  of Transient Functional Containers](https://www.usenix.org/conference/atc19/presentation/fouladi)


## The good, the bad, and the ugly

In _Unix Shell Programming: The Next 50 Years_, the authors argue that while the shell is a powerful tool, it can be improved for modern users and workflows. To make this argument, the paper first considers "the good, the bad, and the ugly" of shells in order to outline what should (or should not) change in shells going forward.

The paper identifies four _good_ components of modern shells: 

- _Universal composition_: The shell already prioritizes chaining small programs working in concert (which can be written in many different languages), according to the Unix philosophy.
- _Stream processing_: The shell is well structured to perform computation that flows from one command to another through pipes (for example, using xargs). The paradigm of stream processing is an active area of research outside of the shell and shows up in modern distributed systems like [Apache Flink](https://flink.apache.org/) or [Spark Streaming](https://spark.apache.org/streaming/).
- _Unix-native_: "The features and abstractions of the shell are well suited to the Unix file system and file-based abstractions. Unix can be viewed as a naming service, mapping strings to longer strings, be it data files or programs"
- _Interactive_: A REPL-like environment for interacting with your system translates into user efficiency.

Next - four _bad_ features are detailed, with the note that, "It's hard to imagine ‘addressing’ these characteristics without turning the shell into something it isn’t; it’s hard to get the good of the shell without these bad qualities"{% sidenote 'wordexp' 'As an example, the paper links to [previous research](https://cs.pomona.edu/~michael/papers/px2018.pdf) that word expansion ("the conversion of user input into...a command and its arguments") make up a significant portion of user commands.' %}:

- _Too arbitrary_: Almost any command can be executed as part of a shell pipeline{% sidenote 'shelltetris' '[Shell tetris](https://www.unix.com/shell-programming-and-scripting/174525-tetris-game-based-shell-script-new-algorithm.html)!' %}. While this flexibility is useful for interacting with many different components (each of which may be in a different language), the arbitrariness of a shell makes formalizing a shell's behavior significantly more difficult.
- _Too dynamic_: Shell behavior can depend on runtime execution state, making analysis of shell scripts more difficult (analysis techniques could be helpful for determining undesirable outcomes of shell scripts before running them).
- _Too obscure_: There is a 300 page specification for the [POSIX shell](https://pubs.opengroup.org/onlinepubs/9699919799.2018edition/utilities/V3_chap02.html#tag_18_12), in addition to [test suites](http://get.posixcertified.ieee.org/testsuites.html). Unfortunately, the authors found multiple issues with common shells, and even with the test suites themselves! The undefined nature of what a shell is actually supposed to do in specific situations means that it is hard to make guarantees about correctness{% sidenote 'smoosh' "[One of the author's papers](https://mgree.github.io/papers/popl2020_smoosh.pdf) goes more in-depth on the question of 'What is the POSIX shell?'" %}.

Lastly, four _ugly_ components are detailed:

- _Error proneness_: There aren't checks to prevent a user from making mistakes (which could have drastic conditions). [Unix/Linux Horror Stories](https://www-uxsup.csx.cam.ac.uk/misc/horror.txt) has some good ones (or bad, if you were the person making the mistake!).
- _Performance doesn't scale_: the shell isn't set up to parallelize trivially parallelize problems across many cores or machines (which would be very helpful in a modern environment){% sidenote 'gg' 'If this is interesting to you, predominantly all of the papers in the series deal with this problem.'%}.
- _Redundant recomputation_: If a developer makes a change to a shell script, they will have to rerun it in its entirety (unless they are a shell wizard and have gone out of their way to ensure that their script does not do so, while potentially making operations idempotent).
- _No support for contemporary deployments_: Similar to the 2nd point - most shell scripts aren't designed to take advantage of multiple machines, nor of cloud deployments.


## Enabling the shell to move forward

The paper next argues that two sets of recent academic research are enabling the shell to move forward: _formalizing the shell_ and _annotation languages_.

Recent work on _formalizing the shell_ is detailed in [Executable Formal Semantics for the POSIX Shell](https://mgree.github.io/papers/popl2020_smoosh.pdf), which has two major components: _Smoosh_ and _libdash_ - the artifacts for [both are open source](https://github.com/mgree/smoosh). 

_Smoosh_ is an executable shell specification written in [Lem](https://dl.acm.org/doi/10.1145/2692915.2628143){% sidenote 'Smoosh' "Which can then be translated to different formats, including proof languages like Coq" %}. A shell specification written in code (versus the extensive written specification) meant that the aforementioned paper was able to test various shells for undefined behavior, in the process finding several bugs in implementation (not to mention, bugs in the test suite for the POSIX shell specification!){% sidenote 'smoosh' "Another interesting feature of _Smoosh_ is that it provides two interfaces to interact with the OS - one actually invokes syscalls, whereas the other mode simulates syscalls (and is used for [symbolic execution](https://www.cs.umd.edu/~mwh/se-tutorial/symbolic-exec.pdf)). This vaguely reminds me of the testing system used in [FoundationDB](/2021/06/12/foundationdb-a-distributed-unbundled-transactional-key-value-store.html), covered in a previous paper review."%}.  _libdash_ transforms shell scripts from (or to) abstract syntax trees, and is used by _Smoosh_.

_Annotation languages_ can allow users to specify how a command runs, in addition to possible inputs and outputs. Strictly specifying a command allows for it to be included as a step (with inputs and outputs) in a data flow graph, enabling more advanced functionality - for example, deciding to divide the inputs of a step across many machines, perform computation in parallel, then coalescing the output. If this type of advanced functionality sounds interesting to you, stay tuned! I'll be reading about the two papers that fall into this category (PaSH & POSH) over the next few weeks.

After discussing these two research areas, the paper discusses a new project from the authors, called Jash (Just Another SHell). It can act as a shim between the user and the actual execution of a shell command. Eventually, Jash seems like it could implement functionality similar to an execution engine or query planner, evaluating commands at runtime and deciding how to perform the requested work (providing feedback to the user if the script will produce unintended side effects). 

## The future

The paper outlines five functionalities for the future of the shell: 

- _Distribution_: in the context of a shell, this means building a system capable of scaling beyond a single machine (for example, inserting compute resources at different stages of a shell command's execution to parallelize) - all three of the papers in this series dive deep on this idea.
- _Incremental support_: if a shell script is changed slightly, but can reuse previous computation, a shell could strive to do so.{% sidenote 'dd' 'The paper cites [Differential Dataflow](https://github.com/TimelyDataflow/differential-dataflow), which is related to another paper I have had on the backlog for a while - [Naiad: A Timely Dataflow System](http://sigops.org/s/conferences/sosp/2013/papers/p439-murray.pdf).' %} 
- _Heuristic support_: While transforming a shell script into a data flow graph can be facilitated by _annotation languages_, it would be costly to annotate every shell command. Ideally, the annotation of commands could be performed automatically (or with the support of automation).
- _User support_: A shell should take advantage of modern features like language servers. A formal specification for interacting with the shell can theoretically simplify interactions with the shell.
- _Formal support_: The paper cites how formalization has helped C "tool authors and standards writers", in particular with respect to undefined behavior. Diving deep on this, I found a [few](http://people.csail.mit.edu/nickolai/papers/wang-undef.pdf) helpful papers that discuss undefined C behavior - in particular [this one](https://blog.regehr.org/archives/1520) from Pascal Cuoq and John Regehr).

## Conclusion

The shell is an integral part of systems, and this paper makes a case for revisiting the shell's sharp edges, while revamping its functionality for modern use cases. I'm excited to keep diving deep on this topic - this is the first post in a series I'm doing! If you enjoyed it (or otherwise have suggestions), find me on [Twitter](https://twitter.com/micahlerner). Until next time.
