#!/usr/bin/perl
########################################################
########################################################
##
## Name:    Control.pl
## Author:  Jared R. Mallas
##          
## Purpose: Main controller script for Framework jobs
## Usage:
## 
########################################################
########################################################
use lib "$ENV{'AFHOME'}/lib";

use strict;

use common::io;
use common::util;

######################################################################
####################### Begin Mainline ###############################
######################################################################

# Setup local variables including valid parameter list;
my (%paramHash, %argHash);
my($validParameterList, $returnCode);
my $exitCode = 0;

$validParameterList = qq/group, application, state, jobtype/;
$validParameterList .= qq/, norun:0, debug:0, logType:o, mainLog/;

# Read in passed in arguments
%argHash = argvToHash(\@ARGV, \$validParameterList);
$paramHash{'Control.args'} = \%argHash;

setPath(\%paramHash);

if ($paramHash{'Control.args'}{'debug'} > 0)
{
  writeToLog($paramHash{'mainLog'},
  \"Beginning Framework job\nThe following arguments were passed:",
  "o:0:1");

  writeToLog($paramHash{'mainLog'},
  \hashRefToString($paramHash{'Control.args'}),
  "o:0:1");
}

# Determine Base (the root of the framework)
deriveAFHome(\%paramHash);

# Gather all vars from property files
gatherProperties(\%paramHash);

unless($paramHash{'Control.args'}{'logType'} == "o")
{
  # Set up main log
  $paramHash{'mainLogName'} = $paramHash{'Control.args'}{'group'} . "_" . 
      $paramHash{'Control.args'}{'application'} . "_" . 
        $paramHash{'Control.args'}{'state'} . "-" . 
          $paramHash{'Control.args'}{'jobtype'} . ".0.log";
  
  $paramHash{'mainLog'} = $paramHash{'Control.properties'}{'common'}{'logDir'} . "/" . $paramHash{'mainLogName'};
  
  $paramHash{'job.properties'}{'mainLog'} = $paramHash{'mainLog'};
  
  if ($paramHash{'Control.args'}{'debug'} > 0)
  {
    writeToLog($paramHash{'mainLog'},
    \"\n\nRolling main log:\n\n",
    "o:0:1");
  }
  
  # Roll main logs (invoked from Util)
  logRoller($paramHash{'mainLog'}, $paramHash{'Control.properties'}{'common'}{'LogCount'});
}

# Produce job header:
writeToLog($paramHash{'mainLog'},
\genHeader(\%paramHash),
"$paramHash{'Control.args'}{'logType'}:0:0");

writeToLog($paramHash{'mainLog'},
\"Setting up job:\n\n",
"$paramHash{'Control.args'}{'logType'}:0:1");

# Setup the executing job..
$exitCode = setUpJob(\%paramHash);

if ($paramHash{'Control.args'}{'debug'} > 1)
{
  writeToLog($paramHash{'mainLog'},
  \"Printing out job properties after initial setup:\n\n",
  "$paramHash{'Control.args'}{'logType'}:1:2");

  writeToLog($paramHash{'mainLog'},
  \hashRefToString($paramHash{'job.properties'}),
  "$paramHash{'Control.args'}{'logType'}:2:2");
}
 
writeToLog($paramHash{'mainLog'},
\"Performing dynamic substitution of variables:\n\n",
"$paramHash{'Control.args'}{'logType'}:0:1");

$exitCode = performDynamicSubstitution($paramHash{'job.properties'});

if ($paramHash{'Control.args'}{'debug'} > 1)
{
  writeToLog($paramHash{'mainLog'},
  \"Printing out job properties after dynamic substitution:\n\n",
  "$paramHash{'Control.args'}{'logType'}:1:2");

  writeToLog($paramHash{'mainLog'},
  \hashRefToString($paramHash{'job.properties'}),
  "$paramHash{'Control.args'}{'logType'}:2:2");
}

writeToLog($paramHash{'mainLog'},
\"Scanning for removed properties:\n\n",
"$paramHash{'Control.args'}{'logType'}:0:1");

$exitCode = purgeNulledProperties(\%paramHash);

writeToLog($paramHash{'mainLog'},
\"Setting up modules:\n\n",
"$paramHash{'Control.args'}{'logType'}:0:1");

$exitCode = parseModules(\%paramHash);

unless ($exitCode != 0)
{
  if ($paramHash{'Control.args'}{'debug'} > 1)
  {
    writeToLog($paramHash{'mainLog'},
      \"Printing out job properties before execution:\n\n",
        "$paramHash{'Control.args'}{'logType'}:1:2");
    writeToLog($paramHash{'mainLog'},
      \hashRefToString($paramHash{'job.properties'}),
        "$paramHash{'Control.args'}{'logType'}:2:2");
  }

  writeToLog($paramHash{'mainLog'},
  \"Preparing to execute job:\n\n",
  "$paramHash{'Control.args'}{'logType'}:0:1");
  
  writeToLog($paramHash{'mainLog'},
  \"The following modules will be called: $paramHash{'job.properties'}{'modules'}\n\n",
  "$paramHash{'Control.args'}{'logType'}:0:1");

  $exitCode = executeJob(\%paramHash);
}
else
{
  if ($exitCode = 1)
  {
    writeToLog($paramHash{'mainLog'},
      \"A required argument was not found. Please examine control file",
        "$paramHash{'Control.args'}{'logType'}:1:2");
  }
}

exit $exitCode;

#######################################################################
################################ End Mainline #########################
#######################################################################

## sub deriveBase
sub deriveAFHome
{
  my ($refToParamHash) = @_;
  my ($derefScalar, %ControlArgs);

  ## Pull Control args...
  $derefScalar = $$refToParamHash{'Control.args'};
  %ControlArgs = %$derefScalar;

  ## Removing references to "Base" in favor of AFHOME
  ## unless($ControlArgs{'Base'})
  ## {
  ##   if ($ENV{'Base'})
  ##   {
  ##     $ControlArgs{'Base'} = $ENV{'Base'}
  ##   }
  ##   else
  ##   {
  ##     writeToLog("$$refToParamHash{'mainLog'}" , \"DEFAULT VALUE: NULL ASSIGNED TO Base!!" , "o:3:3");
  ##     $ControlArgs{'Base'} = "NULL";
  ##   }
  ## }
  
  unless($ControlArgs{'AFHOME'})
  {
    if ($ENV{'AFHOME'})
    {
      $ControlArgs{'AFHOME'} = $ENV{'AFHOME'}
    }
    else
    {
      writeToLog("$$refToParamHash{'mainLog'}" , \"DEFAULT VALUE: /Users/jrmallas/perlscripts/dist ASSIGNED TO AFHOME!!" , "o:3:3");
      $ControlArgs{'AFHOME'} = "/Users/jrmallas/perlscripts/dist";
    }
  }
  
  ## Removing references to stView
  ## unless($ControlArgs{'stView'})
  ## {
  ##   if ($ENV{'ST_VIEW'})
  ##   {
  ##     $ControlArgs{'stView'} = $ENV{'ST_VIEW'}
  ##   }
  ## }
  
  $$refToParamHash{'Control.args'} = \%ControlArgs
}

sub purgeNulledProperties
{
  ## This subroutine is designed to look at the parameter list and delete
  ## any parameters that are set to "NULL"

  my ($refToParamHash) = @_;
  my ($derefScalar, %JobProps, $sectionKey);

  ## Pull job properties
  $derefScalar = $$refToParamHash{'job.properties'};
  %JobProps = %$derefScalar;
  
  foreach $sectionKey (sort keys %JobProps)
  {
     ## print "Key: " . $sectionKey . "\n";
     ## print "Value: " . $JobProps{$sectionKey} . "\n";
     if ($JobProps{$sectionKey} =~ m/NULL/)
     {
       if ($paramHash{'Control.args'}{'debug'} > 0)
       {
         writeToLog($paramHash{'mainLog'},
         \"Removing parameter: $sectionKey Previous value: $JobProps{$sectionKey}",
         "$paramHash{'Control.args'}{'logType'}:1:2");
       }

       delete($JobProps{$sectionKey});
     }
  }

  $$refToParamHash{'job.properties'} = \%JobProps;
}

sub parseModules
{
  ## This subroutine is designed to look at the requested modules from
  ## the application.properties file, and determine which additional 
  ## values need to be passed to the module(s) as arguments.

  ## TODO: Figure out how to roll detailLogs once per job...
  ## logRoller($paramHash{'mainLog'}, $paramHash{'Control.properties'}{'common'}{'LogCount'});

  my ($refToParamHash) = @_;
  my ($derefScalar, %jobHash, %moduleHash, %moduleArgs, %ControlArgs, %ControlProps);
  my (@moduleArray, $module, $moduleList, $detailLog, %uniqDetailLogs, %moduleLogs);
  my (@cmdArray, $cmd);
  my (@argArray, $arg, $postFix, $bRequired);

  ## Pull Control args...
  $derefScalar = $$refToParamHash{'Control.args'};
  %ControlArgs = %$derefScalar;

  ## Pull Control props...
  $derefScalar = $$refToParamHash{'Control.properties'}{'common'};
  %ControlProps = %$derefScalar;

  ## Which modules are called for?
  $derefScalar = $$refToParamHash{'job.properties'};
  %jobHash = %$derefScalar;
  $moduleList = $jobHash{'modules'};

  ## You should probably get the module hash in here too...
  $derefScalar = $$refToParamHash{'Module.properties'};
  %moduleHash = %$derefScalar;

  ## And since we have that, lets get the module args section...
  $derefScalar = $moduleHash{'moduleArgs'};
  %moduleArgs = %$derefScalar;

  ## And since we have that, lets get the baseLogName section...
  $derefScalar = $moduleHash{'baseLogName'};
  %moduleLogs = %$derefScalar;

  ## For each called-for module, determine if its a valid module
  ## or if the module is called more than once.
  @moduleArray = split (", " , $moduleList);
  foreach $module (@moduleArray)
  {
    $detailLog = "";
    ## Is this module called more than once during this job
    ## It should look something like this: moduleName.pl**<any number of chars><EOL>
    if ($module =~ s/(\*\*.*$)//)
    {
      
      ## We encased our regex above in parens. When you do that, it puts the matched
      ## pattern into the scalar var $1 which is kinda handy.
      $postFix = $1;
      $cmd = $module;

      if ($ControlArgs{'debug'} > 1)
      {
        writeToLog("$$refToParamHash{'mainLog'}" , \"Located the following module: $module" , "$ControlArgs{'logType'}:3:3");
      }
      
      if ($moduleArgs{$module})
      {
        @argArray = split(", " , $moduleArgs{$module});

        foreach $arg (@argArray)
        {
          if ($arg =~ s/\[(.*)\]/$1/)
          {
            if ($ControlArgs{'debug'} > 1)
            {
              writeToLog("$$refToParamHash{'mainLog'}" , \"REQUIRED ARGUMENT FOUND: $arg" , "$ControlArgs{'logType'}:3:3");
            }
            $bRequired = 1;
          }
          else
          {
            $bRequired = 0;
          }

          if ($ControlArgs{'debug'} > 1)
          {
            writeToLog("$$refToParamHash{'mainLog'}" , \"Searching for: $arg $postFix" , "$ControlArgs{'logType'}:3:3");
          }

          if ($jobHash{$arg . $postFix})
          {
            $cmd .= " -" . $arg . " " . $jobHash{$arg . $postFix};
          }
          elsif ($jobHash{$arg})
          {
            $cmd .= " -" . $arg . " " . $jobHash{$arg};
          }
          elsif ($arg =~ m/detailLog/)
          {
            ## print "\n\n\nHIT DETAIL LOG CHECK!!!\n\nHERE IS ARG: $arg\nHERE IS MODULE: $module\nHERE IS DETAIL LOG: $detailLog\n\n\n";
            $detailLog = $ControlProps{'logDir'} . "/" . $ControlArgs{'group'} . "-" .
              $ControlArgs{'jobtype'} . "-" .
                $ControlArgs{'application'} . "-" .
                  $ControlArgs{'state'} . "-" .
                    $moduleLogs{$module} . ".0.log";

            $uniqDetailLogs{$detailLog} = "holdem";
            $cmd .= " -detailLog " . $detailLog;
          }
          else
          {
            ## Arg was not found... That may be bad, if the arg is required
            if ($bRequired)
            {
              writeToLog("$$refToParamHash{'mainLog'}" ,
                \"The required parameter: $arg\nwas not defined for module: $module" ,
                  "$ControlArgs{'logType'}:0:1");
              return 1;
            }
          }
        }
      }
      else
      {
        writeToLog("$$refToParamHash{'mainLog'}" , \"$module was not found in Module.properties" , "$ControlArgs{'logType'}:0:1");
        return 1;
      }
      
    }
    else # Which means that the module didn't have "**" in the listing
    {
      $cmd = $module;
      
      if ($moduleArgs{$module})
      {
        @argArray = split(", " , $moduleArgs{$module});

        foreach $arg (@argArray)
        {
          if ($arg =~ s/\[(.*)\]/$1/)
          {
            if ($ControlArgs{'debug'} > 1)
            {
              writeToLog("$$refToParamHash{'mainLog'}" , \"REQUIRED ARGUMENT FOUND: $arg" , "$ControlArgs{'logType'}:3:3");
            }
            $bRequired = 1;
          }
          else
          {
            $bRequired = 0;
          }

          if ($ControlArgs{'debug'} > 1)
          {
            writeToLog("$$refToParamHash{'mainLog'}" , \"Searching for: $arg $postFix" , "$ControlArgs{'logType'}:3:3");
          }

          if ($jobHash{$arg})
          {
            $cmd .= " -" . $arg . " " . $jobHash{$arg};
          }
          elsif ($arg =~ m/detailLog/)
          {
            ## print "\n\n\nHIT DETAIL LOG CHECK!!!\n\nHERE IS ARG: $arg\nHERE IS MODULE: $module\nHERE IS DETAIL LOG: $detailLog\n\n\n";
            $detailLog = $ControlProps{'logDir'} . "/" . $ControlArgs{'group'} . "-" .
              $ControlArgs{'jobtype'} . "-" .
                $ControlArgs{'application'} . "-" .
                  $ControlArgs{'state'} . "-" .
                    $moduleLogs{$module} . ".0.log";

            $uniqDetailLogs{$detailLog} = "holdem";
            $cmd .= " -detailLog " . $detailLog;
          }
          else
          {
            ## Arg was not found... That may be bad, if the arg is required
            if ($bRequired)
            {
              writeToLog("$$refToParamHash{'mainLog'}" ,
                \"The required parameter: $arg\nwas not defined for module: $module" ,
                  "$ControlArgs{'logType'}:0:1");
              return 1;
            }
          }
        }
      }
      else
      {
        writeToLog("$$refToParamHash{'mainLog'}" , \"$module was not found in Module.properties" , "$ControlArgs{'logType'}:0:1");
        return 1;
      }

    }

    ## TODO: Check to see if all required arguments have been assigned a value
    
    $cmd = $ControlProps{'moduleLoc'} . "/" . $cmd;
    # $cmd = $cmd . genDetailLog();
    # genDetailLog($module);
    push (@cmdArray, $cmd);
  }

  ## Insert the command array into the job properties.
  $$refToParamHash{'job.properties'}{'commandList'} = [ @cmdArray ];

  return 0;
  
}

sub executeJob
{
  my ($refToParamHash) = @_;
  my ($hashReference, %jobHash);
  my ($arrayReference, @cmdArray, $cmd);
  my ($cmdOut, $cmdRC, $RC);

  $RC = 0;
  ## All that should be left to do at this point
  ## is execute the commands in order...
  $hashReference = $$refToParamHash{'job.properties'};
  %jobHash = %$hashReference;

  $arrayReference = $jobHash{'commandList'};
  @cmdArray = @$arrayReference;

  foreach $cmd (@cmdArray)
  {
    unless($jobHash{'norun'})
    {
      writeToLog("$$refToParamHash{'mainLog'}" , \"Executing:\n  $cmd" , "$jobHash{'logType'}:0:1"); 
    
      system $cmd;
      ## $cmdOut = `$cmd`;
      $cmdRC = $?;
      $cmdRC = $cmdRC/256;
      
      # writeToLog("$$refToParamHash{'mainLog'}" , \"COMMAND RETURN CODE: $cmdRC\n" , "$jobHash{'logType'}:0:3");

      unless ($cmdRC == 0)
      {
        writeToLog("$$refToParamHash{'mainLog'}" , \"COMMAND DID NOT EXIT SUCCESSFULLY!\n" , "$jobHash{'logType'}:0:3");
        ## writeToLog("$$refToParamHash{'mainLog'}" , \$cmdOut , "$jobHash{'logType'}:0:3");
        if ($cmdRC == 1)
        {
          ## 1 is a fatal error, greater than 1 is warning
          writeToLog("$$refToParamHash{'mainLog'}" ,
            \"Execution failure is critical. Aborting remainder of job.\n" ,
              "$jobHash{'logType'}:0:3");
          $RC = 1;
          return $RC;
        }
        else
        {
          writeToLog("$$refToParamHash{'mainLog'}" ,
            \"Execution failure is NOT critical. Job will continue.\n" ,
              "$jobHash{'logType'}:0:3");
          $RC = 2;
        }
      }
      else
      {
        writeToLog("$$refToParamHash{'mainLog'}" , \"COMMAND APPEARS TO HAVE RUN SUCCESSFULLY!\n" , "$jobHash{'logType'}:0:3");
        ## writeToLog("$$refToParamHash{'mainLog'}" , \$cmdOut , "$jobHash{'logType'}:1:0");
      }
    }
    else
    {
      writeToLog("$$refToParamHash{'mainLog'}" , \"Simulating:\n  $cmd" , "$jobHash{'logType'}:0:1"); 
    }
  }

  return $RC;
}

sub gatherProperties
{
  my ($refToParamHash) = @_;
  my (%controlHash, %moduleHash, %envHash, %appHash, %instOfParamHash);
  my ($sectionKey, $varKey, %tempHash, $randomScalar, $subbable, $subber);

  if ($$refToParamHash{'Control.args'}{'debug'} > -1)
  {
    writeToLog("$$refToParamHash{'mainLog'}" ,
    \"Begin gatherProperties", 
    "o:0:1");
  }

  ## Read Control.properties
  %controlHash = propFileToHash("$ENV{'AFHOME'}/properties/Control.properties");
  ## Scan for any dynamically assigned vars that are used prior to assigning job props
  foreach $sectionKey (sort keys %controlHash)
  {
    # print "  Section: $sectionKey\n";
    $randomScalar = $controlHash{$sectionKey};
    %tempHash = %$randomScalar;
    foreach $varKey (sort keys %tempHash)
    {
      # print "Variable: $varKey   Value: $controlHash{$sectionKey}{$varKey}\n";
      if ($controlHash{$sectionKey}{$varKey} =~ m/(\<(.*)\>)/)
      {
        $subbable = $1;
        $subber = $2;
        # print "MATCHED!!\n";
        # print "Is there an arg for $subber: $$refToParamHash{'Control.args'}{$subber}\n";
        if($$refToParamHash{'Control.args'}{$subber})
        {
          $controlHash{$sectionKey}{$varKey} =~ s/$subbable/$$refToParamHash{'Control.args'}{$subber}/;
        }
      }
    }
  }
  $$refToParamHash{'Control.properties'} = \%controlHash;



  ## Read Module.properties
  %moduleHash = propFileToHash("$ENV{'AFHOME'}/properties/Module.properties");
  $$refToParamHash{'Module.properties'} = \%moduleHash;

  ## Read Env.properties
  %envHash = propFileToHash("$ENV{'AFHOME'}/properties/Env.properties");
  $$refToParamHash{'Env.properties'} = \%envHash;

  ## Read application.properties if exists
  if (-e "$ENV{'AFHOME'}/properties/$$refToParamHash{'Control.args'}{'application'}.properties")
  {
    %appHash = propFileToHash("$ENV{'AFHOME'}/properties/" . "$$refToParamHash{'Control.args'}{'application'}.properties");
    $$refToParamHash{'App.properties'} = \%appHash;
  }
  else
  {
    writeToLog($paramHash{'mainLog'}, \"Unable to read $ENV{'AFHOME'}/properties/$$refToParamHash{'Control.args'}{'application'}.properties!!", "$paramHash{'Control.args'}{'logType'}:0:0");
    $exitCode = 1;
  }

  if ($$refToParamHash{'Control.args'}{'debug'} > 2)
  {
    writeToLog("$$refToParamHash{'mainLog'}" ,
    \"Printing out parameter hash from gatherProperties:",
    "o:3:5");

    writeToLog("$$refToParamHash{'mainLog'}" ,
    \hashRefToString($refToParamHash), 
    "o:4:5");
  }

}

sub setUpJob
{
  my ($refToParamHash) = @_;
  my (%jobHash);
  my ($key, %hashHolder, $returnCode);
  
  $returnCode = 0;

  ## Pull appropriate vars from the Env property file:
  %hashHolder = setParams($refToParamHash, "Env.properties");
  foreach $key (sort keys %hashHolder)
  {
    $$refToParamHash{'job.properties'}{$key} = $hashHolder{$key};
  }
  %hashHolder = {};
  
  ## Pull appropriate vars from the Control property file:
  %hashHolder = setParams($refToParamHash, "Control.properties");
  foreach $key (sort keys %hashHolder)
  {
    $$refToParamHash{'job.properties'}{$key} = $hashHolder{$key};
  }
  %hashHolder = {};
  
  ## Pull appropriate vars from the application property file:
  %hashHolder = setParams($refToParamHash, "App.properties");
  foreach $key (sort keys %hashHolder)
  {
    $$refToParamHash{'job.properties'}{$key} = $hashHolder{$key};
  }
  %hashHolder = {};
  
  ## Pull appropriate vars from the Control arguments:
  ## %hashHolder = setParams($refToParamHash, "App.properties");
  ## foreach $key (sort keys %hashHolder)
  ## {
  ##   $$refToParamHash{'job.properties'}{$key} = $hashHolder{$key};
  ## }
  ## %hashHolder = {};
 
  return $returnCode;
}

sub setParams
{
  my ($refToParamHash, $propFile) = @_;

  my ($section, $randomScalar);
  my (%firstHash, %hashHolder, %returnHash);
  my ($firstKey, $key);

  ## Figure out which sections you need based on which property file
  ## you're reading from...
  my @sectionList = getSectionList($refToParamHash, $propFile);

  ## Set job properties based on detail in chosen prop file
  foreach $section (@sectionList)
  {
    if ($$refToParamHash{'Control.args'}{'debug'} > 0)
    {
      writeToLog($$refToParamHash{'mainLog'},
          \"Reading section properties from the following section: $section\n",
            "$$refToParamHash{'Control.args'}{'logType'}:3:3");
    }

    if ($$refToParamHash{$propFile}{$section})
    {
        $randomScalar = $$refToParamHash{$propFile}{$section};

        ## de-ref / cast scalar into a hash...
        %firstHash = %$randomScalar;
        
        foreach $firstKey (sort keys %firstHash)
        {
          $returnHash{$firstKey} = $firstHash{$firstKey};
        }
    }
  }

  if ($$refToParamHash{'Control.args'}{'debug'} > 1)
  {
    writeToLog($$refToParamHash{'mainLog'},
        \"Here is the returnHash after reading propfile: $propFile\n",
          "$$refToParamHash{'Control.args'}{'logType'}:3:3");

    writeToLog($$refToParamHash{'mainLog'},
        \hashRefToString(\%returnHash),
          "$$refToParamHash{'Control.args'}{'logType'}:4:3");
  }

  ## Process passed in overrides...
  ## For each hash item inside the Control.args section
  ## add / overwrite in the job hash...

  $randomScalar = $$refToParamHash{'Control.args'};
  %hashHolder = %$randomScalar;

  foreach $key (sort keys %hashHolder)
  {
    $returnHash{$key} = $hashHolder{$key};
  }

  if ($$refToParamHash{'Control.args'}{'debug'} > 1)
  {
    writeToLog($$refToParamHash{'mainLog'},
        \"Here is the returnHash after overrides:\n",
          "$$refToParamHash{'Control.args'}{'logType'}:3:3");

    writeToLog($$refToParamHash{'mainLog'},
        \hashRefToString(\%returnHash),
          "$$refToParamHash{'Control.args'}{'logType'}:4:3");
  }

  return %returnHash;
}

#########################################################################
##
##  Pull the appropriate sections to read from Control.properties
##
#########################################################################
sub getSectionList
{
  my ($refToParamHash, $propFile) = @_;
  my ($section, @sectionArray);
  my ($compoundSection, @compoundSectionArray);
  my ($workingScalar, @returnArray);
  
  if ($$refToParamHash{'Control.args'}{'debug'} > -1)
  {
    writeToLog($$refToParamHash{'mainLog'},
      \"Determining default sections for the following property file: $propFile",
        "$$refToParamHash{'Control.args'}{'logType'}:3:3");
    writeToLog($$refToParamHash{'mainLog'},
      \"Default sections: $$refToParamHash{'Control.properties'}{'default_sections'}{$propFile}\n",
        "$$refToParamHash{'Control.args'}{'logType'}:1:0");
  }

  ## Split up the section list and throw it into an array... Cuz arrays are cool.
  @sectionArray = split (", " , $$refToParamHash{'Control.properties'}{'default_sections'}{$propFile});

  ## You should also add any requested, non-default sections while you're at it...
  if ($$refToParamHash{'Control.args'}{'acls'})
  {
    foreach $section (split (" " , $$refToParamHash{'Control.args'}{'acls'}))
    {
      push(@sectionArray, $section);
    }
  }

  ## Figure out if the sections listed are names or values by seeing if the
  ## string itself is listed as an arg:
  foreach $section (@sectionArray)
  {
    if ($$refToParamHash{'Control.args'}{'debug'} > 1)
    {
      # print "Here is a section: " . $section . "\n\n";
      writeToLog($$refToParamHash{'mainLog'},
        \"Here is a section: $section \n",
          "$$refToParamHash{'Control.args'}{'logType'}:3:5");
    }
    
    ## The regex below will match <any number of chars>*<any number of chars>
    ## I hope to match things like this: MG*Production
    if ($section =~ m/.*\*.*/)
    {
      $workingScalar = "";
      if ($$refToParamHash{'Control.args'}{'debug'} > 1)
      {
        # print "Here is a section: " . $section . "\n\n";
        writeToLog($$refToParamHash{'mainLog'},
          \"Found a compound section!\n",
            "$$refToParamHash{'Control.args'}{'logType'}:3:5");
      }

      @compoundSectionArray = split (/\*/ , $section);
      foreach $compoundSection (@compoundSectionArray)
      {
        if ($$refToParamHash{'Control.args'}{$compoundSection})
        {
          $workingScalar .= $$refToParamHash{'Control.args'}{$compoundSection} . "\*";
        }
        else
        {
          $workingScalar .= $compoundSection . "\*";
        }
      }
      
      $workingScalar =~ s/\*$//;
      push (@returnArray, $workingScalar);
    }
    else
    {
      ## Figure out of this is a name or a value based on whether or
      ## not the name exists in the argument hash
      if ($$refToParamHash{'Control.args'}{$section})
      {
        # Add the value of section to the return array
        push (@returnArray, $$refToParamHash{'Control.args'}{$section});
      }
      else
      {
        # Add the section to the return array
        push (@returnArray, $section);
      }
    }
  }

  if ($$refToParamHash{'Control.args'}{'debug'} > 2)
  {
    foreach $section (@returnArray)
    {
      writeToLog($$refToParamHash{'mainLog'},
        \"Here is a section of the return array: $section",
          "$$refToParamHash{'Control.args'}{'logType'}:3:5");
    }
  }

  return @returnArray
}

##########################################################################
##
## This function / subroutine is meant to scan the properties of the job
## and identify variables embedded within the set values. For example:
## myFirstProperty = myValue
## mySecondProperty = <myFirstProperty>mySecondValue
##
## When printing $mySecondProperty you should see "myValuemySecondValue"
##
## This function / subroutine uses a goodly amount of regular expressions
## so please only modify if you know what youre doing.
##
##########################################################################
sub performDynamicSubstitution
{
  my ($refToJobHash) = @_;
  my ($key, $value, $workingScalar);
  my ($firstCap, $secondCap);
  my $varIsComplete = 0;
  my $RC = 0;

  ## We've passed in a reference to the job.properties hash
  ## so we need to spin through the keys and make modifications
  ## as necessary.

  if($$refToJobHash{'debug'} > 0)
  {
    writeToLog($$refToJobHash{'mainLog'},
    \"Performing dynamic substitution.", 
    "$$refToJobHash{'logType'}:1:2");
  }

  foreach $key (sort keys %$refToJobHash)
  {
    $varIsComplete = 0;
    while ($varIsComplete == 0)
    {
      if($$refToJobHash{'debug'} > 2)
      {
        writeToLog($$refToJobHash{'mainLog'},
        \"KEY: $key VALUE: $$refToJobHash{$key}", 
        "$$refToJobHash{'logType'}:3:3");
      }
      
      ## The following regex matches any number of characters
      ## enclosed within "<" and ">". Because of the parens, 
      ## it populates the $1 var with the matched pattern
      ## and $2 with the enclosed pattern.
      ## Example:
      ## The pattern to be screened is /<kbase>/apps/appsrv/es
      ## results in $1 = "<kbase>" and $2 = "kbase"
      if ($$refToJobHash{$key} =~ m/.*(\<(.*)\>).*/)
      {
         $firstCap = $1;
         $secondCap = $2;
    
        if ($$refToJobHash{$secondCap})
        {
          if($$refToJobHash{'debug'} > 1)
          {
            # print "Substitution being performed on $$refToJobHash{$key}!\n"
            writeToLog($$refToJobHash{'mainLog'},
            \"Substitution being performed on $$refToJobHash{$key}", 
            "$$refToJobHash{'logType'}:3:3");
   
            # print "Substitution of $firstCap with $$refToJobHash{$secondCap}!\n";
            writeToLog($$refToJobHash{'mainLog'},
            \"Substitution of $firstCap with $$refToJobHash{$secondCap}", 
            "$$refToJobHash{'logType'}:4:3");
          }
  
          $$refToJobHash{$key} =~ s/$firstCap/$$refToJobHash{$secondCap}/;
  
          if($$refToJobHash{'debug'} > 2)
          {
            # print "Here is the resulting key val pair: $key $$refToJobHash{$key}\n";
            writeToLog($$refToJobHash{'mainLog'},
            \"Here is the resulting key val pair: $key $$refToJobHash{$key}", 
            "$$refToJobHash{'logType'}:3:3");
          }
        }
        else
        {
          writeToLog($$refToJobHash{'mainLog'},
          \"Substitution attempted, but failed!",
          "$$refToJobHash{'logType'}:1:9");
  
          writeToLog($$refToJobHash{'mainLog'},
          \"Unable to locate value associated to $firstCap!!",
          "$$refToJobHash{'logType'}:1:9");
          
          $varIsComplete = 1;
          $RC=1;
        }
      }
      else
      {
        ## No <>'s were found
        $varIsComplete = 1;
      }
    }
  }

  return $RC;
}

sub genHeader
{
  my ($refToParamHash) = @_;
  
  my ($randomScalar, $secondScalar, $title, $timeStamp, $jobId, $message);
  my $content;

  $jobId = "JOB ID: $$";
  $timeStamp = timeStamp(7);
  $randomScalar = "################################################################################";
  $secondScalar = "##                                                                            ##";
  $content = "$randomScalar\n$secondScalar\n_REPLACE_\n$secondScalar\n$randomScalar";
  $message = genMessage();

  $title .= &center("HEADER MESSAGE"); 
  $title .= &center($timeStamp);
  $title .= &center($jobId);
  $title .= &center($message);
  chomp($title);

  $content =~ s/_REPLACE_/$title/;
  return $content;
  # writeToLog($$refToParamHash{'Control.args'}{'mainLog'}, \$content, "$$refToParamHash{'Control.args'}{'logType'}:0:0");
}

sub genMessage
{
  ## Yeah... I should TOTALLY be reading this from a property file... Oh well.
  return "Automation Framework Message";
}

sub center
{
  my $thingToCenter = $_[0];
  my ($test, $strLen, $totalWhite, $rightPadding, $leftPadding);
  my $returnable;

  ## Surround thingToCenter with 2 #'s and make it 80 chars wide.
  $strLen = length $thingToCenter;
  $totalWhite = 76 - $strLen;
  $test = $totalWhite % 2;

  if ($test > 0 )
  {
    $totalWhite = $totalWhite - 1;
    $rightPadding = $totalWhite/2;
    $leftPadding = $rightPadding+1;
    # print "-->$thingToCenter<--\n";
    # print "We believe the string has an odd number of characters\n";
    # print "String Length: $strLen\n";
    # print "Adding $leftPadding spaces to the left\n";
    # print "Adding $rightPadding spaces to the right\n";
  }
  else
  {
    $rightPadding = $totalWhite/2;
    $leftPadding = $rightPadding;
    # print "-->$thingToCenter<--\n";
    # print "We believe the string has an even number of characters\n";
    # print "String Length: $strLen\n";
    # print "Adding $leftPadding spaces to the left\n";
    # print "Adding $rightPadding spaces to the right\n";
  } 

  $returnable = "##";

  foreach (1..$leftPadding)
  {
    $returnable .= " ";
  }

  $returnable .= $thingToCenter;

  foreach (1..$rightPadding)
  {
    $returnable .= " ";
  }

  $returnable .= "##\n";

  return $returnable;
}

sub genDetailLog
{
  my $module = $_[0];
  my (%tempHash, $randomScalar);

  %tempHash = propFileToHash("$ENV{'AFHOME'}/properties/Module.properties");
}

sub setPath()
{
  my ($refToParamHash) = @_;

  if ($ENV{'PATH'})
  {
    $ENV{'PATH'} = $ENV{'PATH'} . ":" . "/prod/prop/starteam2008/client/bin";
  }

  if ($paramHash{'Control.args'}{'debug'} > 0)
  {
    writeToLog("$$refToParamHash{'mainLog'}" , \"PATH variable set to:  $ENV{'PATH'}" , "o:3:3");
  }
}
