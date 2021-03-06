package App::Labl;
use Mojo::Base -base;
use File::stat;
use Cwd qw(getcwd abs_path);
use File::Path qw(remove_tree);

our $VERSION = 0.01;

has ['root_dir', 'cwd', '_label_map_cache', '_sequence_number'];

sub init {
    my $self = shift;
    $self->cwd(getcwd());
    my $found_dir;
    while(1) {
	my $cwd = getcwd();
	# root is not allowed
	last if ($cwd eq "/");
	if (-d '.labl') {
	    $found_dir = $cwd;
	    last;
	}
	if (-d '.git') {
	    $found_dir = $cwd if (mkdir(".labl"));
	    last;
	}
	last unless(chdir(".."));
    }
    chdir($self->cwd);
    die "Cannot find project root dir" unless ($found_dir);
    $self->root_dir($found_dir);
    $self->_load;
    return $self;
}

sub clearAll {
    my $self = shift;
    $self->_label_map_cache({});
    $self->_sequence_number(0);
    remove_tree( $self->root_dir . '/.labl', {keep_root => 1} );
}

sub _load {
    my $self = shift;
    my %label_map;
    my $max_number = 0;
    my @labels;
    opendir(my $dh, ($self->root_dir . "/.labl")) or
	die "Can't open label dir: $!";
    @labels = grep(!/^\./, readdir($dh));
    closedir $dh;
    foreach my $label (@labels) {
	my %links;
	chdir($self->root_dir . "/.labl/$label") or
	    die "cannot chdir: $!";
	opendir(my $dh, ".") or die "Can't open label $label: $!";
	foreach (readdir($dh)) {
	    unless (/^\./) {
		my $link = readlink($_);
		defined($link) or die "readlink $_ in $label fail: $!";
		# all links start with "../../"
		$links{substr($link, 6)} = $_;
		if (/^\d+$/) {
		    $max_number = $_ if ($max_number >= 0 && $_ > $max_number);
		} else {
		    if ($max_number >= 0) {
			say STDERR "Warning: data from older version of labl detected. Read only access from now";
			$max_number = -1;
		    }
		}
	    }
	}
	closedir $dh;
	$label_map{$label} = \%links;
    }
    chdir($self->cwd);
    $self->_label_map_cache(\%label_map);
    $self->_sequence_number($max_number);
}

sub all_labelled {
    my $self = shift;
    my %file_map;
    foreach ($self->all_labels) {
	my $this_map = $self->all_labelled_with($_);
	foreach (keys(%{$this_map})) {
	    $file_map{$_} = 1;
	}
    }
    return keys(%file_map);
}

sub all_labelled_with {
    my ($self, $label) = @_;
    return $self->_label_map_cache->{$label} if ($self->has_label($label));
    die "No such label $label!";
}

sub fixup {
    my ($self, $label) = @_;
    my $label_map = $self->all_labelled_with($label);
    chdir($self->root_dir . "/.labl/$label") or
	die "cannot chdir: $!";
    my @canons = keys(%{$label_map});
    foreach my $canon (@canons) {
	my $link = $label_map->{$canon};
	my $lstat = lstat($link);
	my $tstat = stat("../../" . $canon);
	if ($tstat) {
	    # fixup mtime
	    if ($lstat->mtime > $tstat->mtime ) {
		say STDERR "Warning: link $link in label $label has later mtime than canon $canon";
		utime(time(), $lstat->mtime, "../../" . $canon);
	    }
	} else {
	    # link target must exists
	    say STDERR "Warning: link target of $link in label $label, supposedly to be $canon, does not exist";
	    remove_link($canon, $label_map);
	}
    }
    chdir($self->cwd);
    # empty label is dropped
    $self->drop_label($label) unless(scalar(%{$label_map}));
    return $self;
}

# return the canonical name
sub canon_of {
    my $self = shift;
    # root_dir must be a prefix of the name
    my $name = abs_path(shift);
    return substr($name, length($self->root_dir)+1);
}

sub add_label {
    my ($self, $label) = @_;
    my $labl_dir = $self->root_dir . "/.labl";
    mkdir($labl_dir . "/" . $label) or
	die "Can't mkdir $label: $!";
    $self->_label_map_cache->{$label} = {};
    return $self;
}

sub drop_label {
    my ($self, $label) = @_;
    my $labl_dir = $self->root_dir . "/.labl";
    rmdir($labl_dir . "/" . $label) or
	die "Can't rmdir $label: $!";
    delete $self->_label_map_cache->{$label};
    return $self;
}

sub has_label {
    my ($self, $label) = @_;
    return (exists($self->_label_map_cache->{$label}));
}

sub read_only {
    my $self = shift;
    return $self->_sequence_number < 0;
}

sub get_link_name {
    my $self = shift;
    die "Read only access, aborted" if ($self->read_only);
    $self->_sequence_number($self->_sequence_number + 1);
    return $self->_sequence_number;
}

sub remove_link {
    my ($to_be_remove, $label_map) = @_;
    my $old_link = $label_map->{$to_be_remove};
    unlink($old_link) or die "cannot unlink: $!";
    delete($label_map->{$to_be_remove});
    my @candidates = glob($old_link . ',*');
    # use the freed up old_link, because it is shorter 
    if (scalar(@candidates)) {
	my $candidate = $candidates[0];
	my $link = readlink($candidate);
	my $canon = substr($link, 6);
	rename($candidate, $old_link);
	$label_map->{$canon} = $old_link;
    }
}

sub drop_all_with {
    my ($self, $label, @canons) = @_;
    my $label_map = $self->all_labelled_with($label);
    chdir($self->root_dir . "/.labl/$label") or
	die "cannot chdir: $!";
    foreach my $canon (@canons) {
	next unless (exists($label_map->{$canon}));
	remove_link($canon, $label_map);
	utime(undef, undef, "../../" . $canon);
    }
    chdir($self->cwd);
    # empty label is dropped
    $self->drop_label($label) unless(scalar(%{$label_map}));
    return $self;
}

sub add_all_with {
    my ($self, $label, @canons) = @_;
    $self->add_label($label) unless ($self->has_label($label));
    my $label_map = $self->all_labelled_with($label);
    chdir($self->root_dir . "/.labl/$label") or
	die "cannot chdir: $!";
    foreach my $canon (@canons) {
	next if (exists($label_map->{$canon}));
	my $link_name = $self->get_link_name;
	symlink("../../" . $canon, $link_name) or
	    die "cannot symlink: $!";
	utime(undef, undef, "../../" . $canon);
	$label_map->{$canon} = $link_name;
    }
    chdir($self->cwd);
    return $self;
}

sub rename_with {
    my ($self, $label, $old, $new) = @_;
    my $label_map = $self->all_labelled_with($label);
    if (exists($label_map->{$old})) {
	chdir($self->root_dir . "/.labl/$label") or
	    die "cannot chdir: $!";
	remove_link($old, $label_map);
	my $link_name = $self->get_link_name;
	symlink("../../" . $new, $link_name) or
	    die "cannot symlink: $!";
	utime(undef, undef, "../../" . $new);
	$label_map->{$new} = $link_name;
	chdir($self->cwd);
    }
    return $self;
}

sub is_labelled_with {
    my ($self, $label, $file) = @_;
    return exists($self->all_labelled_with($label)->{$file});
}

sub all_labels {
    my $self = shift;
    return keys %{$self->_label_map_cache};
}

sub all_labels_of {
    my ($self, $file) = @_;
    my %map;
    foreach ($self->all_labels) {
	$map{$_} = $self->all_labelled_with($_)->{$file} if
	    (exists($self->all_labelled_with($_)->{$file}));
    }
    return keys %map if ($self->read_only);
    return sort {$map{$a} <=> $map{$b}} keys %map;
}

1;

__END__

=head1 NAME

App::Labl - module to manage labels on files

=head1 SYNOPSIS

 use Labl;
 # init the labl object with files from current working directory
 my $labl = App::Labl->new->init;
 # clear all label data
 $labl->clearAll;
 # list all labels exist in any file for the current project
 my @labels = $labl->all_labels;
 # list all labelled files for the current project
 my @canons = $labl->all_labelled;
 # canonical the filename
 my $canon = $labl->canon_of($filename);
 # list all labels on one file
 my @labels = $labl->all_labels_of($canon);
 # fixup label database by removing dangle links and update mtime of link targets
 $labl->fixup($label);
 # add a label to a set of files
 $labl->add_all_with($label, @canons);
 # drop a label from a set of files
 $labl->drop_all_with($label, @canons);
 # test if a label is associated with one file
 $labl->is_labelled_with($label, $canon);
 # fix labels after a file has been renamed
 $labl->rename_with($label, $oldname, $newname);

=head1 DESCRIPTION

A label is a short string to be associated with any file. Labl maintains
the label database as organized symlinks in the .labl dir under the
project's root dir.

=over 4

=item B<init>

Initialize the labl objects with information gathered from the current
project. A project is defined as a directory tree with a .labl in it,
or failing that, a directory tree with .git in it, in which case a
.labl dir will be created in the project root dir.

  my $labl = App::Labl->new->init;

=item B<canon_of($filename)>

Canonlize the file name as a relative path from the project root, with
all symlink resolved. All file names passed to methods call to Labl
except this one have to be in the canon form.

  my $canon = $labl->canon_of($filename);

=back

=head1 COPYRIGHT

Copyright (C) 2020 Derek Zhou E<lt>derek@3qin.usE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
