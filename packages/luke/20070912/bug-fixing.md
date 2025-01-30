---

title: Bug fixing
date: 2007-09-12 18:54:55
tags:
  - ", "personal
  - ", "technical
layout: rut
---

I spent some time with the wp-randomquotes plugin today.  I noticed a few months ago that it was not displaying every quote in the database, and this has been increasingly annoying me.

It took me longer than it should have to track down what was up.  The problem was that when I delete a quote (which I have done a few times, because there have been times I have entered in one poorly), it does not backfill the quote ID number.  So my quote database goes 1 4 ... 17 18 20 ... 102.  The plugin, when it goes to display all quotes, does an sql query to get all quotes into a single array, which it then counts.  Naturally enough, as you can infer from the above, it finds 99 quotes.  It then iterates from 0 to 100, attempting to find a quote for each $i.  If there is no quote at a given $i (such as $i=2), it skips it.  It gets quote 100 because it increments $i after the test but before it tries to pull the quote.  But it misses quotes 101 and 102 because $i is now larger than 99.  

The solution is to have two iterators, both of which start at 0.  Iterate $i from 0 to 99, when you reach $j = 99, stop.  Inside that while loop, there was already a test for an empty quote, have that increment $j instead of $i.  Then make sure you increment $j after a successful query after displaying the relevant quote.  If you increment it too early, you'll skip the quote you just found.  If you fail to increment it, you will find the same quote repeatedly. This way $j will grow faster for $i, with the difference between them at any given time being equal to the number of deleted quotes that have been reached at that point of the process.  So that when $i = 99, $j = 102.  Then all the quotes display.  

