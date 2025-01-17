use Test;
use Red;
use Red::Column;

plan :skip-all("Different driver setted ($_)") with %*ENV<RED_DATABASE>;

my $*RED-DB             = database "Mock";
my $*RED-DEBUG          = $_ with %*ENV<RED_DEBUG>;
my $*RED-DEBUG-RESPONSE = $_ with %*ENV<RED_DEBUG_RESPONSE>;
my $*RED-COMMENT-SQL    = $_ with %*ENV<RED_COMMENT_SQL>;
$*RED-DB.die-on-unexpected;

role Bla { has Str $.a is column }

model Ble does Bla {}

$*RED-DB.when: :once, :return[], qq:to/EOSQL/;
    CREATE TABLE "ble" (
        a varchar(255) NOT NULL
    )
EOSQL

Ble.^create-table;

model Bli does Bla { has Str $.b is column }

$*RED-DB.when: :once, :return[], qq:to/EOSQL/;
    CREATE TABLE "bli" (
        a varchar(255) NOT NULL,
        b varchar(255) NOT NULL
    )
EOSQL

Bli.^create-table;

$*RED-DB.when: :once, :return[{:1a}], 'insert into "ble" ( a ) values ( ? )';
$*RED-DB.when: :once, :return[], 'commit';
Ble.^create: :a<1>;

role SerialId {
    has UInt $!id is serial;
}

model Blu  { ... }

model Blo does SerialId {
    has UInt $!blu-id is referencing( *.id, :model<Blu> );
    has Blu  $.blu    is relationship( *.blu-id, :no-prefetch );
}

model Blu does SerialId {
    has Blo @.blo is relationship{ .blu-id };
}

$*RED-DB.when: :once, :return[], qq:to/EOSQL/;
    create table "blo" (
        blu_id integer null references blu (id),
        id integer not null primary key autoincrement
    )
EOSQL

$*RED-DB.when: :once, :return[], qq:to/EOSQL/;
    create table "blu" (
        id integer not null primary key autoincrement
    )
EOSQL

Blo.^create-table;
Blu.^create-table;

$*RED-DB.when: :once, :return[{:1id}],            q[insert into "blu" default values];
$*RED-DB.when: :once, :return[{:1id, :1blu-id},], q[insert into "blo"( blu_id )values( ? )];
$*RED-DB.when: :twice, :return[], 'commit';

my $blu = Blu.^create;
my $blo = $blu.blo.create;

$*RED-DB.when: :return[{:1id}], 'select "blu".id from "blu" where "blu".id = ? limit 1';

isa-ok $blu, Blu;
isa-ok $blo, Blo;

is-deeply $blo.blu, $blu;

role Bar[Bool :$opt-in = False] {
   has Int $.b is column;
}

role Baz {
   has Rat $.c is column;
}

model Foo does Bar[:opt-in] does Baz {
    has Int $.id is serial;
    has Str $.a is column;
}

$*RED-DB.when: :once, :return[], q:to/EOSQL/;
    create table "foo"(
        id integer not null primary key autoincrement,
        a varchar ( 255 ) not null,
        b integer not null,
        c real not null
    )
EOSQL
lives-ok { Foo.^create-table }

$*RED-DB.verify;

isa-ok Ble.a, Red::Column;
isa-ok Bli.a, Red::Column;
isa-ok Bli.b, Red::Column;

done-testing
