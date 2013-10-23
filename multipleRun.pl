#!/usr/bin/perl

## This file is provided without any warranty of fitness
## for any purpose. You can redistribute this file
## and/or modify it under the terms of the GNU
## Lesser General Public License (LGPL) as published
## by the Free Software Foundation, either version 3
## of the License or (at your option) any later version.
## (see http://www.opensource.org/licenses for more info)


########################## -Program to Run another program with some parameters(specified in some file) changed- ######################
############# -Usage- ##############
## 1. ./multipleRun.pl inputToMultipleRun.txt;
##	whereas 'inputToMultipleRun.txt' file contains all inputs parameters. Look at multipleRun.doc for more informations.
#####################################

######## Decription ##########
# Following perl script is made to facilitate multiple simulations with differing paremeters.
# Usage: cd <simulatorFolder>; ./multipleRun <inputFile specifying Parameters to vary & it's values>;
# Uppon running this script, it will generate different build folders named as build_0_0, build_0_1, build_1_0,.....etc
#		build_i_j contains results of simulation with i'th value of first parameter & j'th value of second parameter.
#		build_i_j/simulationOuput.out contains results of simulation with i'th value of first parameter & j'th value of second parameter.
# To stop the running of the script, look at the PID which was printed by this script & kill it.

######## Properties ###########
# 1. If file-name or line-number not specified, then the script will grep the 'Parameter-Name'(with only one '=' on it's right side) & pick the first result.
# 2. maximum number of parallel jobs to be submitted can be indicated in the input file by setting 'maxParallelJobs'.
# 3. Comments(lines starting from '/') in all files(.cpp,.h,.txt) are ignored. ### TODO, comments should be properly avoided...
# 4. Comment in input file(to this script) can be placed by prefixing '#'

########### Notes ###########
# 1. To execute Bash command inside perl-script, escape(put backslash) followings '\','$' .. Use ${parameter[$i]} to seperate Bash ']' from Perl
# 2. '$suffixedPattern' is an EREGEX. But backtracking can't be used in this (ie $1,$2 ...etc)

################ TODO #############
# 1. special characters also should be inputted
# 2. Have proper message, while Error existing, if file doesn't exist!!

# \author Anver Hisham <anverhisham@gmail.com>
########################################################################################################################################

use strict;
use warnings;
use POSIX;
$SIG{CHLD} = 'IGNORE';	# To avoid zombie child processes

use constant false => 0;
use constant true  => 1;
sub ReturnFullPath;
sub getCommonElements;
sub trimSpacesOfArray;
sub deleteBlankElementsInArray;
sub prefixZerosToFolderNames;

sub saveBashCommandsForPerl;
sub extractAVariableFromFile;
sub convertToArray;
sub extractInputToMatrix;
sub extractInputFileOfPerl;
sub printAll;
sub trimSpacesFromBothEnd;
sub getColumnsOfMatrix;
sub getNumColumnsPerRowOfMatrix;
sub getIndicesOfKeyword;
sub transposeOfMatrix;
sub max;
sub min;
sub multiThreadBashCommands;
sub waitForAllPIDsToFinish;
sub checkForRegularExpressions;
sub convertToLiteralStringForShellGrep;

use Cwd 'abs_path';
use File::Basename;

## For Debugging, make following true
our $isDebugging = false;

our($commandToKnowAllRunningJobs,$tempFileSuffix,$tempBackupFileSuffix);

exit main();

sub main {

######################### -Get the script file & folder names, & goto script folder - ########################
my $PID = $$;
my($inputfileName,@submittedJobsPIDs,@allPIDsInSystem,@currentRunningJobsPIDs);
my $scriptFilenameWithPath = abs_path($0);
my $scriptFoldername = $scriptFilenameWithPath; $scriptFoldername =~ s/\/[^\/]*$//;
my ($scriptFileName,$callerFolderName)  = (basename($0),`pwd`);    # Absolute Path, Directory name without trailing '/', Script file name alone
if($isDebugging) {				# For Debugging
	$callerFolderName = '/home/anver/Programming/Perl/multipleRun/Example3';
	$inputfileName ='inputToMultipleRun.txt'; #  '/home/anver/Programming/eclipse_workspace/multipleRun/multipleRun.txt'; # TODO change this for release  # 	
}
else {  					# For release 
	$inputfileName = ReturnFullPath(shift(@ARGV)); 
}
print "\n################## Running Perl-Script $scriptFileName (with PID $PID ) ...... on ".localtime."  ##################\n";
print " \$scriptFilenameWithPath = $scriptFilenameWithPath \n \$scriptFoldername = $scriptFoldername \n \$scriptFileName = $scriptFileName \n \$callerFolderName = $callerFolderName\n";
$tempFileSuffix = ".$scriptFileName.temp$PID";           ## Files with this suffix are deleted @end of script.
$tempBackupFileSuffix = ".$scriptFileName.tempBk$PID";   ## Files with this suffix will overwrite the original file @end of script.
chdir "$callerFolderName";
########################################################################################

print "Input file name, \$inputfileName = $inputfileName\n";
#### TODO do tr -cd ''\12\40-\176'' < grepValues_temp.txt > grepValues_temp.txt.new instead.. (refer grepValues.m)
`perl -p -i -e 's/[^\\040-\\176\\012]/ /g' $inputfileName;`; ### Removing all hidden characters in intput text file...

########################## Get ALL options specified in Input file... #######################
my $maxParallelJobs = extractAVariableFromFile('=',$inputfileName,'maxParallelJobs');
if(!$maxParallelJobs) { print "Error: Please specify maxParallelJobs in $inputfileName \n"; exit 0;}
print "\$maxParallelJobs = $maxParallelJobs\n";

my $buildSuffixPatternsToInclude = extractAVariableFromFile('=',$inputfileName,'buildSuffixPatternsToInclude');
my @buildSuffixPatternsToIncludeArray = split(';',$buildSuffixPatternsToInclude);
print "\@buildSuffixPatternsToIncludeArray = @buildSuffixPatternsToIncludeArray\n";
trimSpacesFromBothEnd(\@buildSuffixPatternsToIncludeArray);

my $buildSuffixPatternsToExclude = extractAVariableFromFile('=',$inputfileName,'buildSuffixPatternsToExclude');
my @buildSuffixPatternsToExcludeArray = split(';',$buildSuffixPatternsToExclude);
print "\@buildSuffixPatternsToExcludeArray = @buildSuffixPatternsToExcludeArray\n";
trimSpacesFromBothEnd(\@buildSuffixPatternsToExcludeArray);

my @startCommandToExecuteOutsideBuildFolder = extractVariablesFromFileToArray('=',$inputfileName,'startCommandToExecuteOutsideBuildFolder');
print "\@startCommandToExecuteOutsideBuildFolder = @startCommandToExecuteOutsideBuildFolder\n";

my @endCommandToExecuteOutsideBuildFolder = extractVariablesFromFileToArray('=',$inputfileName,'endCommandToExecuteOutsideBuildFolder');
print "\@endCommandToExecuteOutsideBuildFolder = @endCommandToExecuteOutsideBuildFolder\n";

my @foregroundCommandToExecuteInBuildFolder = extractVariablesFromFileToArray('=',$inputfileName,'foregroundCommandToExecuteInBuildFolder');
print "\@foregroundCommandToExecuteInBuildFolder = @foregroundCommandToExecuteInBuildFolder\n";

my @backgroundCommandToExecuteInBuildFolder = extractVariablesFromFileToArray('=',$inputfileName,'backgroundCommandToExecuteInBuildFolder');
print "\@backgroundCommandToExecuteInBuildFolder = @backgroundCommandToExecuteInBuildFolder\n";

$commandToKnowAllRunningJobs = extractAVariableFromFile('=',$inputfileName,'commandToKnowAllRunningJobs');
print "\$commandToKnowAllRunningJobs = $commandToKnowAllRunningJobs\n";
############################################################################################


########################## Collect all inputs ###############################
## TODO_Urgent: A plausible bug as follows,,,,
my @inputFileMatrix = extractInputToMatrix(0,';',$inputfileName,'maxParallelJobs','buildSuffixPatternsToExclude','commandToExecuteInBuildFolder');
##### Now to chop-out the un-inteded elements from @inputFileMatrix... #####
my @inputFileMatrixtemp; my $inputFileMatrixtempIndex = 0;
for(my $tempIndx=0; $tempIndx<scalar(@inputFileMatrix); $tempIndx ++) {
	if($inputFileMatrix[$tempIndx][0] !~ m/=/)  {
		$inputFileMatrixtemp[$inputFileMatrixtempIndex] = $inputFileMatrix[$tempIndx];
		$inputFileMatrixtempIndex ++;
		}
}
@inputFileMatrix = @inputFileMatrixtemp;
###########################################################################
my @fileNames = convertToArray(getColumnsOfMatrix(\@inputFileMatrix,0));
my @lineNumbers = convertToArray(getColumnsOfMatrix(\@inputFileMatrix,1));
my @parameterNames = convertToArray(getColumnsOfMatrix(\@inputFileMatrix,2));
my @valuesPerParameter = getColumnsOfMatrix(\@inputFileMatrix,3..max(getNumColumnsPerRowOfMatrix(@inputFileMatrix))-1);
trimSpacesFromBothEnd(\@valuesPerParameter);
my @nValuesPerParameter = getNumColumnsPerRowOfMatrix(@valuesPerParameter);
##############################################################################

############## -Backup all files for later retrieval- #############
my @fileNames_unique = getUniqueElements(@fileNames);
backupFile('',@fileNames_unique);
####################################################################

##################### --------------Verification of input-parameters------------- #####################
######## To check if any FileName is missing... #####
my @tempIndicesOfEmptyFileNames = getIndicesOfKeyword(\@fileNames,'');
if(scalar(@tempIndicesOfEmptyFileNames)) {
	print "Error1: File names are missing for the parameters = @parameterNames[@tempIndicesOfEmptyFileNames] \n"; exit 0;
}
######## To check if any parameter name is missing...
my @tempIndicesOfEmptyParameters = getIndicesOfKeyword(\@parameterNames,'');
if(scalar(@tempIndicesOfEmptyParameters)) {
	print "Error2: Parameter names are missing for the fileNames = @fileNames[@tempIndicesOfEmptyParameters] \n"; exit 0;
}
#####################################################
for(my $iParam=0; $iParam<scalar(@parameterNames); $iParam ++ ) {
	my(@currentIndxPerParameter);
	my @parameterNamesForGrep = convertToLiteralStringForShellGrep(@parameterNames);
	##### If fileName is not specified, then get the file name, by grepping parameter (Warning: This feature is not tested!!) #####
	if(!$fileNames[$iParam]) {
		### First Pick the files in folder 'configFiles', then search every where...
		my $grepOutput = `find configFiles/ -regex '.*\\.txt\$' |xargs grep -E -Hnre '^[^/]*\\b${parameterNamesForGrep[$iParam]}[[:blank:]]*=' \$1|head -1 |cut -d: -f1;`;	# configFiles folder name is hard coded here.
		$grepOutput = $grepOutput.`find -regex '.*\\.cpp\$\\|.*\\.h\$' |xargs grep -E -Hnre '^[^/]*\\b${parameterNamesForGrep[$iParam]}[[:blank:]]*=' \$1|head -1 |cut -d: -f1;`;
		my @grepOutputFileNames = split("\n",$grepOutput);
		
		$grepOutput = `find configFiles/ -regex '.*\\.txt\$' |xargs grep -E -Hnre '^[^/]*\\b${parameterNamesForGrep[$iParam]}[[:blank:]]*=' \$1|head -1 |cut -d: -f2;`;	# configFiles folder name is hard coded here.
		$grepOutput = $grepOutput.`find -regex '.*\\.cpp\$\\|.*\\.h\$' |xargs grep -E -Hnre '^[^/]*\\b${parameterNamesForGrep[$iParam]}[[:blank:]]*=' \$1|head -1 |cut -d: -f2;`;
		my @grepOutputLineNumbers = split("\n",$grepOutput);
		
		if(!@grepOutputFileNames) { print "Error3: No file found upon grepping \$iParam = $iParam, \$parameterNamesForGrep[\$iParam] = $parameterNamesForGrep[$iParam] \n"; exit 0; }
		
		#### If line number is specified as input, then pick the file with same input line number ####
		if($lineNumbers[$iParam]) {
			for(my $indx=0; $indx<scalar(@grepOutputLineNumbers); $indx++) {
				if($grepOutputLineNumbers[$indx] == $lineNumbers[$iParam]) {
					$fileNames[$iParam] = ReturnFullPath($grepOutputFileNames[$indx]); last;
				}
			}
			if(!$fileNames[$iParam]) {print "Error4: With given line number, no file exists with \$iParam = $iParam, \$parameterNamesForGrep[\$iParam] = $parameterNamesForGrep[$iParam] \n"; exit 0; }
		}
		
		###### Else assign the first value of @grepOutputFileNames & @grepOutputLineNumbers ####
		else {
			$fileNames[$iParam] = ReturnFullPath($grepOutputFileNames[0]);
			$lineNumbers[$iParam] = $grepOutputLineNumbers[0];
		}
	}
	##### Else if fileName is specified, then check if parameter exists in the file #####
	else	{
		#### -If specified fileName doesn't exists or empty, then Error-Exit
		if(! -s $fileNames[$iParam]) {
			print "Error5a: No non-empty file exists with fileName = $fileNames[$iParam], for \$iParam = $iParam !!! \n"; exit 0;
		}
		
		my $grepOutput =`grep -E -Hnre '^[^/]*\\b${parameterNamesForGrep[$iParam]}[^=]*=[^=]*\$' '$fileNames[$iParam]' |head -1 |cut -d: -f2;`; ## FIXME filesNames containing inputted fileNames are also taken...
		my @grepOutputLineNumbers = split("\n",$grepOutput);
		
		if(!@grepOutputLineNumbers) { print "Error5b: No values found upon grepping \$iParam = $iParam, \$parameterNamesForGrep[\$iParam] = $parameterNamesForGrep[$iParam] \n in file = $fileNames[$iParam] \n"; exit 0; }
		
		#### If line number is specified as input, then verify the grepping... ####
		if($lineNumbers[$iParam] && !grep(/$lineNumbers[$iParam]/,@grepOutputLineNumbers)) {
			print "Error6: With given line number & fileName, Parameter couldn't be grepped for \$iParam = $iParam, \$parameterNamesForGrep[\$iParam] = $parameterNamesForGrep[$iParam] \n in file = $fileNames[$iParam] \n";
			exit 0; 
		}
		###### Else assign the first value of @grepOutputLineNumbers to $lineNumbers[$iParam] ####
		else {
			$lineNumbers[$iParam] = $grepOutputLineNumbers[0];
		}
	}
}
######################################### *******Verification of Inputs is over******* #########################################

####### Now Delete all hidden characters in files, which need to be edited #######
for(my $iParam=0; $iParam<scalar(@fileNames); $iParam ++ ) {
`perl -p -i -e 's/[^\\040-\\176\\012]/ /g' "$fileNames[$iParam]";`;
}
##################################################################################

############ -----------Append the proper input variables to the inputFile--------- #######################
my $toPrint = "\n################## Inputs taken by Perl-Script (with PID $PID ) ...... on ".localtime."  ##################";
for(my $iParam=0; $iParam<scalar(@parameterNames); $iParam ++ ) {
	$toPrint = $toPrint."\n#$fileNames[$iParam];\t$lineNumbers[$iParam];\t$parameterNames[$iParam];";
	for(my $indx=0; $indx<scalar(@{$valuesPerParameter[$iParam]}); $indx++) {
		$toPrint = $toPrint."\t$valuesPerParameter[$iParam][$indx];";
	}
}
$toPrint=convertWordToPerlSearchString($toPrint);
`echo "$toPrint" >> $inputfileName`;		
##########################################################################################################

############ ----------- Execute start commands before doing anything.. --------- #######################
##### TODO test if below condition is proper or not?..
if(!( (scalar(@startCommandToExecuteOutsideBuildFolder)==0) || (scalar(@startCommandToExecuteOutsideBuildFolder)==1 && $startCommandToExecuteOutsideBuildFolder[0]=~m/^\s*$/))) {
	print "Started Execution of startCommandToExecuteOutsideBuildFolder ....\n";
	my @startCommandPIDs = multiThreadBashCommands(@startCommandToExecuteOutsideBuildFolder);
	print "Finished Execution of startCommandToExecuteOutsideBuildFolder ....\n";
}
##########################################################################################################

###########################---------- Iterate for each combination of parameters ------------###############
my $numberOfAllSimulations =1; foreach(@nValuesPerParameter) { $numberOfAllSimulations = $numberOfAllSimulations*$_; }

my @multipliedCDFvaluesFromRight;  $multipliedCDFvaluesFromRight[scalar(@parameterNames)-1]=(1);
for(my $iParam=scalar(@parameterNames)-2; $iParam>=0; $iParam -- ) {
	$multipliedCDFvaluesFromRight[$iParam] = $nValuesPerParameter[$iParam+1]*$multipliedCDFvaluesFromRight[$iParam+1]
}

for(my $iSimulation=0; $iSimulation<$numberOfAllSimulations; $iSimulation++) {
	my(@currentIndxPerParameter);
	for(my $iParam=0; $iParam<scalar(@parameterNames); $iParam ++ ) 	{
		$currentIndxPerParameter[$iParam]=floor($iSimulation/$multipliedCDFvaluesFromRight[$iParam])%$nValuesPerParameter[$iParam];
	}	
	######### Wait untill number of currentRunningJobs < $maxParallelJobs ############ TDOD looking @ only PID will break, if any other process occupy same PID...
#	my @allPIDsInSystem = split("\n",`ps -eo pid`);
	@allPIDsInSystem = split("\n",`$commandToKnowAllRunningJobs`);
	@currentRunningJobsPIDs =  getCommonElements(\@submittedJobsPIDs,\@allPIDsInSystem);
	my $isWaiting = (scalar(@currentRunningJobsPIDs) >= $maxParallelJobs)? 1:0;	# FIXME, $maxParallelJobs should be made to scalar...
	if($isWaiting) {print "\nNumber of jobs running = maxParallelJobs, so waiting started................."; }
	waitForParallelJobsCompletion($maxParallelJobs,@submittedJobsPIDs);
	if($isWaiting) {print "  Waiting Over!!!!!!!!! \n"; }
	##################################################################################

	################## Now it's time to run the necessary commands ##############
	my $buildFolder="build"; for(my $iParam=0; $iParam<scalar(@parameterNames); $iParam ++ ) 	{ $buildFolder = $buildFolder."_$currentIndxPerParameter[$iParam]"; }
	$buildFolder = prefixZerosToFolderNames($buildFolder,@nValuesPerParameter);
	my $suffixedPattern = $buildFolder; $suffixedPattern =~ s/build//;
	## -Check if build folder is eligible or not?
	if(checkForRegularExpressions($suffixedPattern,@buildSuffixPatternsToIncludeArray) && !checkForRegularExpressions($suffixedPattern,@buildSuffixPatternsToExcludeArray)) {
		## -Change Parameter as pecified in input file.
		for(my $iParam=0; $iParam<scalar(@parameterNames); $iParam ++ ) 	{
			`perl -i -pe 's/${parameterNames[$iParam]}[^=\\n]*=[^=\\n]*\$/${parameterNames[$iParam]} = $valuesPerParameter[$iParam][$currentIndxPerParameter[$iParam]];/ if \$.==${lineNumbers[$iParam]}' "$fileNames[$iParam]";`
		}
		## -Make proper build_i folder & goto there.
		print(`rm -rf $buildFolder; mkdir $buildFolder;`);
		chdir "$buildFolder/";		#### changing directory of perl script..
		## -Run foreground command
		my @currentForegroundPIDs = multiThreadBashCommands(@foregroundCommandToExecuteInBuildFolder);
		## -Run background command, and store it's PID
		my @currentBackgroundPIDs=();
		foreach my $backGroundCommand(@backgroundCommandToExecuteInBuildFolder)	{	
			my $currentBackgroundPID= `$backGroundCommand echo \$!`;	chomp($currentBackgroundPID);
			$currentBackgroundPID = `echo $currentBackgroundPID |egrep -o '[0-9]*' |tail -1`;chomp($currentBackgroundPID);
			@currentBackgroundPIDs = (@currentBackgroundPIDs,$currentBackgroundPID);
		}		
		@submittedJobsPIDs = (@submittedJobsPIDs,@currentBackgroundPIDs);
		print "\n\$iSimulation = $iSimulation is running, within folder = $buildFolder, with PID = @currentBackgroundPIDs \n";
		chdir "..";					#### coming back to parent directory..
		@allPIDsInSystem = split("\n",`$commandToKnowAllRunningJobs`); @currentRunningJobsPIDs =  getCommonElements(\@submittedJobsPIDs,\@allPIDsInSystem);
		print "PIDs of jobs submitted till now(".scalar(@submittedJobsPIDs).") = @submittedJobsPIDs \n \@currentRunningJobsPIDs(".scalar(@currentRunningJobsPIDs).")= @currentRunningJobsPIDs \n";
	}
	else
	{
		print "Not eligible for simulation for \$buildFolder = $buildFolder \n";
	}
	#############################################################################
}

print "All Jobs are submitted.. now waiting for all jobs to get finished....";
waitForParallelJobsCompletion(1,@submittedJobsPIDs);
	
############## -Retrieve backed up files...- #############
retrieveBackupFiles('',@fileNames_unique);
##########################################################

############ ----------- Execute end commands after all jobs finished.. --------- #######################
if(!( (scalar(@endCommandToExecuteOutsideBuildFolder)==0) || (scalar(@endCommandToExecuteOutsideBuildFolder)==1 && $endCommandToExecuteOutsideBuildFolder[0]=~m/^\s*$/))) {
	print "Started Execution of endCommandToExecuteOutsideBuildFolder ....\n";
	my @endCommandPIDs = multiThreadBashCommands(@endCommandToExecuteOutsideBuildFolder);
	print "Finished Execution of endCommandToExecuteOutsideBuildFolder ....\n";
}
##########################################################################################################

print "\n All jobs got finished!!!!!!! \n________________ multipleRun.pl Script Over _____________--- on ".`date`."\n";
}			
			



###############################################################################################################################
###########################################----------- FUNCTIONS ----------------##############################################
######## Purpose: To rename build folders so that sort will output in correct order #####
######## Example: Convert build_1_2 to build_01_2, if number of first parameter values is in [10,100)...
######## Warning: folder-name is assumed to be with delimiter '_' for parameterIndex....
sub prefixZerosToFolderNames 	{
	my $folderName = shift(@_);
  	my @nValuesPerParameter = @_;
  	
  	my @tempArr = split('_',$folderName);
  	my $modifiedBuildFolder = shift(@tempArr);
  	
  	my @parameterValueIndices = @tempArr;
	for(my $indx=0;$indx<scalar(@parameterValueIndices);$indx++) {
		 my $nCurrentDecimals;		 		 	
		 my $nTargetDecimals = 1+floor(log($nValuesPerParameter[$indx])/log(10));
		 if ($parameterValueIndices[$indx]==0) {	$nCurrentDecimals = 1; }
		 else { 	$nCurrentDecimals = 1+floor(log($parameterValueIndices[$indx])/log(10)); }
		 
		 $modifiedBuildFolder = $modifiedBuildFolder.'_'.'0'x($nTargetDecimals-$nCurrentDecimals).$parameterValueIndices[$indx];
	}
	return $modifiedBuildFolder;
}
	

######### pointers to two arrays are expected as input ###########
sub getCommonElements {
  my @input0 = @{$_[0]};
  my @input1 = @{$_[1]};
  my @output=();
  foreach my $temp(@input0) {
    # grep(/$_/i, @input1)
    @output=(@output,grep(/\b$temp\b/i, @input1));	## TODO FIXME why '/i' option here?.
  }
  return @output;
}

####### Following function returns string which can be used for search keyword in perl. ###
####### The output keyword can be used for echoing also. #####
sub convertWordToPerlSearchString  {
	
	my $charactersToBackSlash = q(|'()");
	my $input = $_[0];
	$input =~ s/\\/\\\\/g;  #putting '\' before every '\'
	$input =~ s/([$charactersToBackSlash])/\\$1/g;  #putting '\' before every '('
	return $input;
}

####### if we want to run `$shellCommand`, we need to put back slash for every '\' and '$' in $shellCommand
sub saveBashCommandsForPerl {
	my @output; #my $slash ='\$';
	foreach my $input(@_) {
		$input =~ s/\\/\\\\/g;  #putting '\' before every '\'
		$input =~ s/(\$)/$1/g;  #putting '\' before every '$'
		push(@output,$input);
	}
	return @output;
}


################ Output the unique elements in an Array ##################
##### Got code from http://stackoverflow.com/questions/7651/how-do-i-remove-duplicate-items-from-an-array-in-perl
sub getUniqueElements {
    my %seen = ();
    my @r = ();
    foreach my $a (@_) {
        unless ($seen{$a}) {
            push @r, $a;
            $seen{$a} = 1;
        }
    }
    return @r;
}

######## Following function trim the space of on beginning & end of input string(values only if input is a hash)... ########
sub trimSpacesOfArray {
	my $key; my $inputPointer = $_[0];

	for(my $indx=0; $indx<scalar(@$inputPointer); $indx++) {
		$$inputPointer[$indx] =~ s/^\s+//g;
		$$inputPointer[$indx] =~ s/\s+$//g;			
	}
	return @$inputPointer;
}

#### Delete the blank elements in an array...
sub deleteBlankElementsInArray {
	my @input = @_;
	my @output = ();
	my $element;
	foreach	$element (@input) {
		if($element !~ m/^\s*$/) {
			@output = (@output,$element);
		}
	}
	
######## Bug Fixed: Following seemed to be not working when @input contains '0' (6th March 2012)###	
#	while($element = shift(@input)) {
#		if($element !~ m/^\s*$/) {
#			@output = (@output,$element);
#		}
#	}
	return @output;
}
	
## If any relative path from current Folder(where script is getting called) is given, then returns the entire path.
## 	If $input = NULL (ie no input), then current folder(`pwd`) is returned....
sub ReturnFullPath {
	my $output; my $input = $_[0];

	# If no input, then $output=pwd ####Changed from previous function....
	if(!$input)	{ 
		return $input; 
	}
	##############################
	# Check if no '/' appears in the beginning, then it's relative path w.r.t current folder.
	elsif(!($input =~ m/^\//)) { 
		$output=`pwd`;
		chomp($output);
		if(!($input =~ m/^\.$/)) {
			$output = $output."/".$input; 
		}
	}
	##############################
	else {
		$output = $input;
	}
	
	return $output;
}	

###################### Functions for Matrix Manipulation ... etc #############################################

########### Return: array of lines which excludes perl comments & spaces on both sides... #########
########### Usage: extractInputFileOfPerl($fileName)..... ############
sub extractVariablesFromFileToArray {
	my $delimiterForEqual = shift(@_);
	my $inputfileName = shift(@_);
	my @variableNames = @_;
	my @output;
	
	my @lines = extractInputFileOfPerl($inputfileName);
	
	if(scalar(@variableNames)==0) { #### If no variableNames specified, then pick all lines with delimiter
		foreach my $line(@lines) {
			if($line =~ m/=/) {
				$line =~ s/^.*?=//;
				trimSpacesFromBothEnd(\$line);
				push(@output,$line);
			}
		}
	}
	else {	
		foreach my $variableName(@variableNames) {
			my @linesMatched = grep(/^$variableName\s*=/,@lines);
			foreach my $lineMatched(@linesMatched) {
				$lineMatched =~ s/^.*?=//;
				trimSpacesFromBothEnd(\$lineMatched);
				push(@output,$lineMatched);				
			}
		}
	}
	return @output;
}

########### Return: The lines which excludes perl comments & spaces on both sides... #########
########### Usage: extractAVariableFromFile('=',$fileName,'variableName)..... ############
sub extractAVariableFromFile {
	my $delimiterForEqual = shift(@_);
	my $inputfileName = shift(@_);
	my $variableName = shift(@_);
	if(scalar(@_)>0) { print "Error: In function extractVariableFromFileToArray, only 1 variable name is expected..."; exit 0; }
	my $output;
	
	my @lines = extractInputFileOfPerl($inputfileName);
	
	my @linesMatched = grep(/^$variableName\s*=/,@lines);
	if(scalar(@linesMatched)==0) { print "Error(extractAVariableFromFile): Zero lines are matched for parameter $variableName in file $inputfileName !!!"; exit 0; }
	foreach my $lineMatched(@linesMatched) {
		$lineMatched =~ s/^.*?=//;
		trimSpacesFromBothEnd(\$lineMatched);
		$output = $lineMatched;
	}
	return $output;
}

########### Return: array of lines which excludes perl comments & spaces on both sides... #########
########### Usage: extractInputFileOfPerl($fileName)..... ############
sub extractInputFileOfPerl {
	my $inputfileName = $_[0];
	my $delimiter;
	if(defined($_[1]))	{	$delimiter = $_[1];	}
	else				{	$delimiter = '\n';	}
	my @output;		
	
	open FH, "<", "$inputfileName" or die "cannot open < $inputfileName: $!";
	########################## Collect all inputs ###################
	my $iLine=0;
	while(my $line= <FH>) {
		$line =~ s/#.*//g;  # Chopping out the commmenting part...
		chomp($line); 		# Chopping out the end newline character...
		push(@output,split($delimiter,$line));
	}
	trimSpacesFromBothEnd(\@output);
	return @output;	
}


############ Calling: extractInputToMatrix(modelNumber,delimiter in single quote,inputfileName,startingWordPatterns seperated by comma to include/Exclude) ######
############ If first input is 0, then extract only those lines without starting those words... 
############                else, then extract only those lines with starting those words... 
############ Properties: 1. Removes the comments & blank lines in input file.
sub extractInputToMatrix {
	my $modelNumber = shift(@_);
	my $delimiter = shift(@_);
	my $inputfileName = shift(@_);
	my @startingWordPattern = @_;
	my(@outputMatrix,$isLineEligible);   #### TODO check if initialization can be done in declaration itself.
	
	my @lines = extractInputFileOfPerl($inputfileName);
	my $iLine=0;
	foreach my $line(@lines) {	
		############# Checking if line is compatible with modelNumber ###########
		if($modelNumber==0) {		
			$isLineEligible = 1;
			foreach my $element(@startingWordPattern) {
				if($line =~ m/^$element\b/) {
					$isLineEligible = 0; last;
				}
			}
		}
		if($modelNumber!=0){
			$isLineEligible = 0;			
			foreach my $element(@startingWordPattern) {
				if($line =~ m/^$element\b/) {
					$isLineEligible = 1; last;
				}
			}
		}
		if($line =~ m/^$/ || !$isLineEligible) { next; }
		##############################################################################
		
		my @lineElements = split($delimiter,$line);
		@{$outputMatrix[$iLine]} = @lineElements;
		$iLine ++;
	}
	trimSpacesFromBothEnd(\@outputMatrix);
	return @outputMatrix;
}

######### Advantage: Dereference all the pointers & print the values only ()with '\n' for array)..... ##########
######### Input: Only one reference to Scalar/Array... ##########
sub printAll {
	if(scalar(@_)>1) {				##### If input is an Array, then call the function for each element #####
		foreach my $element(@_) {
			printAll($element);
		}
		return;
	}
	
	my $input = $_[0];
	
	if ( UNIVERSAL::isa($input,'REF') ) {											# Reference to a Reference
		printAll(${$input});
	}
	elsif ( ! ref($input) ) { 														# Not a reference
	    if(defined $input) { print "$input \t"; }
	}
	elsif ( UNIVERSAL::isa($input,'SCALAR') ) {  									# Reference to a scalar
		printAll(${$input}); print "\n";
	}
	elsif ( UNIVERSAL::isa($input,'ARRAY') ) { 										# Reference to an array
		foreach my $element(@{$input}) {
			printAll($element);
		}
		print "\n";
	}
	elsif ( UNIVERSAL::isa($input,'HASH') ) { 										# Reference to a hash
	    print "Reference to an hash, Can't be printed...\n";
	}
	elsif ( UNIVERSAL::isa($input,'CODE') ) { 										# Reference to a subroutine
	    print "Reference to an subroutine, Can't be printed...\n";
	}
}

######### Advantage: Trim an array of array of array..... ##########
######### Input: Only one reference to Scalar/Array... ##########
sub trimSpacesFromBothEnd {
	my $input = $_[0];
	
	if ( UNIVERSAL::isa($input,'REF') ) {											# Reference to a Reference
		trimSpacesFromBothEnd(${$input});
	}
	elsif ( ! ref($input) ) { 														# Not a reference
	    print "Error(trimSpacesFromBothEnd): Not a reference, Can't be trimmed...";
	    exit 0;
	}
	elsif ( UNIVERSAL::isa($input,'SCALAR')) {  									# Reference to a scalar
		chomp(${$input});			## TODO This line added on 17-7-2012. won't be harmful, I think
		${$input} =~ s/^\s+//g;
		${$input} =~ s/\s+$//g;		
	}
	elsif ( UNIVERSAL::isa($input,'ARRAY') ) { 										# Reference to an array
		foreach my $element(@{$input}) {
			trimSpacesFromBothEnd(\$element);
		}
	}
	elsif ( UNIVERSAL::isa($input,'HASH') ) { 										# Reference to a hash
	    print "Error(trimSpacesFromBothEnd): Reference to an hash, Can't be trimmed...";
	    exit 0;
	}
	elsif ( UNIVERSAL::isa($input,'CODE') ) { 										# Reference to a subroutine
	    print "Error(trimSpacesFromBothEnd): Reference to an subroutine, Can't be trimmed...";
	    exit 0;
	}
}
######## Return: Transpose of cut part of input matrix with given columns... #######
######## Input: (pointer to Matrix,Array of colum indices to return)... #######
######## Note: Column Index(which is inputted) starts from 0 ##########
sub getColumnsOfMatrix {
	my @inputMatrix = @{shift(@_)};
	my @columnIndices = @_ ;
	my $maxNumberOfColumns = max(getNumColumnsPerRowOfMatrix(@inputMatrix));
	my @output;
	for(my $rowIndexOfInputMatrix=0; $rowIndexOfInputMatrix<scalar(@inputMatrix); $rowIndexOfInputMatrix++) {
		for(my $colIndexforOutputMatrix=0; $colIndexforOutputMatrix<scalar(@columnIndices); $colIndexforOutputMatrix++) {
#		if($columnIndices[$colIndexforOutputMatrix]>=$maxNumberOfColumns) { next; }
			if(defined $inputMatrix[$rowIndexOfInputMatrix][$columnIndices[$colIndexforOutputMatrix]]) {
				$output[$rowIndexOfInputMatrix][$colIndexforOutputMatrix] = $inputMatrix[$rowIndexOfInputMatrix][$columnIndices[$colIndexforOutputMatrix]];
			}
		}	
	}
	return @output;	
}

######## Return: Transpose of cut part of input matrix with given columns... #######
######## Input: (pointer to Matrix,Array of colum indices to return)... #######
######## Note: Column Index(which is inputted) starts from 0 ##########
sub getNumColumnsPerRowOfMatrix {
	my @inputMatrix = @_;
	my @output;
	for(my $rowIndexOfInputMatrix=0; $rowIndexOfInputMatrix<scalar(@inputMatrix); $rowIndexOfInputMatrix++) {
		$output[$rowIndexOfInputMatrix] = scalar(@{$inputMatrix[$rowIndexOfInputMatrix]});
	}	
	return @output;	
}

######## Return: Transpose of input Matrix... #######
######## Input: (pointer to Matrix,Array of colum indices to return)... #######
######## Note: Column Index(which is inputted) starts from 0 ##########
sub transposeOfMatrix {
	my @inputMatrix = @_;
	my @outputMatrix;
	for(my $rowIndexOfInputMatrix=0; $rowIndexOfInputMatrix<scalar(@inputMatrix); $rowIndexOfInputMatrix++) {
		if(! ref($inputMatrix[$rowIndexOfInputMatrix]) ) {	### If input is an array (not matrix)
			$outputMatrix[0][$rowIndexOfInputMatrix] = $inputMatrix[$rowIndexOfInputMatrix];
		}
		else {												### If input is a matrix
			for(my $colIndexOfInputMatrix=0; $colIndexOfInputMatrix<scalar(@{$inputMatrix[$rowIndexOfInputMatrix]}); $colIndexOfInputMatrix++) {
				$outputMatrix[$colIndexOfInputMatrix][$rowIndexOfInputMatrix] = $inputMatrix[$rowIndexOfInputMatrix][$colIndexOfInputMatrix];
			}
		}	
	}
	return @outputMatrix;	
}

######## Return: Array which contains (rowIndex of element 1, colIndex of element 1,....) #######
######## Input: (pointer to Matrix,Array of keywords to search)... #######
######## Note: All Indices starts from 0 ##########
sub getIndicesOfKeyword {
	my @inputMatrix = @{shift(@_)};
	my @keyWordsToSearch = @_;
	my @indicesArray;
	for(my $ikeyWordsToSearch=0; $ikeyWordsToSearch<scalar(@keyWordsToSearch); $ikeyWordsToSearch++) {
		for(my $rowIndexOfInputMatrix=0; $rowIndexOfInputMatrix<scalar(@inputMatrix); $rowIndexOfInputMatrix++) {
			if(! ref($inputMatrix[$rowIndexOfInputMatrix]) ) {	### If input is an array (not matrix)
					if($inputMatrix[$rowIndexOfInputMatrix] =~ m/^$keyWordsToSearch[$ikeyWordsToSearch]$/) {
						push(@indicesArray,$rowIndexOfInputMatrix);
					}
			}
			else {												### If input is a matrix
				for(my $colIndexOfInputMatrix=0; $colIndexOfInputMatrix<scalar(@{$inputMatrix[$rowIndexOfInputMatrix]}); $colIndexOfInputMatrix++) {
					if($inputMatrix[$rowIndexOfInputMatrix][$colIndexOfInputMatrix] =~ m/^$keyWordsToSearch[$ikeyWordsToSearch]$/) {
						push(@indicesArray,$rowIndexOfInputMatrix,$colIndexOfInputMatrix);
					}
				}
			}
		}
	}
	return @indicesArray;	
}

###### Return: Maximum value of Input Array... #####
sub max {
	my @sortedInput = sort {$a <=> $b} @_;
	return $sortedInput[-1];
}
###### Return: Minimum value of Input Array... #####
sub min {
	my @sortedInput = sort {$a <=> $b} @_;
	return $sortedInput[0];
}
######### Advantage: Dereference all the pointers & returns an array (if Matrix is given, then it's read each row by row)..... ##########
######### Input: Only one reference to Scalar/Array... ##########
sub convertToArray {
	my @output;
	if(scalar(@_)>1) {				##### If input is an Array, then call the function for each element #####
		foreach my $element(@_) {
			@output = (@output,convertToArray($element));
		}
		return @output;
	}
	
	my $input = $_[0];
	
	if ( UNIVERSAL::isa($input,'REF') ) {											# Reference to a Reference
		@output = (@output,convertToArray(${$input}));
	}
	elsif ( ! ref($input) ) { 														# Not a reference
	    if(defined $input) { return (@output,$input); }
	}
	elsif ( UNIVERSAL::isa($input,'SCALAR') ) {  									# Reference to a scalar
		@output = (@output,convertToArray(${$input}));
	}
	elsif ( UNIVERSAL::isa($input,'ARRAY') ) { 										# Reference to an array
		foreach my $element(@{$input}) {
			@output = (@output,convertToArray($element));
		}
	}
	elsif ( UNIVERSAL::isa($input,'HASH') ) { 										# Reference to a hash
	    print "Reference to an hash, Can't be printed...\n";
	}
	elsif ( UNIVERSAL::isa($input,'CODE') ) { 										# Reference to a subroutine
	    print "Reference to an subroutine, Can't be printed...\n";
	}
	return @output;
}

### Input: Array of input shell commands #####
### Note: This function waits for all bash-commands to get finished.. ######
use threads();
sub multiThreadBashCommands {
	my @threads; my $ithread=0;
	foreach my $bashCommand(@_) {
		if($bashCommand=~m/^\s*$/) { next; }
		$ithread = $ithread+1;
		push @threads, threads->new(sub{print(`$bashCommand`)}, $ithread);
	}
	foreach (@threads) {
	   $_->join();
	}
}



### Input: Array of input shell commands #####
### Return: Array of PIDs for the bash commands ######
sub spawnBashCommands {
	my @PIDsOfSpawnedProcesses;
	foreach my $bashCommand(@_) {
		if($bashCommand=~m/^\s*$/) { next; }
		my $fPID = fork();
		if(!defined($fPID)) {
			print "Error: Not able to fork...\n";
			exit 0;
		}
		elsif($fPID != 0) {	# Parent Process...
			push(@PIDsOfSpawnedProcesses,$fPID);
			next;
		}
		else {				# Child Process...
			print(`$bashCommand`);
			exit 0;
		}
	}
	return @PIDsOfSpawnedProcesses;
}

### Input: Array of PIDs to wait for...
### wait for all children to finish
sub waitForAllPIDsToFinish {
	for my $pid (@_) {
		if($pid=~m/^\s*$/) { next; }
	    waitpid $pid, 0; # TODO, check wht happens if process is not terminated properly?
	}
}

##### Input: first element is string for matching, remaining are regex-Patterns.. #####
##### Return: 1 if any regex is matching. else 0 ####
##### Note: this will skip all blank elements in regex array.. ####
sub checkForRegularExpressions {
	my $inputString = shift(@_);
	if(scalar(@_)==0) { return 0;}
	foreach my $regex(@_) {
		if(!defined($regex) || $regex =~ m/^\s*$/) { next; }
		if($inputString =~ m/$regex/) {
			return 1;
		}
	}
	return 0;
}

#### Input : Array of strings
#### Output: Array of strings with '\' put before every special characters...
sub convertToLiteralStringForShellGrep {
	my(@inputArray,@output,$inputString);
	@inputArray = @_;
	foreach $inputString(@inputArray) {
		$inputString =~ s/\[/\\\[/g;
		$inputString =~ s/\]/\\\]/g;
		$inputString =~ s/\(/\\\(/g;
		$inputString =~ s/\)/\\\)/g;
		push(@output,$inputString);
	}
	return @output;
}

## Wait untill number of Running Jobs < $maxParallelJobs
sub waitForParallelJobsCompletion {
    my($maxParallelJobs,@submittedJobsPIDsPIDs) = @_;
    my @allPIDsInSystem = split("\n",`$commandToKnowAllRunningJobs`);
    my @currentRunningJobsPIDs =  getCommonElements(\@submittedJobsPIDsPIDs,\@allPIDsInSystem);
    while(scalar(@currentRunningJobsPIDs) >= $maxParallelJobs) {
            sleep  30;  
#		@allPIDsInSystem = split("\n",`ps -eo pid`); 
            @allPIDsInSystem = split("\n",`$commandToKnowAllRunningJobs`);
            @currentRunningJobsPIDs =  getCommonElements(\@submittedJobsPIDsPIDs,\@allPIDsInSystem);
    }
}


## copy file with a suffix into the same folder.
sub backupFile {
    my $tempBackupFileSuffix_local = shift(@_);
    if($tempBackupFileSuffix_local =~ m/^$/) {$tempBackupFileSuffix_local = $tempBackupFileSuffix;}
    foreach my $originalFile(@_) {
        print(`cp -rf $originalFile "${originalFile}${tempBackupFileSuffix_local}";`);
    }
}

## Retrieve backup-file(ie with the suffix).
## Assumtion1: backupFile & original file are located in same folder.
## If a file/folder name inputted, then corresponding backedup file must be presend...
sub retrieveBackupFiles {
    my @inputs = @_;
    ## -Checking number of inputs
    if(scalar(@inputs)<2) {
        print "Error(retrieveBackupFiles): number of inputs must be >1 !! Currently it's ".scalar(@inputs);
        exit 0;
    }     
    ## -Get Suffix string    
    my $tempBackupFileSuffix_local = shift(@inputs);
    if($tempBackupFileSuffix_local =~ m/^$/) {$tempBackupFileSuffix_local = $tempBackupFileSuffix;}
    ## -Iterate for each of the input folder/file    
    foreach my $inputLocation(@inputs) {
        my @filesToRetrieve;
        if($inputLocation =~ m/$tempBackupFileSuffix_local$/) {               ## -If it's backed up folder/file
            if( -s $inputLocation) {
                @filesToRetrieve = ($inputLocation);
            }
            else {
                print "Error(retrieveBackupFiles): Non-Existent Backup folder/file = $inputLocation";
                exit 0;
            }
        }
        elsif(-s "$inputLocation$tempBackupFileSuffix_local") {               ## -If it's original folder/file, with an existing backup file.
            @filesToRetrieve = ("$inputLocation$tempBackupFileSuffix_local"); 
        }
        elsif( -d $inputLocation) {                                     ## -If it's original folder, then get all backedup files inside it
            my $searchPath = $inputLocation;
            @filesToRetrieve = split("\n", `find $searchPath |grep -P '.*$tempBackupFileSuffix_local\$'`);
        }
        else {
            print "Error(retrieveBackupFiles): Non-Existent Backup file = $inputLocation$tempBackupFileSuffix_local";
            exit 0;	
        }

        my @originalFileNames = @filesToRetrieve;
        foreach(@originalFileNames) { s/$tempBackupFileSuffix_local$//g; }
        foreach my $iFile(0..scalar(@originalFileNames)-1) {
            print(`rm -rf $originalFileNames[$iFile]; mv -f $filesToRetrieve[$iFile] $originalFileNames[$iFile];`);
        }
    }
}


