---
layout: post
title: "Seven years in the life of Hypergiants' off-nets"
categories:
intro: These paper reviews can [be delivered weekly to your inbox](https://newsletter.micahlerner.com/), or you can subscribe to the [Atom feed](https://www.micahlerner.com/feed.xml). As always, feel free to reach out on [Twitter](https://twitter.com/micahlerner) with feedback or suggestions!
---

[Seven years in the life of Hypergiants' off-nets](https://dl.acm.org/doi/pdf/10.1145/3452296.3472928)

## What is the research?

Many large tech organizations{% sidenote 'faang' "For example, Akamai, [FAANG/MAGMA/MANGA/other abbreviations](https://news.ycombinator.com/item?id=29032516), and Alibaba."%} (also known as _hypergiants_) serve multimedia content (like video and games){% sidenote 'cdn' 'There is a [related talk](https://youtu.be/jGnVcCQUCdk), _Internet Traffic 2009-2019_ from Craig Labovitz that describes how the, "Internet is now largely a video and game delivery system".'%} to users all around the world. Serving this content with low latency poses difficult technical challenges. One solution is placing servers close to users in _off-net_{% sidenote 'offnet' 'This approach is called _off-net_ because the servers are "off" the main network.' %} networks that consumers directly connect to via their Internet Service Provider (ISP){% sidenote 'eyeball' 'Networks that consumers directly connect to are sometimes called [eyeball networks](https://en.wikipedia.org/wiki/Eyeball_network) - more information on these peering arrangements is [here](https://archive.ph/19jFb).'%}.

{% maincolumn 'assets/hypergiants/figure1.png' '' %}

The authors argue that understanding off-nets is important, as the growth of the pattern could change internet structure, routing, and performance. At the same time, there was limited tooling to understand the prevalence of off-net services, meaning that researchers had minimal visibility into the pattern's impact. The paper aims to address this problem by increasing internet observability, and unlocking future research into off-nets.

## What are the paper's contributions?

The paper makes three main contributions:

- Development of a new approach to characterize off-nets, providing a new dataset on their deployment.
- Validation of the approach using third-party datasets.
- Analysis of the off-net dataset, providing insight into the pattern's usage worldwide by multiple large tech organizations.

## How does the system work?

### Methodology

One of the paper's main goals is reliably detecting hypergiant off-nets worldwide.

The paper's implementation differs from previous attempts to characterize off-nets. Prior research relied on DNS resolvers{% sidenote 'yt' "See example paper on studying [Youtube's server selection](https://ieeexplore.ieee.org/document/5961681). Interestingly, this paper used [PlanetLab](https://planetlab.cs.princeton.edu/), a global research network that was truly ahead of its time!"%} or enumerating patterns in hypergiant DNS records{% sidenote 'nflxenumerate' "See [Open Connect Everywhere: A Glimpse at the Internet Ecosystem through the Lens of the Netflix CDN](https://arxiv.org/abs/1606.05519), a paper on Netflix's [Open Connect](https://openconnect.netflix.com/en/) or [this blog post](https://anuragbhatia.com/2018/03/networking/isp-column/mapping-facebooks-fna-cdn-nodes-across-the-world/) on Facebook's CDN."%} to find servers. Both approaches had their downsides - for example, the first could stress open DNS resolver infrastructure, while the latter relied on fragile DNS enumeration techniques.

To implement their solution, the authors use a new approach that relies on two datasources,  _Transport Layer Security (TLS) certificates_{% sidenote 'tls' "There is great background on TLS from Julia Evan's blog - see [Dissecting a TLS certificate](https://jvns.ca/blog/2017/01/31/whats-tls/), and her [related zine](https://wizardzines.com/comics/certificates/)."%} and _HTTP(s) fingerprints_.

Predominantly all{% sidenote 'tlsadopt' "See [this report](https://www.f5.com/labs/articles/threat-intelligence/the-2021-tls-telemetry-report) on TLS usage."%} hypergiants use _TLS certificates_  to encrypt user traffic. Because hypergiants deploy the same services in off-nets and on-nets, similar certificates are present on servers in both network types - as a result, it is theoretically possible to identify off-nets for a hypergiant if a server on the network is reusing the same certificate on-net.

The paper discusses several complications with putting this idea into practice:

- For legacy reasons, subsidiaries of a hypergiant might not be using the same certificates - the paper cites LinkedIn and Github (acquisitions of Microsoft) using different certificates than the parent company.
- Hypergiants issue certificates for customers to deploy to their own servers, so the presence of a certificate doesn't necessarily mean the server is owned by the hypergiant{% sidenote 'cloudflare' "Cloudflare [provides this option for customers](https://developers.cloudflare.com/ssl/origin-configuration/origin-ca/), meaning that one would have a Cloudflare signed certificate on _your_ origin server."%}.

To limit the impact of these complications, the approach implemented by the paper also verifies _HTTP(S) fingerprints_, checking that a candidate off-net server returns stable/known headers for a given hypergiant.

{% maincolumn 'assets/hypergiants/table1.png' '' %}

The implementation combines both _TLS certificates_ and _HTTP(s) Fingerprints_ in a two pass process.

The first pass scrapes valid TLS certificates from a Hypergiant's on-nets, searching for the name of the organization in the Subject Info of returned certificates{% sidenote "certigo" "There are open source tools for inspecting TLS certificates, including [certigo](https://github.com/square/certigo), that you can use!"%}. Using this data, the system issues queries to IP addresses outside of a hypergiant to identify candidate off-net servers (looking for a TLS certificate match).

Because of the complications (discussed above) of solely relying on certificates to determine off-nets, the paper then makes a second pass over the candidate off-net servers using _HTTP(S) Fingerprints_. If a server returns headers matching the expected hypergiant{% sidenote 'first' "From the first pass, a candidate off-net server has a matching certificate with a hypergiant on-net server." %}, the implementation mark that the off-net server's IP address belongs to hypergiant off-net.

From there, the IPs are mapped to an Autonomous System (AS){% sidenote 'as' "See Cloudflare's docs on [Autonomous Systems](https://www.cloudflare.com/learning/network-layer/what-is-an-autonomous-system/)."%}. As ASes can represent large networks with defined ownership, this mapping{% sidenote 'routeviews' "The paper links to a few resources it uses, one of which is a neat tool called [RouteViews](http://www.routeviews.org/routeviews/index.php/map/)."%} is helpful to develop an understanding of when a hypergiant has a server in a network owned by an [internet service provider (ISP)](https://en.wikipedia.org/wiki/Internet_service_provider) or another organization that provides internet service to consumers.

### Validation

The paper validates its approach to finding off-nets and assigning them to hypergiants in three ways: _comparing to open source datasets_, _consulting with the hypergiants themselves_, and _evaluating relative to previously published results_.

First, the authors compare gathered certificates and their assignments to hypergiants against open source databases, namely [Rapid7](https://opendata.rapid7.com/sonar.ssl/) and [Censys](https://search.censys.io/certificates?q=). The three datasets roughly match, although the existing Rapid7 and Censys datasets have fewer data points{% sidenote 'fewer' 'The authors note their "scan found around 20% more addresses, which we attribute to two causes. First, both Rapid7 and Censys have to respond to complaints and remove IP addresses from their scans. As both scans have run for years, more address space is excluded over time. A second reason for this difference is that our scan took almost four days to execute, which may trigger less rate limiting than the other, faster scans."' %}.

{% maincolumn 'assets/hypergiants/table2.png' '' %}

The authors also consulted with four hypergiants on the veracity of the paper's dataset:

> All four agreed that the estimation of the off-net footprint is very good. One HG operator indicated that 6% of ASes we identified as hosting the HG’s off-nets were not on the HG’s list, and 11% from the HG’s list were not uncovered by our technique (while also indicating that the HG’s list may not be 100% correct)

Lastly, the paper compares against previous research on Facebook and Netflix off-nets, finding that the paper's dataset roughly matches. A fun anecdote from the Facebook-related identification comes from [Anurag Bhatia's blog](https://anuragbhatia.com/2022/07/networking/isp-column/facebook-cache-fna-updates-july-2022/):

> Back in 2019, I was in San Francisco, California for NANOG 75. While roaming around in the lobby, someone read the NANOG card hanging around my neck and greeted me. His 2nd line after greeting was “Oh I know that name, you are the guy who mapped our caching nodes” and we both laughed. I must say this specific category of the post has brought some attention around.

## How is the dataset evaluated?

After verifying the dataset, the paper performs three main analyses: _hypergiant off-net footprint growth_, _calculating hypergiants' reach to the world's internet users_, and _hypergiant deployment overlap_.

To measure _hypergiant off-net footprint growth_, the paper considers counts of ASes where a given hypergiant is present, as well as the size of the network measured by "customer cones"{% sidenote 'caida' 'Sizing is based on [CAIDA](http://www.caida.org/data/active/as-relationships/) AS relationship dataset, which indicates, "Small ASes have customer cones ≤ 10 ASes, Medium ASes have customer cones ≤ 100 ASes, Large ASes ≤ 1000 ASes, and XLarge ASes > 1000 ASes."'%}. Interestingly, the authors call out that hypergiants are present in many more Large/XLarge ASes than is typical for the internet (5% for hypergiants, vs 0.5% for the rest of the internet) - this conclusion makes sense in light of off-net deployments aiming to reach as many customers as possible.


{% maincolumn 'assets/hypergiants/figure3.png' '' %}
{% maincolumn 'assets/hypergiants/figure5.png' '' %}

The paper also represents off-net deployments by region. It is possible to see growth in off-net locations from hypergiants like Facebook, who the authors note started heavily investing in an internal CDN mid-2017{% sidenote 'traffic' "The paper cites [this article](https://seekingalpha.com/article/3613736-apple-microsoft-and-facebook-bring-traffic-to-in-house-cdns-impacting-akamais-media-business) when discussing FB's movie. [Engineering Egress with Edge Fabric: Steering Oceans of Content to the World](https://research.facebook.com/publications/engineering-egress-with-edge-fabric/) on the Facebook blog also discusses integration with many networks around the world. I hope to read papers on traffic engineering in a future paper review!" %}.

{% maincolumn 'assets/hypergiants/figure6.png' '' %}

These regional investments in off-nets impact the ability to put content closer to users, as visible from an increase to the percent of Internet users connected to "ASes hosting Facebook’s off-net servers".

{% maincolumn 'assets/hypergiants/figure9.png' '' %}

Lastly, the paper graphs the total number of ASes with off-nets, and the presence of hypergiants in them. Since 2013, the distinct number of ASes with a hypergiant has grown significantly. As of mid-2021, if an AS hosts any off-net for a top four hypergiant, it is very likely to also host an off-net for another of the top four. At the same time, the number of ASes that host more than one hypergiant has grown significantly.

{% maincolumn 'assets/hypergiants/figure10.png' '' %}

## Conclusion

I found this paper interesting as it creates a novel datasource based on publically available networking information (now made usable due to the increase in TLS-based encryption). Beyond developing a new methodology, the authors verify it using baselines from previous studies, advancing the internet observability state of the art. High performance networking and traffic engineering at scale makes for a fascinating set of technical topics, and I'm looking forward to diving into related research in future paper reviews.