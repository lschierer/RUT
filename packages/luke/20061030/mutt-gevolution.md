---

title: Mutt &amp; gevolution
date: 2006-10-30 18:09:28
tags:
  - ", "pidgin
  - ", "technical
layout: rut
---

Mr. Stefano Zacchiroli's [thoughts][ref1]<sup>[\[1\]][ref1]</sup> on Mutt and gaim's evolution integration have motivated me to write a little on each.

I like mutt.  I really do.  Ever since Mr. Ethan Blanton introduced me to it, it has served me well.  Recently though I started using Mail.app, the OSX mail client, for my personal mail.  I made this change in part to be able to decrease my reliance on gmail and similar for the odd html formatted mail that I want to read, in part for the ease of setup, and in part because the thought of setting up a mail server to send mail from on my laptop is daunting.  I do not trust darwinports to get things right and work consistently all that much, nor do I wish to compile and maintain postfix myself.  This is after all why I use debian on my other machines: to be able to ignore the software that I do not want to actively track and know the details of myself.

But I find myself on OSX for my laptop.  I want to use Quicken, and I want to be able to run the Rosetta language software, even though I do not in fact do so nearly enough to actually make noticeable progress.  It also does not hurt that Civilization, about the only computer game I've remained significantly attracted to since graduating, runs on OSX.  So I find myself leaving mutt some.

Having done so, I can see some other gains.  I have address book integration, which is nice.  So I can, in a theoretical sense, see that if integration between a real address book and an email address book is nice, it might be nice to add in the IM contact list into the mix.  After all, most of the people on the buddy list for my personal accounts are also in my address book.  

Which brings me to gevolution.  I have disliked evolution every time I have touched it.  It is big, consuming more memory than I like.  It is fragile, crashing more than I am willing to put up with in a mail client.  Mail.app's handling of threading is poor, evolution's handing is (or at least was) worse.  Additionally, it pushes me more towards GNOME, and I really do not like the GNOME Desktop Environment.

I appear to not be particularly alone in this dislike of evolution.  As a result, the gevolution plugin, originally written by Mr. Christian (ChipX86) Hammond, is rather neglected.  Mr. Hammond left the project with gevolution in a rather unfinished state, which should not be taken as a detraction from him: most of gaim was then and is still in an unfinished state.  That does not hide the reality though that gevolution, like the rest of gaim, needs a significant amount of Tender Loving Care, but unlike the rest of gaim, is not significantly likely to get any.  

It is very nearly abandoned code.  As such, it is becoming increasingly fragile, and its flaws are going largely unfixed.  When I see this sort of code, my reaction is that we should drop it.  Yes, some users like it, but it is causing problems that we do not intend to invest time fixing.  If someone *really* likes it, they can of course check out an old version of gaim, rip that code out, and make it compile as a 3rd party plugin.

This temptation grows with every bug report I see that ends up being traced to the gevolution plugin.  Bugs about not being able to add or remove buddies, or about slowness, or inexplicable crashes.  What is the solution here?  I am not sure.

<div markdown="1" class="postrefs">
1. Mr. Stefano Zacchiroli.  "dear old mutt"  2006-10-30 http://www.bononia.it/~zack/blog//posts/dear_old_mutt.html
</div>

[ref1]: http://www.bononia.it/~zack/blog//posts/dear_old_mutt.html "dear old mutt"

