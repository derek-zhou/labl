use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'App::Labl',
    VERSION_FROM    => 'lib/App/Labl.pm',
    EXE_FILES       => ['script/labl'],
    PREREQ_PM        => {
	'strict'   => 0,
	'warnings' => 0,
	'Mojo::Base' => 0,
	'Cwd' => 0,
    },
    );
