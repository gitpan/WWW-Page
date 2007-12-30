use 5.008;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME' => 'WWW::Page',
    'VERSION_FROM' => 'lib/WWW/Page.pm',
    ($] >= 5.005
        ?
        (ABSTRACT_FROM => 'lib/WWW/Page.pm',
        AUTHOR => 'Andrew Shitov <andy@shitov.ru>')
        :
        ()
    ),
    'PREREQ_PM' => {
        'XML::LibXML' => 0,
        'XML::LibXSLT' => 0,
    }
);
