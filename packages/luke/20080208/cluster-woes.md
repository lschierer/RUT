---
title: Trust the Science
date: "2008-02-08 18:13:23"
tags:
  - ", "personal
  - ", "technical
---
We are having issues with ocfs2.  These *might* be solved by upgrading to a newer kernel, but it is not easy to find newer amd64 kernels with xen support.  Either way, it is leaving us in a bad position, where one node will frequently find itself unable to create more than a few new files at a time.  This means that monotone operations, tar -x operations, and compiling things are really out of the question in /home.  Not good at all.  

Vincas suggested OpenAFS, which seems similar to the glusterfs that I have been working with some.  These offer a client/server model, more like an nfs replacement than an actual file system.  This could work well, though it is not quite as clean, to my mind, as ocfs2.  Since we are already using ldap, synchronizing UIDs isn't a problem, so file permissions should work fine with either, or even with nfs.  

OpenAFS has the advantage of having debian packages.  One thing to keep in mind is that Dan dislikes it, though I do not know why.  He's certainly come down against some worthy software, while liking some less capable software, but on the other hand, his impressions are often sound.  

Glusterfs is newer, and does not yet have real debian packages, though there are packages from a third party that the gluster guys have included in their wiki.  On the other hand it has Dan approval.  I am not really sure how which would make a more stable platform for us.  

