package Daje::Model::User;

use Mojo::Base -base;
our $VERSION = '0.2';

use Try::Tiny;
use Data::UUID;
use Data::Dumper;
use Digest::SHA qw{sha512_base64};

has 'pg';

sub init{
	my $self = shift;
	
	my $result = try{
		$self->pg->migrations->name('user')->from_data('Daje::Model::User', 'user.sql')->migrate(0);
		return $self;
	}catch{
		say $_;
		return ;
	};
}

sub save_user_p{
	my($self, $user) = @_;
	
	my $stmt = qq{INSERT INTO users as a
					(userid, username, passwd, menu_group)
				VALUES (?,?,?,?)
					ON CONFLICT (userid)
				DO UPDATE SET username = ?, passwd = ?, moddatetime = now()
				RETURNING users_pkey};
	say $stmt;
	my $passwd = sha512_base64($user->{password});
    my $result = $self->pg->db->query_p($stmt,
                (
                    $user->{userid},
                    $user->{username},
                    $user->{password},
                    $user->{menu_group},
                    $user->{username},
                    $passwd,
                 ));

}

sub login{
    my($self, $user, $password) = @_;
    
    my $user_obj;
	$password = '' unless $password;
	
	my $passwd = sha512_base64($password);
    my $result = $self->pg->db->query("select * from users where userid = ? and passwd= ?",($user,$passwd));
    say "'$user' and '$password'";
    say  "Rows  = " . $result->rows();
    if($result->rows() > 0){
        $user_obj = $result->hash;
        my $ug = Data::UUID->new;
        my $token = $ug->create();
        $token = $ug->to_string($token);
        
        my $users_pkey = $user_obj->{users_pkey};
       
        $result = $self->pg->db->query("INSERT INTO users_token (users_fkey, token) VALUES (?,?)
                                    ON CONFLICT (users_fkey) DO UPDATE SET token = ?,
                                    moddatetime = now()",($users_pkey, $token, $token));
        $user_obj->{token} = $token;
    }else{
        $user_obj->{token} = '';
        $user_obj->{error} = 'Username or password is incorrect';
    }
    
    return $user_obj ;
}

sub authenticate{
    my ($self, $token) = @_;
    
    return $self->pg->db->query(qq{SELECT count(*) loggedin FROM users 
                                    JOIN users_token  ON users_fkey = users_pkey
                                            WHERE token = ? },$token
                                )->hash->{loggedin};
}

sub load_user_p{
    my($self, $users_pkey) = @_;
    
    my $stmt = qq{SELECT users_pkey, '' as password, companies_pkey, a.menu_group as menu_groupid ,
                            userid, username, b.menu_group, d.name, f.address1, f.address2,
                            f.address3, f.city, f.zipcode, f.country, '' as confirmpassword
                            FROM users as a 
                            JOIN menu_groups as b ON a.menu_group = menu_groups_pkey
                            JOIN users_companies as c ON a.users_pkey = c.users_fkey
                            JOIN companies as d  ON d.companies_pkey = c.companies_fkey
                            LEFT OUTER JOIN addresses_user as e ON e.users_fkey = a.users_pkey
                            LEFT OUTER  JOIN addresses as f ON f.addresses_pkey = e.addresses_fkey
                                            WHERE users_pkey = ? };
    
    return $self->pg->db->query_p($stmt,($users_pkey));
     
}

sub load_token_user_p{
    my($self, $token) = @_;
    
    my $stmt = qq{SELECT users_pkey, companies_pkey, a.menu_group as menu_groupid ,
                            userid, username, b.menu_group, d.name, f.address1, f.address2,
                            f.address3, f.city, f.zipcode, f.country, 
                            FROM users as a 
                            JOIN menu_groups as b ON a.menu_group = menu_groups_pkey
                            JOIN users_companies as c ON a.users_pkey = c.users_fkey
                            JOIN companies as d  ON d.companies_pkey = c.companies_fkey
                            LEFT OUTER JOIN addresses_user as e ON e.users_fkey = a.users_pkey
                            LEFT OUTER JOIN addresses as f ON f.addresses_pkey = e.addresses_fkey
                            JOIN users_token as g ON g.users_fkey = a.users_pkey
                                            WHERE token = ? };
    
    return $self->pg->db->query_p($stmt,($token));
    
}

sub get_company_fkey_from_token_p{
	my ($self, $token) = @_;
    
    my $stmt = qq{
                    SELECT b.companies_fkey
                        FROM users_token as a
                    JOIN users_companies as b
                        ON a.users_fkey = b.users_fkey
                    AND token = ?                          
                };
                                            
     return $self->pg->db->query_p($stmt,($token));
}

sub isSupport{
    my ($self, $token) = @_;
    
    my $stmt = qq{
                    SELECT b.support
                        FROM users_token as a
                    JOIN users as b
                        ON a.users_fkey = b.users_pkey
                    AND token = ?                          
                };
                                            
    my $result = $self->pg->db->query($stmt,($token));
    my $support = $result->hash->{support};
    $result->finish();
    say "support '$support'";
    return $support;

}
1;

__DATA__

@@ user.sql

-- 1 up


-- 1 down