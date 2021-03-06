# --
# Kernel/System/Znuny4OTRSAttachmentMultiUpload.pm - allows the upload of multiple attachments at once via redefining functions
# Copyright (C) 2014 Znuny GmbH, http://znuny.com/
# --

package Kernel::System::Znuny4OTRSAttachmentMultiUpload;

use strict;
use warnings;

# disable redefine warnings in this scope
{
no warnings 'redefine';

=item Kernel::System::Web::Request::GetUploadAll()

gets file upload data.

    my %File = $ParamObject->GetUploadAll(
        Param  => 'FileParam',  # the name of the request parameter containing the file data
        Source => 'string',     # 'string' or 'file', how the data is stored/returned, see below
    );

    returns (
        Filename    => 'abc.txt',
        ContentType => 'text/plain',
        Content     => 'Some text',
    );

	OR in case of a multi upload in file_upload or FileUpload fields:

	(
        Multiple => 3,
        1        => {
	        Filename    => 'abc.txt',
	        ContentType => 'text/plain',
	        Content     => 'Some text',
		},
		2        => {
	        Filename    => 'abc.txt',
	        ContentType => 'text/plain',
	        Content     => 'Some text',
		},
		3        => {
	        Filename    => 'abc.txt',
	        ContentType => 'text/plain',
	        Content     => 'Some text',
		},
    );

    If you send Source => 'string', the data will be returned directly in
    the return value ('Content'). If you send 'file' instead, the data
    will be stored in a file and 'Content' will just return the file name.

=cut

sub Kernel::System::Web::Request::GetUploadAll {
    my ( $Self, %Param ) = @_;

    # get upload
    my @Upload = $Self->{Query}->upload( $Param{Param} );
    return if !scalar @Upload;

    my $Multiple = 0;
    if (
        scalar @Upload > 1
        && grep { $Param{Param} eq $_ } qw( file_upload FileUpload )
    ) {
        $Multiple = 1;
    }

    my @Attachments = $Self->GetArray( Param => $Param{Param}, Raw => 1 );
    if ( !scalar @Attachments ) {
        @Attachments = ('unkown');
    }

    my %ReturnData;
    my $AttachmentCounter = 0;
    ATTACHMENT:
    for my $Attachment ( @Attachments ) {

        my $NewFileName = "$Attachment";    # use "" to get filename of anony. object
        $Self->{EncodeObject}->EncodeInput( \$NewFileName );

        # replace all devices like c: or d: and dirs for IE!
        $NewFileName =~ s/.:\\(.*)/$1/g;
        $NewFileName =~ s/.*\\(.+?)/$1/g;

        # return a string
        my $Content;
        if ( $Param{Source} && lc $Param{Source} eq 'string' ) {

            while (<$Attachment>) {
                $Content .= $_;
            }
            close $Attachment;
        }

        # return file location in file system
        else {

            # delete upload dir if exists
            my $Path = "/tmp/$$";
            if ( -d $Path ) {
                File::Path::remove_tree($Path);
            }

            # create upload dir
            File::Path::make_path( $Path, { mode => 0700 } );    ## no critic

            $Content = "$Path/$NewFileName";

            open my $Out, '>', $Content || die $!;               ## no critic
            while (<$Attachment>) {
                print $Out $_;
            }
            close $Out;
        }

        # Check if content is there, IE is always sending file uploads without content.
        return          if !$Content && !$Multiple;
        next ATTACHMENT if !$Content;

        my $ContentType = $Self->_GetUploadInfo(
            Filename => $Attachment,
            Header   => 'Content-Type',
        );

        my %UploadData = (
            Filename    => $NewFileName,
            Content     => $Content,
            ContentType => $ContentType,
        );

        return %UploadData if !$Multiple;

        $AttachmentCounter++;

        $ReturnData{ $AttachmentCounter } = \%UploadData;
    }

    $ReturnData{Multiple} = $AttachmentCounter;

    return %ReturnData;
}

# reset all warnings
}

1;
