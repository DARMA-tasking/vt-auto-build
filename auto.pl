#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename;
use lib dirname (__FILE__);

require "args.pl";

my ($build_mode,$build_all_tests,$gtest,$root_dir,$prefix);
my ($backend,$compiler_c,$compiler_cxx,$kokkos_path,$build_kokkos);
my ($par,$clean,$dry_run,$verbose,$atomic,$fast_build,$vt_detector,$lb_on);
my $trace_on;
my ($mpi_cc,$mpi_cxx);
my $vt_build = "";

my $arg = Args->new();

sub clean_dir {
    my $dir = shift;
    chomp $dir;
    return $dir;
}

my $cur_dir = clean_dir `pwd`;

my @vt_builds = (
    'debug',
    'release',
    'relwithdebinfo',
    'coverage' # Enable coverage for VT
);

my @builds = (
    'debug', 'release', 'relwithdebinfo'
);

my @modes = ("debug","release");

$arg->add_required_val("build_mode",    \$build_mode,      \@builds);
$arg->add_required_arg("compiler_c",    \$compiler_c,      "");
$arg->add_required_arg("compiler_cxx",  \$compiler_cxx,    "");
$arg->add_optional_val("vt_build_mode", \$vt_build,        "", \@vt_builds);
$arg->add_optional_arg("root_dir",      \$root_dir,        $cur_dir);
$arg->add_optional_arg("build_tests",   \$build_all_tests, 1);
$arg->add_optional_arg("kokkos",        \$kokkos_path,     "");
$arg->add_optional_arg("build_kokkos",  \$build_kokkos,    0);
$arg->add_optional_arg("prefix",        \$prefix,          "");
$arg->add_optional_arg("par",           \$par,             14);
$arg->add_optional_arg("dry_run",       \$dry_run,         0);
$arg->add_optional_arg("verbose",       \$verbose,         0);
$arg->add_optional_arg("gtest",         \$gtest,           "");
$arg->add_optional_arg("clean",         \$clean,           0);
$arg->add_optional_arg("backend",       \$backend,         0);
$arg->add_optional_arg("atomic",        \$atomic,          "");
$arg->add_optional_arg("mpi_cc",        \$mpi_cc,          "");
$arg->add_optional_arg("mpi_cxx",       \$mpi_cxx,         "");
$arg->add_optional_arg("fast_build",    \$fast_build,      0);
$arg->add_optional_arg("vt_detector",   \$vt_detector,     1);
$arg->add_optional_arg("lb",            \$lb_on,           0);
$arg->add_optional_arg("trace",         \$trace_on,        0);

$arg->parse_arguments(@ARGV);

$root_dir = $root_dir . "/" . $prefix . "/";

my $github_prefix = qw(git@github.com:);

my %repos = (
    'gtest'      => qw(google/googletest.git),
    'vt'         => qw(DARMA-tasking/vt.git),
    'detector'   => qw(DARMA-tasking/detector.git),
    'checkpoint' => qw(DARMA-tasking/checkpoint.git),
    'kokkos'     => qw(kokkos/kokkos.git)
);

my %repos_branch = (
    'gtest'      => qw(master),
    'vt'         => qw(develop),
    'detector'   => qw(master),
    'checkpoint' => qw(develop),
    'kokkos'     => qw(develop)
);

my @repo_install_order = (
    'gtest',
    'detector',
    'checkpoint',
    'vt'
);

# in case of coverage, we turn the build to a debug mode
# and switch the compiler for a compatible one : gcc
# to add coverage flags for CXX_FLAGS and C_FLAGS
if ($vt_build eq "coverage") {
    $build_mode = "debug";
    my $gcc_for_coverage ="gcc-8";
    my $gxx_for_coverage ="g++-8";
    my $gcc = `which $gcc_for_coverage`;
    my $gxx = `which $gxx_for_coverage`;
    if ($gcc eq "") {
        die "Failed: Please install $gcc_for_coverage for using code coverage ";
    }
    if ($gxx eq "") {
        die "Failed: Please install $gxx_for_coverage for using code coverage ";
    }
    $compiler_c = $gcc;
    $compiler_cxx = $gxx;
    chomp($compiler_c);
    chomp($compiler_cxx);
}

if ($vt_build eq "") {
    $vt_build = $build_mode;
}

if ($build_kokkos == 1) {
    if ($kokkos_path ne "") {
        die "if build_kokkos is enabled, kokkos=X should not be present\n";
    }
    $kokkos_path = "$root_dir/kokkos/kokkos-install/lib/";
    unshift @repo_install_order, "kokkos";
}

print "auto build: root=$root_dir, prefix=$prefix: @repo_install_order\n";

# exit 1;

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
    my $vt_path = "$root_dir/vt/vt-install";
    if ($repo eq "checkpoint") {
        my $build_test = "ON";
        if (!$build_all_tests) {
            $build_test = "OFF";
        }
        return "1 $detector_path $gtest $build_test " .
               " $compiler_c $compiler_cxx $kokkos_path";
    } elsif ($repo eq "detector") {
        return "$compiler_c $compiler_cxx";
    } elsif ($repo eq "vt") {
        my $dpath = $detector_path;
        my $cpath = $checkpoint_path;
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
        my $mpi_str = "";
        $mpi_str .= "mpi_cc=$mpi_cc "   if $mpi_cc  ne "";
        $mpi_str .= "mpi_cxx=$mpi_cxx " if $mpi_cxx ne "";
        my $fast_str = "";
        $fast_str .= "fast=1 " if $fast_build == 1;
        my $detect_str = "";
        $detect_str .= "detector_on=0" if $vt_detector == 0;
        my $lb_str = "";
        $lb_str .= "lb_on=1" if $lb_on == 1;
        my $trace_str = "";
        $trace_str .= "trace_on=1" if $trace_on == 1;
        my $str =
            "build_mode=$vt_build "         .
            "compiler=clang "               .
            $compiler_str                   .
            $mpi_str                        .
            $fast_str                       .
            "build_tests=$build_all_tests " .
            "detector=$dpath "              .
            "gtest=$gtest "                 .
            "$atomic_str "                  .
            "$detect_str "                  .
            "$trace_str "                   .
            "$lb_str "                      .
            "checkpoint=$cpath ";
        print "compiler string=\"$compiler_str\"\n";
        print "string=\"$str\"\n";
        return $str;
    } elsif (
        $repo eq "gtest" || $repo eq "kokkos"
      ) {
        return "$compiler_c $compiler_cxx";
    }
}

sub build_install {
    my ($base_dir,$repo,$mode) = @_;
    my $src_dir = "$base_dir/$repo";
    my $build_dir = "$base_dir/$repo-build";
    my $build_dir_debug = "$base_dir/$repo-build-debug";
    my $install_dir = "$base_dir/$repo-install";
    &create_dir($build_dir);
    if ($repo eq "gtest") {
      &create_dir($build_dir_debug);
    }
    &create_dir($install_dir);
    my $repo_path = "$github_prefix/$repos{$repo}";
    my $branch = "$repos_branch{$repo}";
    my $git_cmd = "git clone --branch $branch --depth=1 $repo_path $src_dir";
    if ($repo eq "gtest") {
      $git_cmd = "git clone --branch $branch $repo_path $src_dir && cd $src_dir && git checkout 43863938377a9ea";
    }
    print "\n";
    print "=== Starting build/install of dependency: $repo ===\n";
    print "=== Cloning $repo_path: $git_cmd ===\n";
    system "$git_cmd" if (!(-e $src_dir));
    #print "XXX: cd $src_dir && git checkout $repos_branch{$repo}\n";
    my $prefix_cd = "cd $build_dir &&";
    my $prefix_cd_debug = "cd $build_dir_debug &&";
    my $args = &get_args($repo);
    if (
        $repo eq "gtest" || $repo eq "kokkos"
      ) {

        my $conf_cmd = "$prefix_cd $cur_dir/build-$repo.sh Release $args";
        my $conf_cmd_debug = "$prefix_cd_debug $cur_dir/build-$repo.sh Debug $args";
        system("$conf_cmd") == 0 or die "Failed: $conf_cmd\n";
        if ($repo eq "gtest") {
            system("$conf_cmd_debug") == 0 or die "Failed: $conf_cmd_debug\n";
        }
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
    my $build_cmd_debug = "$prefix_cd_debug make $verbose_str -j$par";
    my $build_install_debug = "$prefix_cd_debug make install $verbose_str -j$par";

    print "Running: $build_cmd\n";
    system("$build_cmd") == 0 or die "Build failed: $build_cmd\n";
    print "Running: $build_install\n";
    system("$build_install") == 0 or die "Install failed: $build_cmd\n";;
    if ($repo eq "gtest") {
        print "Running: $build_cmd_debug\n";
        system("$build_cmd_debug") == 0 or die "Build failed: $build_cmd_debug\n";
        print "Running: $build_install_debug\n";
        system("$build_install_debug") == 0 or die "Install failed: $build_install_debug\n";;
    }
    if ($repo eq "gtest" && $gtest eq "") {
        $gtest="$base_dir/$repo-install/";
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
    if ($clean == 1) {
        &clean_repo($base_dir,$repo);
    } else {
        &create_dir("$base_dir");
        &build_install($base_dir,$repo);
    }
}


