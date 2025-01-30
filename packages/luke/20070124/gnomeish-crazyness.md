---

title: GNOMEish crazyness
date: 2007-01-24 19:07:17
tags:
  -  pidgin
  -  technical
layout: rut
---

Today, as I was updating the software on my iBook, I noticed that metacity was installed.  I do not use metacity at all, much less on my iBook running MacOS X, so my natural reaction was to remove it.  I was rather surprised to find that doing so was not all that straightforward.  This is one of the things that I find inadequate in darwinports, that when I am trying to remove software that things depend on, I have to remove each manually and in order.  It cannot sort through the list of packages on the command line and sort them appropriately for me.  But I am going down a tangent here.

Returning to the topic at hand, I found that I had to remove the gnome python desktop stuff.  Since nothing appeared to depend on it, I assumed that it must be something I installed by mistake, and removed it.  

Then I go to see if gramps is installable yet.  A significant number of ports have been upgraded since I last tried, so this is a reasonable experiment.  What is the first package it pulls as darwinports tries to install it?  Metacity.

Again, I do not use metacity at all.  Gramps runs just fine on my linux desktop.  Metacity is *clearly* <strong><em>not</em></strong> a dependency of gramps.  Why is it being pulled then?

The problem with many GNOME programs (of which gramps is one), is that the authors consider the case of using the software with something other than the default GNOME environment as an afterthought at best.  Thus to require a window manager for a graphical program makes some sense.  *But I do not use that window manager, and any of a number of other ones work perfectly well with gramps.*  So *why* in the world must I have metacity?  Only because the authors of GNOME are infested with a lets-take-over-the-world attitude.

Those of us developing gaim are not like that.  We know full well that gaim is not and never will be the best client for everyone.  That is why we are working on the core/ui split, so that others can write their own interface, one that better fits their needs, without duplicating all of the work that goes into making that interface run.  Open source is, or at least should be, about choices.  We ought not to forget that.

