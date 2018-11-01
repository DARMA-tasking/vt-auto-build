#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename;
use lib dirname (__FILE__);

require "args.pl";

my ($build_mode,$build_all_tests,$gtest,$root_dir,$prefix,$fmt_path);
my ($backend,$compiler_c,$compiler_cxx,$kokkos_path);
my ($par,$clean,$dry_run,$verbose, $atomic);

my $arg = Args->new();

sub clean_dir {
    my $dir = shift;
    chomp $dir;
    return $dir;
}

my $cur_dir = clean_dir `pwd`;

$arg->add_required_arg("build_mode",  \$build_mode         );
$arg->add_required_arg("compiler_c",  \$compiler_c,      "");
$arg->add_required_arg("compiler_cxx",\$compiler_cxx,    "");
$arg->add_optional_arg("root_dir",    \$root_dir,        $cur_dir);
$arg->add_optional_arg("build_tests", \$build_all_tests, 1);
$arg->add_optional_arg("fmt",         \$fmt_path,        "");
$arg->add_optional_arg("kokkos",      \$kokkos_path,     "");
$arg->add_optional_arg("prefix",      \$prefix,          "");
$arg->add_optional_arg("par",         \$par,             14);
$arg->add_optional_arg("dry_run",     \$dry_run,         0);
$arg->add_optional_arg("verbose",     \$verbose,         0);
$arg->add_optional_arg("gtest",       \$gtest,           "");
$arg->add_optional_arg("clean",       \$clean,           0);
$arg->add_optional_arg("backend",     \$backend,         0);
$arg->add_optional_arg("atomic",      \$atomic,          "");

$arg->parse_arguments(@ARGV);

$root_dir = $root_dir . "/" . $prefix . "/";

my $github_prefix = qw(git@github.com:);

my %repos = (
    'gtest'      => qw(google/googletest.git),
    'fmt'        => qw(fmtlib/fmt.git),
    'vt'         => qw(darma-mpi-backend/vt.git),
    'detector'   => qw(darma-mpi-backend/detector.git),
    'meld'       => qw(darma-mpi-backend/meld.git),
    'checkpoint' => qw(darma-mpi-backend/checkpoint.git)
);

my %repos_branch = (
    'gtest'      => qw(release-1.8.1),
    'fmt'        => qw(5.2.1),
    'vt'         => qw(develop),
    'detector'   => qw(master),
    'meld'       => qw(master),
    'checkpoint' => qw(master)
);

my @repo_install_order = (
    'fmt',
    'gtest',
    'meld',
    'detector',
    'checkpoint',
    'vt'
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
    if ($repo eq "checkpoint") {
        my $build_test = "ON";
        if (!$build_all_tests) {
            $build_test = "OFF";
        }
        return "1 $detector_path $gtest $build_test "
            " $compiler_c $compiler_cxx $kokkos_path";
    } elsif ($repo eq "detector" || $repo eq "meld") {
        return "$compiler_c $compiler_cxx";
    } elsif ($repo eq "vt") {
        my $dpath = $detector_path;
        my $cpath = $checkpoint_path;
        my $mpath = $meld_path;
        my $compiler_str = "";
        if ($compiler_c ne "") {
            $compiler_str = $compiler_str . "compiler_c=${compiler_c} "
        }
        if ($compiler_cxx ne "") {
            $compiler_str = $compiler_str . "compiler_cxx=${compiler_cxx} "
        }
        my $atomic_str = "";
        if ($atomic ne "") {
            $atomic_str = "atomic=true";
        }
        my $str =
            "build_mode=$build_mode " .
            "compiler=clang " .
            $compiler_str .
            "build_tests=$build_all_tests " .
            "detector=$dpath " .
            "meld=$mpath " .
            "fmt=$fmt_path " .
            "gtest=$gtest " .
            "$atomic_str " .
            "checkpoint=$cpath ";
        print "compiler string=\"$compiler_str\"\n";
        print "string=\"$str\"\n";
        return $str;
    } elsif ($repo eq "fmt" || $repo eq "gtest") {
        return "$compiler_c $compiler_cxx";
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
    my $branch = "$repos_branch{$repo}";
    my $git_cmd = "git clone --branch $branch --depth=1 $repo_path $src_dir";
    print "\n";
    print "=== Starting build/install of dependency: $repo ===\n";
    print "=== Cloning $repo_path: $git_cmd ===\n";
    system "$git_cmd" if (!(-e $src_dir));
    #print "XXX: cd $src_dir && git checkout $repos_branch{$repo}\n";
    my $prefix_cd = "cd $build_dir &&";
    my $args = &get_args($repo);
    if ($repo eq "fmt" || $repo eq "gtest") {
        my $conf_cmd = "$prefix_cd $cur_dir/build-$repo.sh Release $args";
        system("$conf_cmd") == 0 or die "Failed: $conf_cmd\n";
    } elsif ($repo eq "vt") {
        my $cmd = "$prefix_cd $src_dir/scripts/build_$repo.pl $args\n";
        system("$cmd") == 0 or die "Failed: $cmd\n";
    } else {
        my $cmd = "$prefix_cd $src_dir/build-$repo.sh $build_mode $args";
        system("$cmd") == 0 or die "Failed: $cmd\n";
    }
    my $verbose_str = "";
    if ($verbose == 1) {
        $verbose_str = " VERBOSE=1 ";
    }
    my $build_cmd = "$prefix_cd make $verbose_str -j$par";
    my $build_install = "$prefix_cd make install $verbose_str -j$par";
    print "Running: $build_cmd\n";
    system("$build_cmd") == 0 or die "Build failed: $build_cmd\n";
    print "Running: $build_install\n";
    system("$build_install") == 0 or die "Install failed: $build_cmd\n";;
    if ($repo eq "gtest" && $gtest eq "") {
        $gtest="$base_dir/$repo-install/";
    }
    if ($repo eq "fmt" && $fmt_path eq "") {
        $fmt_path="$base_dir/$repo-install/";
    }
}

my $version = `cmake --version | head -1 | awk '{print \$3}'`;
chomp $version;

system("cmake -P test_cmake_version.cmake") == 0 or
    die "You need a more up-to-date cmake:\n \t " .
    "Current version: $version \n\t" .
    "Required version: 3.10\n";
# print "CMAKE VERSION: $ret\n";

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


