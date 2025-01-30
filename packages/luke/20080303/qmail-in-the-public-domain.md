---

title: Qmail in the public domain!
date: 2008-03-03 16:29:58
tags:
  - ", "personal
  - ", "technical
layout: rut
---

Today I learned that qmail was released to the public domain back in November.[^200803031]  Vincas tells me that he informed me of this change back in November when it happened, and that I was not interested.  I do not know where my head was at the time.

As we are now looking at using qpsmtpd for auth and greylisting, it is entirely feasible to put qmail behind it instead of postfix, and to ditch mailman in favor of ezmlm.  I am thinking that this might be the best way to go, particularly now that there is a route forward for qmail.  One of the flaws in it has historically been that its development simply does not move, at all. 

For this reason I am thinking that I would look at netqmail and not qmail itself, as there are more developers for it.  


[^200803031]: Dr. D. J. Bernstein.  <http://cr.yp.to/qmail/dist.html>, I learned this after reading MJ Ray, "Removing messages from a qmail queue is not a FAQ" MJR's slef-reflection. 2008-03-03 <http://mjr.towers.org.uk/blog/2008/debian#qmailremove>

