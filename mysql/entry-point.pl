#!/usr/bin/perl

# vim: set ai expandtab sw=3 ts=8 shiftround:

use strict;

BEGIN
{
   push( @INC, grep { -d $_ } map { use Cwd; use File::Basename; join( '/', dirname( Cwd::abs_path($0) ), $_ ); } ( "common/lib/perl5", "../common" ) );
}

use Zimbra::DockerLib;

$| = 1;
my $ENTRY_PID = $$;

## SECRETS AND CONFIGS #################################

my $MYSQL_PASSWORD = Secret("mysql.password");

## CONNECTIONS TO OTHER HOSTS ##########################


## THIS HOST LOCAL VARS ################################

chomp( my $THIS_HOST = `hostname -f` );
chomp( my $ZUID      = `id -u zimbra` );
chomp( my $ZGID      = `id -g zimbra` );

my $MYSQL_PORT = 7306;

## CONFIGURATION ENTRY POINT ###########################

EntryExec(
   seq => [

      #FIXME - manual permission fixed should not be required
      sub { { desc => "Creating required dirs", exec => { user => "root", args => [ "mkdir", "-p", "/opt/zimbra/index", "/opt/zimbra/store", "/opt/zimbra/mailboxd" ], }, }; },
      sub { { desc => "Fixing Ownership", exec => { user => "root", args => [ "chown", "-R", "zimbra.zimbra", "/opt/zimbra" ], }, }; },
      sub { { desc => "Fixing Permissions", exec => { user => "root", args => ["/opt/zimbra/libexec/zmfixperms"], }, }; },

      sub {
         {
            local_config => {
               zimbra_uid                 => $ZUID,
               zimbra_gid                 => $ZGID,
               zimbra_user                => "zimbra",
               zimbra_server_hostname     => $THIS_HOST,
               ssl_allow_untrusted_certs  => "false",
               ssl_allow_mismatched_certs => "false",
               mysql_bind_address         => "0.0.0.0",
               mysql_port                 => $MYSQL_PORT,
            },
         };
      },

      #######################################################################

      #FIXME - requires LDAP to work!!
      #sub { { desc => "Setting up syslog", exec => { user => "root", args => ["/opt/zimbra/libexec/zmsyslogsetup"], }, }; },

      sub { { desc => "Initialize and start MySQL", exec => { user => "zimbra", args => [ "/opt/zimbra/libexec/zmmyinit", "--sql_root_pw", $MYSQL_PASSWORD ], }, }; },

      #FIXME - is start required?
      sub { { desc => "Bringing up services", exec => { args => [ "/opt/zimbra/bin/mysql.server", "start" ], }, }; },

      sub { { publish_service => {}, }; },
   ],
);

END
{
   if ( $$ == $ENTRY_PID )
   {
      print "IF YOU ARE HERE, THEN AN ERROR HAS OCCURRED (^C to exit), OR ATTACH TO DEBUG\n";
      sleep
   }
}