use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'XML::xmlapi',
    AUTHOR              => q{Michael Roberts <michael@vivtek.com>},
    VERSION_FROM        => 'lib/XML/xmlapi.pm',
    ABSTRACT_FROM       => 'lib/XML/xmlapi.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'XML-xmlapi-*' },
);
