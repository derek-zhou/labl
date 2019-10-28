use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'App::Labl',
    ABSTRACT_FROM    => 'lib/App/Labl.pm',
    AUTHOR           => 'Derek Zhou',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.012',
    VERSION_FROM    => 'lib/App/Labl.pm',
    EXE_FILES       => ['script/labl'],
    PREREQ_PM        => {
	'strict'   => 0,
	'warnings' => 0,
	'Mojo::Base' => 0,
	'Cwd' => 0,
    },
    META_MERGE => {
	'meta-spec' => { version => 2 },
	resources => {
	    repository => {
		type => 'git',
		url  => 'https://github.com/derek-zhou/labl.git',
		web  => 'https://github.com/derek-zhou/labl',
	    },
	},
    },
    );
