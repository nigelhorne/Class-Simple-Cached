# Generated from Makefile.PL using makefilepl2cpanfile

requires 'perl', '5.6.2';

requires 'Carp';
requires 'Class::Simple';
requires 'Params::Get';
requires 'Scalar::Util';

on 'test' => sub {
	requires 'CHI';
	requires 'Class::Simple';
	requires 'English';
	requires 'File::Spec';
	requires 'Test::Carp';
	requires 'Test::DescribeMe';
	requires 'Test::Most';
	requires 'Test::Needs';
	requires 'Test::NoWarnings';
	requires 'Test::Requires';
};

on 'develop' => sub {
	requires 'Devel::Cover';
	requires 'Perl::Critic';
	requires 'Test::Pod';
	requires 'Test::Pod::Coverage';
};
