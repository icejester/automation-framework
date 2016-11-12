################################################################################
################################################################################
##
## Name: throttle.pm
##
## Prpose: Provide a mechanism to contain an arbitrary number of
##         running commands, capture the stderr / stdout and 
##         return codes of those commands, and report on the active
##         status of the commands
##
## Author: Jared R. Mallas
##         
## 
## Date: 11/11/2010
##
## Details: You should recieve a list of hashes formatted like this:
## { cmd => "ls -l", stdout => "", stderr => "", rc => 0, pid => 0, proc => "" };
##
## Example: (tmp.pl)
##
## use lib "/some/directory/automation/Production/dist/lib";
## 
## use common::throttle;
## use strict;
##
## my $someScalar;
## my $thing;
## my %resultHash;
## my %cmdHash;
## my $key;
## 
## $someScalar = common::throttle->new();
## 
## $cmdHash{'1'} = { cmd => "sleeper.ksh 8", stdout => "", stderr => "", rc => 0, pid => 0 };
## $cmdHash{'2'} = { cmd => "sleeper.ksh 2", stdout => "", stderr => "", rc => 0, pid => 0 };
## $cmdHash{'3'} = { cmd => "sleeper.ksh 1", stdout => "", stderr => "", rc => 0, pid => 0 };
## $cmdHash{'4'} = { cmd => "sleeper.ksh 9", stdout => "", stderr => "", rc => 0, pid => 0 };
## $cmdHash{'5'} = { cmd => "sleeper.ksh 2", stdout => "", stderr => "", rc => 0, pid => 0 };
## 
## $someScalar->CmdQueue(\%cmdHash);
## $someScalar->ThrottleLimit(4);
## 
## $someScalar->execute();
## 
## $thing = $someScalar->CompletedCmdQueue;
## %resultHash = %$thing;
## 
## for $key (sort keys %resultHash)
## {
##   print "KEY: $key\n";
##   print "  Value: $resultHash{$key}";
##   print "CMD=>$resultHash{$key}{'cmd'} ";
##   print "RC=>$resultHash{$key}{'rc'} ";
##   print "PID=>$resultHash{$key}{'pid'}\n";
## }
## 
################################################################################
################################################################################

package common::throttle;

use strict;

use Proc::Background;
use common::util;

################################################################################
################################################################################
##
## Spin up and execute what has been added to queue.
##
################################################################################
################################################################################
sub execute
{
  my $self = shift;
  my ($queueHashRef, %tempQueue, $tempQueueKey);
  my ($runningHashRef, %tempRun, $tempRunKey);
  my ($doneHashRef, %tempDone, $tempDoneKey);
  my ($keyCount, $RC, $PID);
  if ($self->{Verbosity} > 0){ print "Throttle initialized with $self->{ThrottleLimit}\n"; }

  # Move object from the CmdQueue to the ActiveCmdQueue then
  # to the CompletedCmdQueue.
  # { cmd => "ls -l", stdout => "", stderr => "", rc => 0, pid => 0, proc => "" }

  $queueHashRef = $self->{CmdQueue};
  %tempQueue = %$queueHashRef;

  $runningHashRef = $self->{ActiveCmdQueue};
  %tempRun = %$runningHashRef;

  $doneHashRef = $self->{CompletedCmdQueue};
  %tempDone = %$doneHashRef;

  foreach $tempQueueKey (sort keys %tempQueue)
  {
    # Should give me 1, 2, 3, 4...
    if ($self->{Verbosity} > 1){ print "Adding Command: $tempQueue{$tempQueueKey}{'cmd'} to running queue\n"; }
    $tempRun{$tempQueueKey} = $tempQueue{$tempQueueKey};
    delete($tempQueue{$tempQueueKey});
    $tempRun{$tempQueueKey}{'proc'} = Proc::Background->new($tempRun{$tempQueueKey}{'cmd'});

    if ($self->{Verbosity} > 0){ print "Added Command: $tempRun{$tempQueueKey}{'cmd'} to running queue\n"; }
    $keyCount = keys %tempQueue;
    if ($self->{Verbosity} > 1){ print "Cmd queue count: $keyCount\n"; }

    $keyCount = keys %tempDone;
    if ($self->{Verbosity} > 1){ print "Done queue count: $keyCount\n"; }
    if ($self->{Verbosity} > 2){ printHashRef(\%tempDone); }

    $keyCount = keys %tempRun;
    if ($self->{Verbosity} > 1){ print "Run queue count: $keyCount\n"; }
    if ($self->{Verbosity} > 1){ printHashRef(\%tempRun); }

    while ($keyCount >= $self->{ThrottleLimit})
    {
      if ($self->{Verbosity} > 1){ print "Throttle is full...\nLooking to see if the procs are done...\n"; }
      ## Check to see if any procs have finished...
      foreach $tempRunKey (sort keys %tempRun)
      {
        ## If you find a completed proc, remove it from 
        ## the running queue and add it to the completed queue.
        ## You may notice (and be confused by) the use of "bless."
        ## Bless marks the variable as a type of Proc::Background so
        ## we can invoke the "alive" method.

        ### print "Here is the proc value stored in tempRun: $tempRun{$tempRunKey}{'proc'}\n";
        unless(bless($tempRun{$tempRunKey}{'proc'}, "Proc::Background")->alive)
        {
          if ($self->{Verbosity} > 0){ print "Process $tempRunKey completed!\n"; }
          $RC = bless($tempRun{$tempRunKey}{'proc'}, "Proc::Background")->{_exit_value};
          $PID = bless($tempRun{$tempRunKey}{'proc'}, "Proc::Background")->pid;
          $tempRun{$tempRunKey}{'rc'} = $RC/256;
          $tempRun{$tempRunKey}{'pid'} = $PID;
          $tempDone{$tempRunKey} = $tempRun{$tempRunKey};
          delete($tempRun{$tempRunKey});
        }
        else
        {
          if ($self->{Verbosity} > 1){ print "Process named $tempRunKey is still alive!!\n"; }
        }
        $keyCount = keys %tempRun;
      }
      sleep 2;
    }
  }

  while ($keyCount > 0)
  {
    foreach $tempRunKey (sort keys %tempRun)
    {
      ## If you find a completed proc, remove it from
      ## the running queue and add it to the completed queue.
      ## You may notice (and be confused by) the use of "bless."
      ## Bless marks the variable as a type of Proc::Background so
      ## we can invoke the "alive" method.

      ### print "Here is the proc value stored in tempRun: $tempRun{$tempRunKey}{'proc'}\n";
      unless(bless($tempRun{$tempRunKey}{'proc'}, "Proc::Background")->alive)
      {
        if ($self->{Verbosity} > 0){ print "Process $tempRunKey completed!\n"; }
        $RC = bless($tempRun{$tempRunKey}{'proc'}, "Proc::Background")->{_exit_value};
        $PID = bless($tempRun{$tempRunKey}{'proc'}, "Proc::Background")->pid;
        $tempRun{$tempRunKey}{'rc'} = $RC/256;
        $tempRun{$tempRunKey}{'pid'} = $PID;
        $tempDone{$tempRunKey} = $tempRun{$tempRunKey};
        delete($tempRun{$tempRunKey});
      }
      else
      {
        if ($self->{Verbosity} > 1){ print "Process named $tempRunKey is still alive!!\n"; }
      }
      $keyCount = keys %tempRun;
    }
    sleep 4;
  }

  foreach $tempDoneKey (sort keys %tempDone)
  {
    ### print "Key: " . $tempDoneKey . "\n";
    ### print "  Value: " . $tempDone{$tempDoneKey} . "\n";
    ### printHashRef($tempDone{$tempDoneKey}{proc});
    $RC = bless($tempDone{$tempDoneKey}{proc}, "Proc::Background")->{_exit_value};
    ### print "Captured RC of: " . $RC/256 . "\n";
  }

  $self->{CmdQueue} = \%tempQueue;
  $self->{CompletedCmdQueue} = \%tempDone;
  $self->{RunningCmdQueue} = \%tempRun;
  ### print "LEAVING EXECUTE!!\n";
}

################################################################################
################################################################################
##
## Object constructor
##
################################################################################
################################################################################
sub new
{
  my $self = {};
  my $cmdQueue = undef;
  my %compQueue;
  my $verbosity;
  my $compQueueRef = \%compQueue;
  $self->{CmdQueue} = $cmdQueue;
  $self->{ActiveCmdQueue} = {};
  $self->{CompletedCmdQueue} = $compQueueRef;
  $self->{ThrottleLimit} = undef;
  $self->{Verbosity} = $verbosity;

  bless($self);
  return $self;
}

################################################################################
################################################################################
##
## getter / setter for "CmdQueue"
##
################################################################################
################################################################################
sub CmdQueue
{
  my $self = shift;
  if (@_)
  {
    $self->{CmdQueue} = shift;
  }

  return $self->{CmdQueue};
}

################################################################################
################################################################################
##
## getter / setter for "ActiveCmdQueue"
##
################################################################################
################################################################################
sub ActiveCmdQueue
{
  my $self = shift;
  if (@_)
  {
    $self->{ActiveCmdQueue} = shift;
  }

  return $self->{ActiveCmdQueue};
}

################################################################################
################################################################################
##
## getter / setter for "CompletedCmdQueue"
##
################################################################################
################################################################################
sub CompletedCmdQueue
{
  my $self = shift;
  if (@_)
  {
    $self->{CompletedCmdQueue} = shift;
  }

  return $self->{CompletedCmdQueue};
}

################################################################################
################################################################################
##
## getter / setter for "ThrottleLimit"
##
################################################################################
################################################################################
sub ThrottleLimit
{
  my $self = shift;
  if (@_)
  {
    $self->{ThrottleLimit} = shift;
  }

  return $self->{ThrottleLimit};
}

################################################################################
################################################################################
##
## getter / setter for "Verbosity"
## 
################################################################################
################################################################################
sub Verbosity
{
  my $self = shift;
  if (@_)
  {
    $self->{Verbosity} = shift;
  }

  return $self->{Verbosity};
}

################################################################################
################################################################################
##
## EXAMPLE OF HOW TO MODIFY CONTENTS OF THIS STRUCTURE
##
################################################################################
################################################################################
## sub modContents
## {
##   my $self = shift;
## 
##   my @tempArray;
##   my $tempScalar = $self->{CmdQueue};
##   my @tempArray = @$tempScalar;
##   $tempArray[0]{'number'} = 999;
##   $tempArray[1]{'number'} = 999;
## 
##   $self->{CmdQueue} = \@tempArray;
##   
##   return $self->{CmdQueue};
## }
##
################################################################################
################################################################################

1;
