use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Filesystem::DiskFree',
    'VERSION_FROM' => 'DiskFree.pm', # finds $VERSION
);
