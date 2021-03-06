package DotPlot;
use strict;
use warnings;

use feature qw/switch/;
use Storable qw(dclone);

=head1 NAME

DotPlot - A module to read, manipulate and write DotPlot Files (Version 0.1 - nov 8 2011)

=head1 SYNOPSIS

		This module reads a DotPlot file as produced by RNAfold from the
		Vienna Package (http://www.tbi.univie.ac.at/RNA/).
		The DotPlot can then be read and modified in an object-oriented
		way. It is possible to add different colored annotations to the plot
		and finally write it to a postscript file.
		
		NOTE: Throughout the module base pair numbering will start with 0.
			I.e: A sequence with 10 bases will have bases 0 to 9.
			Please be aware that this differs from the representation in the 
			dotplot as numbering starts with 1 there.

=head2 EXAMPLES

=head3 CREATION & READING
	
	(1) my $DP = new DotPlot("/path/to/dotplot.ps");
		
		Creates a new DotPlot object from the given Postscript File.
		(The file will remain unchanged)
	
	(2) my $prob = DP.getProbability(<firstBase>, <secondBase>);
			
			Returns the probability that base 0 will pair with base 14 as 
			stated in the dotplot. 

=head3 MANIPULATION
	
	(3) DP.mirrorDotPlot()
		
		This function will cause the entries from the upper-right part of the 
		dotplot to be copied into the lower left half, i.e. the MFE structure
		will be deleted and the probability entries will be represented twice.
		Can be useful, if the MFE is not interesting, but more space for
		annotations is needed.
		
		
	(4) DP.setBasePairProbability(<firstBasePair>, <secondBasePair>, <newProbability>);
	
		Resets the probability value of a given BasePair.
		(NOTE: In case the DP has been mirrored before, this will only affect
		the upper right entry!)
	  	
	(5) DP.setUpperFullBox(<firstBase>, <secondBase>, <Red>, <Green>, <Blue>);
		
		Creates a filled box of given Color at given position in the upper right
		part of the dotplot. If a box exists at the given position it's size
		will remain. Otherwise the box will fill the whole field.
		(NOTE: The upper right fullBox entries are used to represent the 
		probabilities, so additional full boxes may corrupt this data.)
		
		(DP.setLowerFullBoxes works analogously)
	
	(6) DP.setUpperCross(<firstBase>, <secondBase>, <Red>, <Green>, <Blue>);

		Analog: DP.setLowerCross, DP.setUpperEmptyBox, DP.setLowerEmptyBox
		
		Creates a cross (or empty box) of given color at given position.
		These entries to not mess with probability scores.

=head3 OUTPUT
	
	(7) DP.writeToFile("/path/to/outputFile.ps");
	
			Will write the DotPlot object to a Postscript file. This file
			can again be read and manipulated by this module.
			(CAUTION: Existing files will be overwritten!)

=head1 AUTHOR: 

Niklas Meinzer <meinzern@informatik.uni-freiburg.de>


=cut

# these constants represent the supportet types of annotations,
# that can be applied to the DotPlot
use constant {
    LOWERCROSS   => 0,
    UPPERCROSS   => 1,
    LOWERFULLBOX => 2,
    UPPERFULLBOX => 3,
    LOWEREMPTYBOX => 4,
    UPPEREMPTYBOX => 5,
};

#######################################################################
# Creates a new DotPlot object from a DotPlot file as created by
# RNAfold
# INPUT: the filename of the input file
# OUTPUT: a reference to the newly created DotPlot object
#######################################################################
sub new
{
  my $class = shift;
  my $self = {};
  
  my $filename = shift;

  if(!defined $filename)
  {
    die("DotPlot::new: No filename given!");
  }
  
  #$self->parseDotPlotFile($filename);
  $self->{"leadingComments"} = [];
  $self->{"leadingCommands"} = [];
  $self->{"definitions"} = {};
  
  # holds the colorvalues for the empty boxes
  # if no entry exists, there will be no box
  $self->{"upperEmptyBoxes"} = {};
  $self->{"lowerEmptyBoxes"} = {};
  $self->{"upperBoxes"} = {};
  $self->{"lowerBoxes"} = {};
  $self->{"lowerCrosses"} = {};
  $self->{"upperCrosses"} = {};
  
  bless $self, $class;
  
  $self->parseDotPlotFile($filename);

  
  return $self;
}

#######################################################################
# Writes the DotPlot object to a DotPlot File
# INPUT: the filename of the output file
# OUTPUT: none
#######################################################################
sub writeToFile
{
  my $self = shift;
  my $filename = shift;
  
  if(!defined $filename)
  {
    die("DotPlot::writeToFile: No filename given!");
  }
  
  open(OUT, ">$filename");
  
  if(tell(OUT) == -1)
  {
		die("DotPlot::writeToFile: Unable to open file!");
	}
	
	# Write the leading comments
	
	foreach my $line (@{$self->{"leadingComments"}})
	{
		print OUT $line;
	}
	
	# Write DP specific line
	print OUT "/DPdict 100 dict def\nDPdict begin\n";
	
	# Write postscript definitions
	
	while (my ($name, $value) = each(%{$self->{"definitions"}}))
	{
		# the len definition must be the last definition, because it is 
		# used to indentify the end of the definitions during parsing 
		next if($name eq "len");
		print OUT "/$name " . $value . " def\n\n";
	}
	# finally write len definition
	print OUT "/len " . $self->{"definitions"}->{"len"} . " def\n\n";

	
	# Write leading commands
	foreach my $line (@{$self->{"leadingCommands"}})
	{
		next if ($line =~ m/^[ |\n]$/);
		print OUT $line;
	}
	
	# write boxes
	while (my ($key, $value) = each (%{$self->{"upperBoxes"}}))
	{
		my ($fb, $sb) = split /-/, $key;
		print OUT $value->{"R"} . " " . $value->{"G"} . " " . $value->{"B"} . " setrgbcolor ";
		print OUT "$fb $sb " . $value->{"size"} . " ubox\n";
	}
	while (my ($key, $value) = each (%{$self->{"lowerBoxes"}}))
	{
		my ($fb, $sb) = split /-/, $key;
		print OUT $value->{"R"} . " " . $value->{"G"} . " " . $value->{"B"} . " setrgbcolor ";
		print OUT "$fb $sb " . $value->{"size"} . " lbox\n";
	}
	
	# write empty boxes
	while (my ($key, $value) = each (%{$self->{"upperEmptyBoxes"}}))
	{
		my ($fb, $sb) = split /-/, $key;
		print OUT $value->{"R"} . " " . $value->{"G"} . " " . $value->{"B"} . " setrgbcolor ";
		print OUT "$fb $sb " . $value->{"size"} . " obox\n";
	}
	while (my ($key, $value) = each (%{$self->{"lowerEmptyBoxes"}}))
	{
		my ($fb, $sb) = split /-/, $key;
		print OUT $value->{"R"} . " " . $value->{"G"} . " " . $value->{"B"} . " setrgbcolor ";
		print OUT "$fb $sb " . $value->{"size"} . " lobox\n";
	}	
	# write crosses
	while (my ($key, $value) = each (%{$self->{"upperCrosses"}}))
	{
		my ($fb, $sb) = split /-/, $key;
		print OUT $value->{"R"} . " " . $value->{"G"} . " " . $value->{"B"} . " setrgbcolor ";
		print OUT "$fb $sb " . $value->{"size"} . " ucross\n";
	}
	while (my ($key, $value) = each (%{$self->{"lowerCrosses"}}))
	{
		my ($fb, $sb) = split /-/, $key;
		print OUT $value->{"R"} . " " . $value->{"G"} . " " . $value->{"B"} . " setrgbcolor ";
		print OUT "$fb $sb " . $value->{"size"} . " lcross\n";
	}	
	
	# Write ending commands
	
	
	print OUT "showpage\nend";
	
	close(OUT);
  
}

# resets the value of a basepair
# counting begins at 0
sub setBasePairProbability
{
  my $self = shift;
  my $fb = shift;
  my $sb = shift;
  my $newValue = shift;
  
  if(!defined $fb or !defined $sb or !defined $newValue)
  {
    die("DotPlot::setBasePair: No BasePair or new value specified!");
  }
  my $BP = ($fb+1) . "-" . ($sb+1);
  
  my $entry = $self->{"upperBoxes"}->{$BP};
  if(!defined $entry)
  {
    $entry = {"R" => 0, "G" => 0, "B" => 0};
  }
  $entry->{"size"} = sqrt($newValue);
  
  $self->{"upperBoxes"}->{$BP} = $entry;
}
# sets a new RGB value for a given BasePair
sub setUpperFullBox
{
  my $self = shift;
  $self->setColoredEntry(shift, shift, shift, shift, shift, $self->{"upperBoxes"});
}

sub setUpperCross
{
  my $self = shift;
  $self->setColoredEntry(shift, shift, shift, shift, shift, $self->{"upperCrosses"});
}
sub setLowerCross
{
  my $self = shift;
  $self->setColoredEntry(shift, shift, shift, shift, shift, $self->{"lowerCrosses"});
}

# creates an entry for an empty box around aBP
sub setUpperEmptyBox
{  
  my $self = shift;
  
  $self->setColoredEntry(shift, shift, shift, shift, shift, $self->{"upperEmptyBoxes"});
}

# creates an entry for an empty box around aBP in the lower left part of the DotPlot
sub setLowerEmptyBox
{  
  my $self = shift;
  $self->setColoredEntry(shift, shift, shift, shift, shift, $self->{"lowerEmptyBoxes"});
}

# creates an entry for a filled Box in the lower left part of the DotPlot
sub setLowerFullBox
{  
  my $self = shift;
  $self->setColoredEntry(shift, shift, shift, shift, shift, $self->{"lowerBoxes"});
}

# sets a colored Entry
# counting begins at 0
sub setColoredEntry
{
  my $self = shift;
  
  my $fb = shift;
  my $sb = shift;
  my $BP = ($fb +1) . "-" . ($sb + 1);
  
  my $R = shift;
  my $G = shift; 
  my $B = shift;
  
  my $hash = shift;
  
  if(!defined $R or !defined $G or !defined $B or !defined $BP or !defined $hash)
  {
    die("DotPlot::setColoredEntry: Invalid input");
  }
  
  my $oldEntry = $hash->{$BP};
  
  if(!defined $oldEntry)
  {
		$oldEntry = {"size" => 1};
	}
  $oldEntry->{"R"} = $R;
  $oldEntry->{"G"} = $G;
  $oldEntry->{"B"} = $B;
  
  $hash->{$BP} = $oldEntry;  
}


# copies values of upper boxes to values of lower boxes
sub mirrorDotPlot
{
  my $self = shift;
  
  $self->{"lowerBoxes"} = {};
  
  while (my ($key, $originalValue) = each(%{$self->{"upperBoxes"}}))
  {
    my $value = dclone($originalValue);
    # set color to black
    $value->{"R"} = 0;
    $value->{"G"} = 0;
    $value->{"B"} = 0;
    $self->{"lowerBoxes"}->{$key} = $value;
  }
  $self->{"mirrored"} = 1;
}

sub parseDotPlotFile
{
	use constant HEADER => "%Warning: This DotPlot file has been modified using the DotPlot.pm module\n
%	  This module uses commands starting with %#\n
%	  Do not delete these lines or the file can not be loaded again!\n
%# modified\n";

	my $self = shift;
	
	my $filename = shift;
  
	# open file
	if(not(-e $filename)){
		die("File ",$filename," does not exist!\n");
	}
	open(PLOT, $filename);
	my @plot = <PLOT>;
	close(PLOT);
	
	# Parse leading comments
	while(scalar(@plot) != 0)
	{
		my $line = shift(@plot);
		
		# the first line that does not start with a %, a space or a line break
		# ends the leading comments
		
		if($line =~ m/^[%| |\n]/)
		{
			push(@{$self->{"leadingComments"}}, $line);
			next;
		}
		last;
	}
	
	# Parse definitions
	
	while(scalar(@plot) != 0)
	{
		my $line = shift(@plot);
		if($line =~ m/^\//)
		{
			my $newDefName = (split / /, $line)[0];
			$newDefName =~ s/\/|\{|\n//g;
			# Skip the DPdict definition as it is always present and 
			# included automatically
			next if ($newDefName eq "DPdict" || $newDefName eq "Helvetica");
			my $newDefValue = $line;
			$newDefValue =~ s/^\/$newDefName *|\n//g;
			
			# one lined definition?
			if($newDefValue =~ m/ def/g)
			{
				$newDefValue =~ s/ def//g;
				$self->{"definitions"}->{$newDefName} = $newDefValue;								
				# len is usually the last definition
				last if $newDefName eq "len";
				next;
			}
			# determine value of definition
			while(scalar(@plot) != 0)
			{
				$line = shift(@plot);
				if($line =~ m/ def/g)
				{
					$line =~ s/ def|\n//g;
					$newDefValue .= "\n" . $line;
					last;
				}
				$line =~ s/\n//g;
				$newDefValue .= "\n" . $line;
			}
			$self->{"definitions"}->{$newDefName} = $newDefValue;
		}
	}
  
  # add missing definitions
  $self->addMissingDefinitions();
	
	# Parse leading commands
	while(scalar(@plot) != 0)
	{
		my $line = shift(@plot);
		push(@{$self->{"leadingCommands"}}, $line);
		last if $line =~ m/^drawgrid$/;
	}

	# finally parse the boxes, empty boyes and crosses
	while(scalar(@plot) != 0)
	{
		my $line = shift(@plot);
		chomp $line;
		# omit comments
		next if $line =~ m/^%/;
		# "showpage" yields the end of the entries
		last if ($line eq "showpage");
		
		my @splitted = split / /,$line;
		my $len = scalar(@splitted);
		if($len != 4 && $len != 8)
		{
			die("Invalid line: $line");
		}
		
		# assemble entry
		my $newEntry = {"R" => 0,
										"G" => 0,
										"B" => 0};
	  my $key = "";
		if($len == 8)
		{
			$newEntry->{"R"} = $splitted[0];
			$newEntry->{"G"} = $splitted[1];
			$newEntry->{"B"} = $splitted[2];
			$newEntry->{"size"} = $splitted[6];
			
			$key = $splitted[4] . "-" . $splitted[5];
		}
		if($len == 4)
		{
			$newEntry->{"size"} = $splitted[2];
			$key = $splitted[0] . "-" . $splitted[1];
		}		
		
		# identify entry
		my $kind = $splitted[$len-1];
		
			if($kind eq "ubox")
			{
				$self->{"upperBoxes"}->{$key} = $newEntry;
			}
			if($kind eq "lbox")
			{
				$self->{"lowerBoxes"}->{$key} = $newEntry;
			}
			if($kind eq "lobox")
			{
				$self->{"lowerEmptyBoxes"}->{$key} = $newEntry;
			}
			if($kind eq "obox")
			{
				$self->{"upperEmptyBoxes"}->{$key} = $newEntry;
			}
			if($kind eq "lcross")
			{
				$self->{"lowerCrosses"}->{$key} = $newEntry;
			}
			if($kind eq "ucross")
			{
				$self->{"upperCrosses"}->{$key} = $newEntry;
			}
		
		
	}

}

# returns the probability of a given Basepair as found in the dotplot
# basepair counting begins with 0
sub getProbability
{
  my $self = shift;
  
  my $fb = shift;
  my $sb = shift;
  
  if(!defined $fb || !defined $sb)
  {
    die("DotPlot::getProbability: No BP given!");
  }
  
  my $BP = ($fb+1) . "-" . ($sb+1);
  
  my $prob;
  
  if(!defined $self->{"upperBoxes"}->{$BP})
  {
    $prob = 0;
  } else {
    $prob = $self->{"upperBoxes"}->{$BP}->{"size"};
  }
  
  # return $prob^2 because the Dotplot saves sqrts of probabilitys
  return $prob*$prob;
}

# adds postscript definitions for empty boxes and crosses
sub addMissingDefinitions
{
  my $self = shift;
  
  if(!defined $self->{"definitions"}->{"obox"})
  {
    $self->{"definitions"}->{"obox"} = "{\nlogscale {\n      log dup add lpmin div 1 exch sub dup 0 lt { pop 0 } if\n   } if\n   3 1 roll\n   exch len exch sub 1 add rect\n} bind";
  }
  if(!defined $self->{"definitions"}->{"lobox"})
  {
    $self->{"definitions"}->{"lobox"} = "{3 1 roll\nlen exch sub 1 add rect\n} bind";
  }
  if(!defined $self->{"definitions"}->{"rect"})
  {
    $self->{"definitions"}->{"rect"} = "{ %size x y rect - draws rectangle centered on x,y\n2 index 0.5 mul sub            % x -= 0.5\nexch 2 index 0.5 mul sub exch  % y -= 0.5\n3 -1 roll dup rectstroke\n} bind";
  }
  if(!defined $self->{"definitions"}->{"cross"})
  {
    $self->{"definitions"}->{"cross"} = "{ %size x y box - draws box centered on x,y\n   0.5 sub            % x -= 0.5\n   exch  0.5 sub exch  % y -= 0.5\n   1 index 1 index newpath moveto 1 index 1 add 1 index 1 add lineto stroke\n   1 index 1 add 1 index newpath moveto 1 index 1 index 1 add lineto stroke\n} bind";
  }
  if(!defined $self->{"definitions"}->{"lcross"})
  {
    $self->{"definitions"}->{"lcross"} = "{\n   3 1 roll\n   len exch sub 1 add cross\n} bind";
  }
  if(!defined $self->{"definitions"}->{"ucross"})
  {
    $self->{"definitions"}->{"ucross"} = "{\n   3 1 roll\n   exch len exch sub 1 add cross\n} bind";
  }
}

# this method takes a dot bracket string, annotation type and color
# and applies annotations corresponding to this dot bracket string
sub annotateDotBracketString
{
  my $self = shift;

  my ($string, $type, $R, $G, $B) = @_;

  my $annotations;

  given($type) {
    when (UPPERCROSS) { $annotations = $self->{upperCrosses}; }
    when (LOWERCROSS) { $annotations = $self->{lowerCrosses}; }
    when (UPPERFULLBOX) { $annotations = $self->{upperFullBoxes}; }
    when (LOWERFULLBOX) { $annotations = $self->{lowerFullBoxes}; }
    when (UPPEREMPTYBOX) { $annotations = $self->{upperEmptyBoxes}; }
    when (LOWEREMPTYBOX) { $annotations = $self->{lowerEmptyBoxes}; }
  }
  
  my $hash = dotBracketToHash($string);

  while( my ($key, $value) = each(%{$hash})){
    $self->setColoredEntry($key, $value, $R, $G, $B, $annotations);
  }
}

#================================================================
# Converts a dot bracket string into a base pair hash
# 
#================================================================
sub dotBracketToHash
{
	my $temp = shift;
	
	my @input = split //,$temp;
	
	my @BracketTypes = ( "()" ,
						 "[]" ,
						 "{}" ,
						 "<>" ,
						 "Aa" ,
						 "Bb");

	my %Stacks = ();
	
	for(my $i = 0; $i < scalar(@BracketTypes); $i++)
	{
		$Stacks{$BracketTypes[$i]} = ();
	}
	
	my %out = ();
	
	for (my $i = 0; $i < scalar(@input); $i++)
	{
	  next if($input[$i] eq ".");
	  foreach my $BT (@BracketTypes)
	  {
		  my @B = split //, $BT;
		  next unless ($input[$i] eq $B[0]) || ($input[$i] eq $B[1]);
		  if($input[$i] eq $B[0])
		  {
			  push(@{$Stacks{$BT}}, $i);
			  last;
		  }
		  if($input[$i] eq $B[1])
		  {
			  my $fb = pop(@{$Stacks{$BT}});
			  $out{$fb} = $i;
			  last;
		  }
 	  }
	}
	return \%out;
}
1;

