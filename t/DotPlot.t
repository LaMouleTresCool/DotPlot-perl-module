#!/usr/bin/perl -w

use strict;
use DotPlot;
use lib '..';

use Test::More qw(no_plan);

BEGIN
{
	use_ok("DotPlot");
}

can_ok("DotPlot", ("new"));

# Test parsing of DP files
my $testPlot = DotPlot->new("t/TestData/dot2.ps");
is(scalar(@{$testPlot->{"leadingComments"}}), 15, "leanding comments");

is(scalar(keys(%{$testPlot->{"definitions"}})), 15, "definitions");
ok(defined $testPlot->{"definitions"}->{"lpmin"});
ok(defined $testPlot->{"definitions"}->{"lbox"});
ok(defined $testPlot->{"definitions"}->{"drawgrid"});

ok(!($testPlot->{"definitions"}->{"drawgrid"} =~ m/^\/drawgrid/), "catch bad formatted def");

is(scalar(@{$testPlot->{"leadingCommands"}}), 12, "leanding commands");


is($testPlot->{"definitions"}->{"logscale"},"false", "definition value");
is($testPlot->{"definitions"}->{"box"},"{ %size x y box - draws box centered on x,y
   2 index 0.5 mul sub            % x -= 0.5
   exch 2 index 0.5 mul sub exch  % y -= 0.5
   3 -1 roll dup rectfill
} bind", "definition value");

is(scalar(keys(%{$testPlot->{"upperBoxes"}})), 208, "uboxes");
is(scalar(keys(%{$testPlot->{"lowerBoxes"}})), 11, "lboxes");
is($testPlot->{"upperBoxes"}->{"30-36"}->{"size"}, 0.004850104);
is($testPlot->{"upperBoxes"}->{"2-11"}->{"size"}, 0.638868622);
# test getProbability

ok(equal($testPlot->getProbability(1,10), 0.4081531,5), "getProbability");


$testPlot = DotPlot->new("t/TestData/dot4.ps");

is(scalar(keys(%{$testPlot->{"lowerEmptyBoxes"}})), 16, "loboxes");
is(scalar(keys(%{$testPlot->{"upperEmptyBoxes"}})), 11, "oboxes");
is(scalar(keys(%{$testPlot->{"upperCrosses"}})), 1, "ucrosses");
is(scalar(keys(%{$testPlot->{"lowerCrosses"}})), 1, "lcrosses");

$testPlot->writeToFile("t/TestData/test.ps");

$testPlot = DotPlot->new("t/TestData/test.ps");

is(scalar(keys(%{$testPlot->{"lowerEmptyBoxes"}})), 16, "loboxes");
is(scalar(keys(%{$testPlot->{"upperEmptyBoxes"}})), 11, "oboxes");
is(scalar(keys(%{$testPlot->{"upperCrosses"}})), 1, "ucrosses");
is(scalar(keys(%{$testPlot->{"lowerCrosses"}})), 1, "lcrosses");

is(scalar(keys(%{$testPlot->{"definitions"}})), 15, "definitions");


$testPlot->writeToFile("t/TestData/test2.ps");


$testPlot->setBasePairProbability(7, 26, 0.5);
$testPlot->mirrorDotPlot();
$testPlot->setUpperFullBox(7, 26, 1,0,0);
$testPlot->setUpperEmptyBox(7, 26, 1,0,0);

is($testPlot->{"upperEmptyBoxes"}->{"8-27"}->{"R"}, 1, "after color was set: R value ok?");
is($testPlot->{"upperBoxes"}->{"8-27"}->{"R"}, 1, "after color was set: R value ok?");
is($testPlot->{"upperBoxes"}->{"8-27"}->{"G"}, 0, "after color was set: G value ok?");
is($testPlot->{"upperBoxes"}->{"8-27"}->{"B"}, 0, "after color was set: B value ok?");

is($testPlot->{"lowerBoxes"}->{"8-27"}->{"R"}, 0, "after color was set: R value ok?");
is($testPlot->{"lowerBoxes"}->{"8-27"}->{"G"}, 0, "after color was set: G value ok?");
is($testPlot->{"lowerBoxes"}->{"8-27"}->{"B"}, 0, "after color was set: B value ok?");


$testPlot = DotPlot->new("t/TestData/dot.ps");

$testPlot->mirrorDotPlot();

while (my ($key, $value) = each(%{$testPlot->{"upperBoxes"}}))
{
  is($testPlot->{"lowerBoxes"}->{$key}->{"size"}, $value->{"size"}, "mirroredBps");
  is($testPlot->{"lowerBoxes"}->{$key}->{"R"}, 0, "mirroredBPS black?");
}



sub equal 
{ 
  my ($A, $B, $dp) = @_;
  return sprintf("%.${dp}g", $A) eq sprintf("%.${dp}g", $B);
}

1;
