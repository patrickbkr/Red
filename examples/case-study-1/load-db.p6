#!/usr/bin/env perl6

use Red;


use lib <./lib>;
use OurFuncs;

=begin comment
# do not know how to 'use' these yet:
#model Person {...}
use Present;
use Attend;
use Email;
use Person;
=end comment

#==========================================================
# TODO Successfully split the following models into a lib
#      directory as individual packages and 'use' them
#      in this script and the 'query-db.p6' script.
model Person {...}

model Email is rw {
    # relationship
    has UInt $!person-id is referencing{:column<key>, :model<Person>};
    has Person $.person  is relationship{:column<key>, :model<Person>};

    # data:
    has Str  $.email     is column;
    has Str  $.notes     is column{:nullable};
    has UInt $.status    is column{:nullable};
}

model Present is rw {
    # relationship
    has UInt $!person-id is referencing{:column<key>, :model<Person>};
    has Person $.person  is relationship{:column<key>, :model<Person>};

    # data:
    has UInt $.year      is column;
    has Str  $.notes     is column{:nullable};
}

model Attend is rw {
    # relationship
    has UInt $!person-id is referencing{:column<key>, :model<Person>};
    has Person $.person  is relationship{:column<key>, :model<Person>};

    # data:
    has UInt $.year      is column;
    has Str  $.notes     is column{:nullable};
}

model Person is rw {
    # note the following is for user-defined keys
    has Str $.key          is id; 

    # data:
    has Str $.last         is column;
    has Str $.first        is column;
    has Str $.notes        is column{:nullable};

    # relations
    has Attend @.attends   is relationship({.person-id }, :model<Attend>);
    has Email @.emails     is relationship({.person-id }, :model<Email>);
    has Present @.presents is relationship({.person-id }, :model<Present>);
}
#==========================================================


my $f   = './data/attendees.csv';
my $dbf = './data/ctech.sqlite';

# use the following in-memory version and Red debug until
# getting desired results
my $*RED-DEBUG = 1;
=begin comment
my $*RED-DB = database "SQLite";
=end comment
my $*RED-DB = database "SQLite", :database($dbf);

if !@*ARGS {
    say qq:to/HERE/;
    Usage: $*PROGRAM go

    Reads data from CSV file '$f' and
    loads them into an SQLite database
    (file '$dbf').
    HERE
    exit;
}

# try blocks are needed until Red gets some updates
try { Attend.^create-table; }
handle-error $!;

try { Present.^create-table; }
handle-error $!;

try { Email.^create-table; }
handle-error $!;

try { Person.^create-table; }
handle-error $!;

my %keys = SetHash.new ; # check for dups
for $f.IO.lines -> $line {
    my @w = split $COMMA, $line;
    my $last  = tclc @w.shift;
    my $first = tclc @w.shift;
    # rest of data may vary
    my %a = SetHash.new;
    my %e = SetHash.new;
    my %p = SetHash.new;

    # TODO use a grammar to extract data from the input line
    for @w -> $w is copy {
        $w .= trim;
        if $w ~~ /(\d**4) (:i p)?/ {
            my $year = ~$0;
            if  $1 {
                %p{$year}++;
            }
            else {
                %a{$year}++;
            }
        }
        elsif $w ~~ /'@'/ {
            $w .= lc;
            %p{$w}++;
        }
        else {
            note "FATAL: Unexpected data word '$w'";
            die  "line: '$line'";
        }
    }

    # put in db
    # get a key for Person
    my $key = create-csv-key :$last, :$first;
    # unique?
    if %keys{$key}:exists {
        die "FATAL: key '$key' is NOT unique.";
    }
    else {
        %keys{$key}++;
    }

    # we have the data, insert into the four tables if not there already
    # TODO fix or add easy row checks with primary keys
    my $x = Person.^all.grep({.key eq $key});
    if !$x {
        my $p = Person.^create(:key($key), :last($last), :first($first));
        # check each child table's entry
        for %a.keys {
            $x = Attend.^all.grep({.year eq $_});
            $p.attends.create(:person_id($key), :year($_)) if !$x;
        }
        for %e.keys {
            $x = Email.^all.grep({.email eq $_});
            $p.emails.create(:person_id($key), :email($_)) if !$x;
        }
        for %p.keys {
            $x = Present.^all.grep({.year eq $_});
            $p.presents.create(:person_id($key), :year($_)) if !$x;
        }
    }
}

say "Normal end.";
say "Data are in database file '$dbf'." if $dbf.IO.f;
