---

title: glusterfs woes
date: 2008-10-07 14:40:36
tags:
  -  personal
  -  technical
layout: rut
---

As a correction to my [previous post](http://www.schierer.org/~luke/log/20081001-2244/libfuse2-woes), libfuse2 is not in fact at fault here.  I am able to mount an sshfs with the suid option.  The problem is that *gluster* does not implement the -o option, and so I cannot pass the suid option to the mount, and thus the default of nosuid takes effect.

I am still quite disappointed. 

