---
layout: post
title: "Design and Evaluation of IPFS: A Storage Layer for the Decentralized Web"
categories:
---

[Design and Evaluation of IPFS: A Storage Layer for the Decentralized Web](https://research.protocol.ai/publications/design-and-evaluation-of-ipfs-a-storage-layer-for-the-decentralized-web/trautwein2022.pdf)

## What is the research?

This paper discusses the open source [IPFS](TODO link) project, a file store distributed on computers around the world. While many associate the idea of the "decentralized web" with cryptocurrencies, IPFS does not natively support (nor require) a crypto token{% sidenote 'protocol' "I haven't covered crypto projects on this blog (yet), but I know giving them even a slight acknowledgement can be a divisive topic :) That said, one of main developers of the projects is involved with FileCoin TODO."%} Similar to technologies like BitTorrent{% sidenote 'bittorrent' "TODO bittorrent explanation"%}, the project is permissionless, and relies on distributed systems primitives (like distributed hash tables{% sidenote 'kademlia' "TODO talk about kademlia" %}).

The authors argue that IPFS can reduce single-points of failure in internet architecture by providing a distributed storage layer.

## What are the paper's contributions?

The paper makes three main contributions:

- Design and implementation of IPFS
- Creation and verification of measurement techniques to understand the network
- Evaluation of the distributed network structure and per-node performance

## How does the system work?

The goal of IPFS is to distribute data across a network of nodes, while ensuring that the data is fetchable in the future.

To accomplish this goal, the network implements three core functionalities:

- _Content addressing_: data in the network is uniquely identified so that future requesters of the data can fetch it using a given key
- _Peer addressing_, which allows nodes in the network to find and connect to one another.
- _Content indexing_, which allows nodes to share that they're storing certain data and track what neighbors in the network are hosting.

### Content Addressing

To simplify storing and fetching data from the network, IPFS nodes create multi-part _content identifiers_ for items. Each _content identifier_ contains a version, encoding of the data (for example, JSON or protobuf), and a hash of the data{% sidenote 'hash' "TODO describe that there are multiple hashing algorithms that could be used"%}. The hash of the data is particularly useful for checking the results of future fetches (as one can hash the result, then compare it to the expected hash).

TODO figure 1

Each file in the network is divided into ~256kb _chunks_ and given a _content identifier_. These chunks are then connected in a [Merkle Directed Acyclic Graph](https://proto.school/merkle-dags) - "A Merkle-DAG is a data structure similar to a Merkle-tree but without balance requirements."{% sidenote 'merkle' "Merkle tree-like datastructures show up in a number of places in computer science, like TODO see references in https://en.wikipedia.org/wiki/Merkle_tree"%} A main reason for using a DAG instead of a tree to represent relationships between chunks is that allowing chunks to have multiple parents means saved space (TODO).

### Peer Addressing

Nodes in IPFS identify themselves using a _multiaddress_ that contains multiple layers of information required to reach the node. These layers include the network layer (protocol and address), transport layer (protocol and port).

TODO figure 2

One of the top layers is the P2P layer, which contains IPFS specific ways for nodes to identify themselves. In particular,
peers in IPFS rely on public-key cryptography{% sidenote "pkc" "TODO link to description of public-key cryptography"%} to identify themselves, and publish a hashed public key to uniquely identify themselves (_Peer ID_).

### Content Indexing

Nodes in the network store metadata on where other files in the network are. The technique that IPFS uses is called a _distribtued hash table_, and is similar to BitTorrent's implementation (TODO reference bittorrent implementation){% sidenote 'bittorrent' "TODO note how this is different than main Kademlia spec"%}

IPFS implements two types of peering to the DHT - _clients_ and _servers_. _Clients_ have limited capabilites and exist so that nodes can participate in the network, without gumming up the works if they are non-reachable. For example:

> "DHT Clients only request records or content from the network but do not store or provide any of them. The DHT client/server distinction prevents unreachable peers from becoming part of other peers’ routing tables, thus speeding up the publication and retrieval processes."

### IPFS in Action

There is a multistep process for a node to publish data, for that data to be reachable by other nodes, and for other nodes to retrieve it.

TODO figure 3

First, a node imports data locally and gets a _content identifier_ that uniquely identifies the data. Then, the node publishes a _provider record_ (TODO reference provider record code) to nearby neighbors in the DHT{% sidenote 'diff' "The paper notes several differences from the Kademlia spec, talk about them TODO"%}, effectively announcing that the new data is available on the network. To limit staleness of these records, IPFS nodes implement two parameters: a _republish interval_ (which ensures that there is a minimum number of nodes aware of the content), and an _expiry interval_ (which requires a provider of the data to continously refresh the record).

Once another node wants to retrieve a specific piece of content from the network, it connects to peers in the network and performs the _BitSwap protocol_. TODO describe bitswap. If all chunks are not found at this stage, the requester walks the DHT in order to find peers that have it stored. If the requester contacts a node that doesn't have the data stored (and only has the _provider record_, which indicates that the data exists somewhere in the network), the node redirects to the actual location of the data.

The paper also touches on the idea of IPFS Gateways, which serve as user-friendly entrypoints speaking HTTP. Gateways also "pin" data to speed up retrieval in the future. The paper references a list of publically available gateways [here](https://ipfs.github.io/public-gateway-checker/).

## How is the research evaluated?

The paper evalutes the structure and performance of the IPFS network.

To understand the scale of the deployed IPFS network, the authors built a scraper that periodically fetches and stores metadata about the network, including peers and their uptime{% sidenote 'ipfs' "TODO this is very cool that they store data for the study on IPFS https://bafybeigkawbwjxa325rhul5vodzxb5uof73neszqe6477nilzziw5k5oj4.ipfs.dweb.link "%}.

TODO figure 4

The paper then uses this dataset to quantify the distribution of nodes around the world and their presence in Autonomous Systems (TODO AS see the hypergiant paper). Grouping by peer count per country - "The US (28.5%) and China (24.2%) dominate the share of peers, followed by France (8.3%), Taiwan (7.2%), and South Korea (6.7%)." After mapping peer IDs to Autonoumous zones, a surprisingly low share of nodes are hosted on cloud providers.

TODO Table 3

The paper also measures the churn of nodes in order to track the health of the network. Over time, many nodes go offline or experience downtime.

TODO figure 8

### IPFS Performance Evaluation

Single node performance is critical for ensuring that the IPFS network remains functioning and healthy. To evaluate this, the paper considers the performance of core tasks that a node performs: _publication_, _retrieval_

## Conclusion

The IPFS paper is interesting as it represent a new implementation on some of the past ideas introduced by other distributed networks (including BitTorrent). I enjoyed reading about how the paper has taken the Kademlia DHT and tweaked it to suit their needs, based on experience from production. IPFS represents an interesting extension of past work, and it will be interesting to see if it is capable of providing high-quality p2p storage while maintaining its goal of decentralization.
