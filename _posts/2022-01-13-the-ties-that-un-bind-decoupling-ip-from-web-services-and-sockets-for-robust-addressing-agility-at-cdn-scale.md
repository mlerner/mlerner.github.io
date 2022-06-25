---
layout: post
title: "The Ties that un-Bind: Decoupling IP from web services and sockets for robust addressing agility at CDN-scale"
intro: This week's paper is from a conference earlier in 2021 (SIGCOMM 2021). I'm also trying out a new format for the paper reviews, your thoughts are greatly appreciated.
include_default_intro: true
categories:
---

[The Ties that un-Bind: Decoupling IP from web services and sockets for robust addressing agility at CDN-scale](https://dl.acm.org/doi/10.1145/3452296.3472922)

## What is the research?

The research in  _The Ties that un-Bind: Decoupling IP from web services and sockets for robust addressing agility at CDN-scale_ describes CloudFlare's work to decouple networking concepts (hostnames and sockets) from IP addresses.

{% maincolumn 'assets/ties/fig1.png' '' %}

By decoupling hostnames and sockets from addresses, CloudFlare's infrastructure can quickly change the machines that serve traffic for a given host, as well as the services running on each host - the authors call this approach _addressing agility_.

## What are the paper's motivations?

The paper notes _reducing IP address use_ as the initial motivation for decoupling IP addresses from hostnames. The authors argue that CDNs don't necessarily need large numbers of IP addresses to operate - this is in contrast with the fact that, "large CDNs have acquired a massive number of IP addresses: At the time of this writing, Cloudflare has 1.7M IPv4 addresses, Akamai has 12M, and Amazon AWS has over 51M!"

Traditionally, many CDNs use large numbers of IPs because their architecture (shown in the figure below) places entry and exit points on the public internet - entry points receive requests from clients, while exit points make requests to origin servers on cache miss{% sidenote 'arch' '[These docs](https://www.cloudflare.com/learning/cdn/glossary/origin-server/) on "What is an origin server?" are helpful.'%}. For these machines to be reachable, they need public IP addresses.

{% maincolumn 'assets/ties/fig2.png' '' %}

Other factors can increase a CDN's IP address usage. CDNs may bind specific IPs to hostnames, creating a relationship between the number of hostnames served by the CDN and the number of addresses the CDN requires. Furthermore, CDN servers normally have an upper bound on networking sockets{% sidenote 'socketover' "Network connections have read/write buffers for connections, as well as a kernel data structure called [`sk_buff`](https://wiki.linuxfoundation.org/networking/sk_buff). More info [here](https://stackoverflow.com/a/8732314)."%}, so increased client usage also translates into more machines (and associated IP addresses).

## How does it work?

The paper focuses on two types of bindings:

- _Hostname-to-address_ bindings control how hostnames (like `www.micahlerner.com`) map to IP addresses/machines that can serve requests
- _Address-to-socket_ bindings control how services running on machines{% sidenote 'sockets' "For a reference on network sockets, I have really enjoyed [Beej's Guide to Networking Programming](https://beej.us/guide/bgnet/)"%} service client requests.

First, the paper describes how CloudFlare can quickly and dynamically update _hostname-to-address_ bindings by changing configurations called _policies_ - DNS servers ingest _policies_ and use them to decide which IP addresses to return for a given hostname.

{% maincolumn 'assets/ties/fig3.png' '' %}

One example policy allows hostnames to map to IP addresses randomly chosen from a set of candidates (called a _pool_). Using _policies_ instead of fixed mappings from hostnames to IP addresses is in contrast with other deployments, where changing _hostname-to-IP address_ mappings is both operationally complex and error-prone.

The second major change to IP addressing decouples _address-to-socket_ bindings.

Normally a service receives traffic on a fixed set of ports - this approach has several downsides, including that each socket has overhead (meaning a fixed number of services can run on each machine) and it isn't possible to run two services with overlapping ports on the same machine without complications{% sidenote 'sameport' "The paper notes one approach, using `INADDR_ANY` (relevant documentation [here](https://man7.org/linux/man-pages/man7/ip.7.html)), that allows one socket to receive packets sent to all interfaces on a machine. This approach doesn't come without its downsides, like potentially introducing security issues - if internal traffic goes to the same socket as external traffic, an internal service could accidentally respond to external requests."%} (as they can't re-use the same port).

{% maincolumn 'assets/ties/fig4.png' '' %}

To addresses these challenges, CloudFlare's system introduces _programmable socket lookup_{% sidenote 'crowded' "The CloudFlare blog has more background [here](https://blog.cloudflare.com/its-crowded-in-here/)."%}, using BPF{% sidenote 'bpf' "eBPF/BPF have come up a few times in past paper reviews, and I really like [this post](https://jvns.ca/blog/2017/06/28/notes-on-bpf---ebpf/) from Julia Evans on the topic."%} (as part of the implementation, the authors built [`sk_lookup`](https://lwn.net/Articles/819618/){% sidenote 'ebpf' "There is also a greta tutorial [here](https://ebpf.io/summit-2020-slides/eBPF_Summit_2020-Lightning-Jakub_Sitnicki-Steering_connections_to_sockets_with_BPF_socke_lookup_hook.pdf)." %}). This approach routes traffic inside of the kernel based on rules. An example rule could route client traffic to different instances of the same service running side-by-side, with a separate socket for every instance.

{% maincolumn 'assets/ties/fig5.png' '' %}

## Why does the research matter?

The paper discusses a number of performance and security benefits that _addressing agility_ provides - importantly, these benefits are available with no discernible change to other important system metrics!

First, decoupling _hostname-to-address_ and _address-to-socket_ bindings allows the CloudFlare CDN{% sidenote 'transfer' "The paper notes that the approach is transferable to external deployments as well, with a few caveats." %} to operate with fewer IPs. Addresses no longer need to be reserved for use by a specific host name and machines can now have significantly more sockets. Fewer IP addresses impacts cost and lowers barrier to entry - the paper notes that the IP space owned by the major cloud providers is worth north of 500 million USD (if not more).

The IP addresses that CloudFlare does continue to use are also become easier to manage. Dynamically allocating IP addresses to hostnames turns the operational task of taking machines (and the associated addresses) offline into a matter of removing addresses from the pool provided to clients.

Furthermore, the randomization approach described (where IP addressess from a pool are returned in response to DNS queries) by the paper results in better load balancing.

{% maincolumn 'assets/ties/fig7.png' '' %}

While the paper discusses the scalability benefits _addressing agility_ provides, it also discusses other implications beyond limiting address use - as an example, the approach can help with Denial of Service attacks.

If a specific address is under attack, the traffic to that address can be blackholed{% sidenote 'blackholed' "CloudFlare's reference on blachole routing [here](https://www.cloudflare.com/learning/ddos/glossary/ddos-blackhole-routing/)."%}. If a hostname is under attack, the traffic to that hostname will be distributed evenly across machines in the address pool.
