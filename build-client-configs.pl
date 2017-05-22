#
# Build client configs using the given deployment config and service name.
#

use Template;
use strict;
use Data::Dumper;
use Config::Simple;
use Getopt::Long::Descriptive;

my($opt, $usage) = describe_options("%c %o deployment.cfg service-name target-dir output-name-template",
				    ['define=s@', 'tpage definition', { default => [] }],
				    ['help|h', 'show this help message']);

print($usage->text), exit 0 if $opt->help;
die($usage->text) if @ARGV != 4;

my $cfg_file = shift;
my $service = shift;
my $target = shift;
my $output_template = shift;

my $template = Template->new({ OUTPUT_PATH => $target });

my $cfg = Config::Simple->new();
$cfg->read($cfg_file);
print $cfg->dump;
my %vars;
for my $def (@{$opt->define})
{
    my($var, $val) = split(/=/, $def, 2);
    $vars{$var} = $val;
}

my $block = $cfg->get_block($service);

my @groups = sort { $a cmp $b } grep { defined($_) } map { /^group\.([^.]+)\..*name/ } keys %$block;

for my $group (@groups)
{
    my $name = $block->{"group.$group.name"};
    my $apps = $block->{"group.$group.apps"};
    my $num = $block->{"group.$group.client-count"};
    my %gvars = %vars;
    $gvars{client_group} = $name;
    $gvars{client_count} = $num;
    $gvars{supported_apps} = ref($apps) ? join(",", @$apps) : $apps;
    my $outfile = sprintf($output_template, $group);
    open(OUT, ">", "$target/$outfile") or die "Cannot write $target/$outfile: $!";
    $template->process("awe_client.cfg.tt", \%gvars, \*OUT) || die Template->error;
    close(OUT);
}
