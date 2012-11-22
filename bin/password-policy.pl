#!/usr/bin/env perl

use Net::LDAP;
use FindBin;
use JSON::Parse 'json_to_perl';

open my $qcontrol, '<', '/var/qmail/control/ldapbasedn';
my $base = <$qcontrol>;
close $qcontrol;
chomp($base);

print "Password plzz \n";
chomp($pass = <STDIN>);

my $cfg_loc = "$FindBin::Bin/../config/settings.json";
local $/;

open my $config_json, '<', $cfg_loc ;
my $json_txt = <$config_json>;
chomp($json_txt);
my $config = json_to_perl ($json_txt);
my $ldap = Net::LDAP->new("localhost", timeout=>10) or die "failed";
my $msg = $ldap->bind("uid=easypush,ou=People,$base", password=>"$pass");
my $base_search = $ldap->search( filter=>'(objectClass=qmailUser)', base=>"ou=people,$base") ;

my @base_entries = $base_search->entries;
my $exflag = 0;

foreach $base_entry (@base_entries) {
  my  $uidn = $base_entry->get_value(uid);
  my $search = $ldap->search( filter=>"(uid=$uidn)", base=>"ou=people,$base");

  my @entries = $search->entries;
  foreach my $exuser (@{ $config->{excluded_users} }) {
    $exflag = $exflag + 1 if($exuser eq $uidn );
    }
  #print "$exflag $uidn \n";
  if ( ( $search->count != 1 ) || ($exflag != 0)) {
    warn "entry not found or excluded user $uidn" ;
    $exflag=0;
    }

  else {
    my $dn = @entries[0]->dn;
    my $dse = int (time/86400);
    my $shadowMaxval  = $config->{expiry_days};
    my $shadowWarnval = $config->{warn_days};
    my @reparray;
    push @reparray, 'shadowMax', $shadowMaxval ;
    push @reparray, 'shadowWarning', $shadowWarnval ;
    push @reparray, 'shadowLastChange', $dse ;

    if ( $#reparray > 0 ){
      push @whatToChange, 'replace';
      push @whatToChange, \@reparray;
      }

    else {
       print "no changes folks";
       }

    my $result = $ldap->modify($dn,
                                 changes => [
                                              @whatToChange
                                            ]
                              );
 
    }
}  
