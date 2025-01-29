---
title: Trust the Science
date: "2008-10-02 03:44:31"
tags:
  - ", "technical
---
Discovered tonight that libfuse2 forces fuse file systems, such as gluster, to mount with nodev,nosuid.  This means that I cannot host an ikiwiki with CGI support on a gluster file system.  This does not please me. 

I would really like to see this, and read/write shared mmaps (for spamprobe and similar) to be supported in fuse file systems (and naturally gluster in particular). 

