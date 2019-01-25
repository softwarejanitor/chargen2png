#!/usr/bin/perl -w

#
# chargen2png.pl
#
# Convert Apple II CHARGEN (VIDEO) ROM images to a PNG image.
#
# 20181105 Leeland Heins
#

use strict;
use Gtk2;

use constant TRUE => 1;
use constant FALSE => 0;

# Backing pixmap for drawing area
my $pixmap = undef;

my %allocated_colors;

my $block_size = 4;  # Default to 4x4 pixels.

my $filename = '';
my $png_filename = '';

my $flip = FALSE;  # Default to //e style CHARGEN ROM.

# Parse the command line parameters.
while (defined $ARGV[0] && $ARGV[0] =~ /^-/) {
  # Block size for pixels, can be 1 to 7.
  if (defined $ARGV[0] && $ARGV[0] eq "-b" && defined $ARGV[1] && $ARGV[1] =~ /^[1234567]$/) {
    $block_size = $ARGV[1];
    shift;
    shift;
  # -f = Flip for Apple ][+ mode.
  } elsif (defined $ARGV[0] && $ARGV[0] eq "-f") {
    # For ][+ style CHARGEN ROMs.  Default is for //e.
    $flip = TRUE;
    shift;
  }
}

# Allow specifying ROM image on the command line.
if (defined $ARGV[0] && $ARGV[0] ne '') {
  $filename = shift;
}

# Apple II characters are a 7x8 matrix.  Block size is the scaling factor for the output image.
my $x_size = 7 * 16 * $block_size;
my $y_size = 8 * 16 * $block_size;

my $x_offset = 0;
my $y_offset = 0;

# Draw the CHARGEN ROM into the pixmap.
sub draw_charset {
  my ($widget, $filename) = @_;

  my $fh;
  my $buffer = '';
  # Open the input CHARGEN ROM file.
  if (open($fh, "<$filename")) {
    binmode $fh;
    # Read the input CHARGEN ROM file, 4096 for a //e ROM, 2048 for a ][+ ROM, I think 8192 for an international //e ROM maybe.
    my $size = read($fh, $buffer, 8192);
    #print "size=$size\n";
    my @raw = unpack "C[8192]", $buffer;
    # Display all 256 characters in a 16x16 matrix.
    for (my $chr = 0; $chr < 256; $chr++) {
      for (my $y = 0; $y < 8; $y++) {
        for (my $x = 0; $x < 7; $x++) {
          my $offset = ($chr << 3) + $y;
          my $bit = 1 << $x;
          my $byte = $raw[$offset];
          if ($byte & $bit) {
            my $xl;
            if ($flip) {
              # For a ][+ style ROM
              $xl = (112 - (7 * ($chr & 0xf) + $x)) * $block_size;
            } else {
              # For a //e style ROM
              $xl = (7 * ($chr & 0xf) + $x) * $block_size;
            }
            $pixmap->draw_rectangle($widget->style->black_gc, TRUE, $xl, ($y + 8 * ($chr >> 4)) * $block_size, $block_size, $block_size);
          }
        }
      }
    }
    # Refresh the pixmap.
    $widget->queue_draw_area(0, 0, $widget->allocation->width, $widget->allocation->height);
  } else {
    print "Failed to open $filename\n";
  }
}

# Draw the whole pixmap white
sub erase_pixmap {
  my $widget = shift; # GtkWidget         *widget

  $pixmap->draw_rectangle($widget->style->white_gc,
                          TRUE,
                          0, 0,
                          $widget->allocation->width,
                          $widget->allocation->height);
  $widget->queue_draw_area(0, 0, $widget->allocation->width, $widget->allocation->height);
}

# Create a new backing pixmap of the appropriate size
sub configure_event {
  my $widget = shift; # GtkWidget         *widget
  my $event  = shift; # GdkEventConfigure *event

  $pixmap = Gtk2::Gdk::Pixmap->new($widget->window,
                                   $widget->allocation->width,
                                   $widget->allocation->height,
                                   -1);
  $pixmap->draw_rectangle($widget->style->white_gc,
                          TRUE,
                          0, 0,
                          $widget->allocation->width,
                          $widget->allocation->height);

  return TRUE;
}

# Redraw the screen from the backing pixmap
sub expose_event {
  my $widget = shift; # GtkWidget      *widget
  my $event  = shift; # GdkEventExpose *event

  $widget->window->draw_drawable(
                     $widget->style->fg_gc($widget->state),
                     $pixmap,
                     $event->area->x, $event->area->y,
                     $event->area->x, $event->area->y,
                     $event->area->width, $event->area->height);

  return FALSE;
}

# Allow saving the image as a PNG file.
sub save_png {
  my $png_file = shift;

  if ($png_file ne "") {
    #if (-e $png_file) {
    #  print "File $png_file already exists!\n";
    #} else {
      my $pixbuf = Gtk2::Gdk::Pixbuf->new('GDK_COLORSPACE_RGB', TRUE, 8, $x_size, $y_size);
      $pixbuf->get_from_drawable($pixmap, undef, 0, 0, 0, 0, $x_size, $y_size);
      if ($pixbuf->save($png_file, 'png')) {
        print "ERROR!\n";
      } else {
        print "Saved!\n";
      }
    #}
  } else {
    print "Must enter filename to save!\n";
  }
}

{
  Gtk2->init;

  my $window = Gtk2::Window->new('toplevel');
  $window->set_name("Chord Wizard");

  my $vbox = Gtk2::VBox->new(FALSE, 0);
  $window->add($vbox);
  $vbox->show;

  $window->signal_connect("destroy", sub { exit(0); });

  # Create the drawing area

  my $drawing_area = Gtk2::DrawingArea->new;
  $drawing_area->set_size_request($x_size + $x_offset + $x_offset, $y_size + $y_offset + $y_offset);
  $vbox->pack_start($drawing_area, TRUE, TRUE, 0);

  $drawing_area->show;

  # Signals used to handle backing pixmap

  $drawing_area->signal_connect(expose_event => \&expose_event);
  $drawing_area->signal_connect(configure_event => \&configure_event);

  my $hbox = Gtk2::HBox->new(FALSE, 0);
  $hbox->show;

  $vbox->pack_start($hbox, FALSE, FALSE, 0);

  # Allow entry of the CHARGEN (VIDEO) ROM image filename.
  my $label1 = Gtk2::Label->new();
  $label1->set_markup("Chargen File:");
  $label1->show;

  $hbox->pack_start($label1, FALSE, FALSE, 0);

  my $entry1 = Gtk2::Entry->new_with_max_length(128);
  $entry1->set_width_chars(32);
  $entry1->show;
  $entry1->set_text($filename) if $filename;

  $hbox->pack_start($entry1, FALSE, FALSE, 0);

  my $load_button = Gtk2::Button->new("Load");
  $load_button->show;
  $hbox->pack_start($load_button, FALSE, FALSE, 0);

  $load_button->signal_connect_swapped(clicked => sub {
      # Get the CHARGEN ROM image filename.
      $filename = $entry1->get_text();
      print "Load $filename\n";
      # Load and draw the image.
      draw_charset($window, $filename) if $filename;
    }, $window);

  my $hbox2 = Gtk2::HBox->new(FALSE, 0);
  $hbox2->show;

  $vbox->pack_start($hbox2, FALSE, FALSE, 0);

  # Allow entry of a filename to output the PNG image to.
  my $label2 = Gtk2::Label->new();
  $label2->set_markup("PNG File:");
  $label2->show;

  $hbox2->pack_start($label2, FALSE, FALSE, 0);

  my $entry2 = Gtk2::Entry->new_with_max_length(128);
  $entry2->set_width_chars(32);
  $entry2->show;

  $hbox2->pack_start($entry2, FALSE, FALSE, 0);

  # Button to allow saving the image to a PNG file.
  my $save_button = Gtk2::Button->new("Save");
  $save_button->show;
  $hbox2->pack_start($save_button, FALSE, FALSE, 0);

  $save_button->signal_connect_swapped(clicked => sub {
      # Get the filename from the text entry widget.
      $png_filename = $entry2->get_text();
      # Actually save the image to a PNG file.
      save_png($png_filename);
    }, $window);

  my $hbox3 = Gtk2::HBox->new(FALSE, 0);
  $hbox3->show;

  $vbox->pack_start($hbox3, FALSE, FALSE, 0);

  # For //e mode.
  my $button_key = Gtk2::RadioButton->new(undef, "//e");
  $hbox3->pack_start($button_key, TRUE, TRUE, 0);
  $button_key->set_active(TRUE);
  $button_key->signal_connect('toggled' => sub { $flip = FALSE; &erase_pixmap($window); &draw_charset($window, $filename) if $filename; }, $window);
  $button_key->show;

  my @button_group = $button_key->get_group;

  # For ][+ mode.
  $button_key = Gtk2::RadioButton->new_with_label(@button_group, "][+");
  $hbox3->pack_start($button_key, TRUE, TRUE, 0);
  $button_key->signal_connect('toggled' => sub { $flip = TRUE; &erase_pixmap($window); &draw_charset($window, $filename) if $filename; }, $window);
  $button_key->show;

  my $blocksize_combobox = Gtk2::ComboBox->new_text;
  my @blocksizes = ( '1', '2', '3', '4', '5', '6', '7' );

  foreach my $blocksize (@blocksizes) {
    $blocksize_combobox->append_text($blocksize);
  }
  $blocksize_combobox->set_active(2);
  $blocksize_combobox->signal_connect_swapped('changed' => sub {
      # Get the new block size from the combo box widget.
      $block_size = $blocksize_combobox->get_active_text;
      # Re-size the window and re-draw at the new size.  This is not quite working correctly.
      $x_size = 7 * 16 * $block_size;
      $y_size = 8 * 16 * $block_size;
      print "block_size=$block_size x_size=$x_size, y_size=$y_size\n";
      #$pixmap = Gtk2::Gdk::Pixmap->new($drawing_area->window, $drawing_area->allocation->width, $drawing_area->allocation->height, -1);
      $pixmap = Gtk2::Gdk::Pixmap->new($drawing_area->window, $x_size, $y_size, -1);
      $drawing_area->set_size_request($x_size + $x_offset + $x_offset, $y_size + $y_offset + $y_offset);
      #$pixmap->draw_rectangle($drawing_area->style->white_gc, TRUE, 0, 0, $drawing_area->allocation->width, $drawing_area->allocation->height);
      $window->resize($x_size, $y_size + 80);
      $window->set_size_request($x_size + $x_offset + $x_offset, $y_size + $y_offset + $y_offset);
      #$drawing_area->set_size_request($x_size + $x_offset + $x_offset, $y_size + $y_offset + $y_offset);
      &erase_pixmap($window);
      &draw_charset($window, $filename) if $filename;
      &draw_charset($window, $filename) if $filename;
    }, $window);

  $blocksize_combobox->show;
  $hbox3->pack_start($blocksize_combobox, FALSE, FALSE, 0);

  my $clear_button = Gtk2::Button->new("Clear");
  $hbox3->pack_start($clear_button, FALSE, FALSE, 0);
  $clear_button->signal_connect_swapped(clicked => sub { &erase_pixmap($window); $filename = ''; $entry1->set_text(''); $entry2->set_text(''); }, $window);
  $clear_button->show;

  # .. And a quit button
  my $quit_button = Gtk2::Button->new("Quit");
  $hbox3->pack_start($quit_button, FALSE, FALSE, 0);

  $quit_button->signal_connect_swapped(clicked => sub { $_[0]->destroy; }, $window);
  $quit_button->show;

  $window->show;

  &erase_pixmap($window);
  &draw_charset($window, $filename) if $filename;

  Gtk2->main;
}

