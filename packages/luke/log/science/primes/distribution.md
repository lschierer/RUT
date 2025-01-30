---

title: "Distribution of Prime Numbers"
date: 
tags:
  - mathematics
layout: rut
---


I over heard Peter asking about how frequently prime numbers occur,
specifically, are they less frequent as numbers get bigger.  This made me
curious.  In the graph below, each data point represents the count of prime
numbers between successive groupings of 1000 numbers.  Thus the first data point
is the count of prime numbers occurring between 0 and 1000, the second data
point the count between 1001 and 2000, and so on. The data was generated with a
fairly simple bash for loop using the bsd-games primes command:

`m=1000; for i in ``seq 0 $m 1000000``; do j=$(( $i+$m )); k=``primes $i $j | wc -l``;  echo "$j $k" >> input.dat; done` 

[[!img distribution.png alt="distribution of prime numbers per 1000" ]]

