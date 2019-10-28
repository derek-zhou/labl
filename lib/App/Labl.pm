package App::Labl;
use Mojo::Base -base;
use Cwd qw(getcwd abs_path);

our $VERSION = 0.01;

has ['root_dir', 'cwd', 'all_labels', '_label_map_cache'];

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
    $self->_label_map_cache({});
    opendir(my $dh, ($found_dir . "/.labl")) or
	die "Can't open label dir: $!";
    my @labels = grep(!/^\./, readdir($dh));
    closedir $dh;
    $self->all_labels(\@labels);
    return $self;
}

sub all_labeled_with {
    my ($self, $label) = @_;
    if (exists($self->_label_map_cache->{$label})) {
	return $self->_label_map_cache->{$label};
    }
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
	}
    }
    closedir $dh;
    chdir($self->cwd);
    $self->_label_map_cache->{$label} = \%links;
    return \%links;
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
    my @all_labels = @{$self->all_labels};
    my $labl_dir = $self->root_dir . "/.labl";
    mkdir($labl_dir . "/" . $label) or
	die "Can't mkdir $label: $!";
    push @all_labels, $label;
    $self->all_labels(\@all_labels);
    return $self;
}

sub drop_label {
    my ($self, $label) = @_;
    my @all_labels = @{$self->all_labels};
    my $labl_dir = $self->root_dir . "/.labl";
    rmdir($labl_dir . "/" . $label) or
	die "Can't rmdir $label: $!";
    delete $self->_label_map_cache->{$label};
    my @new_labels = grep { $_ ne $label } @all_labels;
    $self->all_labels(\@new_labels);
    return $self;
}

sub has_label {
    my ($self, $label) = @_;
    foreach (@{$self->all_labels}) {
	return 1 if ($_ eq $label);
    }
    return 0;
}

sub get_link_name {
    my $canon = shift;
    my @tokens = reverse(split(/\//, $canon));
    my $name = $tokens[0];
    my $i = 1;
    while (-e $name) {
	die "The $canon cannot be linked!" if ($i == scalar(@tokens));
	$name = $name . ',' . $tokens[$i];
	$i++;
    }
    return $name;
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
    my $label_map = $self->all_labeled_with($label);
    chdir($self->root_dir . "/.labl/$label") or
	die "cannot chdir: $!";
    foreach my $canon (@canons) {
	next unless (exists($label_map->{$canon}));
	remove_link($canon, $label_map);
    }
    chdir($self->cwd);
    # empty label is dropped
    $self->drop_label($label) unless(scalar(%{$label_map}));
    return $self;
}

sub add_all_with {
    my ($self, $label, @canons) = @_;
    $self->add_label($label) unless ($self->has_label($label));
    my $label_map = $self->all_labeled_with($label);
    chdir($self->root_dir . "/.labl/$label") or
	die "cannot chdir: $!";
    foreach my $canon (@canons) {
	next if (exists($label_map->{$canon}));
	my $link_name = get_link_name($canon);
	symlink("../../" . $canon, $link_name) or
	    die "cannot symlink: $!";
	$label_map->{$canon} = $link_name;
    }
    chdir($self->cwd);
    return $self;
}

sub rename_with {
    my ($self, $label, $old, $new) = @_;
    my $label_map = $self->all_labeled_with($label);
    if (exists($label_map->{$old})) {
	chdir($self->root_dir . "/.labl/$label") or
	    die "cannot chdir: $!";
	remove_link($old, $label_map);
	my $link_name = get_link_name($new);
	symlink("../../" . $new, $link_name) or
	    die "cannot symlink: $!";
	$label_map->{$new} = $link_name;
	chdir($self->cwd);
    }
    return $self;
}

sub is_labeled_with {
    my ($self, $label, $file) = @_;
    return exists($self->all_labeled_with($label)->{$file});
}

sub all_labels_of {
    my ($self, $file) = @_;
    return grep {exists($self->all_labeled_with($_)->{$file})} @{$self->all_labels};
}

1;

__END__

=head1 NAME

App::Labl - module to manage labels on files

=head1 SYNOPSIS

 use Labl;
 # init the labl object with files from current working directory
 my $labl = App::Labl->new->init;
 # list all labels exist in any file for the current project
 my @labels = @{$labl->all_labels};
 # canonical the filename
 my $canon = $labl->canon_of($filename);
 # list all labels on one file
 my @labels = $labl->all_labels_of($canon);
 # add a label to a set of files
 $labl->add_all_with($label, @canons);
 # drop a label from a set of files
 $labl->drop_all_with($label, @canons);
 # test if a label is associated with one file
 $labl->is_labeled_with($label, $canon);
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

Copyright (C) 2019 Derek Zhou E<lt>derek@shannon-data.comE<gt>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
