#!/usr/bin/perl
# 
# This is free and unencumbered software released into the public domain.
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
#
# In jurisdictions that recognize copyright laws, the author or authors
# of this software dedicate any and all copyright interest in the
# software to the public domain. We make this dedication for the benefit
# of the public at large and to the detriment of our heirs and
# successors. We intend this dedication to be an overt act of
# relinquishment in perpetuity of all present and future rights to this
# software under copyright law.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE. 
#
#
#
# Simple script to delete an email account to a postfix/dovecot
# setup configured for flat file lookups and authentication.  
# Postfix is configured for non postfix mail store: seperate domains: non unix accounts
# The allowed recipient email addresses for postfix are stored in a vmailbox file. 
# Postfix uses dovecot for authentication.
# Dovecot is configured for virtual users, non unix accounts, using passwd-file. 
# The dovecot user accounts (email addresses) and SHA512-Crypt passwords are stored in
# an authentication file. 
# Before deleting the original postfix vmailbox files and dovecot authentication file are 
# backed up into a backup directory
# It is assumed that the root will run the script and the default umask is set to a secure 077.  
#
# Although some file locking checks are implemented, this simple script is not transactional 
# and is only meant for a single admin to run. 
# Concurrently running this script can potentially cause the files to be corrupted !
#
# Ng Chiang Lin
# Feb 2017
#


use strict;
use warnings;
use File::Path;

#Postfix virtual_mailbox_maps file
my $VMAILBOX = "/example_location/postfix/vmailbox";

#Dovecot passwd-file
my $AUTHFILE ="/example_location/nighthour.sg/passwd";

#User account that owns the dovecot $AUTHFILE
my $DOVEAUTH="doveowner";

#Postfix postmap binary
my $POSTMAP ="/usr/sbin/postmap";

#The Backup directory for $VMAILBOX and $DOVEAUTH
#The trailing / is required.
my $BACKDIR = "/example_location/backup/";

#The directory containing the virtual domain, the user email directories are inside here. 
#The trailing / is required
my $MAIL_DOMAIN_DIR="/example_location/virtualdomains/nighthour.sg/";

#Unix chown binary
my $CHOWN_CMD="/bin/chown";


my $password; 
my $emailadd;
my $delete; 


if(scalar(@ARGV) < 1 or scalar(@ARGV) > 2)
{
   die "Usage: delete_email_acct.pl <email address>\n" 
       ."       delete email_acct.pl -R <email address>\n"
       ."       -R means to delete the email account mail directory as well\n";
}

if(scalar(@ARGV) == 1)
{
    $emailadd = $ARGV[0];
}
else
{
    $delete = $ARGV[0]; 
    $emailadd = $ARGV[1];
}

$emailadd = lc($emailadd);

# Simple check that arg is an allowed email format. 
# The check is not rfc compliant
if ( not $emailadd =~ /^(?!.*\.\.)[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]\@[a-zA-Z0-9]+\.[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z]$/ )
{
    die "Invalid email address format !\n";
}

if(scalar(@ARGV) == 2)
{
    if (not $delete =~/-R/i )
    {
        die "Invalid deletion option, use -R or -r to delete the account mail directory\n"; 
    }
}



# Check the email address to make sure it exists
if (not findEmail($VMAILBOX))
{
    die "Email doesn't exist in $VMAILBOX !\n";
}

if(not findEmail($AUTHFILE))
{
  die "Email doesn't exist in $AUTHFILE !\n";
}


backupFile($VMAILBOX);
deleteEntry($VMAILBOX);

my $cmd = $POSTMAP . " " . $VMAILBOX;
if (system($cmd) != 0 )
{
    
    die "Error running postmap !\n"
        . "User account partially deleted. Check $VMAILBOX and rerun $POSTMAP manually.\n"
        . "Manually remove from $AUTHFILE and delete user directory if needed.\n";
}



backupFile($AUTHFILE);
deleteEntry($AUTHFILE);
$cmd = $CHOWN_CMD ." " . $DOVEAUTH . ": " . $AUTHFILE;
if (system($cmd) != 0 )
{
    
    die "Error setting ownership of $AUTHFILE !\n"
        . "User account partially deleted. Check and manually set ownership of $AUTHFILE \n"
        . "Delete user directory if needed.\n";
}


if(scalar(@ARGV) == 2)
{
  my @parts = split(/@/, $emailadd); 
  my $dpath = $MAIL_DOMAIN_DIR . $parts[0];
  # deletes the email account directory. The email address has already been verified earlier
  # to make sure that it is the right format. 
  rmtree($dpath);
  print "Account deleted\n";
}
else
{
  print "Account deleted. Manual removal of mail directory required !\n";
}


#
# Backup an existing file to the backup directory
# Takes the file to be backed up as argument
#
sub backupFile
{
    my $fname = shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =localtime();
    my $mth = 1 + $mon ;
    my $yr = $year + 1900;
    my @parts = split(/\//, $fname);
    my $index = scalar(@parts) - 1;
    my $vfilename = $parts[$index];

    my $backfile = $BACKDIR . $vfilename . "-$mday-$mth-$yr-$hour$min$sec" ;

    open(my $ifp, "<$fname") or die "Cannot open file $fname, $!"; 
    flock($ifp, 1);

    open(my $ofp, ">>$backfile") or die "Cannot open file $backfile, $!"; 
    flock($ofp, 2);
    seek($ofp, 0, 0); 
    truncate($ofp, 0);

    while(my $line = <$ifp>)
    {
        print $ofp $line ; 
    }

   close($ifp);
   close($ofp); 

}



# Delete a line that contains an email address from 
# a file
# Takes the file name of the file containing the email address
# as argument
#
sub deleteEntry
{

    my $fname = shift;
    my $tmpfile = $fname . ".tmp"; 
 
    open(my $ifp, "<$fname") or die "Cannot open file $fname, $!"; 
    flock($ifp, 1);

    open(my $ofp, ">>$tmpfile") or die "Cannot open file $tmpfile, $!"; 
    flock($ofp, 2);
    seek($ofp, 0, 0); 
    truncate($ofp, 0);

    while(my $line = <$ifp>)
    {
        $line =~ s/^\s+|\s+$//g ;
        if(  not $line  =~ /$emailadd/i and not $line eq "")
        {
            print $ofp $line . "\n" ; 
        }
    }

   close($ifp);
   close($ofp); 

  rename($tmpfile, $fname);


}


#
# Subroutine to check if the email address
# already exists in a file. 
# Takes the file to check as argument. 
#
sub findEmail
{
   my $fname = shift;
   open(my $inputfh, "<$fname") or die "Cannot open file $fname, $!";
   flock($inputfh, 1);
   while (my $line = <$inputfh>)
   {
         $line =~ s/^\s+|\s+$//g ; 
         if( $line  =~ /$emailadd/i )
         {
            close($inputfh);
            return 1;
         }

   }

   close($inputfh);
   return 0; 
}




