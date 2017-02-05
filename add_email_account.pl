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
# Simple script to add an email account to a postfix/dovecot
# setup configured for flat file lookups and authentication.  
#
# Postfix is configured for non postfix mail store: seperate domains: non unix accounts
# The allowed recipient email addresses for postfix are stored in a vmailbox file. 
# Postfix uses dovecot for authentication.
# Dovecot is configured for virtual users, non unix accounts, using passwd-file. 
# The dovecot user accounts (email addresses) and SHA512-Crypt passwords are stored in
# an authentication file. 
# It is assumed that the root will run the script and the default umask is set to a secure 077.  
#
# Although some file locking checks are implemented, this simple script is not transactional 
# and is only meant for a single admin to run. 
# Concurrently running this script can potentially cause the files to be corrupted !
#
#
#
# Ng Chiang Lin
# Feb 2017
#


use strict;
use warnings;

#Postfix virtual_mailbox_maps file
my $VMAILBOX = "/example_location/postfix/vmailbox";

#Dovecot passwd-file
my $AUTHFILE ="/example_location/nighthour.sg/passwd";

#Postfix postmap binary
my $POSTMAP ="/usr/sbin/postmap";

#Defines minimum password length
my $P_LEN_LIMIT = 12;
#Defines the minimum number for lower, upper letters, symbol and digits
my $P_TYPE_LIMIT =2; 

my $password; 

if(scalar(@ARGV) != 1)
{
   die "Usage: add_email_acct.pl <email address>\n";
}


# Simple check that arg is an allowed email format. 
# The check is not rfc compliant
my $emailadd = $ARGV[0];
$emailadd = lc($emailadd);
if ( not $emailadd =~ /^(?!.*\.\.)[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]\@[a-zA-Z0-9]+\.[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z]$/ )
{
  die "Invalid email address format !\n";

}


# Check the email address to make it doesn't already exists
if (findDuplicate($VMAILBOX))
{
    die "Email already exists in $VMAILBOX !\n";
}


if(findDuplicate($AUTHFILE))
{
  die "Email already exists in $AUTHFILE !\n";
}



$password  = getPass(); 
while ($password eq "")
{
   $password = getPass();
}

my $postfixline = $emailadd . " " . "whatever";
appendEntry($VMAILBOX, $postfixline);

my $cmd = $POSTMAP . " " . $VMAILBOX;
if (system($cmd) != 0 )
{
    
    die "Error running postmap !\n"
        . "User account partially added. To recover, manually remove new email from $VMAILBOX and run postmap\n";
}


my $salt = generateSalt(); 
if($salt eq "")
{
   die "Password salt not generated successfully !\n"
       ."User account partially added. To recover, manually remove new email from $VMAILBOX and run postmap\n" ;
}

my $shadowpass = crypt($password, '$6$' . $salt);

my $dovecot_authline = $emailadd . ":" . $shadowpass ;
appendEntry( $AUTHFILE, $dovecot_authline);

print "Account created\n";


#
# Subrountine to append a line to a file
# Takes the file and the line to be appended as arguments.
#
sub appendEntry
{
    my $fname = shift;
    my $line = shift; 

    open(my $outputfh, ">>$fname") or die "Cannot open file $fname, $!";
    flock($outputfh, 2);
    print $outputfh  $line . "\n";
    close($outputfh); 

}


#
# Subroutine to check if the email address
# already exists in a file. 
# Takes the file to check as argument. 
#
sub findDuplicate
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


#
# Subroutine to prompt for new account password 
# and confirm new password
# Returns password if successful, empty string otherwise
# 
#
sub getPass
{
    my $pass=readPass("Enter Password for Account:");
    $pass =~ s/^\s+|\s+$//g ;
   
    if (!checkPassComplexity($pass))
    {
        print "Password needs to be at least $P_LEN_LIMIT characters\n" 
           . "Contains at least 2 lowercase, 2 uppercase letters, 2 digits and 2 symbols.\n" 
           . "Spaces are not allowed !\n" ;

        return "";
    }

    my $confirm=readPass("Confirm password:");
    $confirm =~ s/^\s+|\s+$//g ;
 
    if($pass eq $confirm)
    {
        return $pass ;
    }
    else
    {
        print "Password does not match \n";
        return ""; 
    }
}

#
# Simple subroutine to check the complexity of 
# password. 
# Takes the password as argument
# Returns 1 if complexity passes or 0 otherwise. 
#
sub checkPassComplexity
{

    my ($symbols,$uppercase, $lowercase, $digits, $spaces, $len) = (0) x 6; 
    my $passwd = shift;
    $len = length($passwd); 
    if($len < $P_LEN_LIMIT )
    {
       return 0; 
    }

    my @schars = split("", $passwd); 

    foreach my $c (@schars)
    {

        if ($c =~ /[a-z]/)
        {
            $lowercase++;   
        }       
        elsif ( $c =~ /[A-Z]/)
        {
            $uppercase++;
        }
        elsif ($c =~/[0-9]/)
        {
            $digits++;
        }
        elsif ($c =~/\s/)
        {
           $spaces++;
        }
        else
        {
           $symbols++;
        }
    }


    if($lowercase < $P_TYPE_LIMIT or $uppercase < $P_TYPE_LIMIT 
       or $digits < $P_TYPE_LIMIT or $symbols < $P_TYPE_LIMIT 
       or $spaces != 0)
    {
        return 0;
    }

    return 1; 
}



#
# Subroutine to read the password from console
# Takes a message to print out as argument
# Returns the password entered. 
#
sub readPass
{
    my $msg = shift; 
    system("stty -echo");
    print "$msg";
    my $in = <STDIN>;
    system("stty echo");
    print "\n";
    return $in;

}

#
# Subroutine to generate a 16 char salt
#
sub generateSalt
{

    my @salt_t = ("a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n",
              "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "A", "B",
              "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P",
              "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "0", "1", "2", "3",
              "4", "5", "6", "7", "8", "9");
    my $data;
    my $rlen;

    # Using urandom in this case
    # For very secure requirements use /dev/random instead but this can block
    # if there is not enough entropy. 
    open (my $ranfh, "</dev/urandom") or die "Cannot open /dev/random \n";
    $rlen = read($ranfh, $data, 16);
    close($ranfh);

    my @dataarr = split("", $data);
    my $salt ="";

    foreach $b (@dataarr)
    {
        my $index = ord($b) % 62 ; 
        $salt = $salt . $salt_t[$index];
    }

    return $salt; 
}

