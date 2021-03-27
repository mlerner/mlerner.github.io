---
layout: book
title: "The Man Who Solved the Market"
author: Gregory Zuckerman
rating: 4
categories:
    - Finance
---

Spurred on by [the announcement](https://www.ft.com/content/6ea8207b-b41a-43df-9737-ae481814a8d4) that the world's most successful hedge fund was beginning to trade bitcoin futures, I decided to read the canonical book about the firm. 

_The Man Who Solved the Market: How Jim Simons Launched the Quant Revolution_ is the story of Renaissance Technologies (also known as RenTech), a firm that has been called [“the best physics and mathematics department in the world”](https://www.telegraph.co.uk/finance/10188335/Quants-the-maths-geniuses-running-Wall-Street.html).

The first three quarters of the book talks about how Jim Simons, the firm's founder, parlayed a position in the top echelons of Math academia into heading a secretive and successful quantitative trading firm. Simons began his career as a cryptologist at Princeton's Institute for Defense Analyses (often shortened to IDA). After vocalizing his beliefs during the Vietnam War led to his firing from IDA, he became the head of SUNY Stonybrook's Math department, which he proceeded to build into one of the best of its time.

The first section of the book also discusses the mathematical contributions of the early characters involved in building RenTech, and I really enjoyed the anecdotes. A few examples of what the early staff did before joining the firm:

- Leonard Baum's work on the `Baum-Welch algorithm`, which can be used to predict the unknown parameters of Hidden Markov Models  (HMM) - an interesting history of Hidden Markov Models is [here](https://ethw.org/First-Hand:The_Hidden_Markov_Model). I wanted to learn more about how HMM work, and this was an [excellent guide](https://towardsdatascience.com/introduction-to-hidden-markov-models-cd2c93e6b781). 
-  Elwyn Berlekamp's work on algebraic coding theory (used to compress, error check, or encrypt data, among other uses) and his study of combinatorial game theory (in short, the application of math to games). He also coauthored [an interesting book series](https://www.amazon.com/gp/product/1568811306/) with *John Conway*, the creator of [Conway's Game of Life](http://www.scholarpedia.org/article/Game_of_Life), about how to play games mathematically. I loved [this video](https://www.youtube.com/watch?v=KboGyIilP6k) of him talking about how to play Dots and Boxes.
- Jim Simon's research on topology. I don't know much about the subject, but definitely a topic to bookmark for later.

Another part of the book I noticed was the recurring connection between poker and the approach that RenTech took in its early days (the book also includes stories of Simons' poker plays). One of the early members of the firm, Elwyn Berlekamp, "argued that buying and selling infrequently magnifies the consequences of each move. Mess up a couple times, and your portfolio could be doomed. Make a lot of trades, however, and each individual move is less important, reducing a portfolio’s overall risk." This approach echoes of poker players who "grind" by only making small, positive expected-value bets that add up over time. Along these lines, Edward Thorp (and his [book](https://www.amazon.com/dp/B07ZWJFYW5) `A Man for All Markets: From Las Vegas to Wall Street, How I Beat the Dealer and the Market`) also come up a number of times - I hadn't read this book, but filing it away for later. 

The last thing that stood out to me about the first half of the book was how the firm participated in forging the path for quantitative investors. Even though RenTech was founded in a time where business compute power was miniscule compared to what is available in 2020, they judiciously used their technology to search for signal among the noise. One way they did this was by simply building, then mining, better datasets than their competitors - for example, by going to the Federal Reserve and digitizing publically available information about past market conditions. Individuals inside the firm were meticulous about cleaning datasets of increasing granularity and making their work available to researchers for modeling purposes. The hunt for alternative datasets that can give an edge to quantitative investors continues today, but many would argue that RenTech led the way.

The last quarter of the book talks primarily about firm politics and how it changed once Simons stepped back from day-to-day management. In particular it discusses how Robert Mercer, the executive that assumed Simons' role, became a key figure in influencing the 2016 election (Mercer has since stepped down). Relative to the rest of the book, learning about firm politics wasn't as interesting and seemed to drag on. Even though this section of the book wasn't as riveting, I think not including it would leave a hole in the RenTech story - it would be unusual if you went on Wikipedia having read a whole book about the firm and were surprised to learn about Mercer, as well as his support of Breitbart and Cambridge Analytica.
