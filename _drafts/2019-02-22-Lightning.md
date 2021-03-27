---
layout: post
title: 'A simple introduction Bitcoin Lightning [Part 1]'
date: '2019-01-13 00:00:00Z'
categories: post
---

I've seen several explanations of Lightning, and all of them have seemed overly
complex, or have required substantial prior knowledge. As part of a "Paper
Club" (??? link to Hunter) I helped lead at Bitwise, I really got into the
nitty gritty of how Lightning works, and was able to scope out parts of the
protocol that I didn't understand. Notably, this article focuses only on how
payment channels, one of the main features of Lightning, works. There are other
components to the protocol, but if one understands payment channels, you have
gotten most of the knowledge needed to go a step further to understand routing,
HTLCs and other more advanced topics that I will cover in a future post. This
post does require some prior knowledge about Bitcoin, which is mostly covered 
in a chapter of [Mastering
Bitcoin](https://www.oreilly.com/library/view/mastering-bitcoin/9781491902639/ch02.html).

As a quick review, one must understand how a Bitcoin transaction is structured.
A Bitcoin transaction contains inputs and outputs. The inputs point to
previously created outputs resulting from other transactions. Inputs require
signatures that authorize the spending of the outputs that are being used.
Bitcoin transactions are bundled together by miners and placed in a block that
points at a previous block.
