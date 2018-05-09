#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename;
use lib dirname (__FILE__);

require "args.pl";

my ($build_mode,$compiler,$build_all_tests,$gtest,$root_dir,$prefix,$fmt_path);
my ($par,$clean,$dry_run,$verbose);

my $arg = Args->new();

sub clean_dir {
    my $dir = shift;
    chomp $dir;
    return $dir;
}

my $cur_dir = clean_dir `pwd`;

$arg->add_required_arg("build_mode",  \$build_mode);
$arg->add_required_arg("compiler",    \$compiler);
$arg->add_optional_arg("root_dir",    \$root_dir, $cur_dir);
$arg->add_optional_arg("build_tests", \$build_all_tests, 1);
$arg->add_optional_arg("fmt",         \$fmt_path, "");
$arg->add_optional_arg("prefix",      \$prefix, "");
$arg->add_optional_arg("par",         \$par, 8);
$arg->add_optional_arg("dry_run",     \$dry_run, 0);
$arg->add_optional_arg("verbose",     \$verbose, 0);
$arg->add_optional_arg("gtest",       \$gtest, "");
$arg->add_optional_arg("clean",       \$clean, 0);

$arg->parse_arguments(@ARGV);

$root_dir = $root_dir . "/" . $prefix . "/";

my $github_prefix = qw(git@github.com:);

my %repos = (
    'vt'         => qw(darma-mpi-backend/vt.git),
    'detector'   => qw(darma-mpi-backend/detector.git),
    'meld'       => qw(darma-mpi-backend/meld.git),
    'checkpoint' => qw(darma-mpi-backend/checkpoint.git),
    'backend'    => qw(darma-mpi-backend/darma-backend.git),
    'frontend'   => qw(DARMA-tasking/darma-frontend.git),
    'examples'   => qw(DARMA-tasking/darma-examples.git)
);

my @repo_install_order = (
    'meld',
    'detector',
    'checkpoint',
    'vt',
    'frontend',
    'backend',
    'examples'
);

print "auto build: root=$root_dir, prefix=$prefix\n";

sub clean_repo {
    my ($base_dir,$repo) = @_;
    if (-e "$base_dir") {
        system "rm -rf $base_dir";
    }
}

sub create_dir {
    my $dir = shift;
    system "mkdir -p $dir" if (!(-e $dir));
}

sub get_args {
    my $repo = shift;
    my $detector_path = "$root_dir/detector/detector-install";
    my $checkpoint_path = "$root_dir/checkpoint/checkpoint-install";
    my $meld_path = "$root_dir/meld/meld-install";
    my $vt_path = "$root_dir/vt/vt-install";
    my $frontend_path = "$root_dir/frontend/frontend-install";
    my $backend_path = "$root_dir/backend/backend-install";
    if ($repo eq "checkpoint") {
        return "1 $detector_path $gtest";
    } elsif ($repo eq "backend") {
        return "$vt_path $frontend_path $fmt_path";
    } elsif ($repo eq "examples") {
        return "$frontend_path $backend_path";
    } elsif ($repo eq "vt") {
        my $dpath = $detector_path;
        my $cpath = $checkpoint_path;
        my $mpath = $meld_path;
        return
            "build_mode=$build_mode " .
            "compiler=$compiler " .
            "build_tests=$build_all_tests " .
            "detector=$dpath " .
            "meld=$mpath " .
            "fmt=$fmt_path " .
            "gtest=$gtest " .
            "checkpoint=$cpath ";
    }
}

sub build_install {
    my ($base_dir,$repo,$mode) = @_;
    my $src_dir = "$base_dir/$repo";
    my $build_dir = "$base_dir/$repo-build";
    my $install_dir = "$base_dir/$repo-install";
    &create_dir($build_dir);
    &create_dir($install_dir);
    my $repo_path = "$github_prefix/$repos{$repo}";
    print "Cloning $repo_path...\n";
    system "git clone $repo_path $src_dir" if (!(-e $src_dir));
    my $prefix_cd = "cd $build_dir &&";
    my $args = &get_args($repo);
    if ($repo eq "frontend" || $repo eq "examples") {
        system "$prefix_cd $cur_dir/build-$repo.sh $build_mode $args";
    } elsif ($repo eq "vt") {
        #print "$prefix_cd $src_dir/scripts/build_$repo.pl $args";
        system "$prefix_cd $src_dir/scripts/build_$repo.pl $args";
    } else {
        system "$prefix_cd $src_dir/build-$repo.sh $build_mode $args";
    }
    system "$prefix_cd make -j$par";
    system "$prefix_cd make install -j$par";
}

foreach my $repo (@repo_install_order) {
    my $base_dir = "$root_dir/$repo";
    #print "$repo: base=$base_dir\n";
    #next if ($repo ne 'meld');
    if ($clean == 1) {
        &clean_repo($base_dir,$repo);
    } else {
        &create_dir("$base_dir");
        &build_install($base_dir,$repo);
    }
}


