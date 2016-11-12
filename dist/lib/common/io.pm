######################################################################
######################################################################
##
## Name: io.pm
##
## Prpose: Collection of common input / output subroutines
##
## Author: Jared R. Mallas
##         
## 
## Date: 04/30/2010
##
######################################################################
######################################################################

package common::io;

use strict;
use File::Basename;

use vars qw(@ISA @EXPORT);
use Exporter;

@ISA     = qw(Exporter);
@EXPORT  = qw(writeToLog argvToHash propFileToHash txtFileToScalar);

#############################################
#############################################
#
# Subroutine used to standardize how
# log files are written...
#
#############################################
#############################################
sub writeToLog
{
  my ($logToWrite, $refToString, $formatKey) = @_;
  my ($formatHead, $formatTail, %txtHashForms, %webHashForms);
  my ($stringToWrite) = $$refToString;
  chomp($stringToWrite);
  $txtHashForms{'Indent0'} = "";
  $txtHashForms{'Indent1'} = "  ";
  $txtHashForms{'Indent2'} = "$txtHashForms{'Indent1'}$txtHashForms{'Indent1'}";
  $txtHashForms{'Indent3'} = "$txtHashForms{'Indent1'}$txtHashForms{'Indent2'}";
  $txtHashForms{'Indent4'} = "$txtHashForms{'Indent2'}$txtHashForms{'Indent2'}";
  $txtHashForms{'Indent5'} = "$txtHashForms{'Indent2'}$txtHashForms{'Indent3'}";
  $txtHashForms{'Indent6'} = "$txtHashForms{'Indent3'}$txtHashForms{'Indent3'}";
  $txtHashForms{'Indent7'} = "$txtHashForms{'Indent3'}$txtHashForms{'Indent4'}";
  $txtHashForms{'Indent8'} = "$txtHashForms{'Indent4'}$txtHashForms{'Indent4'}";
  $txtHashForms{'Indent9'} = "$txtHashForms{'Indent4'}$txtHashForms{'Indent5'}";
  $txtHashForms{'Mark0'}   = "";
  $txtHashForms{'Mark1'}   = "**";
  $txtHashForms{'Mark2'}   = "->";
  $txtHashForms{'Mark3'}   = "-->";
  $txtHashForms{'Mark4'}   = "=>";
  $txtHashForms{'Mark5'}   = "==>";
  $txtHashForms{'Mark7'}   = "*>";
  $txtHashForms{'Mark8'}   = "!>";
  $txtHashForms{'Mark9'}   = "!!";
  $txtHashForms{'Markd'}   = "d  ";
  
  my (@formatArray) = split /:/ , $formatKey;
  my ($indVar) = "Indent$formatArray[1]";
  my ($marVar) = "Mark$formatArray[2]";

  if ($formatArray[0] =~ /t/ | $formatArray[0] =~ /o/ | $formatArray[0] =~ /e/)
  {
    $stringToWrite =~ s/^/$txtHashForms{$indVar}$txtHashForms{$marVar} /g;
    $stringToWrite =~ s/\n/\n$txtHashForms{$indVar}$txtHashForms{$marVar} /g;
    $formatHead = "";
    $formatTail = "";
  }
  elsif ($formatArray[0] =~ /w/)
  {
    $formatHead = "";
    $formatTail = "";
  }
  else
  {
    $formatHead = "";
    $formatTail = "\n";
  }
  
  if ($formatArray[0] =~ /t/ | $formatArray[0] =~ /w/)
  {
    open(LOG_FILE, ">>$logToWrite") || die "Unable to open log file $logToWrite.\nAttempted to write: $stringToWrite\n";
    print LOG_FILE "$formatHead$stringToWrite$formatTail\n";
    close LOG_FILE;
  }
  elsif ($formatArray[0] =~ /o/)
  {
    print STDOUT "$formatHead$stringToWrite$formatTail\n";
  }
  elsif ($formatArray[0] =~ /e/)
  {
    print STDERR "$formatHead$stringToWrite$formatTail\n";
  }

}

#############################################
#############################################
#
# Subroutine used to standardize how
# arguments are parsed...
#
# Supported parameter formats:
# 
# "Standard Format"
#  -parameter value
#   *OR*
#  -parameter val1 val2
#  * Resulst in a variable named "parameter"
#  * with it's value set to
#  * "value" or "val1 val2"
# 
# "Switch Format"
#  -switch
#  * Results in a variable named "switch"
#  * with it's value set to "1"
#   
# "Boolean Format"
#  -condition true|false
#  * Results in a variable named "condition"
#  * with it's value set to "true"
#   
#############################################
#############################################
sub argvToHash
{

  ## Setup local / default variables:
  my (@wipArray, @wipArrayTwo, $x, %parameterHash);
  my ($wipScalar, $element);

  ## You should have passed in an array and a
  ## list by reference, array for the arg string,
  ## and a list of valid parameters...
  my ($refToArgV, $refToValidParams) = @_;

  ## Dice up valid parameters and set up their defaults
  ## print "DICING UP VALID PARAM LIST!!\n\n";
  foreach $element (split ', ', $$refToValidParams)
  {
    ## If the valid parameter has a : in it, there is a
    ## default value...
    ## print $element . "\n";
    if ($element =~ m/:/)
    {
      $wipScalar = (split ':', $element)[0];
      ## print $wipScalar . "\n";
      $parameterHash{$wipScalar} = (split ':', $element)[1];
    }

  }

  ## Cut up ArgV array into list
  @wipArray = @$refToArgV;
  $wipScalar = join(' ', @wipArray);
  # chomp($wipScalar);

  $#wipArray = -1;

  @wipArray = split(' -', $wipScalar);
  # shift @wipArray;

  foreach $x (0..$#wipArray)
  {
    $wipScalar = $wipArray[$x];
    $wipScalar =~ s/^-//;
    ## print "This should be one parameter set --->" . $wipScalar . "<---\n";
    @wipArrayTwo = (split ' ', $wipScalar);
    if ($#wipArrayTwo == 0)
    {
      # This is a switch
      $parameterHash{$wipArrayTwo[0]} = 1;
    }
    else
    {
      ## Unless the current var is already assigned a value,
      ## and that var is not "appendable"
      unless($parameterHash{$wipArrayTwo[0]} && isAppendable($wipArrayTwo[0]))
      {
        $wipScalar = shift @wipArrayTwo;
        $parameterHash{$wipScalar} = join (' ', @wipArrayTwo);
      }
      else
      {
        $wipScalar = shift @wipArrayTwo;
        $parameterHash{$wipScalar} .= " " . join (' ', @wipArrayTwo);
      }

      chomp($parameterHash{$wipScalar});
    }
    
  }

  ## THE FOLLOWING NEEDS TO BE ADDRESSED LATER!!
  ## Determine valid vs invalid parameters

  ## Parse argv into var names and types

  ## Populate referenced hash

  ## Return the hash...

  return %parameterHash;
}

#############################################
#############################################
#
# Subroutine for parsing property files
# into a hashmap
#
#############################################
#############################################
sub propFileToHash
{
  my ($propFile) = @_;
  my ($propFileName) = basename($propFile);
  my (%propertyHash, $lineRead, @wipArray, $dataChunk);

  open (PROPFILE, $propFile) || die "Unable to read $propFile!!\n\n";

  $dataChunk = "common";

  while ($lineRead = (<PROPFILE>))
  {
    chomp $lineRead;

    $lineRead =~ s/^\s+//;
    $lineRead =~ s/\s+$//;

    unless ($lineRead eq "" || $lineRead =~ m/\#/)
    {
      if ($lineRead =~ m/^\[/)
      {
        # print "hit if-check for bracket!!\n";
        $lineRead =~ s/^\[ //;
        $lineRead =~ s/\ ]$//;
        $dataChunk = $lineRead;
      }
      else
      {
        @wipArray = split ('=' , $lineRead);
  
        $propertyHash{$dataChunk}{$wipArray[0]} = $wipArray[1];
      }
    }

  }

  return %propertyHash;
}

#############################################
#############################################
#
# Subroutine for globbing the contents of
# a text file into a scalar
#
#############################################
#############################################
sub txtFileToScalar
{
  my ($outfile) = @_;
  my $scalar;

  open(FILETOREAP, "<$outfile");

  while (<FILETOREAP>)
  {
    $scalar .= $_;
  }

  close FILETOREAP;

  unlink $outfile;

  return $scalar;
}

sub isAppendable
{
  my ($tester) = @_;
  my ($validAppendables, $element);

  # print "Entering isAppendable!\n";

  $validAppendables = qq/acls/; 
  
  foreach $element (split ', ', $validAppendables)
  {
    if ($tester =~ m/^$element$/)
    {
      print "$element is appendable!!\n";
      return 1;
    }
  }

  return 0;
}
