---
title: Trust the Science
date: "2005-08-29 21:53:31"
tags:
  - ", "personal
---
William emailed me today, apparently the Archdiocease of Philidephia is blocking outgoing port 22, or at least that seems to be the case from a quick email diagnosis.   My first thought solution was to switch him to vnc, I quickly installed tightvncserver and the associated webserver plugin, but that was a no go.  While I can connect to it from both Mozilla Firefox and Microsoft Internet Explorer, he cannot.  I think that problem is <em>likely</em> solvable, but probably not without seeing the computer myself. 

So I set up squirrelmail, to give him webmail access.  While not as nice as pine is even, this will do the job (he was used to William & Mary's webmail afterall), and he might even like it somewhat.  Still, there were problems.  SquirrelMail did not seem to want to fully work with my apache 1.x install, and I did not see an obvious solution.  So I made the rash decision to move to apache 2.x.  Naturally, I did not think ahead here, but just bulldozed my way through, causing a little bit of panic on my part until the last few pieces fell into place.

There was a big catch getting php to work, I needed some extra packages for that.  Then mysql still did not work.  A couple packages later, it looked like I had everything, but it still did not work.  Google reveals that a couple of lines need to be uncommented in the apache2 php.ini file.   That fixes that.   But Gallery is not working.  It is complaining about php_value, how did I fix that for apache 1.x?  I have no clue, and google is not helping this time, at least, not at first.  I eventualy stumble on a page of Gallery's documentation that gives me just enough to remember what I had to add.  But where do I add it?  Here I really come face to face and get a grasp of apache2's modular config files.  It is not hard once you realize what is happening, but it threw me at first.  

Still no go though.  But now at least, I can get to Gallery's setup page, the first page of which fortunately has all sorts of dependency checking.  Thank goodness for small favors, this tells me that I do not have mod_rewrite.  By now I understand a little of what is going on, and it was fairly trivial to realize that it was installed (by something) but not enabled, and to create the necessary symlink.   After that, everything I can think to test is working, and, as an added bonus, my guess was correct: SquirrelMail seems to fully work now.

On a side note, I do not particularly like SquirrelMail, it <em>certainly</em> does not meat my needs, since I have set up a number of maildir mailboxes (which it does not support), but I think it will do enough to meet William's needs.

