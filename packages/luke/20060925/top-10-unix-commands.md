---

title: "top 10 unix commands"
date: 2006-09-25 21:24:47
tags:
  -  personal
  -  technical
layout: rut
---

luke@server1:~$ history|awk '{print $2}'|awk 'BEGIN {FS="|"} {print $1}'|sort|uniq -c|sort -rn|head -10<br />
     90 ls<br />
     71 cd<br />
     49 vi<br />
     28 mv<br />
     20 rm<br />
     18 screen<br />
     17 cp<br />
     16 ssh<br />
     16 cat<br />
     15 sudo<br />
luke@server1:~$ 


