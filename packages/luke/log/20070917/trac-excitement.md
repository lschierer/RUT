---

title: "trac excitement"
date: 2007-09-17 16:30:32
tags:
  -  pidgin
layout: rut
---

In the days immediately preceding the 2.2.0 release, I called for some time to be spent looking at the growing backlog of bugs and enhancement requests that has accumulated in trac since we went public with pidgin and finch.   Sean in particular responded beyond my hopes, closing more than 100 tickets in just a few days!!

In related news, Ethan, with the help of one of the trac developers, managed to nail the source of our continual problems with trac.  By eliminating the drop down that listed the people to whom a ticket could be assigned, he *radically* reduced the performance hit we take by running trac on our server.  The load average has dropped from 10+ to 3-5, and the CPU utilization is down in the 20-40% range instead of the 100-110% range (possible only because we are a vmware guest I suspect, how else could you use 110% of your processor?).

Overall, we are responding faster to more issues since we left SF's trackers for trac, while still maintaining a relatively fast development cycle.  In the months to come, hopefully we will nail an even greater chunk of the incoming tickets, and come up with a better way for translators to interact with the project. 

Despite this though, we are continually being told that we are unresponsive to our users, and insulted for our decisions.  Only this morning, for example, we were told that 90% of users think that every change we have made since the first 2.0.0 beta is a step backwards.  When the user failed to come up with anything other than vague insults and obvious red-herrings in more than 10 minutes, we removed him from the channel.  This is regrettable, not that we removed him, but that it was necessary.  We try very hard to listen to everyone who approaches us with comments and criticism of our work.  While we cannot take all the advice we receive, it is physically impossible, and in fact do not take much of it, we *have* reversed unpopular decisions and/or worked with various segments of the user base to come up with some compromise.  

Still, I honestly think that (almost) no one *really* cares about the exact graphic used for the available state.  For years I have seen people asking about replacing this graphic or that graphic, or even all of them.  Such people have been genuinely concerned that the specific graphic used for this or that was poorly chosen.  The complaints about the green circle do not (with a few rare exceptions) match that pattern.  Rather, people complain about the graphic being "huge" even though it is the same size as the protocol icon it replaced.  Alternatively, they complain about it being ugly, but want to replace it not with a different icon representing available, but with an option to use it as an emblem over the protocol icon instead.  If the icon itself, and not the removal of the protocol icons, was the problem, then returning the protocol icons and returning status to an emblem would not be the solution.  Similarly, the icon is clearly only "huge" in relation to the very small emblems that previously denoted state. 

That being said, it will be interesting to see *if* the complaints change in light of the new option to see protocol icons merged in for 2.2.0.  I suspect that they will not, though hopefully the (relatively) few users who tried to remain rational in the firestorm debates that have come up since 2.0.0, will be pleased.  

