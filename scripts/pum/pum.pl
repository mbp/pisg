#!/usr/bin/perl -w

###
### pisg user manager version 3.2
###
### Copyleft (C) 2005 by Axel 'XTaran' Beckert <abe@deuxchevaux.org>
### Copyleft (C) 2005 by Torbjörn 'Azoff' Svensson <azoff@se.linux.org>
###
#
# This is complete reimplementation from scratch of addalias script
# 2.2 by deadlock which itself was based on the original addalias
# program by Doomshammer
#
# The purpose of this script is to let users manage themself their
# info for the pisg ircstats program by mbrix.
#
# This program may be used, copied and distributed under the terms of
# the GNU General Public License (GPL) version 2 or later. See
# http://www.gnu.org/copyleft/gpl.txt or the file COPYING for the full
# license text.
#
# Version History:
#
#   3.0: Initial program by XTaran
#   3.1: First released version with a lot of patches by Azoff
#   3.2: Action buttons instead of links since search engines follow
#        links and therefore deleted nicks (XTaran)
#
# Credits from XTaran to
# + Christoph 'Myon' Berg for motivating me to rewrite addalias.pl
# + #plant on IRCNet (and again Myon  ;-)  without which I probably
#   never would have used addalias.pl and therefore never felt the
#   urge to rewrite it from scratch.  ;-) 
# + The Debian Project for the operating system running on my 133 MHz
#   IBM ThinkPad, on which I developed my parts of this piece of Open
#   Source Software (although I have other machines around, but I
#   entirely developed the script while sitting on the toilet, in bed
#   or in the bath tub.  ;-) 
# + Larry for Perl
# + RMS for GNU Emacs

use Data::Dumper;
use AppConfig qw(ARGCOUNT_ONE);

use CGI qw(:standard *table);
use CGI::Carp qw(fatalsToBrowser carpout);

###
### BEGIN CONFIG
###

my $config_file = "pum.conf";

###
### END CONFIG
###

###
### BEGIN INIT
###

my $VERSION = '3.2';
my $title_prefix = "pisg IRC Statistics User Manager $VERSION";
my $script_uri = $ENV{SCRIPT_NAME};
my %data = ();
my @attributes = qw(nick alias link sex pic bigpic ignore);

param( -name => 'op', -value => 'list' ) unless defined param('op');
# print the default css
if (param('op') eq 'css') {
    print <<EOF
Content-type: text/css


table {
    border:             0;
    border-spacing:        2;
}

td {
    background-color:     #E5E5E5;
}

#num {
    text-align:            right;
}
EOF
;
    exit(0);
} 

print header();

my $config = AppConfig->new({ GLOBAL => { ARGCOUNT => ARGCOUNT_ONE }});
$config->define('cgi_css', { DEFAULT => '' });
$config->define('cgi_debug', { DEFAULT => 0 });
$config->define('cgi_alias_disp', { DEFAULT => 30 });
$config->define('cgi_user_del', { DEFAULT => 0 });
$config->define('cgi_pics_prefix', { DEFAULT => '' });
$config->define('backup_enable', { DEFAULT => '1' });
$config->define('backup_dir', { DEFAULT => '/tmp' });
$config->define('backup_suffix', { DEFAULT => '%t' });
$config->define('list_buttons', { DEFAULT => 0 });
$config->define('pisg_user_config', { DEFAULT => 'users.conf' });

-e $config_file or die "Configuration file $config_file doesn't exist";
-f _ or die "Configuration file $config_file is no file";
-r _ or die "Configuration file $config_file is not readable";
$config->file($config_file);

###
### END INIT
###

my $title = $title_prefix;
my $css = $config->get('cgi_css');

if (param('op') eq 'show') {
    $title .= ": Show user '".param('nick')."'";
} elsif (param('op') eq 'edit') {
    $title .= ": Edit user '".param('nick')."'";
} elsif (param('op') eq 'list') {
    $title .= ": List all known nicknames";
} elsif (param('op') eq 'del') {
    $title .= ": Delete user '".param('nick')."'";
} 

print start_html(-title => $title,
         -style => { src => ($css ? $css : "$script_uri?op=css")});
print "\n" . h1($title) . "\n";

if (param('op') eq 'show') {
    &show_data;

    print _p(a({ href => $script_uri.'?op=edit&nick='.param('nick') }, 
          "Edit this data set"));
} elsif (param('op') eq 'edit') {
    &show_data_form;
} elsif (param('op') eq 'save' or param('op') eq 'create') {
    &save_data;
} elsif (param('op') eq 'list') {
    &show_nicks;
} elsif (param('op') eq 'del' and $config->get('cgi_user_del')) {
    &del_nick;
} else {
    print _p("Error: Unknown operation!");
}

if (not (param('op') eq 'del' and not param('confirm') and
    $config->get('cgi_user_del'))) {
    print _p(a({ href => "$script_uri?op=edit" }, 'Create new nick'));
    print _p(a({ href => "$script_uri?op=list" }, 'List all known nicks'));

    print _p('Back to the '.a({ href => $script_uri }, 'pum start page'));
}

print hr,pre(Dumper({ map { $_ => param($_) } param() },\%data,\%ENV))
    if ($config->get('cgi_debug') or param('debug'));
print end_html();

###
### functions
###


# make html readable
sub _table { return table(@_) . "\n"; }
sub _th { return th(@_) . "\n"; }
sub _Tr { return Tr(@_) . "\n"; }
sub _td { return td(@_) . "\n"; }
sub _start_form { return start_form(@_) . "\n"; }
sub _hidden { return hidden(@_) . "\n"; }
sub _submit { return submit(@_) . "\n"; }
sub _reset { return reset(@_) . "\n"; }
sub _end_form { return "</form>\n"; } 
sub _p { return p(@_) . "\n"; }


sub read_config {
    my ($user) = @_;

    my $filename = &get_user_config;
    open(CFG, '<', $filename) or 
        die "Can't open pisg user configuration file '$filename' for reading: $!";
    while (my $line = <CFG>) {
        chomp($line);
        next if $line =~ /^(|#.*)$/;
        die "Unknown pisg user configuration file syntax: '$line'"
            unless $line =~ m|^\s*<user\s+(.*?)/?>\s*$|i;
        my $line_data_string = $1;
        my %line_data = ();
        while ($line_data_string =~ s/^(\w+)="([^\"]+)"\s*//) {
            $line_data{lc($1)} = $2;
        }

        my $nick = $line_data{nick};
        die "No nickname(s) found in '$line'" unless $nick;

        $data{lc($nick)} = \%line_data;
        last if lc($user) eq lc($nick);
    }
    close(CFG);
}

sub write_config {
    my $filename = &get_user_config;

    if ($config->get('backup_enable')) {
        use File::Basename;
        use File::Copy;

        my $time = time();
        my $dir = $config->get('backup_dir');
        my $name = basename($filename);
        my $suffix = $config->get('backup_suffix');
        
        my $newfile = "$dir/$name.$suffix";
        $newfile =~ s/\%t/$time/;

        copy($filename, $newfile) or 
            warn "Couldn't copy '$filename' to $newfile': $!";
    }

    open(CFG, '>', $filename) or 
        die "Can't open pisg user configuration file '$filename' for writing: $!";

    foreach my $key (sort { lc($a) cmp lc($b) } keys %data) {
        my $set = $data{$key};
        print CFG qq{<user};
            die "Data set without nick found: ".Dumper($set) unless $set->{nick};
        foreach my $attr (@attributes) {
            print CFG qq[ $attr="$set->{$attr}"] if $set->{$attr};
        }
        print CFG qq{>\n};
    }

    close(CFG);
}

sub get_user_config {
    my $filename = $config->get('pisg_user_config') or 
        die "Can't find key user_config in section pisg in config file $config_file";
    return $filename;
}

sub save_data {
    die "No nick given" unless param('nick');
    die "Nick may be only changed in capitalisation" 
        if lc(param('nick')) ne lc(param('old_nick')) and param('op') ne 'create';

    my %new_data = ();
    foreach my $attr (@attributes) {
        my $value = param($attr);
        next unless $value;

        next if $attr eq 'sex' and $value eq '-';

        die "No double quotes allowed in data: '$value'" 
            if $value =~ /\"/;
        warn "Waka waka in data: '$value'"
            if $value =~ /[<>]/;

        $new_data{$attr} = $value;
    }

    my $nick = $new_data{nick};
    die "No nick in data found" unless $nick;

    &read_config;

    die "Data for nick '".lc($nick)."' already exists"
        if param('op') eq 'create' and $data{lc($nick)};

    $data{lc($nick)} = \%new_data;
    &write_config;

    print _p('Data successfully saved.');

    &show_data;
    &show_data_form;
}

sub show_data {
    my $this = shift;
    unless ($this) {
        my $nick = lc(param('nick'));
        read_config($nick);
        $this = $data{$nick};
    }

    my $pp = $config->get('cgi_pics_prefix');
    print start_table;
    print _Tr(_th('Nickname'), _th($this->{nick}));
    print _Tr(_td('Alias(ses)'), _td($this->{alias}));
    print _Tr(_td('Link'), _td(defined($this->{link}) and 
                        $this->{link} =~ m(^http://)i ?
                  a({ href => $this->{link}}, $this->{link}) :
                  $this->{link} ?
                  a({ href => "mailto:$this->{link}"}, 
                    $this->{link}) : '(unset)'));
    print _Tr(_td('Sex'), _td(defined $this->{sex} ? 
                $this->{sex} eq 'm' ? 'male' :
                $this->{sex} eq 'f' ? 'female' :
                $this->{sex} eq 'b' ? 'bot' : '(unset)' :
                 '(unset)'));
    print _Tr(_td('Picture'), _td($this->{pic} ? 
                     img({ src => $pp.$this->{pic},
                           alt => $this->{pic} }) : 
                     '(unset)'));
    print _Tr(_td('Big picture'), _td($this->{bigpic} ? 
                     a({href => $pp.$this->{bigpic}}, 
                       $this->{bigpic}) : 
                     '(unset)'));
    print _Tr(_td('Ignore'), _td($this->{ignore} ? 'True' : 'False'));
    print end_table;
}

sub show_data_form {
    my $nick = lc(param('nick'));
    read_config($nick) if $nick;
    my $this = $data{$nick};
    my $pp = $config->get('cgi_pics_prefix');
    print _start_form('GET', $script_uri);
    print _hidden( -name  => 'op', -value => ( ($nick or param('op') eq
            'create') ? 'save' : 'create' ), -override => 1);
    print _hidden('old_nick', $nick);
    print _table(_Tr(_td('Nickname'), _td(textfield('nick',$this->{nick},9))),
        _Tr(_td('Alias(ses)'), _td(textfield('alias',$this->{alias},30))),
        _Tr(_td('Link'), _td(textfield('link',$this->{link},30))),
        _Tr(_td('Sex'), _td(radio_group('sex',['f','m','b','-'],
                         $this->{sex} || '-','',
                         { f => 'female',
                           m => 'male',
                           b => 'bot',
                         '-' => 'unspecified' }))),
        _Tr(_td('Picture'), _td(textfield('pic',$this->{pic},30))),
        _Tr(_td('Big picture'), _td(textfield('bigpic',$this->{bigpic},30))),
        _Tr(_td('Ignore'), _td(checkbox('ignore',
            ($this->{ignore} ? 'checked' : ''), 'y', ''))));
    print _submit('submit', 'Save data set');
    print _reset('reset', 'Reset form');
    print _end_form();

    if (defined $data{lc($nick)}) {
        print _start_form('GET', $script_uri);
        print _hidden( -name  => 'op', -value => 'del', -override => 1);
        print _hidden('nick', $nick);
        print _submit('submit', "Remove data for '$nick'");
        print _end_form();
    }
}

sub _get_op($$) {
    my $op = shift;
    my $nick = shift;

    return ($config->get('list_buttons') 
	    ?
	    _start_form('GET').
	    _hidden('nick', $nick).
	    _submit('op', $op).
	    _end_form() 
	    :
	    a({ href => "$script_uri?op=$op&nick=".escapeHTML($nick) }, $op)
	    );
}

sub show_nicks {
    read_config();
    print start_table;
    my $i=1;
    my $alias_disp = $config->get('cgi_alias_disp');
    foreach my $nick (sort keys %data) {
        my $alias = $data{$nick}{alias} || '';
        $nick = $data{$nick}{nick};
        if (length($alias) > $alias_disp) {
            $alias = substr($alias, 0, $alias_disp) . '...';
        }

        print _Tr(
            _td({id => 'num'}, $i),
            _td(&_get_op('show', $nick)),
            _td(&_get_op('edit', $nick)),
            ($config->get('cgi_user_del') ? _td(&_get_op('del', $nick)) : '' ),
            _td(escapeHTML($nick.($alias ? " ($alias)" : ''))),
        );
        $i++;
    }
    print end_table;
}


sub del_nick {
    my $nick = param('nick');
    die "No nick given" unless $nick;

    if (param('confirm')) {
        &read_config;

        die "No such nick '$nick'." 
            unless defined $data{lc($nick)};

        delete $data{lc($nick)};

        &write_config;

        print _p("User '$nick' successfully deleted.");
    } elsif (param('no')) {
	&show_nicks;
    } else {
        print _p("Are you sure you want to delete the user '$nick'?");

        print _p(_start_form('GET'),
		 _hidden('nick',$nick),
		 _hidden('op','del'),
		 _submit('confirm', 'Yes'),
		 # Not all CGI.pm version know -onclick, so it's hardcoded here
		 '<input type="submit" name="no" value="No" onclick="history.back(); return false" />',
		 _end_form());
    }
}
