---

title: Maildir, imap, and webmail
date: 2005-08-30 15:35:19
tags:
  -  personal
layout: rut
---

<p>Apparently my maildir woes with imap stem from the fact that dovecot cannot handle a mix of maildir and mbox folders.<a href="http://wiki.dovecot.org/moin.cgi/QuestionsAndAnswers#head-ca096174a590558f7ad33420c3ccb62e989ac063">[1]</a> Next I am going to try mailutils-imap4d.</p>  

<p><strong><big>UPDATE 2005-08-30-12:14</big></strong>:  mailutils-imap4d is no good. squirrelmail cannot get its inbox, imp3 cannot log in at all with it.  I am back to dovecot for now.</p>
<font size="-2">[1] Dovecot FAQ http://wiki.dovecot.org/moin.cgi/QuestionsAndAnswers#head-ca096174a590558f7ad33420c3ccb62e989ac063 </font>

