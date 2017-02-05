# Perl scripts to manage email accounts for Postfix/Dovecot setup 

## Introduction
The repository contains a few simple perl scripts for managing email accounts on a postfix/dovecot setup. 
Postfix is a popular mail server (Mail Transfer Agent) that uses SMTP (Simple Mail Transfer Protocol) for sending and receiving emails. 
Dovecot is a POP3 (Post Office Protocol 3) and IMAP (Internet Message Access Protocol) server that allows email client like mozilla thunderbird to retrieve user emails. Together they function as a complete mail system and is quite popular for hosting emails on a
unix-like system, such as ubuntu. 

In this particular setup, Postfix is configured for virtual domains, non unix accounts and non postfix mail store. Dovecot is configured
for virtual users and uses passwd-file as authentication. The perl scripts in the repository help to automate the management of email accounts in such a setup. 

Refer to the following sites for more information on Postfix and Dovecot

[http://www.postfix.org/](http://www.postfix.org/)

[https://www.dovecot.org/](https://www.dovecot.org/)


## Usage Information

There are 3 perl scrpts, add_email_account.pl, delete_email_account.pl and set_email_password.pl. It is assumed the root user will be running these script and the default umask for the user has been set to 077. The umask setting of 077 is for file security, it means that files created by the root user will only be readable/writable by the root user and no one else. The perl scripts are not meant for concurrent execution, it is assumed that the root user will be the only one running the script. 

The scripts contain specific variables pertaining to the postfix/dovecot setup. These have to be configured properly.  
Briefly the main variables are

* $VMAILBOX refers to the location of the postfix virtual_mailbox_maps that contains valid recipient addresses.
* $AUTHFILE refers to the location of the passwd-file that Dovecot uses for user account authentication. 
* $MAIL_DOMAIN_DIR refers to the location where the user mail directories are located. 
* $BACKDIR refers to a backup directory used for storing backup copies of $VMAILBOX and $AUTHFILE.
* $DOVEAUTH refers to the user account that owns the $AUTHFILE file. 

Look through the scripts to understand how it works.  

## Running the scripts
To add a new email account.

>perl add_email_account.pl mytestaccount@nighthour.sg 

To delete a email account without deleting off its email directory containing the user emails.

>perl delete_email_account.pl mytestaccount@nighthour.sg 

To delete a email account and its email directory

>perl delete_email_account.pl -r mytestaccount@nighthour.sg

To set/reset password for an account

>perl set_email_password.pl mytestaccount@nighthour.sg


## Source signature
Gpg Signed commits are used for committing the source files. 

> Look at the repository commits tab for the verified label for each commit. 

> A userful link on how to verify gpg signature in [https://github.com/blog/2144-gpg-signature-verification](https://github.com/blog/2144-gpg-signature-verification)



