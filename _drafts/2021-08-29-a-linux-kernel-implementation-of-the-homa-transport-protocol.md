---
layout: post
title: "A Linux Kernel Implementation of the Homa Transport Protocol, Part 2"
categories:
---

_Over the next few weeks I will be reading papers from [Usenix ATC](https://www.usenix.org/conference/atc21) and [OSDI](https://www.usenix.org/conference/osdi21) - as always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions about papers to read! These weekly paper reviews can [be delivered weekly to your inbox](https://tinyletter.com/micahlerner/), or you can subscribe to the new [Atom feed](https://www.micahlerner.com/feed.xml)._

[A Linux Kernel Implementation of the Homa Transport Protocol](https://www.usenix.org/system/files/atc21-ousterhout.pdf)

This week's paper review is Part 2 in a series on the Homa Transport Protocol. Part 1 is available [here](TODO). While the first part of the series focuses on describing the goals of Homa, this paper review discusses an implementation of the protocol as a Linux Kernel module{% sidenote 'linuxkernelmodule' "There is a great description of writing your own Linux Kernel module [here](https://linux-kernel-labs.github.io/refs/heads/master/labs/kernel_modules.html)."%}.
