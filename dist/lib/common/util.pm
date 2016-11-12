######################################################################
######################################################################
##
## Name: util.pm
##
## Prpose: Collection of nice to have utilities
##
## Author: Jared R. Mallas
##         
## 
## Date: 04/30/2010
##
######################################################################
######################################################################

package common::util;

use strict;
use Socket;
use Sys::Hostname;


use vars qw(@ISA @EXPORT);
use Exporter;

@ISA     = qw(Exporter);
@EXPORT  = qw(hashRefToString printHashRef logRoller getCurrentUser getLocalHost timeStamp checkDir createDir);

#############################################
#############################################
#
#  I always forget how to do this...
#
#  Oh and another thing... You can't use this
#  for a hash thats more than four levels
#  deep... Deal with it.
#
#############################################
#############################################
sub hashRefToString
{
  my($passedInHash) = @_;
  my($key, $secondKey, $thirdKey, $fourthKey);
  my($level, $secondLevel, $thirdLevel, $fourthLevel);
  my($returnScalar);

  foreach $key (sort keys %$passedInHash)
  {
    $secondLevel = $$passedInHash{$key};

    if (ref ($secondLevel) eq 'HASH')
    {

      foreach $secondKey (sort keys %$secondLevel) 
      {
        $thirdLevel = $$secondLevel{$secondKey};

        if (ref ($thirdLevel) eq 'HASH')
        {

          foreach $thirdKey (sort keys %$thirdLevel)
          {
            $returnScalar .= "$key==>$secondKey==>$thirdKey==>$$thirdLevel{$thirdKey}<==\n";
          }

        }
        else
        {
          $returnScalar .= "$key==>$secondKey=>$$secondLevel{$secondKey}<==\n";
        }
      }
    }
    else
    {
      $returnScalar .= "==>$key=>$$passedInHash{$key}<==\n";
    }
  }

  return $returnScalar;
}

sub printHashRef
{
  my ($passedInHash) = @_;
  my($scalar);

  $scalar = hashRefToString($passedInHash);

  print $scalar;
}


#############################################
#############################################
#
# logRoller is used to create iterations or
# copies of log files. For example, if you
# pass in /logs/accept/nohup0.log and 1, the
# log roller will remove nohup1.log rename
# nohup0.log to nohup1.log, and create an
# empty nohup0.log
#
#############################################
#############################################
sub logRoller
{
  my ($logName, $maxIterations) = @_;
  my ($workingStringScalar, $x, $y);

  ## We assume that the log name would be "somethingsomethingsomething.0.log"
  ## the key is to know what the "somethingsomethingsomething" is...

  $x = $maxIterations-1;

  $logName =~ s/.0.log//;

  unlink("$logName.$maxIterations.log");

  while ($x >= 0)
  {
    $y = $x +1;
    rename("$logName.$x.log", "$logName.$y.log");
    $x--;
  }

  open(LOG_FILE, ">$logName.0.log") || die "Log roller is unable to create $logName.\n";

  close LOG_FILE;
}

sub getCurrentUser
{
  # print "The user running this is " . getlogin() . "\n";
  return scalar getpwuid( $< );
}

sub getLocalHost()
{
  return hostname();
}

sub timeStamp
{
  my($format) = $_[0];
  my($return);
  (my $sec,my $min,my $hour,my $mday,my $mon,my $year,my $wday, my $yday, my $isdst) = localtime();
  $year = $year + 1900;
  $mon = $mon + 1;
  if (length($mon)  == 1) {$mon = "0$mon";}
  if (length($mday) == 1) {$mday = "0$mday";}
  if (length($hour) == 1) {$hour = "0$hour";}
  if (length($min)  == 1) {$min = "0$min";}
  if (length($sec)  == 1) {$sec = "0$sec";}
  if ($format == 1) {$return = "$year\-$mon\-$mday $hour\:$min\:$sec";}
  if ($format == 2) {$return = $mon . $mday . $year;}
  if ($format == 3) {$return = substr($year,2,2) . $mon . $mday;}
  if ($format == 4) {$return = $mon . $mday . substr($year,2,2);}
  if ($format == 5) {$return = $year . $mon . $mday . $hour . $min . $sec;}
  if ($format == 6) {$return = $year . $mon . $mday;}
  if ($format == 7) {$return = $mon .'/'. $mday .'/'. $year .' '. $hour .':'. $min .':'. $sec;}
  if ($format == 8) {$return = $year . $mon . $mday . $hour . $min;}
  if ($format == 9) {$return = $mday . '/' . $mon . '/' . $year;}
  return $return;
}

#############################################
#############################################
#
# checkDir is used to verify whether or not
# a directory exists on a particular
# particular filesystem. You might be asking
# yourself, "Why not use the built in perl
# function?" I thought that too, but this is
# primarily used for checking for directories
# on remote machines. 
#
#############################################
#############################################
sub checkDir
{
  my(%passedInHash) = @_;

  my $checkDirCmd;
  ## Use passedInHash like this
  ## $$passedInHash{<someKey>}

  if ($^O =~ m/linux/)
  {
    ## I need to execute something to this effect:
    ## ssh <ID>@<HOST> "if [ -d </some/dir> ]; then exit 0; else exit 1; fi"
    if ($passedInHash{'host'} && $passedInHash{'remoteId'})
    {
      $checkDirCmd = "ssh";
      $checkDirCmd .= " $passedInHash{'remoteId'}\@$passedInHash{'host'}";
      $checkDirCmd .= " \'if \[ -d " . $passedInHash{'dir'} . " \]\; then exit 0\; else exit 1\; fi\'";

      my $stdOut = `$checkDirCmd`;
      my $RC = $?/256;

      return $RC;
    }
    else
    {
      print "\n\n\nUnable to check for existence of a remote directory!!\nutil.pm::checkDir\n\n\n";
      return 0;
    }
  }
  else
  {
    ## Yeah... I know this is weak... I don't
    ## have the time to make this cross
    ## platform at the moment.
    return 0;
  }
}


#############################################
#############################################
#
#############################################
#############################################
sub createDir
{
  my(%passedInHash) = @_;

  my $createDirCmd;
  ## Use passedInHash like this
  ## $$passedInHash{<someKey>}

  if ($^O =~ m/linux/)
  {
    ## I need to execute something to this effect:
    ## ssh <ID>@<HOST> "if [ -d </some/dir> ]; then exit 0; else exit 1; fi"
    if ($passedInHash{'host'} && $passedInHash{'remoteId'})
    {
      $createDirCmd = "ssh";
      $createDirCmd .= " $passedInHash{'remoteId'}\@$passedInHash{'host'}";
      $createDirCmd .= " \'mkdir -p $passedInHash{'dir'}\'";

      my $stdOut = `$createDirCmd`;
      my $RC = $?/256;
      if ($RC > 0)
      {
        print "Unable to create directory!!\n$stdOut\n";
      }

      return $RC;
    }
    else
    {
      print "Unable to create remote directory!!\n";
      return 1;
    }
  }
  else
  {
    ## Yeah... I know this is weak... I don't
    ## have the time to make this cross
    ## platform at the moment.
    return 0;
  }
}
