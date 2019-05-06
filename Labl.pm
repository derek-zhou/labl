package Labl;
use Mojo::Base -base;
use Cwd qw(getcwd abs_path);

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

sub drop_all_with {
    my ($self, $label, @canons) = @_;
    my $label_map = $self->all_labeled_with($label);
    chdir($self->root_dir . "/.labl/$label") or
	die "cannot chdir: $!";
    foreach my $canon (@canons) {
	next unless (exists($label_map->{$canon}));
	unlink($label_map->{$canon}) or die "cannot unlink: $!";
	delete($label_map->{$canon});
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
	my $l = rindex($canon, "/");
	my $basename = ($l >= 0) ? substr($canon, $l + 1) : $canon;
	symlink("../../" . $canon, $basename) or
	    die "cannot symlink: $!";
	$label_map->{$canon} = $basename;
    }
    chdir($self->cwd);
    return $self;
}

sub rename_with {
    my ($self, $label, $old, $new) = @_;
    my $label_map = $self->all_labeled_with($label);
    if (exists($label_map->{$old})) {
	my $l = rindex($new, "/");
	my $basename = ($l >= 0) ? substr($new, $l + 1) : $new;
	chdir($self->root_dir . "/.labl/$label") or
	    die "cannot chdir: $!";
	unlink($label_map->{$old}) or die "cannot unlink: $!";
	delete($label_map->{$old});
	symlink("../../" . $new, $basename) or die "cannot symlink: $!";
	$label_map->{$new} = $basename;
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
