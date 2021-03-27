---
layout: post
title: "Drovorub and Fancy Bear"
categories: 
tags:
- Computer Security
---
Last week the NSA and FBI [released a report](https://media.defense.gov/2020/Aug/13/2002476465/-1/-1/0/CSA_DROVORUB_RUSSIAN_GRU_MALWARE_AUG_2020.PDF) on the "Drovorub" malware, and attributed the malware to the GRU (a branch of Russia's intelligence services). More specifically, they believe that the software was produced by a hacking unit inside of the GRU known as [FancyBear](https://en.wikipedia.org/wiki/Fancy_Bear), APT28, or Strontium (depending on which industry group you're talking to). 

A wide variety of attacks have been attributed to FancyBear over the years, including ones targeting the DNC in 2016 (to sway the election), WADA (to delegitimize the organization's anti-doping case concerning Russian athletes), and the Ukrainian power grid (in support of Russia's ongoing conflict). One of my favorite podcasts, Darknet Diaries, talked about the group and their operations in the episode about [NotPetya](https://darknetdiaries.com/transcript/54/). [Sandworm: A New Era of Cyberwar and the Hunt for the Kremlin's Most Dangerous Hackers](https://www.washingtonpost.com/outlook/the-ruthless-russian-hacking-unit-that-tried-to-crash-ukraine/2019/12/26/beaf477a-1470-11ea-a659-7d69641c6ff7_story.html) is also a great book about the GRU's hacking activity, in particular about targeting the Ukraine electrical grid.
The report is interesting because it details advanced infrastructure used to attack Linux systems. Once the malware burrows into a system, it communicates with a command and control server (a central hub owned by the attacker) via websockets. The NSA/FBI documented how the malware works end to end, including information about how messages between the server and infected machines are authenticated (a fairly involved process).

![](https://firebasestorage.googleapis.com/v0/b/firescript-577a2.appspot.com/o/imgs%2Fapp%2FMivsh%2F8CumQ6yVLk.png?alt=media&token=5c583bcc-facb-49fb-9f11-ba9c119c2e66)

Closing out the report is information about how organizations can detect the malware running on their systems to root out attacks that have already happened or to prevent future attacks from proceeding. I enjoyed this part of the report in particular because it provides concrete next steps to the defenders of IT networks around the world (commonly known in the industry as "Blue Team")
