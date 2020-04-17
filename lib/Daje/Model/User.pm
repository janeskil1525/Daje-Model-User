package Daje::Model::User;
use Mojo::Base 'Daje::Utils::Sentinelsender';

our $VERSION = '1.3.6';

use Try::Tiny;
use Data::UUID;
use Data::Dumper;
use Digest::SHA qw{sha512_base64};

has 'pg';

sub save_user{
	my($self, $user) = @_;

	my $stmt;
	my $result;
	delete $user->{password} unless $user->{password};

	if (exists $user->{password}){
		$user->{passwd} = sha512_base64($user->{password});
		$stmt = qq{INSERT INTO users (username, userid, active, passwd, menu_group) VALUES (?,?,?,?,?)
                    ON CONFLICT (userid) DO UPDATE SET username = ?,
                    passwd = ?, moddatetime = now(), active = ?
                        RETURNING users_pkey};

		$result = try {
			$self->pg->db->query($stmt,(
				$user->{username},
				$user->{userid},
				$user->{active},
				$user->{passwd},
				$user->{menu_groupid},
				$user->{username},
				$user->{passwd},
				$user->{active}
			));
		}catch{
			$self->capture_message(
				'','Daje::Model::User::save_user with password', (ref $self),
				"Daje::Model::User::save_user"
				, $_
			);
		};
	}else{
		$stmt = qq{UPDATE users SET username = ?,
                        moddatetime = now(), active = ? WHERE userid = ?
                    RETURNING users_pkey};

		$result = try{
			$self->pg->db->query($stmt,(
				$user->{username},
				$user->{active},
				$user->{userid},
			));
		}catch{
			$self->capture_message(
				'','Daje::Model::User::save_user with no password', (ref $self),
				"Daje::Model::User::save_user"
				, $_
			);
		}
	}

	return $result;
}

sub save_user_p{
	my($self, $user) = @_;

	my $stmt;
	my $result;
	delete $user->{password} unless $user->{password};

	if (exists $user->{password}){
		$user->{passwd} = sha512_base64($user->{password});
		$stmt = qq{INSERT INTO users (username, userid, active, passwd, menu_group) VALUES (?,?,?,?,?)
                    ON CONFLICT (userid) DO UPDATE SET username = ?,
                    passwd = ?, moddatetime = now(), active = ?
                        RETURNING users_pkey};

		$result = $self->pg->db->query_p($stmt,(
			$user->{username},
			$user->{userid},
			$user->{active},
			$user->{passwd},
			$user->{menu_groupid},
			$user->{username},
			$user->{passwd},
			$user->{active}
		));
	}else{
		$stmt = qq{INSERT INTO users (username, userid, active, menu_group) VALUES (?,?,?,?)
                    ON CONFLICT (userid) DO UPDATE SET username = ?,
                        moddatetime = now(), active = ?
                    RETURNING users_pkey};

		$result = $self->pg->db->query_p($stmt,(
			$user->{username},
			$user->{userid},
			$user->{active},
			$user->{menu_groupid},
			$user->{username},
			$user->{active}
		));
	}

	return $result;
}

sub login{
	my($self, $user, $password) = @_;

	my $user_obj;
	$password = '' unless $password;

	my $passwd = sha512_base64($password);
	my $result = $self->pg->db->query("select * from users where userid = ? and passwd= ?",($user,$passwd));
	if($result->rows() > 0){
		$user_obj = $result->hash;
		my $ug = Data::UUID->new;
		my $token = $ug->create();
		$token = $ug->to_string($token);

		my $users_pkey = $user_obj->{users_pkey};

		$result = $self->pg->db->query(qq{INSERT INTO users_token (users_fkey, token) VALUES (?,?)
                                    ON CONFLICT (users_fkey) DO UPDATE SET token = ?,
                                        moddatetime = now()},
			($users_pkey, $token, $token));
		$user_obj->{token} = $token;
	}else{
		$user_obj->{token} = '';
		$user_obj->{error} = 'Username or password is incorrect';
	}

	return $user_obj ;
}

# Just check if user and password matches with some user in the databas
#
# Return number of hits, more than 0 and user is matched
#
sub login_light{ #scalar (userid, password)
	my($self, $user, $password) = @_;

	$password = '' unless $password;
	my $passwd = sha512_base64($password);
	my $result = $self->pg->db->query("select * from users where userid = ? and passwd= ?",($user,$passwd));
	return $result->rows() > 0;
}

sub authenticate{
	my ($self, $token) = @_;

	return $self->pg->db->query(qq{SELECT count(*) loggedin FROM users
                                    JOIN users_token  ON users_fkey = users_pkey
                                            WHERE token = ? },$token
	)->hash->{loggedin};
}

sub load_user{
	my($self, $users_pkey) = @_;

	my $stmt = qq{SELECT users_pkey, '' as password, companies_pkey, a.menu_group as menu_groupid ,
                            userid, username, b.menu_group, d.name, f.address1, f.address2,
                            f.address3, f.city, f.zipcode, f.country, '' as confirmpassword, a.active,
                            c.companies_fkey as companies_fkey
                            FROM users as a
                            JOIN menu_groups as b ON a.menu_group = menu_groups_pkey
                            JOIN users_companies as c ON a.users_pkey = c.users_fkey
                            JOIN companies as d  ON d.companies_pkey = c.companies_fkey
                            LEFT OUTER JOIN addresses_user as e ON e.users_fkey = a.users_pkey
                            LEFT OUTER  JOIN addresses as f ON f.addresses_pkey = e.addresses_fkey
                                            WHERE users_pkey = ? };

	return $self->pg->db->query($stmt,($users_pkey));

}

sub load_user_p{
	my($self, $users_pkey) = @_;

	my $stmt = qq{SELECT users_pkey, '' as password, companies_pkey, a.menu_group as menu_groupid ,
                            userid, username, b.menu_group, d.name, f.address1, f.address2,
                            f.address3, f.city, f.zipcode, f.country, '' as confirmpassword, a.active,
                            c.companies_fkey as companies_fkey
                            FROM users as a
                            JOIN menu_groups as b ON a.menu_group = menu_groups_pkey
                            JOIN users_companies as c ON a.users_pkey = c.users_fkey
                            JOIN companies as d  ON d.companies_pkey = c.companies_fkey
                            LEFT OUTER JOIN addresses_user as e ON e.users_fkey = a.users_pkey
                            LEFT OUTER  JOIN addresses as f ON f.addresses_pkey = e.addresses_fkey
                                            WHERE users_pkey = ? };

	return $self->pg->db->query_p($stmt,($users_pkey));

}
sub load_user_from_userid{
	my($self, $userid) = @_;

	my $stmt = qq{SELECT users_pkey, '' as password, companies_pkey, a.menu_group as menu_groupid ,
                            userid, username, b.menu_group, d.name, f.address1, f.address2,
                            f.address3, f.city, f.zipcode, f.country, '' as confirmpassword, a.active,
                            c.companies_fkey as companies_fkey
                            FROM users as a
                            JOIN menu_groups as b ON a.menu_group = menu_groups_pkey
                            JOIN users_companies as c ON a.users_pkey = c.users_fkey
                            JOIN companies as d  ON d.companies_pkey = c.companies_fkey
                            LEFT OUTER JOIN addresses_user as e ON e.users_fkey = a.users_pkey
                            LEFT OUTER  JOIN addresses as f ON f.addresses_pkey = e.addresses_fkey
                                            WHERE userid = ? };

	return $self->pg->db->query($stmt,($userid))->hash;
}

sub load_token_user_p{
	my($self, $token) = @_;

	my $stmt = qq{SELECT users_pkey, companies_pkey, a.menu_group as menu_groupid ,
                            userid, username, b.menu_group, d.name, f.address1, f.address2,
                            f.address3, f.city, f.zipcode, f.country, a.active, c.companies_fkey as companies_fkey
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

sub load_token_user{
	my($self, $token) = @_;

	my $stmt = qq{SELECT users_pkey, companies_pkey, a.menu_group as menu_groupid ,
                            userid, username, b.menu_group, d.name, f.address1, f.address2,
                            f.address3, f.city, f.zipcode, f.country, a.active, c.companies_fkey as companies_fkey
                            FROM users as a
                            JOIN menu_groups as b ON a.menu_group = menu_groups_pkey
                            JOIN users_companies as c ON a.users_pkey = c.users_fkey
                            JOIN companies as d  ON d.companies_pkey = c.companies_fkey
                            LEFT OUTER JOIN addresses_user as e ON e.users_fkey = a.users_pkey
                            LEFT OUTER JOIN addresses as f ON f.addresses_pkey = e.addresses_fkey
                            JOIN users_token as g ON g.users_fkey = a.users_pkey
                                            WHERE token = ? };

	return $self->pg->db->query($stmt,($token));

}


sub load_token_user_company_pkey{
	my($self, $token) = @_;

	my $stmt = qq{SELECT users_pkey, companies_pkey
                            FROM users as a
                            JOIN menu_groups as b ON a.menu_group = menu_groups_pkey
                            JOIN users_companies as c ON a.users_pkey = c.users_fkey
                            JOIN companies as d  ON d.companies_pkey = c.companies_fkey
                            LEFT OUTER JOIN addresses_user as e ON e.users_fkey = a.users_pkey
                            LEFT OUTER JOIN addresses as f ON f.addresses_pkey = e.addresses_fkey
                            JOIN users_token as g ON g.users_fkey = a.users_pkey
                                            WHERE token = ? };

	return $self->pg->db->query($stmt,($token));

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

sub get_company_fkey_from_token{
	my ($self, $token) = @_;

	my $stmt = qq{
                    SELECT b.companies_fkey
                        FROM users_token as a
                    JOIN users_companies as b
                        ON a.users_fkey = b.users_fkey
                    AND token = ?
                };

	return $self->pg->db->query($stmt,($token))->hash;
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
	my $support = 0;

	$support = $result->hash->{support} if($result->rows > 0);
	$result->finish();
	say "support '$support'";
	return $support;

}

sub set_setdefault_data{
	my ($self, $data) = @_;

	my $fields;
	($data, $fields) = Daje::Utils::Postgres::Columns->new(
		pg => $self->pg
	)->set_setdefault_data($data, 'users');

	return $data, $fields;
}

sub get_table_column_names {
	my $self = shift;

	my $fields;
	$fields = Daje::Utils::Postgres::Columns->new(
		pg => $self->pg
	)->get_table_column_names('users');

	return $fields;
}
1;


