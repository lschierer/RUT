---

title: "Gaim forks"
date: 2006-10-17 15:43:29
tags:
  -  pidgin
  -  technical
layout: rut
---

Today in the gaim forum<sup>[\[1\]][ref1]</sup>, a user proposed forking gaim because of the slowness and selfishness with which we proceed.<sup>[\[2\]][ref2]</sup>  If it happens it will not be the first such fork, but rather the third or forth such.  The only unique thing about it will be that will be libgaim based.

I have always a little bit contemptuous of true forks, because they have consistently been started by users who clearly have no clue how much work we put into gaim.  Precisely because they were unprepared for that level of effort, these forks have quickly failed.

A libgaim based "fork" would be a different matter entirely.  It would not, in fact, be a true fork at all, and to call it one is to utterly mistake why we worked so hard to split gaim into a UI and a library, into "gaim" and "libgaim."

We *want* there to exist other interfaces.  You want an interface that integrates with GNOME to a significant degree?  GREAT!  Grab libgaim, and even grab our existing Gtk UI if you like any aspect of it, and write one.  You want an interface built to fit in with KDE?  Awesome, grab libgaim, break out your QT API reference, and get busy.  OSX?  I personally think Adiumx does a reasonable job, for all I have a few differences of opinion with them, but hey, if you do not want to help them with their libgaim based efforts, write a second (or third, considering Proteus) one.  Dissatisfied with wingaim?  I *sincerely* hope that someone will write a better UI for windows users than we provide.  

The point here is that we have what is (in my opinion) one of the best back-end code bases available, with better (though far from perfect) protocol support than most other projects have been able to generate.  Why should that effort be duplicated?  It represents 2/3rds of the necessary code to run a successful IM client project.  That is a *ton* of effort essentially being wasted when we duplicate it over and over again.  Effort that we believe could be better used to make more things work for more users.

But while it is clear that supporting the varied protocols requires a huge chunk of very similar code, it is far from clear that it is possible for any one interface to fully please all users.  I go so far as to argue, consistently, that it is in fact *impossible* for any given interface to be the best for everyone.

The only reasonable way to approach this then is to enable people to write interfaces that meet their needs while avoiding the duplication of effort that starting from scratch entails.  This requires libgaim, or at least some equivalent.  We here in gaim could never support the N interfaces that we foresee, or at least hope to see, eventually existing.  But now we will not need to.  The source is there for your use, grab it, and lets see what you can do with it, what sort of interface you design.  I wish you the best of luck!


<div markdown="1" class="postrefs">
1.  Gaim currently uses a SourceForge forum at https://sourceforge.net/forum/forum.php?forum_id=665
2. zerkkk.  "Gaim fork"  Users Helping Users Gaim forum.  2006-10-17.  https://sourceforge.net/forum/forum.php?thread_id=1594038&forum_id=665
</div>

[ref1]: https://sourceforge.net/forum/forum.php?forum_id=665 "Users Helping Users, Gaim SourceForge forum"
[ref2]: https://sourceforge.net/forum/forum.php?thread_id=1594038&forum_id=665 "Gaim Fork"

