use Mojo::Base -strict;

use Test::More;

use Mojo::Pg;

use Daje::Utils::Translations;

ok(get_query());
ok(get_translation_list());
ok(grid_header());
ok(details_headers());

sub details_headers{
	my $pg = Mojo::Pg->new->dsn("dbi:Pg:dbname=WebShop;host=81.216.60.23;port=15432;user=postgres;password=PV58nova64");
	my $tran = Daje::Utils::Translations->new(pg => $pg);
	my $stmt_default = qq{
		SELECT setting_value, setting_order, setting_properties FROM default_settings_values
			JOIN settings
		ON settings_pkey = settings_fkey
			WHERE setting_name = ?
		ORDER BY setting_order;
    };
	
	my $data->{basket_pkey} = '123';
	$data->{basketid} = '123456788';
	$data->{approved} = '0';
	$data->{status} = 'NEW';
	$data->{payment} = 'Invoice';
	
	my $field_list = $pg->db->query($stmt_default,('Basket_details_fields'))->hashes ;
	my $detail = $tran->details_headers('Basket_details_fields', $field_list, $data, 'swe');
	
	return exists $detail->{payment}->{order};
}

sub grid_header{
	
	my $pg = Mojo::Pg->new->dsn("dbi:Pg:dbname=WebShop;host=81.216.60.23;port=15432;user=postgres;password=PV58nova64");
	my $tran = Daje::Utils::Translations->new(pg => $pg);
	my $stmt_default = qq{
		SELECT setting_value, setting_order, setting_properties FROM default_settings_values
			JOIN settings
		ON settings_pkey = settings_fkey
			WHERE setting_name = ?
		ORDER BY setting_order;
    };
	my $field_list = $pg->db->query($stmt_default,('Basket_grid_fields'))->hashes ;
	my $headerlist = $tran->grid_header('Basket_grid_fields', $field_list, 'swe');
	
	return ref($headerlist) eq 'ARRAY';
}

sub get_translation_list{
	
	my $pg = Mojo::Pg->new->dsn("dbi:Pg:dbname=WebShop;host=81.216.60.23;port=15432;user=postgres;password=PV58nova64");
	my $tran = Daje::Utils::Translations->new(pg => $pg);
	my $stmt_default = qq{
		SELECT setting_value, setting_order, setting_properties FROM default_settings_values
			JOIN settings
		ON settings_pkey = settings_fkey
			WHERE setting_name = ?
		ORDER BY setting_order;
    };
	my $field_list = $pg->db->query($stmt_default,('Basket_grid_fields'))->hashes ;
	my $translist = $tran->get_translation_list('Basket_grid_fields', $field_list, 'swe');
	
	return ref($translist) eq 'ARRAY';
}

sub get_query{
	
	my $pg = Mojo::Pg->new->dsn("dbi:Pg:dbname=WebShop;host=81.216.60.23;port=15432;user=postgres;password=PV58nova64");
	my $tran = Daje::Utils::Translations->new(pg => $pg);
	my $stmt_default = qq{
		SELECT setting_value, setting_order, setting_properties FROM default_settings_values
			JOIN settings
		ON settings_pkey = settings_fkey
			WHERE setting_name = ?
		ORDER BY setting_order;
    };
	
	my $field_list = $pg->db->query($stmt_default,('Basket_grid_fields'))->hashes ;
	my $fields = $tran->get_query('Basket_grid_fields', $field_list, 'swe');
	
	return index($fields,'basket_item_pkey');
}


done_testing();