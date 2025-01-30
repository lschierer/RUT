---

title: unix utilities rock
date: 2006-11-30 16:23:13
tags:
  - ", "personal
  - ", "technical
layout: rut
---

Bossman asks "can you write a script that makes a tar.gz of each user in the /home dir please?"

After a couple false starts involving the bash for loop (which I still think could solve the problem), and a quick glance at the find man page, I produce the one line result.

<code>find /home -type d -mindepth 1 -maxdepth 1 -exec tar cvf {}.tar.gz {} ';'</code>



